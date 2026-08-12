WITH userbase AS (
      SELECT
          u.[uid],
          u.[shortname] AS [UserLogin],
          u.[name]      AS [UserName],
          u.[email],
          u.[active],
          u.[password_change]
      FROM [dwsystem].[dbo].[DWUser] u
  ),

  renames AS (
      SELECT DISTINCT
          ub.[uid],
          x.value('@oldValue', 'nvarchar(256)') AS [OldUserName]
      FROM [dwsystem].[dbo].[DWOrgSettingsAudit] a
      CROSS APPLY a.[eventData].nodes('//AuditEntryValue[@name="UsernameAudit.Property"]') AS t(x)
      INNER JOIN userbase ub
          ON x.value('@newValue', 'nvarchar(256)') COLLATE SQL_Latin1_General_CP1_CI_AS
           = ub.[UserName] COLLATE SQL_Latin1_General_CP1_CI_AS
      WHERE a.[objectType] = 2
        AND a.[eventType] = 1
  ),

  user_names AS (
      SELECT [uid], CAST([UserName] AS nvarchar(256)) COLLATE SQL_Latin1_General_CP1_CI_AS AS [MatchName] FROM userbase
      UNION
      SELECT [uid], CAST([email] AS nvarchar(256)) COLLATE SQL_Latin1_General_CP1_CI_AS FROM userbase
      UNION
      SELECT [uid], CAST([UserLogin] AS nvarchar(256)) COLLATE SQL_Latin1_General_CP1_CI_AS FROM userbase
      UNION
      SELECT [uid], CAST([UserName] + '@cfworks.com' AS nvarchar(256)) COLLATE SQL_Latin1_General_CP1_CI_AS FROM userbase
      UNION
      SELECT [uid], CAST([UserName] + '@precastcorp.com' AS nvarchar(256)) COLLATE SQL_Latin1_General_CP1_CI_AS FROM userbase
      UNION
      SELECT [uid], CAST([UserName] + '@wyman.com' AS nvarchar(256)) COLLATE SQL_Latin1_General_CP1_CI_AS FROM userbase
      UNION
      SELECT [uid], CAST([OldUserName] AS nvarchar(256)) COLLATE SQL_Latin1_General_CP1_CI_AS FROM renames
      UNION
      SELECT [uid], CAST([OldUserName] + '@cfworks.com' AS nvarchar(256)) COLLATE SQL_Latin1_General_CP1_CI_AS FROM renames
      UNION
      SELECT [uid], CAST([OldUserName] + '@precastcorp.com' AS nvarchar(256)) COLLATE SQL_Latin1_General_CP1_CI_AS FROM renames
      UNION
      SELECT [uid], CAST([OldUserName] + '@wyman.com' AS nvarchar(256)) COLLATE SQL_Latin1_General_CP1_CI_AS FROM renames
  ),

  audit_summary AS (
      SELECT
          un.[uid],
          MAX(CASE WHEN a.[eventType] = 3 THEN a.[eventLoggedDate] END)  AS [LastLogin_UTC],
          MAX(CASE WHEN a.[eventType] = 4 THEN a.[eventLoggedDate] END)  AS [LastLogout_UTC],
          MIN(CASE WHEN a.[eventType] = 0 THEN a.[eventLoggedDate] END)  AS [CreationDate_UTC],
          MIN(CASE WHEN a.[eventType] = 0 THEN a.[objectName] END)       AS [CreationMatchedObjectName],
          MIN(CASE WHEN a.[eventType] = 0 THEN a.[userInitiated] END)    AS [CreationInitiatedBy]
      FROM user_names un
      INNER JOIN [dwsystem].[dbo].[DWOrgSettingsAudit] a
          ON a.[objectType] = 2
          AND a.[objectName] = un.[MatchName]
      GROUP BY un.[uid]
  ),

  allroles AS (
      SELECT u.[uid], r.[name] AS [RoleName]
      FROM [dwsystem].[dbo].[DWUser] u
      INNER JOIN [dwsystem].[dbo].[DWUserToRole] ur ON u.[uid] = ur.[uid]
      INNER JOIN [dwsystem].[dbo].[DWRoles] r ON ur.[rid] = r.[rid]
      WHERE r.[active] = 1

      UNION

      SELECT u.[uid], r.[name]
      FROM [dwsystem].[dbo].[DWUser] u
      INNER JOIN [dwsystem].[dbo].[DWUserToGroup] ug ON u.[uid] = ug.[uid]
      INNER JOIN [dwsystem].[dbo].[DWGroup] g ON ug.[gid] = g.[gid]
      INNER JOIN [dwsystem].[dbo].[DWGroupToRole] gr ON g.[gid] = gr.[gid]
      INNER JOIN [dwsystem].[dbo].[DWRoles] r ON gr.[rid] = r.[rid]
      WHERE g.[active] = 1 AND r.[active] = 1
  ),

  rolesummary AS (
      SELECT
          ar.[uid],
          STRING_AGG(ar.[RoleName], '; ') AS [AllRoles],
          MAX(CASE WHEN ar.[RoleName] = 'Administrator' THEN 1 ELSE 0 END) AS [IsAdministrator],
          MAX(CASE WHEN ar.[RoleName] = 'Designer' THEN 1 ELSE 0 END) AS [IsDesigner]
      FROM allroles ar
      GROUP BY ar.[uid]
  ),

  groupsummary AS (
      SELECT
          ug.[uid],
          STRING_AGG(g.[name], '; ') AS [AllGroups]
      FROM (
          SELECT DISTINCT u.[uid], ug.[gid]
          FROM [dwsystem].[dbo].[DWUserToGroup] ug
          INNER JOIN [dwsystem].[dbo].[DWUser] u ON u.[uid] = ug.[uid]
      ) ug
      INNER JOIN [dwsystem].[dbo].[DWGroup] g ON ug.[gid] = g.[gid]
      WHERE g.[active] = 1
      GROUP BY ug.[uid]
  )

  SELECT
      ub.[uid],
      ub.[UserLogin],
      ub.[UserName],
      ub.[email],
      CASE WHEN ub.[active] = 1 THEN 'Active' ELSE 'Inactive' END AS [UserStatus],
      CASE
          WHEN ISNULL(rs.[IsAdministrator], 0) = 1 AND ISNULL(rs.[IsDesigner], 0) = 1 THEN 'Admin / Designer'
          WHEN ISNULL(rs.[IsAdministrator], 0) = 1 THEN 'Admin'
          WHEN ISNULL(rs.[IsDesigner], 0) = 1 THEN 'Designer'
          ELSE 'User'
      END AS [AccountType],
      ISNULL(rs.[IsAdministrator], 0) AS [IsAdministrator],
      ISNULL(rs.[IsDesigner], 0) AS [IsDesigner],
      gs.[AllGroups],
      rs.[AllRoles],
      aus.[CreationDate_UTC],
      DATEADD(HOUR, -5, aus.[CreationDate_UTC]) AS [CreationDate_CDT],
      CASE
          WHEN aus.[CreationDate_UTC] IS NOT NULL THEN 'Audit - Created Event'
          ELSE 'No Create Event Found'
      END AS [CreationDateSource],
      aus.[CreationMatchedObjectName],
      aus.[CreationInitiatedBy],
      aus.[LastLogin_UTC],
      DATEADD(HOUR, -5, aus.[LastLogin_UTC]) AS [LastLogin_CDT],
      aus.[LastLogout_UTC],
      DATEADD(HOUR, -5, aus.[LastLogout_UTC]) AS [LastLogout_CDT],
      ub.[password_change] AS [LastPasswordSet]
  FROM userbase ub
  LEFT JOIN audit_summary aus ON ub.[uid] = aus.[uid]
  LEFT JOIN rolesummary rs ON ub.[uid] = rs.[uid]
  LEFT JOIN groupsummary gs ON ub.[uid] = gs.[uid]
  ORDER BY ub.[UserName], [AccountType];