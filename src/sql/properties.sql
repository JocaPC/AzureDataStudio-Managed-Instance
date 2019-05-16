IF( SERVERPROPERTY('EngineEdition') = 8 )
select
    [Cores] = virtual_core_count, 
    [Memory] = CASE 
    WHEN hardware_generation = 'Gen4' THEN CONCAT(7 * virtual_core_count, ' GB')
    ELSE CONCAT(5.1 * virtual_core_count, ' GB')
    END,
    [Max storage] = CONCAT(max_storage_gb , ' GB'),
    [Service tier] = service_tier,
    [Hardware generation] = hardware_generation, 
	[Log rate(max)] = 
    CASE 
    WHEN service_tier = 'GeneralPurpose' THEN CONCAT(22, ' MB/s')
    WHEN service_tier = 'BusinessCritical' AND virtual_core_count <= 48/4 THEN CONCAT(virtual_core_count *4, ' MB/s')
    ELSE '48 MB/s'
    END,
    [Data rate] = 
    CASE 
    WHEN service_tier = 'GeneralPurpose' THEN '100-250 MB/s/file'
    ELSE CONCAT(24 * virtual_core_count, ' MB/s')
    END,
    [IOPS] = 
    CASE 
    WHEN service_tier = 'GeneralPurpose' THEN '500-7500/file'
    ELSE CONCAT(' ',1375 * virtual_core_count)
    END,
    [Max tempdb size] = 
    CASE 
    WHEN service_tier = 'GeneralPurpose' THEN CONCAT(24 * virtual_core_count, ' GB')
    ELSE CONCAT(max_storage_gb, ' GB')
    END
FROM sys.dm_os_sys_info

	, (select top 1 service_tier = sku, virtual_core_count, hardware_generation, max_storage_gb = reserved_storage_mb/1024
	from master.sys.server_resource_stats
	where start_time > DATEADD(mi, -7, GETUTCDATE())
    order by start_time desc) as srs
