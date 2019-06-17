IF( SERVERPROPERTY('EngineEdition') = 8 )
WITH 
sku as 
(select top 1 service_tier = sku, virtual_core_count, hardware_generation, max_storage_gb = reserved_storage_mb/1024
	from master.sys.server_resource_stats
	where start_time > DATEADD(mi, -7, GETUTCDATE())
    order by start_time desc) ,
volumes as (
SELECT	Storage = CASE WHEN volume_mount_point = 'http://' THEN 'Remote storage'
                        ELSE 'Local SSD'
                    END,
		[GB Used] = CAST(MIN(total_bytes / 1024. / 1024 / 1024) AS NUMERIC(8,1)),
		[GB Available] = CAST(MIN(available_bytes / 1024. / 1024 / 1024) AS NUMERIC(8,1)),
		[GB Total] = CAST(MIN((total_bytes+available_bytes) / 1024. / 1024 / 1024) AS NUMERIC(8,1))
FROM sys.master_files AS f
CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.file_id)
GROUP BY volume_mount_point)
SELECT [(on local SSD):] = case 
                when sku.service_tier = 'GeneralPurpose' then 'TempDB'
                else 'TempDB, user and system databases'
            end,
        [GB Used], [GB Available], [GB Total]
FROM volumes, sku
WHERE volumes.Storage = 'Local SSD'
;