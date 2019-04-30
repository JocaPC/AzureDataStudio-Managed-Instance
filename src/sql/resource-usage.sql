IF( SERVERPROPERTY('EngineEdition') = 8 )
select
    [time] = start_time,
    [storage usage %] = storage_space_used_mb/reserved_storage_mb *100,
    [cpu usage %] = avg_cpu_percent
from master.sys.server_resource_stats
where start_time >= DATEADD(hh, -1, GETUTCDATE())
order by start_time asc