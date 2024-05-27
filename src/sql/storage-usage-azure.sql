IF( SERVERPROPERTY('EngineEdition') = 8 )
WITH gp_stats ([Remaining GP files])
AS (
SELECT  --[Allocated TB] = CONCAT(CAST(size_tb as [tinyint]), 'TB out of 35TB'),
		[Remaining GP files] = CAST((35 - size_tb) * 8 AS int)
FROM
( SELECT
        SUM(CASE
                WHEN  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  <= 128
                    THEN 128
                WHEN  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  > 128 AND  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  <= 512
                    THEN 512
                WHEN  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  > 512 AND  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  <= 1024
                    THEN 1024
                WHEN  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  > 1024 AND  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  <= 2048
                    THEN 2048
                WHEN  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  > 2048 AND  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  <= 4096
                    THEN 4096
                ELSE 8192
        END)/1024.
    FROM master.sys.master_files
    WHERE physical_name LIKE 'https:%'
) AS alloc(size_tb)),
next_gen_gp_stats ([Remaining Next-Gen files])
AS (
SELECT
		[Remaining Next-Gen files] = CAST((32768 - file_count) AS int)
FROM
( SELECT COUNT(*)
    FROM master.sys.master_files
    WHERE physical_name LIKE 'C:\ManagedDisks%'
) AS alloc(file_count)),
volumes as (
SELECT	Storage = CASE
                    WHEN f.physical_name LIKE 'C:\ManagedDisks%' THEN 'Premium Managed Disks'
                    WHEN f.physical_name LIKE 'https%' THEN 'Premium Page Blobs'
                    ELSE 'Local SSD'
                  END,
		[GB Used] = CAST(MIN(total_bytes / 1024. / 1024 / 1024) AS NUMERIC(8,1)),
		[GB Available] = CAST(MIN(available_bytes / 1024. / 1024 / 1024) AS NUMERIC(8,1)),
		[GB Total] = CAST(MIN((total_bytes+available_bytes) / 1024. / 1024 / 1024) AS NUMERIC(8,1))
FROM sys.master_files AS f
CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.file_id)
GROUP by
    CASE
        WHEN f.physical_name LIKE 'C:\ManagedDisks%' THEN 'Premium Managed Disks'
        WHEN f.physical_name LIKE 'https%' THEN 'Premium Page Blobs'
        ELSE 'Local SSD'
    END)
SELECT  [ ] = 'User/system databases',
        [GB Used], [GB Available], [GB Total], 
        [Remaining files (data and log)] = [Remaining GP files],
        [*Backups are not included in this report] = ''
FROM volumes
    join gp_stats
        on volumes.Storage = 'Premium Page Blobs'
WHERE volumes.Storage = 'Premium Page Blobs'
UNION ALL
SELECT [ ] = 'User/system databases',
        [GB Used], [GB Available], [GB Total],
        [Remaining files (data and log)] = [Remaining Next-Gen files],
        [*Backups are not included in this report] = ''
FROM volumes
    JOIN next_gen_gp_stats
        ON volumes.Storage = 'Premium Managed Disks'
WHERE volumes.Storage = 'Premium Managed Disks'
UNION ALL
SELECT [ ] = 'Not available', 
        [GB Used] = 0, [GB Available] = 0, [GB Total] = 0, 
        [Remaining files (data and log)] = 0,
        [*Backups are not included in this report] = ''
FROM volumes
    join gp_stats
        on volumes.Storage = 'Local SSD'
WHERE volumes.Storage = 'Local SSD'
;