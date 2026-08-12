/* Good Query to see where a specific UID resides. Good to use if the Delete UID query misses a table 
Alternatively you can also run the following query to see what tables the UID column is located.

 SELECT
    TABLE_SCHEMA,
    TABLE_NAME,
    COLUMN_NAME,
    DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE COLUMN_NAME = 'UID'
ORDER BY TABLE_SCHEMA, TABLE_NAME;

*/

SET NOCOUNT ON;

DECLARE @SearchUID INT = 4;
DECLARE @SQL NVARCHAR(MAX) = N'';

IF OBJECT_ID('tempdb..#UIDTables') IS NOT NULL
    DROP TABLE #UIDTables;

CREATE TABLE #UIDTables
(
    DatabaseName SYSNAME,
    SchemaName   SYSNAME,
    TableName    SYSNAME
);

INSERT INTO #UIDTables
SELECT 'dwsystem', s.name, t.name
FROM dwsystem.sys.tables t
JOIN dwsystem.sys.schemas s ON s.schema_id = t.schema_id
JOIN dwsystem.sys.columns c ON c.object_id = t.object_id
WHERE c.name = 'UID'
  AND c.system_type_id = 56

UNION ALL

SELECT 'dwdata', s.name, t.name
FROM dwdata.sys.tables t
JOIN dwdata.sys.schemas s ON s.schema_id = t.schema_id
JOIN dwdata.sys.columns c ON c.object_id = t.object_id
WHERE c.name = 'UID'
  AND c.system_type_id = 56

UNION ALL

SELECT 'dwworkflowengine', s.name, t.name
FROM dwworkflowengine.sys.tables t
JOIN dwworkflowengine.sys.schemas s ON s.schema_id = t.schema_id
JOIN dwworkflowengine.sys.columns c ON c.object_id = t.object_id
WHERE c.name = 'UID'
  AND c.system_type_id = 56

UNION ALL

SELECT 'dwnotification', s.name, t.name
FROM dwnotification.sys.tables t
JOIN dwnotification.sys.schemas s ON s.schema_id = t.schema_id
JOIN dwnotification.sys.columns c ON c.object_id = t.object_id
WHERE c.name = 'UID'
  AND c.system_type_id = 56;

SELECT @SQL =
    STRING_AGG(
        '
SELECT
    ''' + DatabaseName + ''' AS DatabaseName,
    ''' + SchemaName + ''' AS SchemaName,
    ''' + TableName + ''' AS TableName,
    COUNT_BIG(*) AS MatchCount
FROM '
        + QUOTENAME(DatabaseName) + '.'
        + QUOTENAME(SchemaName) + '.'
        + QUOTENAME(TableName) + '
WHERE UID = @SearchUID
HAVING COUNT_BIG(*) > 0',
        '
UNION ALL
'
    )
FROM #UIDTables;

EXEC sp_executesql
    @SQL,
    N'@SearchUID INT',
    @SearchUID;

	select * from #UIDTables
