SET QUOTED_IDENTIFIER OFF;

IF( SERVERPROPERTY('EngineEdition') = 8 )
BEGIN;

WITH a as (
SELECT
name = 'HIGH_VLF_COUNT' COLLATE Latin1_General_100_CI_AS,
reason = (CAST(count(*) AS VARCHAR(6)) + ' VLF in ' + DB_NAME(mf.database_id)) COLLATE Latin1_General_100_CI_AS,
score = CAST(1-EXP(-count(*)/100.) AS NUMERIC(6,2))*100,
[state] = 'Mitigate' COLLATE Latin1_General_100_CI_AS,
script = CONCAT("USE [", DB_NAME(mf.database_id),"];DBCC SHRINKFILE (N'",name,"', 1, TRUNCATEONLY);") COLLATE Latin1_General_100_CI_AS,
details = (CAST(count(*) AS VARCHAR(6)) + ' VLF can cause unavailability of ' + DB_NAME(mf.database_id) + " after failover. Shrink log file using 'https://github.com/Microsoft/tigertoolbox/tree/master/Fixing-VLFs'") COLLATE Latin1_General_100_CI_AS
from sys.master_files mf
cross apply sys.dm_db_log_info(mf.database_id) li
where li.file_id = mf.file_id
group by mf.database_id, mf.file_id, name
having count(*) > 50
UNION ALL
select	name = 'MEMORY_PRESSURE' COLLATE Latin1_General_100_CI_AS,
		reason = CONCAT('PLE ', v.cntr_value,
						' lower than ', (((300*l.cntr_value*8/1024)/1024)/4)) COLLATE Latin1_General_100_CI_AS
		, score = ROUND(100*(1 - EXP (
			- CASE WHEN l.cntr_value > 0
				THEN (((l.cntr_value*8./1024)/1024)/4)*300 
				ELSE 0
			END / v.cntr_value )),0)
		, state = 'Investigate' COLLATE Latin1_General_100_CI_AS
		, script = 'Add more memory or find the queries that use most of memory.' COLLATE Latin1_General_100_CI_AS
		, details = CONCAT('Page life expectency ', v.cntr_value,
						' is lower than ', (((300*l.cntr_value*8/1024)/1024)/4),
						' on ', RTRIM(v.object_name),'. Check PAGEIOLATCH and RESOURCE_SEMAPHORE wait statistics to verify is the problem in memory usage.') COLLATE Latin1_General_100_CI_AS
from sys.dm_os_performance_counters v
join sys.dm_os_performance_counters l on v.object_name = l.object_name
where v.counter_name = 'Page Life Expectancy'
and l.counter_name = 'Database pages'
and l.object_name like '%Buffer Node%'
and (CASE WHEN l.cntr_value > 0 THEN (((l.cntr_value*8./1024)/1024)/4)*300 ELSE NULL END) / v.cntr_value > 1
UNION ALL
SELECT	name COLLATE Latin1_General_100_CI_AS, reason COLLATE Latin1_General_100_CI_AS, score,
		[state] = JSON_VALUE(state, '$.currentValue') COLLATE Latin1_General_100_CI_AS,
        script = JSON_VALUE(details, '$.implementationDetails.script') COLLATE Latin1_General_100_CI_AS,
        details COLLATE Latin1_General_100_CI_AS
FROM sys.dm_db_tuning_recommendations
UNION ALL
SELECT	name = 'AZURE_STORAGE_35_TB_LIMIT' COLLATE Latin1_General_100_CI_AS,
		reason = CONCAT((35 - alloc.size_tb) * 8, ' remaining files') COLLATE Latin1_General_100_CI_AS,
		score = (alloc.size_tb/35.)*100,
		[state] = 'Warning' COLLATE Latin1_General_100_CI_AS, script = NULL,
		details = CONCAT( 'You cannot create more than ', (35 - alloc.size_tb) * 8, ' additional database files.') COLLATE Latin1_General_100_CI_AS
FROM
( SELECT
SUM(CASE WHEN  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  <= 128 THEN 128
WHEN  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  > 128 AND  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  <= 256 THEN 256
WHEN  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  > 256 AND  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  <= 512 THEN 512
WHEN  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  > 512 AND  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  <= 1024 THEN 1024
WHEN  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  > 1024 AND  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  <= 2048 THEN 2048
WHEN  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  > 2048 AND  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  <= 4096 THEN 4096
ELSE 8192
END)/1024
FROM master.sys.master_files
WHERE physical_name LIKE 'https:%') AS alloc(size_tb)
WHERE alloc.size_tb > 30
UNION ALL
SELECT name = 'STORAGE_LIMIT' COLLATE Latin1_General_100_CI_AS,
		reason = CASE CAST(volume_mount_point as CHAR(1))
		WHEN 'C' THEN CONCAT('Reaching ',CAST(100*used_gb/total_gb as INT), '% of max TempDB size.')
		ELSE CONCAT('Reaching ',CAST(100*used_gb/total_gb as INT),'% of storage limit.')
		END COLLATE Latin1_General_100_CI_AS,
		score = CAST(100*used_gb/total_gb as INT),
		[state] = 'Mitigate' COLLATE Latin1_General_100_CI_AS,
		script = 'Use the Azure portal, PowerShell/CLI to add more storage.' COLLATE Latin1_General_100_CI_AS,
		details = CONCAT( 'You are using ' , used_gb,'GB out of ', total_gb, 'GB') COLLATE Latin1_General_100_CI_AS
from (SELECT	volume_mount_point,
		used_gb = CAST(MIN(total_bytes / 1024. / 1024 / 1024) AS NUMERIC(8,1)),
		available_gb = CAST(MIN(available_bytes / 1024. / 1024 / 1024) AS NUMERIC(8,1)),
		total_gb = CAST(MIN((total_bytes+available_bytes) / 1024. / 1024 / 1024) AS NUMERIC(8,1))
	FROM sys.master_files AS f
	CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.file_id)
	GROUP BY volume_mount_point) volumes(volume_mount_point, used_gb, available_gb, total_gb)
