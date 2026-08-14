/* This query creates results for popular database tables customer support uses to troubleshoot. This is a query that you can copy and paste as a csv for support.

Mainly these tables are used to resolve:
	Authentication issues
	IIS Issues
	Server Messaging issues for 7.13+
	Guid issues
	Server Machine Names

There is an Update statement at the far right that is a copy of the XML Settings from dwsystemsettings. 



Possible future features:
I aim to implement this as an automated script but for now it is something you can run as is.
Will include DWtask table.
Other tables if needed.

	*/
USE DWSYSTEM;
SET NOCOUNT ON;

------------------------------------------------------------
-- Drop existing temp tables
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

------------------------------------------------------------
-- DWOrgDBVersion
------------------------------------------------------------
SELECT
    CAST(v.[version] AS NVARCHAR(255))
        COLLATE DATABASE_DEFAULT AS [version]
INTO #tempDWOrgDBVersion
FROM [dbo].[DWOrgDBVersion] AS v;

------------------------------------------------------------
-- DWServerSetup
------------------------------------------------------------
SELECT
    CAST(s.[key] AS NVARCHAR(255))
        COLLATE DATABASE_DEFAULT AS [key],
    s.[value]
INTO #tempDWServerSetup
FROM [dbo].[dwserversetup] AS s;

------------------------------------------------------------
-- DWOrganizationDB
------------------------------------------------------------
SELECT
    CAST(o.[guid] AS NVARCHAR(255))
        COLLATE DATABASE_DEFAULT AS [guid],
    CAST(o.[organization] AS NVARCHAR(255))
        COLLATE DATABASE_DEFAULT AS [organization]
INTO #tempDWOrganizationDB
FROM [dbo].[DWOrganizationDB] AS o;

------------------------------------------------------------
-- DWSystemSettings
------------------------------------------------------------
SELECT
    CAST(ss.[guid] AS NVARCHAR(255))
        COLLATE DATABASE_DEFAULT AS [guid],
    CAST(ss.[type] AS NVARCHAR(255))
        COLLATE DATABASE_DEFAULT AS [type],
    ss.[settings]
INTO #tempDWSystemSettings
FROM [dwsystem].[dbo].[DWSystemSettings] AS ss;

------------------------------------------------------------
-- DWSystemUser
------------------------------------------------------------
SELECT
    CAST(u.[name] AS NVARCHAR(255))
        COLLATE DATABASE_DEFAULT AS [name],
    u.[uid]
INTO #tempDWSystemUser
FROM [dbo].[DWSystemUser] AS u;

------------------------------------------------------------
-- Names the Intial columns and grabs data from DWORGDBVERSION
------------------------------------------------------------
SELECT
    N'DWOrgDBVersion'
        COLLATE DATABASE_DEFAULT AS [SourceTable],

    CAST(CONCAT(N'DW Version: ', v.[version]) AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT AS [Info and Guids],

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT AS [Info],

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT AS [Web Connection Name],

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT AS [Http Root],

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT AS [Machine],

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT AS [Connection Information],

    CAST(NULL AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT AS [Update Statement]

FROM #tempDWOrgDBVersion AS v

UNION ALL

SELECT
    N'DWOrganizationDB'
        COLLATE DATABASE_DEFAULT,

    CAST(CONCAT(N'Org Guid: ', o.[guid]) AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST(CONCAT(N'Org Name: ', o.[organization]) AS NVARCHAR(MAX))
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

FROM #tempDWOrganizationDB AS o

UNION ALL

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

------------------------------------------------------------
-- DWSystemSettings: WebConnection rows
------------------------------------------------------------
SELECT
    N'DWSystemSettings'
        COLLATE DATABASE_DEFAULT,

    CAST(CONCAT(N'Guid: ', d.[guid]) AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST(d.[type] AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST(
        d.[settings].value(
            '(//WebConnection/@name)[1]',
            'nvarchar(200)'
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT,

    CAST(
        d.[settings].value(
            '(//WebConnection/@httpRoot)[1]',
            'nvarchar(500)'
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT,

    CAST(
        d.[settings].value(
            '(//WebConnection/@machine)[1]',
            'nvarchar(200)'
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT,

    CAST(
        CONCAT(
            N'Database=',
            d.[settings].value(
                '(//DatabaseConnection/Connection/Database/text())[1]',
                'nvarchar(200)'
            ),
            N'; Port=',
            d.[settings].value(
                '(//DatabaseConnection/Connection/Port/text())[1]',
                'nvarchar(20)'
            ),
            N'; Login=',
            d.[settings].value(
                '(//DatabaseConnection/Connection/Login/UserName/text())[1]',
                'nvarchar(200)'
            )
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT,

    CAST(
        CONCAT(
            N'UPDATE [dwsystem].[dbo].[DWSystemSettings]',
            CHAR(13),
            CHAR(10),
            N'SET [settings] = N''',
            REPLACE(
                CAST(d.[settings] AS NVARCHAR(MAX)),
                N'''',
                N''''''
            ),
            N'''',
            CHAR(13),
            CHAR(10),
            N'WHERE [guid] = N''',
            REPLACE(d.[guid], N'''', N''''''),
            N''';'
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT

FROM #tempDWSystemSettings AS d
WHERE
    d.[settings].exist('(//WebConnection)[1]') = 1
    -- OR d.[settings].exist('(//DatabaseConnection)[1]') = 1

UNION ALL

------------------------------------------------------------
-- DWSystemSettings: DatabaseConnection rows
------------------------------------------------------------
SELECT
    N'DWSystemSettings'
        COLLATE DATABASE_DEFAULT,

    CAST(CONCAT(N'Guid: ', d.[guid]) AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST(d.[type] AS NVARCHAR(MAX))
        COLLATE DATABASE_DEFAULT,

    CAST(
        d.[settings].value(
            '(//WebConnection/@name)[1]',
            'nvarchar(200)'
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT,

    CAST(
        d.[settings].value(
            '(//WebConnection/@httpRoot)[1]',
            'nvarchar(500)'
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT,

    CAST(
        d.[settings].value(
            '(//DatabaseConnection/Connection/Server/text())[1]',
            'nvarchar(200)'
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT,

    CAST(
        CONCAT(
            N'Name=',
            d.[settings].value(
                '(//DatabaseConnection/Connection/Name/text())[1]',
                'nvarchar(200)'
            ),
            N'; Database=',
            d.[settings].value(
                '(//DatabaseConnection/Connection/Database/text())[1]',
                'nvarchar(200)'
            ),
            N'; Port=',
            d.[settings].value(
                '(//DatabaseConnection/Connection/Port/text())[1]',
                'nvarchar(20)'
            ),
            N'; Login=',
            d.[settings].value(
                '(//DatabaseConnection/Connection/Login/UserName/text())[1]',
                'nvarchar(200)'
            )
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT,
CAST(
    CONCAT(
        N'UPDATE [dwsystem].[dbo].[DWSystemSettings]',
        CHAR(13), CHAR(10),
        N'SET [settings] =',
        CHAR(13), CHAR(10),
        N'''',
        CAST(d.[settings] AS NVARCHAR(MAX)),
        N'''',
        CHAR(13), CHAR(10),
        N'WHERE [guid] =''',
        d.[guid],
        N''';'
    )
    AS NVARCHAR(MAX)
) COLLATE DATABASE_DEFAULT AS [Update Statement]
FROM #tempDWSystemSettings AS d
WHERE
    d.[settings].exist('(//DatabaseConnection)[1]') = 1;

------------------------------------------------------------
-- Drop temp tables at the end
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