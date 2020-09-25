IF( SERVERPROPERTY('EngineEdition') = 8 )
select
    [time] = CONVERT(VARCHAR(5), CAST(start_time AS smalldatetime), 108),
    [storage usage %] = AVG(storage_space_used_mb)/AVG(reserved_storage_mb) *100,
    [cpu usage %] = AVG(avg_cpu_percent),
	--> applicable to BC, you will never reach 100% on GP because you will probably hit some db file IOPS limit before this.
	[iops %] = CAST(max(100.*io_requests) 
				/	DATEDIFF(s, MIN(start_time), MAX(end_time) )
				/	(4000.*MAX(virtual_core_count))  AS NUMERIC(5,1)),
	[mbps %] = CAST(max(io_bytes_read+io_bytes_written) *100./1024./1024 
				/	DATEDIFF(s, min(start_time), MAX(end_time))
				/	(60*MAX(virtual_core_count)) AS NUMERIC(5,1)) --> no hard-limit in instance but let me know if you succeed to reach 60MB/s per core :)
from master.sys.server_resource_stats
where start_time >= DATEADD(hh, -1, GETUTCDATE())
group by CAST(start_time AS smalldatetime)
order by CAST(start_time AS smalldatetime) asc