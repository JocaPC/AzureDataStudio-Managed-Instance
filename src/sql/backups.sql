
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

*/
SET NOCOUNT ON;

DECLARE @ErrorLog TABLE (
                        LogID int NOT NULL IDENTITY(1,1),
                        LogDate datetime NOT NULL,
                        ProcessInfo nvarchar(50) NOT NULL,
                        LogText nvarchar(4000) NOT NULL,
                        PRIMARY KEY (LogDate, LogID)
                        );

IF (NOT IS_SRVROLEMEMBER(N'securityadmin') = 1) AND (NOT HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE') = 1)
BEGIN
    RAISERROR(27219,-1,-1);
END;

-- Get unfiltered log

INSERT INTO @ErrorLog (LogDate, ProcessInfo, LogText)
EXEC sys.xp_readerrorlog 0, 1, @p1 = N'Backup(';

-- Return filtered log
SELECT TOP 2000 el.LogDate,
       LogText = IIF(d.name IS NULL, el.LogText, REPLACE(el.LogText COLLATE Latin1_General_100_CI_AS, d.physical_database_name, d.name))
FROM @ErrorLog AS el
LEFT JOIN sys.databases d ON el.LogText COLLATE Latin1_General_100_CI_AS LIKE '%'+d.physical_database_name+'%'
WHERE SUBSTRING(el.LogText, 1, 7) = N'Backup('
and d.name not in ('master', 'model')
ORDER BY el.LogDate DESC,
         el.LogID
OPTION (RECOMPILE, MAXDOP 1);

END