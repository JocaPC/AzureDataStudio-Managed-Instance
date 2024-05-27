IF( SERVERPROPERTY('EngineEdition') = 8 )
select
    [Cores] = virtual_core_count, 
    [Memory] = CASE 
    WHEN hardware_generation = 'Gen4' THEN CONCAT(7 * virtual_core_count, ' GB')
    WHEN hardware_generation = 'Gen5' THEN CONCAT(5.1 * virtual_core_count, ' GB')
    WHEN hardware_generation = 'Gen6' THEN CONCAT(5.1 * virtual_core_count, ' GB')
    WHEN hardware_generation = 'Gen7' THEN CONCAT(5.1 * virtual_core_count, ' GB')
    WHEN hardware_generation = 'Gen8IM' THEN CONCAT(LEAST(7 * virtual_core_count, 560), ' GB')
    WHEN hardware_generation = 'Gen8IH' THEN CONCAT(LEAST(13.6 * virtual_core_count, 870.4), ' GB')
    ELSE CONCAT(5.1 * virtual_core_count, ' GB')
    END,
    [Max storage] = CONCAT(max_storage_gb , ' GB'),
    [Service tier] = service_tier,
    [Next-Gen General Purpose] = mf.[Next-Gen General Purpose],
    [Hardware generation] = hardware_generation, 
    [Log write rate(max)] =
    CASE 
    WHEN service_tier = 'GeneralPurpose' and mf.[Next-Gen General Purpose] = 'false' THEN CONCAT(LEAST(4.5 * virtual_core_count, 120), ' MB/s')
    ELSE CONCAT(LEAST(4.5 * virtual_core_count, 192), ' MB/s')
    END,
    [Data rate] = 
    CASE 
    WHEN service_tier = 'GeneralPurpose' and mf.[Next-Gen General Purpose] = 'false' THEN '100-250 MB/s/file'
    WHEN service_tier = 'GeneralPurpose' and mf.[Next-Gen General Purpose] = 'true' THEN 'IOPS / 30 MBps included free of charge'
    ELSE 'Up to VM limits'
    END,
    [IOPS] = 
    CASE 
    WHEN service_tier = 'GeneralPurpose' and mf.[Next-Gen General Purpose] = 'false' THEN '500-7500/file'
    WHEN service_tier = 'GeneralPurpose' and mf.[Next-Gen General Purpose] = 'true' THEN '3 IOPS per GB of storage included free of charge'
    ELSE CONCAT(' ', LEAST(4000* virtual_core_count, 320000))
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

    , (select top 1
    case
        when physical_name like 'C:\ManagedDisks%' then 'True'
        else 'False'
    end as [Next-Gen General Purpose]
    from sys.master_files
    where database_id = 1
    and type_desc = 'log') as mf