# General-Scripts Run in Elevated Permissions #
## IIS AppPool PS script that allows you to change all of Docuware App Pools with ease.
  - User's must have Logon Batch, Logon Service, Security Perms.
  - This is a easy script to adjust in case you want it for any app pool just by changing the -like "Docuware*" part of the script.

## Docuware Timeout Script (Adjusts timeouts)
  - https://support.docuware.com/en-us/knowledgebase/article/KBA-34459
  - Searches locations listed in the code for the docuware.dal.dll.config 
  - Changes the timeout of the application to 10 minutes.(adjustable)
  - Writes logs of what changed.
## Version Check Tool 
  - https://support.docuware.com/en-us/knowledgebase/article/KBA-36256
  - Searches for ALL docuware.dal.dll.config files in the C: default location.
  - I would make sure to read the KBA before applying to understand the ramifications but this script will allow you to breeze through this.
## Total Count Limit Search in Docuware (Pagination)
  - Limits Search count in Docuware to 10,000 records. (Adjustable in the code)
  - Copies dwmachine.config as a .bak and creates a Docuware.content.settings file
  - https://support.docuware.com/en-us/knowledgebase/article/KBA-37189

#### Possible bugs:
  - Can't run the scripts as is. May need to copy the script and paste into powershell.
