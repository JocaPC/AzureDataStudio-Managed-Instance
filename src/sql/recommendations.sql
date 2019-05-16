SET QUOTED_IDENTIFIER OFF;

IF( SERVERPROPERTY('EngineEdition') = 8 )
BEGIN;

WITH a as (
SELECT
name = 'HIGH_VLF_COUNT',
reason = CAST(count(*) AS VARCHAR(6)) + ' VLF in ' + name + ' file',
score = CAST(1-EXP(-count(*)/100.) AS NUMERIC(6,2))*100,
[state] = 'Mitigate' COLLATE Latin1_General_100_CI_AS,
script = CONCAT("USE [", DB_NAME(mf.database_id),"];DBCC SHRINKFILE (N'",name,"', 1, TRUNCATEONLY);"),
details = (SELECT [file] = name, db = DB_NAME(mf.database_id), vlf_count = count(*), recommended_script = 'https://github.com/Microsoft/tigertoolbox/tree/master/Fixing-VLFs' FOR JSON PATH, WITHOUT_ARRAY_WRAPPER)
from sys.master_files mf
cross apply sys.dm_db_log_info(mf.database_id) li
where li.file_id = mf.file_id
group by mf.database_id, mf.file_id, name
having count(*) > 50
UNION ALL
select	name = 'MEMORY_PRESSURE',
		reason = CONCAT('Page life expectancy ', v.cntr_value,
						' lower than ', (((l.cntr_value*8/1024)/1024)/4)*300,
						' on ', RTRIM(v.object_name))
		, score = 100*(1 - EXP (
			- CASE WHEN l.cntr_value > 0
				THEN (((l.cntr_value*8./1024)/1024)/4)*300 
				ELSE 0
			END / v.cntr_value ))
		, state = 'Investigate' COLLATE Latin1_General_100_CI_AS
		, script = 'N/A: Add more memory or find the queries that use most of memory.'
		, details = 'Check PAGEIOLATCH wait statistics to verify is the problem in memory usage.'
from sys.dm_os_performance_counters v
join sys.dm_os_performance_counters l on v.object_name = l.object_name
where v.counter_name = 'Page Life Expectancy'
and l.counter_name = 'Database pages'
and l.object_name like '%Buffer Node%'
and (CASE WHEN l.cntr_value > 0 THEN (((l.cntr_value*8./1024)/1024)/4)*300 ELSE NULL END) / v.cntr_value > 1
UNION ALL
SELECT	name, reason, score,
		[state] = JSON_VALUE(state, '$.currentValue'),
        script = JSON_VALUE(details, '$.implementationDetails.script'),
        details
FROM sys.dm_db_tuning_recommendations


UNION ALL
SELECT	name = 'AZURE_STORAGE_35_TB_LIMIT',
		reason = 'Remaining number of database files is low',
		score = (alloc.size_tb/35.)*100,
		[state] = 'Warning' COLLATE Latin1_General_100_CI_AS, script = NULL,
		details = CONCAT( 'You cannot create more than ', (35 - alloc.size_tb) * 8, ' additional database files.')
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
SELECT name = 'STORAGE_LIMIT',
		reason = CASE CAST(volume_mount_point as CHAR(1))
		WHEN 'C' THEN 'Reaching TempDB size limit on local storage.'
		ELSE 'Reaching storage size limit on instance.'
		END,
		score = used_gb/total_gb,
		[state] = 'Mitigate' COLLATE Latin1_General_100_CI_AS,
		script = 'Use the Azure portal, PowerShell, or Azure CLI to increase the instance storage.' COLLATE Latin1_General_100_CI_AS,
		details = CONCAT( 'You are using ' , used_gb,'GB out of ', total_gb, 'GB')
from (SELECT	volume_mount_point,
		used_gb = CAST(MIN(total_bytes / 1024. / 1024 / 1024) AS NUMERIC(8,1)),
		available_gb = CAST(MIN(available_bytes / 1024. / 1024 / 1024) AS NUMERIC(8,1)),
		total_gb = CAST(MIN((total_bytes+available_bytes) / 1024. / 1024 / 1024) AS NUMERIC(8,1))
	FROM sys.master_files AS f
	CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.file_id)
	GROUP BY volume_mount_point) volumes(volume_mount_point, used_gb, available_gb, total_gb)
WHERE used_gb/total_gb > .8
UNION ALL
SELECT name = 'STORAGE_LIMIT',
		reason = 'Reaching storage size limit on instance',
		score = 100*storage_usage_perc*storage_usage_perc,
		[state] = 'Mitigate' COLLATE Latin1_General_100_CI_AS,
		script = 'Use the Azure portal, PowerShell, or Azure CLI to increase the instance storage.',
		details = CONCAT( 'In 2 hours the instance will probably reach ' , CAST(storage_usage_perc AS NUMERIC(4,2)), '% of your storage - increase the instance storage now.')
from (
select top 1 storage_usage_perc =
(storage_space_used_mb +
((storage_space_used_mb - lead (storage_space_used_mb, 100) over (order by start_time desc))
	/
DATEDIFF(mi, lead (start_time, 100) over (order by start_time desc), start_time))  * 120)
/ reserved_storage_mb
from master.sys.server_resource_stats
where storage_space_used_mb > (.8 * reserved_storage_mb) -- ignore if the current storage is less than 80%
order by start_time desc
) a(storage_usage_perc)
WHERE a.storage_usage_perc > .8
UNION ALL
SELECT	name = 'CPU_PRESSURE',
		reason = CONCAT('High CPU usage ', cpu ,'% on the instance in past hour.'),
		score = cpu,
		[state] = 'Investigate' COLLATE Latin1_General_100_CI_AS,
		script = 'N/A: Find top queries that are using a lot of CPU and optimize them or add more cores by upgrading the instance.',
		details = CONCAT( 'Instance is using ', cpu, '% of CPU.')
FROM (select cpu = AVG(avg_cpu_percent)
	from master.sys.server_resource_stats
	where start_time > DATEADD(hour , -1, GETUTCDATE())) as usage(cpu)
where cpu > 90
UNION ALL
select
        name = wait_type COLLATE Latin1_General_100_CI_AS,
		reason = CASE wait_type
                    WHEN 'INSTANCE_LOG_RATE_GOVERNOR' THEN CONCAT('Reaching ',
                     (SELECT TOP 1 CASE WHEN sku = 'General Purpose' THEN '22'
                                ELSE '48' END
                        from master.sys.server_resource_stats
                        where start_time > DATEADD(minute , -10, GETUTCDATE())), ' MB/s instance log rate limit.' )
                    WHEN 'WRITELOG' THEN 'Potentially reaching the IO limits of log file.'
                    ELSE 'Potentially reaching the IO limit of data file.'
                END COLLATE Latin1_General_100_CI_AS,
        score = 80.,
		[state] = 'Investigate' COLLATE Latin1_General_100_CI_AS,
        script = 'N/A: this is Managed Instance limit' COLLATE Latin1_General_100_CI_AS,
		details = null
 from (select top 10 *
from sys.dm_os_wait_stats
order by wait_time_ms desc) as ws
where wait_type in ('INSTANCE_LOG_RATE_GOVERNOR', 'WRITELOG')
or wait_type like 'PAGEIOLATCH%'
)
select * from a order by score desc;
END
