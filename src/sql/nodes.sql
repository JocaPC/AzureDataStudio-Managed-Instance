IF( SERVERPROPERTY('EngineEdition') = 8 )
with nodes as (
	select db_name = DB_NAME(database_id),
		minlsn = CONVERT(NUMERIC(38,0), ISNULL(truncation_lsn, 0)),
		maxlsn = CONVERT(NUMERIC(38,0), ISNULL(last_hardened_lsn, 0)),
		seeding_state =
			CASE WHEN seedStats.internal_state_desc NOT IN ('Success', 'Failed') OR synchronization_health = 1
						THEN 'Warning' ELSE
                     (CASE WHEN synchronization_state = 0 OR synchronization_health != 2
							THEN 'ERROR' ELSE 'OK' END)
			END,
		replication_endpoint_url =
		CASE WHEN replication_endpoint_url IS NULL AND (synchronization_state = 1  OR fccs.partner_server IS NOT NULL)
			THEN fccs.partner_server + ' - ' + fccs.partner_database -- Geo replicas will be in Synchronizing state
        ELSE replication_endpoint_url END,
		repl_states.* , seedStats.internal_state_desc, frs.fabric_replica_role
		from sys.dm_hadr_database_replica_states repl_states
              LEFT JOIN sys.dm_hadr_fabric_replica_states frs
                     ON repl_states.replica_id = frs.replica_id
              LEFT OUTER JOIN sys.dm_hadr_physical_seeding_stats seedStats
                     ON seedStats.remote_machine_name = replication_endpoint_url
                     AND (seedStats.local_database_name = repl_states.group_id OR seedStats.local_database_name = DB_NAME(database_id))
                     AND seedStats.internal_state_desc NOT IN ('Success', 'Failed')
              LEFT OUTER JOIN sys.dm_hadr_fabric_continuous_copy_status fccs
                     ON repl_states.group_database_id = fccs.copy_guid
),
nodes_progress AS (
SELECT *, logprogresssize_p =
                     CASE WHEN maxlsn - minlsn != 0 THEN maxlsn - minlsn
                           ELSE 0 END
FROM nodes
),
nodes_progress_size as (
select
	log_progress_size = CASE WHEN last_hardened_lsn > minlsn AND logprogresssize_p > 0
				THEN (CONVERT(NUMERIC(38,0), last_hardened_lsn) - minlsn)*100.0/logprogresssize_p
    ELSE 0 END, *
	from nodes_progress
)
SELECT
	[Database] = db_name,
	[Is primary] = is_primary_replica,
	[Endpoint] = replication_endpoint_url,
	[Sync progress] = CASE WHEN internal_state_desc IS NOT NULL -- Check for active seeding
                           THEN 'Seeding'
                     WHEN logprogresssize_p > 0
                           THEN CONVERT(VARCHAR(100), CONVERT(NUMERIC(20,2),log_progress_size)) + '%'
                     ELSE 'Select the Primary Node' END,
	[Is local] = is_local,
	state = synchronization_state_desc,
	[Lag (sec)] = secondary_lag_seconds
	FROM nodes_progress_size
ORDER BY db_name ASC, is_primary_replica DESC;