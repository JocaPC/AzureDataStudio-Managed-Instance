IF( SERVERPROPERTY('EngineEdition') = 8 )
BEGIN
/*
Description:
Script based on Dimitri Furman's  dbo.sp_readmierrorlog procedure.
dbo.sp_readmierrorlog is a stored procedure that returns the contents of SQL Server and SQL Agent error logs on an MI instance.
The procedure filters out debug-level messages logged for service operation and troubleshooting purposes,
in order to make the error log more readable and actionable for MI users.
The procedure can be customized to add/remove specific filter strings.

Unfiltered error log remains available using the sys.sp_readerrorlog stored procedure.

Usage examples:

-- Current filtered MI error log (default)
DECLARE
    @p1 int = 0,
    @p2 int = NULL, 
    @p3 nvarchar(4000) = NULL,
    @p4 nvarchar(4000) = NULL

-- Current filtered MI SQL Agent log
DECLARE
    @p1 int = 0, 
    @p2 int = 2, -- 2 SQL Agent Jobs 
    @p3 nvarchar(4000) = NULL,
    @p4 nvarchar(4000) = NULL

-- Current filtered MI error log with messages containing string "Error: 18056"
DECLARE
    @p1 int = 0, 
    @p2 int = NULL,
    @p3 nvarchar(4000) = 'Error: 18056',
    @p4 nvarchar(4000) = NULL

-- Current filtered MI error log with messages containing strings "Error: 18056" and "state: 1"
DECLARE
    @p1 int = 0,
    @p2 int = NULL,
    @p3 nvarchar(4000) = 'Error: 18056',
    @p4 nvarchar(4000) = 'state: 1'

-- Filtered MI error log before last rollover
DECLARE
    @p1 int = 1, --> 1 Before last rollower
    @p2 int = NULL, 
    @p3 nvarchar(4000) = NULL,
    @p4 nvarchar(4000) = NULL

*/
DECLARE
    @p1 int = 0, -- 1 before as rollower
    @p2 int = NULL, -- 2 SQL Agent Jobs 
    @p3 nvarchar(4000) = NULL,
    @p4 nvarchar(4000) = NULL



SET NOCOUNT ON;

DECLARE @ErrorLog TABLE (
                        LogID int NOT NULL IDENTITY(1,1),
                        LogDate datetime NOT NULL,
                        ProcessInfo nvarchar(50) NOT NULL,
                        LogText nvarchar(4000) NOT NULL,
                        PRIMARY KEY (LogDate, LogID)
                        );
DECLARE @LogFilter TABLE (
                         FilterText nvarchar(100) NOT NULL PRIMARY KEY,
                         FilterType tinyint NOT NULL -- 1 - starts with; 2 - contains; 3 - starts with "Backup(<user db guid>"
                         );

