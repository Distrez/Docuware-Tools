/*
    This query creates results for popular database tables
    customer support uses to troubleshoot.

    The results can be copied and pasted as CSV for support.

    Mainly these tables are used to resolve:
        - Authentication issues
        - IIS issues
        - Server messaging issues for 7.13+
          DWServerSetup is currently commented out.
        - GUID issues
        - Server machine names
        - DWTasks with TRYCOUNT greater than zero

    The Query Text column contains an UPDATE statement that is
    a copy of the XML settings from DWSystemSettings.
	Also contains delete from trycount > 0
*/

USE [DWSYSTEM];

SET NOCOUNT ON;

------------------------------------------------------------
-- Drop existing temporary tables
------------------------------------------------------------
IF OBJECT_ID('tempdb..#tempDWOrgDBVersion') IS NOT NULL
    DROP TABLE #tempDWOrgDBVersion;

IF OBJECT_ID('tempdb..#tempDWServerSetup') IS NOT NULL
    DROP TABLE #tempDWServerSetup;

IF OBJECT_ID('tempdb..#tempDWOrganizationDB') IS NOT NULL
    DROP TABLE #tempDWOrganizationDB;

IF OBJECT_ID('tempdb..#tempDWSystemSettings') IS NOT NULL
    DROP TABLE #tempDWSystemSettings;

IF OBJECT_ID('tempdb..#tempDWSystemUser') IS NOT NULL
    DROP TABLE #tempDWSystemUser;

IF OBJECT_ID('tempdb..#tempDWTasks') IS NOT NULL
    DROP TABLE #tempDWTasks;

IF OBJECT_ID('tempdb..#tempSQLServerLog') IS NOT NULL
    DROP TABLE #tempSQLServerLog;

------------------------------------------------------------
-- Create temporary table: DWOrgDBVersion
------------------------------------------------------------
SELECT
    CAST(v.[version] AS NVARCHAR(255))
        COLLATE DATABASE_DEFAULT AS [version]
INTO #tempDWOrgDBVersion
FROM [dbo].[DWOrgDBVersion] AS v;

/*
------------------------------------------------------------
-- Create temporary table: DWServerSetup
-- Currently commented out
------------------------------------------------------------
SELECT
    CAST(s.[key] AS NVARCHAR(255))
        COLLATE DATABASE_DEFAULT AS [key],

    s.[value]
INTO #tempDWServerSetup
FROM [dbo].[DWServerSetup] AS s;
*/

------------------------------------------------------------
-- Create temporary table: DWOrganizationDB
------------------------------------------------------------
SELECT
    CAST(o.[guid] AS NVARCHAR(255))
        COLLATE DATABASE_DEFAULT AS [guid],

    CAST(o.[organization] AS NVARCHAR(255))
        COLLATE DATABASE_DEFAULT AS [organization]
INTO #tempDWOrganizationDB
FROM [dbo].[DWOrganizationDB] AS o;

------------------------------------------------------------
-- Create temporary table: DWSystemSettings
------------------------------------------------------------
SELECT
    CAST(ss.[guid] AS NVARCHAR(255))
        COLLATE DATABASE_DEFAULT AS [guid],

    CAST(ss.[type] AS NVARCHAR(255))
        COLLATE DATABASE_DEFAULT AS [type],

    ss.[settings]
INTO #tempDWSystemSettings
FROM [dbo].[DWSystemSettings] AS ss;

------------------------------------------------------------
-- Create temporary table: DWSystemUser
------------------------------------------------------------
SELECT
    CAST(u.[name] AS NVARCHAR(255))
        COLLATE DATABASE_DEFAULT AS [name],

    u.[uid]
INTO #tempDWSystemUser
FROM [dbo].[DWSystemUser] AS u;

------------------------------------------------------------
-- Create temporary table: DWTasks
------------------------------------------------------------
SELECT
    t.[ID],
    t.[TASK_TYPE],
    t.[TRYCOUNT]
INTO #tempDWTasks
FROM [dbo].[DWTasks] AS t;

------------------------------------------------------------
-- Get SQL Server TCP listening information
--
-- Parameter 0 = current SQL Server error log
-- Parameter 1 = SQL Server Database Engine log
-- Search text 3 = "listening on"
------------------------------------------------------------
CREATE TABLE #tempSQLServerLog
(
    [LogDate]     DATETIME,
    [ProcessInfo] NVARCHAR(50),
    [Text]        NVARCHAR(MAX)
);

DECLARE @SQLListeningInfo NVARCHAR(MAX);

