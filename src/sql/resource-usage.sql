IF( SERVERPROPERTY('EngineEdition') = 8 )
select
    [time] = CAST(start_time AS smalldatetime),
    [storage usage %] = AVG(storage_space_used_mb)/AVG(reserved_storage_mb) *100,
    [cpu usage %] = AVG(avg_cpu_percent)
from master.sys.server_resource_stats
where start_time >= DATEADD(hh, -1, GETUTCDATE())
group by CAST(start_time AS smalldatetime)
order by CAST(start_time AS smalldatetime) asc