WHERE used_gb/total_gb > .8
UNION ALL
SELECT name = 'STORAGE_LIMIT' COLLATE Latin1_General_100_CI_AS,
		reason = CONCAT('Reaching ',storage_usage_perc,'% of storage') COLLATE Latin1_General_100_CI_AS,
		score = ROUND(100*storage_usage_perc*storage_usage_perc,0),
		[state] = 'Mitigate' COLLATE Latin1_General_100_CI_AS,
		script = 'Use the Azure portal, PowerShell, or Azure CLI to increase the instance storage.' COLLATE Latin1_General_100_CI_AS,
		details = CONCAT( 'Storage increased from ' , delta_storage_gb , ' GB to ',
                             storage_space_used_gb, ' GB in past ', delta_mi, ' min. In may reach ',
                             storage_space_estimated_gb, ' GB in 2 hours. Increase the instance storage now.') COLLATE Latin1_General_100_CI_AS
from (
select top 1 storage_usage_perc =
(storage_space_used_mb +
((storage_space_used_mb - lead (storage_space_used_mb, 100) over (order by start_time desc))
	/
DATEDIFF(mi, lead (start_time, 100) over (order by start_time desc), start_time))  * 120)
/ reserved_storage_mb,
storage_space_used_gb = CAST(storage_space_used_mb/1000 AS NUMERIC(8,0)),
storage_space_estimated_gb = CAST((storage_space_used_mb +
((storage_space_used_mb - lead (storage_space_used_mb, 100) over (order by start_time desc))
	/
DATEDIFF(mi, lead (start_time, 100) over (order by start_time desc), start_time))  * 120)/1000 AS NUMERIC(8,0)),
delta_mi = DATEDIFF(mi, lead (start_time, 1000) over (order by start_time desc), start_time),
delta_storage_gb =  CAST(lead (storage_space_used_mb, 100) over (order by start_time desc)/1000 AS NUMERIC(8,0))
from master.sys.server_resource_stats
order by start_time desc
) a(storage_usage_perc, storage_space_used_gb, storage_space_estimated_gb, delta_mi, delta_storage_gb)
WHERE a.storage_usage_perc > .8
AND 1.1 * storage_space_used_gb < storage_space_estimated_gb
UNION ALL
SELECT	name = 'CPU_PRESSURE' COLLATE Latin1_General_100_CI_AS,
		reason = CONCAT(cpu ,'% used on in past hour.') COLLATE Latin1_General_100_CI_AS,
		score = cpu,
		[state] = 'Investigate' COLLATE Latin1_General_100_CI_AS,
		script = 'N/A' COLLATE Latin1_General_100_CI_AS,
		details = CONCAT( 'Instance is using ', cpu, '% of CPU. Find the top queries that are using a lot of CPU and optimize them or add more cores by upgrading the instance.') COLLATE Latin1_General_100_CI_AS
FROM (select cpu = AVG(avg_cpu_percent)
	from master.sys.server_resource_stats
	where start_time > DATEADD(hour , -1, GETUTCDATE())) as usage(cpu)
where cpu > 90
UNION ALL
SELECT	name = command COLLATE Latin1_General_100_CI_AS,
		reason = command COLLATE Latin1_General_100_CI_AS,
		score = CASE command
                    WHEN 'RESTORE DATABASE' THEN 40.
                    WHEN 'BACKUP DATABASE' THEN 60.
					WHEN 'BACKUP LOG' THEN 30.
					ELSE 60.
                END,
		[state] = 'Info' COLLATE Latin1_General_100_CI_AS,
		script = NULL,
		details = CONCAT(cnt, ' ', command, 
        CASE
			WHEN cnt = 1 THEN ' request is currently in progress'
        	ELSE ' requests are currently in progress'
        END) COLLATE Latin1_General_100_CI_AS    