IF (NOT IS_SRVROLEMEMBER(N'securityadmin') = 1) AND (NOT HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE') = 1)
BEGIN
    RAISERROR(27219,-1,-1);
END;

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

-- Get unfiltered log
IF @p2 IS NULL
BEGIN
    INSERT INTO @ErrorLog (LogDate, ProcessInfo, LogText)
    EXEC sys.xp_readerrorlog @p1;
END
ELSE
BEGIN
    INSERT INTO @ErrorLog (LogDate, ProcessInfo, LogText)
    EXEC sys.xp_readerrorlog @p1,@p2,@p3,@p4;
END;

-- Return filtered log
SELECT TOP 200 el.LogDate,
       el.ProcessInfo,
       LogText = IIF(d.name IS NULL, el.LogText, REPLACE(el.LogText, d.physical_database_name, d.name))
FROM @ErrorLog AS el
LEFT JOIN sys.databases d ON el.LogText LIKE '%'+d.physical_database_name+'%'
WHERE SUBSTRING(el.LogText, 1, 7) <> N'Backup('
AND SUBSTRING(el.LogText, 1, 21) <> N' [RotateDatabaseKeys]'
AND SUBSTRING(el.LogText, 1, 58) <> N'[AzureKeyVaultClientHelper::CheckDbAkvWrapUnwrap]: Skipped'
AND SUBSTRING(el.LogText, 1, 21) <> N'[CFabricCommonUtils::'
AND SUBSTRING(el.LogText, 1, 24) <> N'[CFabricReplicaManager::'
AND SUBSTRING(el.LogText, 1, 26) <> N'[CFabricReplicaPublisher::'
AND SUBSTRING(el.LogText, 1, 25) <> N'[CFabricReplicatorProxy::'
AND SUBSTRING(el.LogText, 1, 18) <> N'[CheckDbAkvAccess]'
AND SUBSTRING(el.LogText, 1, 19) <> N'[CurrentSecretName]'
AND SUBSTRING(el.LogText, 1, 15) <> N'[DbrSubscriber]'
AND SUBSTRING(el.LogText, 1, 33) <> N'[DISK_SPACE_TO_RESERVE_PROPERTY]:'
AND SUBSTRING(el.LogText, 1, 18) <> N'[EnableBPEOnAzure]'
AND SUBSTRING(el.LogText, 1, 22) <> N'[FabricDbrSubscriber::'
AND SUBSTRING(el.LogText, 1, 19) <> N'[GenericSubscriber]'
AND SUBSTRING(el.LogText, 1, 36) <> N'[GetEncryptionProtectorTypeInternal]'
AND SUBSTRING(el.LogText, 1, 20) <> N'[GetInstanceSloGuid]'
AND SUBSTRING(el.LogText, 1, 44) <> N'[GetInterfaceEndpointsConfigurationInternal]'
AND SUBSTRING(el.LogText, 1, 23) <> N'[GetTdeAkvUrisInternal]'
AND SUBSTRING(el.LogText, 1, 13) <> N'[HADR Fabric]'
AND SUBSTRING(el.LogText, 1, 16) <> N'[HADR TRANSPORT]'
AND SUBSTRING(el.LogText, 1, 13) <> N'[INFO] [CKPT] '
AND SUBSTRING(el.LogText, 1, 27) <> N'[INFO] ckptCloseThreadFn():'
AND SUBSTRING(el.LogText, 1, 30) <> N'[INFO] createBackupContextV2()'
AND SUBSTRING(el.LogText, 1, 38) <> N'[INFO] Created Extended Events session'
AND SUBSTRING(el.LogText, 1, 19) <> N'[INFO] Database ID:'
AND SUBSTRING(el.LogText, 1, 41) <> N'[INFO] getMaxUnrecoverableCheckpointId():'
AND SUBSTRING(el.LogText, 1, 9) <> N'[INFO] Hk'
AND SUBSTRING(el.LogText, 1, 24) <> N'[INFO] HostCommonStorage'
AND SUBSTRING(el.LogText, 1, 40) <> N'[INFO] ProcessElementsInBackupContext().'
AND SUBSTRING(el.LogText, 1, 29) <> N'[INFO] RootFileDeserialize():'
AND SUBSTRING(el.LogText, 1, 31) <> N'[INFO] trimSystemTablesByLsn():'
AND SUBSTRING(el.LogText, 1, 15) <> N'[LAGController]'
AND SUBSTRING(el.LogText, 1, 10) <> N'[LogPool::'
AND SUBSTRING(el.LogText, 1, 18) <> N'[ReplicaController'
AND SUBSTRING(el.LogText, 1, 23) <> N'[SetupAkvPrincipalCert]'
AND SUBSTRING(el.LogText, 1, 38) <> N'[SetupInterfaceEndpointsConfiguration]'
AND SUBSTRING(el.LogText, 1, 27) <> N'[SetupSslServerCertificate]'
AND SUBSTRING(el.LogText, 1, 16) <> N'[SetupTdeAkvUri]'
AND SUBSTRING(el.LogText, 1, 25) <> N'[SetupTenantCertificates]'
AND SUBSTRING(el.LogText, 1, 40) <> N'[SloManager::AdjustCpuSettingForResource'
AND SUBSTRING(el.LogText, 1, 27) <> N'[SloParams::ParseSloParams]'
AND SUBSTRING(el.LogText, 1, 20) <> N'[SQLInstancePartner]'
AND SUBSTRING(el.LogText, 1, 21) <> N'[TransportSubscriber]'
AND SUBSTRING(el.LogText, 1, 22) <> N'[VersionCleaner][DbId:'
AND SUBSTRING(el.LogText, 1, 31) <> N'[XDB_DATABASE_SETTINGS_PROPERTY'
AND SUBSTRING(el.LogText, 1, 35) <> N'A connection for availability group'
AND SUBSTRING(el.LogText, 1, 20) <> N'accepting vlf header'
AND SUBSTRING(el.LogText, 1, 56) <> N'BACKUP DATABASE WITH DIFFERENTIAL successfully processed'
AND SUBSTRING(el.LogText, 1, 22) <> N'Backup(managed_model):'
AND SUBSTRING(el.LogText, 1, 13) <> N'Backup(msdb):'
AND SUBSTRING(el.LogText, 1, 25) <> N'Backup(replicatedmaster):'
AND SUBSTRING(el.LogText, 1, 43) <> N'Cannot open database ''model_msdb'' version'
AND SUBSTRING(el.LogText, 1, 12) <> N'CHadrSession'
AND SUBSTRING(el.LogText, 1, 31) <> N'Cleaning up conversations for ['
AND SUBSTRING(el.LogText, 1, 15) <> N'cloud Partition'
AND SUBSTRING(el.LogText, 1, 18) <> N'CloudTelemetryBase'
AND SUBSTRING(el.LogText, 1, 31) <> N'Copying dbt_inactiveDurationMin'
AND SUBSTRING(el.LogText, 1, 45) <> N'Database differential changes were backed up.'
AND SUBSTRING(el.LogText, 1, 24) <> N'DbMgrPartnerCommitPolicy'
AND SUBSTRING(el.LogText, 1, 14) <> N'DBR Subscriber'
AND SUBSTRING(el.LogText, 1, 12) <> N'DWLSSettings'
AND SUBSTRING(el.LogText, 1, 22) <> N'Dynamic Configuration:'
AND SUBSTRING(el.LogText, 1, 35) <> N'Error: 946, Severity: 14, State: 1.'
AND SUBSTRING(el.LogText, 1, 17) <> N'FabricDBTableInfo'
AND SUBSTRING(el.LogText, 1, 27) <> N'Failed to retrieve Property'
AND SUBSTRING(el.LogText, 1, 18) <> N'Filemark on device'
AND SUBSTRING(el.LogText, 1, 30) <> N'FixupLogTail(progress) zeroing'
AND SUBSTRING(el.LogText, 1, 19) <> N'Force log send mode'
AND SUBSTRING(el.LogText, 1, 13) <> N'FSTR: File \\'
AND SUBSTRING(el.LogText, 1, 14) <> N'HADR_FQDR_XRF:'
AND SUBSTRING(el.LogText, 1, 51) <> N'Http code after sending the notification for action'
AND SUBSTRING(el.LogText, 1, 10) <> N'IsInCreate'
AND SUBSTRING(el.LogText, 1, 15) <> N'Layered AG Role'
AND SUBSTRING(el.LogText, 1, 28) <> N'Log was backed up. Database:'
AND SUBSTRING(el.LogText, 1, 34) <> N'Log writer started sending: DbId ['
AND SUBSTRING(el.LogText, 1, 25) <> N'LOG_SEND_TRANSITION: DbId'
AND SUBSTRING(el.LogText, 1, 9) <> N'LogPool::'
AND SUBSTRING(el.LogText, 1, 32) <> N'PerformConfigureDatabaseInternal'
AND SUBSTRING(el.LogText, 1, 21) <> N'PrimaryReplicaInfoMsg'
AND SUBSTRING(el.LogText, 1, 60) <> N'Processing BuildReplicaCatchup source operation on replica ['
AND SUBSTRING(el.LogText, 1, 23) <> N'Processing pending list'
AND SUBSTRING(el.LogText, 1, 37) <> N'Processing PrimaryConfigUpdated Event'
AND SUBSTRING(el.LogText, 1, 28) <> N'ProcessPrimaryReplicaInfoMsg'
AND SUBSTRING(el.LogText, 1, 38) <> N'Querying Property Manager for Property'
AND SUBSTRING(el.LogText, 1, 37) <> N'RefreshFabricPropertyServiceObjective'
AND SUBSTRING(el.LogText, 1, 17) <> N'ResyncWithPrimary'
AND SUBSTRING(el.LogText, 1, 18) <> N'Retrieved Property'
AND SUBSTRING(el.LogText, 1, 31) <> N'Sending the notification action'
AND SUBSTRING(el.LogText, 1, 11) <> N'SetDbFields'
AND SUBSTRING(el.LogText, 1, 34) <> N'Skip Initialization for XE session'
AND SUBSTRING(el.LogText, 1, 32) <> N'Skipped running db sample script'
AND SUBSTRING(el.LogText, 1, 7) <> N'SloInfo'
AND SUBSTRING(el.LogText, 1, 12) <> N'SloManager::'
AND SUBSTRING(el.LogText, 1, 16) <> N'SloRgPropertyBag'
AND SUBSTRING(el.LogText, 1, 33) <> N'State information for database '''
AND SUBSTRING(el.LogText, 1, 18) <> N'The recovery LSN ('
AND SUBSTRING(el.LogText, 1, 26) <> N'UpdateHadronTruncationLsn('
AND SUBSTRING(el.LogText, 1, 76) <> N'Warning: The join order has been enforced because a local join hint is used.'
AND SUBSTRING(el.LogText, 1, 7) <> N'Zeroing '
AND el.LogText NOT LIKE N'% PVS%' ESCAPE '`'
AND el.LogText NOT LIKE N'%) log capture is rescheduled%' ESCAPE '`'
AND el.LogText NOT LIKE N'%`[ERROR`] Log file %.xel cannot be deleted. Last error code from CreateFile is 32%' ESCAPE '`'
AND el.LogText NOT LIKE N'%`[WARNING`] === At least % extensions for file {%' ESCAPE '`'
AND el.LogText NOT LIKE N'%`] local replica received build replica response from `[%' ESCAPE '`'
AND el.LogText NOT LIKE N'%`] log capture becomes idle%' ESCAPE '`'
AND el.LogText NOT LIKE N'%AppInstanceId `[%`]. LeaseOrderId%' ESCAPE '`'
AND el.LogText NOT LIKE N'%CFabricReplicaController%' ESCAPE '`'
AND el.LogText NOT LIKE N'%Deflation Settings%' ESCAPE '`'
AND el.LogText NOT LIKE N'%DeflationSettings%' ESCAPE '`'
AND el.LogText NOT LIKE N'%HaDrDbMgr%' ESCAPE '`'
AND el.LogText NOT LIKE N'%HadrLogCapture::CaptureLogBlock%' ESCAPE '`'
AND el.LogText NOT LIKE N'%is upgrading script ''Sql.UserDb.Sql''%' ESCAPE '`'
AND el.LogText NOT LIKE N'%Persistent store table%' ESCAPE '`'
AND el.LogText NOT LIKE N'%snapshot isolation setting ON for logical master.%' ESCAPE '`'
AND el.LogText NOT LIKE N'%XactRM::PrepareLocalXact%' ESCAPE '`'
ORDER BY el.LogDate DESC,
         el.LogID
OPTION (RECOMPILE, MAXDOP 1);

END