BEGIN TRY

    INSERT INTO #tempSQLServerLog
    (
        [LogDate],
        [ProcessInfo],
        [Text]
    )
    EXEC sys.sp_readerrorlog
        @p1 = 0,
        @p2 = 1,
        @p3 = N'listening on';

    --------------------------------------------------------
    -- Combine all matching listening entries
    --
    -- SQL Server might have separate entries for:
    --     - IPv4
    --     - IPv6
    --     - Dedicated Admin Connection
    --     - Multiple IP addresses or ports
    --------------------------------------------------------
    SELECT
        @SQLListeningInfo =
            STUFF
            (
                (
                    SELECT
                        CHAR(13) +
                        CHAR(10) +
                        CAST(l.[Text] AS NVARCHAR(MAX))
                    FROM #tempSQLServerLog AS l
                    ORDER BY
                        l.[LogDate],
                        l.[Text]
                    FOR XML PATH(N''), TYPE
                ).value(N'.', N'nvarchar(max)'),
                1,
                2,
                N''
            );

    IF NULLIF(@SQLListeningInfo, N'') IS NULL
    BEGIN
        SET @SQLListeningInfo =
            N'SQL Server TCP listening information was not found in the current error log.';
    END;

END TRY
BEGIN CATCH

    SET @SQLListeningInfo =
        CONCAT
        (
            N'Unable to read SQL Server listening information. ',
            N'Error ',
            ERROR_NUMBER(),
            N': ',
            ERROR_MESSAGE()
        );

END CATCH;

