 /* Adjust the UID to what your Admin UID is.
 This is to fix any issues of users creating creating File Cabinets and the Admin did not get owner permissions.
 This effectively changes all owners to the UID declared.
 Realistically only the Admins should be creating cabinets and then giving ownership.

 Alternatively you can also insert a user in this table to give ownership rights.

 update [dwsystem].[dbo].[DWFCProfileToUser]
 set uid = 1

 */