FROM (SELECT r.command, cnt = count(*)
FROM sys.dm_exec_requests r WHERE command IN ('RESTORE DATABASE','BACKUP DATABASE','BACKUP LOG','RESTORE LOG')
GROUP BY command) bre (command, cnt)
UNION ALL
SELECT	name = CASE name
					WHEN 'read_time_ms' THEN 'SLOW_MEMORY_LOAD'
					ELSE 'DIRTY_MEMORY'
				END COLLATE Latin1_General_100_CI_AS,
		reason = CASE name
					WHEN 'read_time_ms' THEN CONCAT(value, 'ms to load pages in memory.')
					ELSE CONCAT(value, '% memory is modified')
				END COLLATE Latin1_General_100_CI_AS,
		score = CASE name
					WHEN 'read_time_ms' THEN 80
					ELSE IIF(2*value>=100, 100, 2*value)
				END,
			[state] = 'Mitigate' COLLATE Latin1_General_100_CI_AS,
			script = 'N/A' + CASE name
					WHEN 'read_time_ms' THEN '. Investigate data IO statistics.'
					ELSE '. Limit workload using Resource Governor.'
				END COLLATE Latin1_General_100_CI_AS,
			details = CASE name
					WHEN 'read_time_ms' THEN 'Slow memory load in ' + db_name + ' indicates IO issues on data files. On GP find data files with big read latency.'
					ELSE 'Database ' + db_name + ' cannot save all changes to data file. Possible unavailability if system crash.'
				END COLLATE Latin1_General_100_CI_AS
FROM   
   (
SELECT		db_name = db_name(database_id),
			read_time_ms = CAST( (AVG(read_microsec)/1000.) AS INT),
			modified_perc = CAST( (100.*SUM(CASE WHEN is_modified = 1 THEN 1 ELSE 0 END))/COUNT_BIG(*) AS INT)
FROM sys.dm_os_buffer_descriptors
WHERE database_id BETWEEN 5 AND 32760 --> to exclude system databases
GROUP BY database_id
HAVING COUNT_BIG(*) > 100--1000 --> bigger that 8GB
) p  
UNPIVOT  
   (value FOR name IN   
      (read_time_ms, modified_perc)  
) AS unpvt
WHERE value > (CASE name
		WHEN 'read_time_ms' THEN 50 -- ignore load time less than 50ms
		ELSE 10 -- ignore less than 10% of dirty pages
	END)
UNION ALL
select
        name = wait_type COLLATE Latin1_General_100_CI_AS,
		reason = CASE wait_type
                    WHEN 'INSTANCE_LOG_RATE_GOVERNOR' THEN 'Possible instance write limit.'
                    WHEN 'WRITELOG' THEN 'Possible log IO limit.'
					WHEN 'RESOURCE_SEMAPHORE' THEN 'Possible memory pressure.'
                    ELSE 'Data IO limit or memory pressure.'
                END COLLATE Latin1_General_100_CI_AS,
        score = CASE wait_type
                    WHEN 'INSTANCE_LOG_RATE_GOVERNOR' THEN 80.
                    WHEN 'WRITELOG' THEN 60.
					WHEN 'RESOURCE_SEMAPHORE' THEN 40.
                    ELSE 50.
                END,
		[state] = 'Investigate' COLLATE Latin1_General_100_CI_AS,
        script = CASE wait_type
                    WHEN 'INSTANCE_LOG_RATE_GOVERNOR' THEN 'N/A: This is fixed resource limit.' 
					WHEN 'WRITELOG' THEN 'Increase log file that is using a lot of IOPS.'
                    WHEN 'RESOURCE_SEMAPHORE' THEN 'Optimize top memory consumers or add more cores/memory.'
					ELSE 'Increase size of data file with IO pressure on General Purpose.'
                END COLLATE Latin1_General_100_CI_AS,
		details = CASE wait_type
                    WHEN 'INSTANCE_LOG_RATE_GOVERNOR' THEN 'Instance and database have log rate limit so they can catch-up and backup all changes.'
                    WHEN 'WRITELOG' THEN 'Queries are waiting log entries to be written.'
					WHEN 'RESOURCE_SEMAPHORE' THEN 'It is possible that some queries causing memory presure and trying to aquire the page.'
                    ELSE 'Instance may not succeed to save the memory pages to the data files as they are changed, or has problem fetching the missing pages in memory.'
                END COLLATE Latin1_General_100_CI_AS       
 from (select top 10 *
from sys.dm_os_wait_stats
order by wait_time_ms desc) as ws
where wait_type in ('INSTANCE_LOG_RATE_GOVERNOR', 'WRITELOG')
or wait_type like 'PAGEIOLATCH%'
)
select * from a order by score desc;
END