------------------------------------------------------------
-- DWOrgDBVersion
-- Defines the final result-set column names
--
-- Second column: DW version
-- Third column: SQL Server listening information
------------------------------------------------------------
SELECT
    N'DWOrgDBVersion'
        COLLATE DATABASE_DEFAULT AS [SourceTable],

    CAST
    (
        CONCAT
        (
            N'DW Version: ',
            v.[version]
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT AS [Info and Guids],

    CAST
    (
        COALESCE
        (
            @SQLListeningInfo,
            N'SQL Server TCP listening information was not found.'
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT AS [Info],

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT AS [Web Connection Name],

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT AS [Http Root],

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT AS [Machine],

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT AS [Connection Information],

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT AS [Query Text]

FROM #tempDWOrgDBVersion AS v

UNION ALL

------------------------------------------------------------
-- DWOrganizationDB
------------------------------------------------------------
SELECT
    N'DWOrganizationDB'
        COLLATE DATABASE_DEFAULT,

    CAST
    (
        CONCAT
        (
            N'Org Guid: ',
            o.[guid]
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT,

    CAST
    (
        CONCAT
        (
            N'Org Name: ',
            o.[organization]
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT,

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT

FROM #tempDWOrganizationDB AS o

UNION ALL

------------------------------------------------------------
-- DWTasks summary
------------------------------------------------------------
SELECT
    N'DWTasks'
        COLLATE DATABASE_DEFAULT,

    CAST
    (
        CONCAT
        (
            N'Total task count: ',
            COUNT_BIG(*)
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT,

    CAST
    (
        CONCAT
        (
            N'Tasks where TRYCOUNT > 0: ',
            COALESCE
            (
                SUM
                (
                    CASE
                        WHEN ISNULL(t.[TRYCOUNT], 0) > 0
                            THEN CAST(1 AS BIGINT)
                        ELSE CAST(0 AS BIGINT)
                    END
                ),
                CAST(0 AS BIGINT)
            )
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT,

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST
    (
        N'DELETE FROM [dwsystem].[dbo].[DWTasks] WHERE [TRYCOUNT] > 0;'
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT

FROM #tempDWTasks AS t

UNION ALL

------------------------------------------------------------
-- DWSystemUser
------------------------------------------------------------
SELECT
    N'DWSystemUser'
        COLLATE DATABASE_DEFAULT,

    CAST(u.[name] AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST(u.[uid] AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT

FROM #tempDWSystemUser AS u

UNION ALL

/*
------------------------------------------------------------
-- DWServerSetup
-- Currently commented out
------------------------------------------------------------
SELECT
    N'DWServerSetup'
        COLLATE DATABASE_DEFAULT,

    CAST(s.[key] AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST(s.[value] AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT

FROM #tempDWServerSetup AS s

UNION ALL
*/

------------------------------------------------------------
-- DWSystemSettings: WebConnection rows
------------------------------------------------------------
SELECT
    N'DWSystemSettings'
        COLLATE DATABASE_DEFAULT,

    CAST
    (
        CONCAT
        (
            N'Guid: ',
            d.[guid]
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT,

    CAST(d.[type] AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST
    (
        d.[settings].value
        (
            '(//WebConnection/@name)[1]',
            'nvarchar(200)'
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT,

    CAST
    (
        d.[settings].value
        (
            '(//WebConnection/@httpRoot)[1]',
            'nvarchar(500)'
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT,

    CAST
    (
        d.[settings].value
        (
            '(//WebConnection/@machine)[1]',
            'nvarchar(200)'
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT,

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST
    (
        CONCAT
        (
            N'UPDATE [dwsystem].[dbo].[DWSystemSettings]',
            CHAR(13),
            CHAR(10),
            N'SET [settings] = N''',
            REPLACE
            (
                CAST(d.[settings] AS NVARCHAR(MAX)),
                N'''',
                N''''''
            ),
            N'''',
            CHAR(13),
            CHAR(10),
            N'WHERE [guid] = N''',
            REPLACE
            (
                d.[guid],
                N'''',
                N''''''
            ),
            N''';'
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT

FROM #tempDWSystemSettings AS d
WHERE
    d.[settings].exist('(//WebConnection)[1]') = 1

UNION ALL

------------------------------------------------------------
-- DWSystemSettings: DatabaseConnection rows
------------------------------------------------------------
SELECT
    N'DWSystemSettings'
        COLLATE DATABASE_DEFAULT,

    CAST
    (
        CONCAT
        (
            N'Guid: ',
            d.[guid]
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT,

    CAST(d.[type] AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST
    (
        d.[settings].value
        (
            '(//WebConnection/@name)[1]',
            'nvarchar(200)'
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT,

    CAST
    (
        d.[settings].value
        (
            '(//WebConnection/@httpRoot)[1]',
            'nvarchar(500)'
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT,

    CAST
    (
        d.[settings].value
        (
            '(//DatabaseConnection/Connection/Server/text())[1]',
            'nvarchar(200)'
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT,

    CAST
    (
        CONCAT
        (
            N'Name=',
            d.[settings].value
            (
                '(//DatabaseConnection/Connection/Name/text())[1]',
                'nvarchar(200)'
            ),
            N'; Database=',
            d.[settings].value
            (
                '(//DatabaseConnection/Connection/Database/text())[1]',
                'nvarchar(200)'
            ),
            N'; Port=',
            d.[settings].value
            (
                '(//DatabaseConnection/Connection/Port/text())[1]',
                'nvarchar(20)'
            ),
            N'; Login=',
            d.[settings].value
            (
                '(//DatabaseConnection/Connection/Login/UserName/text())[1]',
                'nvarchar(200)'
            )
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT,

    CAST
    (
        CONCAT
        (
            N'UPDATE [dwsystem].[dbo].[DWSystemSettings]',
            CHAR(13),
            CHAR(10),
            N'SET [settings] = N''',
            REPLACE
            (
                CAST(d.[settings] AS NVARCHAR(MAX)),
                N'''',
                N''''''
            ),
            N'''',
            CHAR(13),
            CHAR(10),
            N'WHERE [guid] = N''',
            REPLACE
            (
                d.[guid],
                N'''',
                N''''''
            ),
            N''';'
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT

FROM #tempDWSystemSettings AS d
WHERE
    d.[settings].exist('(//DatabaseConnection)[1]') = 1;

------------------------------------------------------------
-- Drop temporary tables
------------------------------------------------------------
IF OBJECT_ID('tempdb..#tempDWOrgDBVersion') IS NOT NULL
    DROP TABLE #tempDWOrgDBVersion;

IF OBJECT_ID('tempdb..#tempDWServerSetup') IS NOT NULL
    DROP TABLE #tempDWServerSetup;

IF OBJECT_ID('tempdb..#tempDWOrganizationDB') IS NOT NULL
    DROP TABLE #tempDWOrganizationDB;

IF OBJECT_ID('tempdb..#tempDWSystemSettings') IS NOT NULL
    DROP TABLE #tempDWSystemSettings;

IF OBJECT_ID('tempdb..#tempDWSystemUser') IS NOT NULL
    DROP TABLE #tempDWSystemUser;

IF OBJECT_ID('tempdb..#tempDWTasks') IS NOT NULL
    DROP TABLE #tempDWTasks;

IF OBJECT_ID('tempdb..#tempSQLServerLog') IS NOT NULL
    DROP TABLE #tempSQLServerLog;