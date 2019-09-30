DECLARE
    @p1 int = 0, -- 1 before as rollower
    @p2 int = NULL, -- 2 SQL Agent Jobs 
    @p3 nvarchar(4000) = NULL,
    @p4 nvarchar(4000) = NULL

DECLARE @LogFilter TABLE (
                         FilterText nvarchar(100) NOT NULL PRIMARY KEY,
                         FilterType tinyint NOT NULL -- 1 - starts with; 2 - contains; 3 - starts with "Backup(<user db guid>"
                         );

--IF (NOT IS_SRVROLEMEMBER(N'securityadmin') = 1) AND (NOT HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE') = 1)
--BEGIN
  --  RAISERROR(27219,-1,-1);
    
--END;

-- Populate filter table
INSERT INTO @LogFilter
(
FilterText,
FilterType
)
VALUES
('`[AzureKeyVaultClientHelper::CheckDbAkvWrapUnwrap`]: Skipped',1),
(' `[RotateDatabaseKeys`]',1),
(' PVS',2),
('`[ERROR`] Log file %.xel cannot be deleted. Last error code from CreateFile is 32',2),
(') log capture is rescheduled',2),
('`[CFabricCommonUtils::',1),
('`[CFabricReplicaManager::',1),
('`[CFabricReplicaPublisher::',1),
('`[CFabricReplicatorProxy::',1),
('`[CheckDbAkvAccess`]',1),
('`[CurrentSecretName`]',1),
('`[DbrSubscriber`]',1),
('`[DISK_SPACE_TO_RESERVE_PROPERTY`]:',1),
('`[EnableBPEOnAzure`]',1),
('`[FabricDbrSubscriber::',1),
('`[GenericSubscriber`]',1),
('`[GetEncryptionProtectorTypeInternal`]',1),
('`[GetInstanceSloGuid`]',1),
('`[GetInterfaceEndpointsConfigurationInternal`]',1),
('`[GetTdeAkvUrisInternal`]',1),
('`[HADR Fabric`]',1),
('`[HADR TRANSPORT`]',1),
('`[INFO`] `[CKPT`] ',1),
('`[INFO`] ckptCloseThreadFn():',1),
('`[INFO`] createBackupContextV2()',1),
('`[INFO`] Created Extended Events session',1),
('`[INFO`] Database ID:',1),
('`[INFO`] getMaxUnrecoverableCheckpointId():',1),
('`[INFO`] Hk',1),
('`[INFO`] HostCommonStorage',1),
('`[INFO`] ProcessElementsInBackupContext().',1),
('`[INFO`] RootFileDeserialize():',1),
('`[INFO`] trimSystemTablesByLsn():',1),
('`[LAGController`]',1),
('`[LogPool::',1),
('`[ReplicaController',1),
('`[SetupAkvPrincipalCert`]',1),
('`[SetupInterfaceEndpointsConfiguration`]',1),
('`[SetupTdeAkvUri`]',1),
('`[SetupSslServerCertificate`]',1),
('`[SetupTenantCertificates`]',1),
('`[SloManager::AdjustCpuSettingForResource',1),
('`[SloParams::ParseSloParams`]',1),
('`[SQLInstancePartner`]',1),
('`[TransportSubscriber`]',1),
('`[XDB_DATABASE_SETTINGS_PROPERTY',1),
('`[VersionCleaner`]`[DbId:',1),
('`[WARNING`] === At least % extensions for file {',2),
('`] local replica received build replica response from `[',2),
('`] log capture becomes idle',2),
('A connection for availability group',1),
('accepting vlf header',1),
('AppInstanceId `[%`]. LeaseOrderId',2),
('BACKUP DATABASE WITH DIFFERENTIAL successfully processed',1),
('Backup(',3),
('Backup(managed_model):',1),
('Backup(msdb):',1),
('Backup(replicatedmaster):',1),
('Cannot open database ''model_msdb'' version',1),
('CFabricReplicaController',2),
('CHadrSession',1),
('Cleaning up conversations for `[',1),
('cloud Partition',1),
('CloudTelemetryBase',1),
('Copying dbt_inactiveDurationMin',1),
('Database differential changes were backed up.',1),
('DbMgrPartnerCommitPolicy',1),
('DBR Subscriber',1),
('Deflation Settings',2),
('DeflationSettings',2),
('DWLSSettings',1),
('Dynamic Configuration:',1),
('Error: 946, Severity: 14, State: 1.',1),
('FabricDBTableInfo',1),
('Failed to retrieve Property',1),
('Filemark on device',1),
('FixupLogTail(progress) zeroing',1),
('Force log send mode',1),
('FSTR: File \\',1),
('HADR_FQDR_XRF:',1),
('HaDrDbMgr',2),
('HadrLogCapture::CaptureLogBlock',2),
('Http code after sending the notification for action',1),
('is upgrading script ''Sql.UserDb.Sql''',2),
('IsInCreate',1),
('Layered AG Role',1),
('Log was backed up. Database:',1),
('Log writer started sending: DbId `[',1),
('LOG_SEND_TRANSITION: DbId',1),
('LogPool::',1),
('PerformConfigureDatabaseInternal',1),
('Persistent store table',2),
('PrimaryReplicaInfoMsg',1),
('Processing BuildReplicaCatchup source operation on replica `[',1),
('Processing pending list',1),
('Processing PrimaryConfigUpdated Event',1),
('ProcessPrimaryReplicaInfoMsg',1),
('Querying Property Manager for Property',1),
('RefreshFabricPropertyServiceObjective',1),
('ResyncWithPrimary',1),
('Retrieved Property',1),
('Sending the notification action',1),
('SetDbFields',1),
('Skip Initialization for XE session',1),
('Skipped running db sample script',1),
('SloInfo',1),
('SloManager::',1),
('SloRgPropertyBag',1),
('snapshot isolation setting ON for logical master.',2),
('State information for database ''',1),
('The recovery LSN (',1),
('UpdateHadronTruncationLsn(',1),
('Warning: The join order has been enforced because a local join hint is used.',1),
('XactRM::PrepareLocalXact',2),
('Zeroing ',1)
;



--SELECT 'AND el.LogText NOT LIKE N'''+lf.FilterText + '%'' ESCAPE ''`'''
SELECT 'AND SUBSTRING(el.LogText, 1, ' +
			CAST(LEN(REPLACE(REPLACE(lf.FilterText,'`',''),'''','''''')) AS VARCHAR(10)) + 
			') <> N'''+ REPLACE(REPLACE(lf.FilterText,'`',''),'''','''''') + '''' 
FROM @LogFilter lf
WHERE lf.FilterType = 1
UNION ALL
SELECT 'AND el.LogText NOT LIKE N''%' + REPLACE(lf.FilterText,'''','''''') + N'%'' ESCAPE ''`'''
FROM @LogFilter lf
WHERE lf.FilterType = 2
UNION ALL
SELECT 'AND NOT (el.LogText LIKE N'''+ lf.FilterText + N'%'' AND TRY_CONVERT(uniqueidentifier,SUBSTRING(el.LogText, 8, 36)) IS NOT NULL)'
FROM @LogFilter lf
WHERE lf.FilterType = 33
