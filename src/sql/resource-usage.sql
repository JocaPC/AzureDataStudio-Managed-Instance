IF( SERVERPROPERTY('EngineEdition') = 8 )
select
    [time] = CONVERT(VARCHAR(5), CAST(start_time AS smalldatetime), 108),
    [storage usage %] = AVG(storage_space_used_mb)/AVG(reserved_storage_mb) *100,
    [cpu usage %] = AVG(avg_cpu_percent),
	[IOPS %] = 	CAST(
                100 * (
					(SUM(io_requests) / DATEDIFF(SECOND, MIN(start_time), MAX(end_time) ) )
					/
					1375. * MIN(virtual_core_count)
				)
                AS NUMERIC(6,1))
				,
	[write %] = CAST(
                100 * ( SUM(io_bytes_written)/1024./1024 / DATEDIFF(SECOND, MIN(start_time), MAX(end_time) ) )
				/
				CASE(MIN(sku))
				WHEN 'GeneralPurpose' THEN 22 -- MB/s
				ELSE 
					CASE 
						WHEN MIN(virtual_core_count) < 16 THEN 3 * MIN(virtual_core_count) -- MB/s
						ELSE 48 -- MB/s
					END
				END AS NUMERIC(6,1))
from master.sys.server_resource_stats
where start_time >= DATEADD(hh, -1, GETUTCDATE())
group by CAST(start_time AS smalldatetime)
order by CAST(start_time AS smalldatetime) asc
