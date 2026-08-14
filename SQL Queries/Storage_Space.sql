/* This scripts provides information on some of the most storage intensive parts of Docuware that can be shrunk without consequences. 

Refer to the how_to_shrink column

*NOTE* These are permanent results and only having backups would revert some of these changes and Docuware is not responsible for any compliance issues after deleting any information
from these tables. 

Information Regarding the tables
_AUD is Audit information of every action regarding those file cabinets.
DWTB is the docuware trashbin after deleting a document, it resides here for 30 days until deletion.
DWExpiredTasks are failed tasks from the DWTask table so these are safe to truncate
DWTasks are tasks that Docuware is currently processing and shouldn't be truncated unless you know that this table is *Stuck* 
	Best to let Docuware Support assist with this issue.


	*There is two more audit tables located in dwsystem that don't fill up as quickly as _AUD and I wouldn't suggest truncating these unless they are actually a problem.*
	[dwsystem].[dbo].[DWOrgSettingsAudit]
	[dbo].[DWSystemSettingsAudit]
*/

-- AUD tables and DWTB from dwdata
SELECT
    'dwdata' AS database_name,
    t.name AS table_name,
    CASE
        WHEN t.name LIKE '%[_]AUD'
            THEN 'TRUNCATE TABLE ' + QUOTENAME(s.name) + '.' + QUOTENAME(t.name)
        WHEN t.name LIKE '%DWTB%'
            THEN 'https://support.docuware.com/en-us/knowledgebase/article/KBA-37164'
    END AS how_to_shrink,
    SUM(CASE WHEN ps.index_id IN (0,1) THEN ps.row_count ELSE 0 END) AS total_rows,
    CAST(SUM(ps.reserved_page_count) * 8.0 / 1024 / 1024 AS DECIMAL(18,4)) AS total_size_gb
FROM dwdata.sys.tables t
JOIN dwdata.sys.schemas s
    ON t.schema_id = s.schema_id
JOIN dwdata.sys.dm_db_partition_stats ps
    ON t.object_id = ps.object_id
WHERE t.name LIKE '%[_]AUD'
   OR t.name LIKE '%DWTB%'
GROUP BY s.name, t.name

UNION ALL

-- Task tables from dwsystem
SELECT
    'dwsystem' AS database_name,
    t.name AS table_name,
    'TRUNCATE TABLE ' + QUOTENAME(s.name) + '.' + QUOTENAME(t.name) AS how_to_shrink,
    SUM(CASE WHEN ps.index_id IN (0,1) THEN ps.row_count ELSE 0 END) AS total_rows,
    CAST(SUM(ps.reserved_page_count) * 8.0 / 1024 / 1024 AS DECIMAL(18,4)) AS total_size_gb
FROM dwsystem.sys.tables t
JOIN dwsystem.sys.schemas s
    ON t.schema_id = s.schema_id
JOIN dwsystem.sys.dm_db_partition_stats ps
    ON t.object_id = ps.object_id
WHERE t.name IN ('DWTasks', 'DWExpiredTasks')
GROUP BY s.name, t.name

ORDER BY database_name, total_size_gb DESC;