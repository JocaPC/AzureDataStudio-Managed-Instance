WITH allocated ([Remaining files])
AS (
SELECT  --[Allocated TB] = CONCAT(CAST(size_tb as [tinyint]), 'TB out of 35TB'),
		[Remaining files] = CAST((35 - size_tb) * 8 AS int)
FROM
( SELECT
        SUM(CASE
                WHEN  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  <= 128
                    THEN 128
                WHEN  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  > 128 AND  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  <= 256
                    THEN 256
                WHEN  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  > 256 AND  CAST(size * 8. / 1024 / 1024 AS decimal(12,4))  <= 512
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
volumes as (
SELECT	Storage = CASE WHEN volume_mount_point = 'http://' THEN 'Azure Premium Disk'
                        ELSE 'Local SSD'
                    END,
		[Used GB] = CAST(MIN(total_bytes / 1024. / 1024 / 1024) AS NUMERIC(8,1)),
		[Available GB] = CAST(MIN(available_bytes / 1024. / 1024 / 1024) AS NUMERIC(8,1)),
		[Total GB] = CAST(MIN((total_bytes+available_bytes) / 1024. / 1024 / 1024) AS NUMERIC(8,1))
FROM sys.master_files AS f
CROSS APPLY sys.dm_os_volume_stats(f.database_id, f.file_id)
GROUP BY volume_mount_point)
SELECT *
FROM volumes
    left join allocated
        on volumes.Storage = 'Azure Premium Disk'
;