/* Uncomment and change X AND Y to the UID/UIDs equivalent
BEGIN TRANSACTION;

DELETE FROM [dwsystem].[dbo].[DWClientLicense]
WHERE UID BETWEEN X AND Y;

DELETE FROM [dwsystem].[dbo].[DWFCProfileToUser]
WHERE UID BETWEEN X AND Y;

DELETE FROM [dwsystem].[dbo].[DWFCSettingsToUser]
WHERE UID BETWEEN X AND Y;

DELETE FROM [dwsystem].[dbo].[DWGeneralProfileToUser]
WHERE UID BETWEEN X AND Y;

DELETE FROM [dwsystem].[dbo].[DWUserSettings]
WHERE UID BETWEEN X AND Y;

DELETE FROM [dwsystem].[dbo].[DWUserToGroup]
WHERE UID BETWEEN X AND Y;

DELETE FROM [dwsystem].[dbo].[DWUserToRole]
WHERE UID BETWEEN X AND Y;

DELETE FROM [dwsystem].[dbo].[DWUserTokenIdentity]
WHERE UID BETWEEN X AND Y;

DELETE FROM [dwsystem].[dbo].[DWSSOExcludedUser]
WHERE UID BETWEEN X AND Y;

DELETE FROM [dwsystem].[dbo].[DwResetPasswordToken]
WHERE UID BETWEEN X AND Y;

-- Depending on your schema, these may or may not actually be user-owned by UID:
DELETE FROM [dwsystem].[dbo].[DWLicense]
WHERE UID BETWEEN X AND Y;

DELETE FROM [dwsystem].[dbo].[DWSystemUser]
WHERE UID BETWEEN X AND Y;

DELETE FROM [dwsystem].[dbo].[DWUser]
WHERE UID BETWEEN X AND Y;

COMMIT TRANSACTION;
*/
