USE [dwsystem];
GO

SET NOCOUNT ON;

SELECT
    dos.[name] AS [Name_of_Process],
    bpm.[workState] AS [workState_is_running],
    dos.[guid],

    CASE dos.[type]
        WHEN N'DocuWare.Settings.BpsProcesses.RequestExport, DocuWare.Settings'
            THEN N'Request export job'

        WHEN N'DocuWare.Settings.FileConnection.FileConnectionSettings, DocuWare.Settings'
            THEN N'File connection job'

        WHEN N'DocuWare.Settings.ProcessServer.AutoIndexWorkflow, DocuWare.Settings'
            THEN N'Autoindex job'

        WHEN N'DocuWare.Settings.ProcessServer.DeletionProcess, DocuWare.Settings'
            THEN N'Deletion job'

        WHEN N'DocuWare.Settings.ProcessServer.SynchronizationProcess, DocuWare.Settings'
            THEN N'Synchronization job'

        ELSE dos.[type]
    END AS [Job_Type],

    CAST
    (
        CONCAT
        (
            /* First update: Change the workflow XML state to stopped */
            N'UPDATE [dwsystem].[dbo].[DWWorkflowStatus]',
            CHAR(13), CHAR(10),

            N'SET [status] = N''',

            REPLACE
            (
                REPLACE
                (
                    CAST(dws.[status] AS NVARCHAR(MAX)),
                    N'state="Running"',
                    N'state="Stopped"'
                ),
                N'''',
                N''''''
            ),

            N'''',
            CHAR(13), CHAR(10),

            N'WHERE [guid] = N''',

            REPLACE
            (
                CAST(dws.[guid] AS NVARCHAR(100)),
                N'''',
                N''''''
            ),

            N''';',

            /* Add a blank line between the two updates */
            CHAR(13), CHAR(10),
            CHAR(13), CHAR(10),

            /* Second update: Change the monitoring workState to 2 */
            N'UPDATE [dwsystem].[dbo].[DWBPSOrgMonitoring]',
            CHAR(13), CHAR(10),

            N'SET [workState] = 2',
            CHAR(13), CHAR(10),

            N'WHERE [processGuid] = N''',

            REPLACE
            (
                CAST(dos.[guid] AS NVARCHAR(100)),
                N'''',
                N''''''
            ),

            N''';'
        )
        AS NVARCHAR(MAX)
    ) COLLATE DATABASE_DEFAULT AS [Update Statement To Kill Running Process]

FROM [dwsystem].[dbo].[DWOrganizationSettings] AS dos

INNER JOIN [dwsystem].[dbo].[DWWorkflowStatus] AS dws
    ON dos.[guid] = dws.[guid]

INNER JOIN [dwsystem].[dbo].[DWBPSOrgMonitoring] AS bpm
    ON bpm.[processGuid] = dos.[guid]

WHERE dos.[type] IN
(
    N'DocuWare.Settings.BpsProcesses.RequestExport, DocuWare.Settings',
    N'DocuWare.Settings.FileConnection.FileConnectionSettings, DocuWare.Settings',
    N'DocuWare.Settings.ProcessServer.AutoIndexWorkflow, DocuWare.Settings',
    N'DocuWare.Settings.ProcessServer.DeletionProcess, DocuWare.Settings',
    N'DocuWare.Settings.ProcessServer.SynchronizationProcess, DocuWare.Settings'
)
AND bpm.[workState] = 3

ORDER BY
    dos.[type],
    dos.[name];
GO