select top 200
    start_time,
    [storage usage %] = storage_space_used_mb/reserved_storage_mb *100,
    [cpu usage %] = avg_cpu_percent
from sys.server_resource_stats
order by start_time desc