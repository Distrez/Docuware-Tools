#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [string]$ServerConfigPath = 'C:\ProgramData\DocuWare\ServerConfig',
    [int]$SearchTotalCountLimit = 10000
   # For future testing [switch]$RestartDocuWareServices
)

# User confirmation must occur before any configuration changes are made.
while ($true) {
        Write-Host ' ----------------------------------------------------- '
        Write-Warning 'You will need to bring down services, MSMQ/IISRESET, Then turn services back online.'
        Write-Warning 'If you are using Server Manager, you will need to close that application as well for changes to take effect.'
        Write-Host 'This will set the search limit to 10000. This is adjustable in the code.' -ForegroundColor Cyan
        Write-Host ''
    $confirmation = Read-Host 'This is a script to run this KBA-37189 do you want to run it? (Yes/No)'

    switch ($confirmation.Trim().ToLowerInvariant()) {
        { $_ -in @('yes', 'y') } {
            Write-Host 'Yes selected. Starting KBA-37189 configuration...' -ForegroundColor Green
            break
        }
        { $_ -in @('no', 'n') } {
            Write-Host 'No selected. The script will now end. No changes were made.' -ForegroundColor Yellow
            break 0
        }
        default {
            Write-Host 'Invalid response. Please enter Yes or No.' -ForegroundColor Yellow
        }
    }

    if ($confirmation.Trim().ToLowerInvariant() -in @('yes', 'y')) {
        break
    }
}

$ErrorActionPreference = 'Stop'

$dwmachinePath = Join-Path $ServerConfigPath 'dwmachine.config'
$contentSettingsPath = Join-Path $ServerConfigPath 'Docuware.Content.settings'
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    # Write directly to the destination. This avoids Move-Item failing when
    # the destination file already exists on Windows PowerShell 5.1.
    [System.IO.File]::WriteAllText($Path, $Content, $script:utf8NoBom)
}

function Test-XmlFile {
    param([Parameter(Mandatory = $true)][string]$Path)

    try {
        $null = [xml][System.IO.File]::ReadAllText($Path)
    }
    catch {
        throw "XML validation failed for '$Path'. $($_.Exception.Message)"
    }
}

Write-Host 'Configuring DocuWare TotalCountLimit...' -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $ServerConfigPath -PathType Container)) {
    throw "The ServerConfig directory was not found: $ServerConfigPath"
}

if (-not (Test-Path -LiteralPath $dwmachinePath -PathType Leaf)) {
    throw "The dwmachine.config file was not found: $dwmachinePath"
}

# Validate the original before making any changes.
Test-XmlFile -Path $dwmachinePath

$dwmachineBackup = "$dwmachinePath.$timestamp.bak"
Copy-Item -LiteralPath $dwmachinePath -Destination $dwmachineBackup -Force
Write-Host "Backup created: $dwmachineBackup" -ForegroundColor Green

$dwmachineText = [System.IO.File]::ReadAllText($dwmachinePath)
$newLine = if ($dwmachineText -match "`r`n") { "`r`n" } else { "`n" }
$settingLine = '      <Setting Key="ContentConfigPath" Value="C:\ProgramData\DocuWare\ServerConfig\Docuware.Content.settings" Encrypted="false" />'

# Remove an existing ContentConfigPath entry so the result is idempotent and
# so the setting can be placed in the exact requested location.
$existingPattern = '(?m)^[\t ]*<Setting\s+Key="ContentConfigPath"[^>]*/>\s*\r?\n?'
$dwmachineText = [regex]::Replace($dwmachineText, $existingPattern, '')

# Insert ContentConfigPath as the first child directly beneath <Settings>.
# This does not depend on DatabaseType being present or on a particular indentation style.
$settingsPattern = '(?is)<Settings(?:\s[^>]*)?>'
$settingsMatch = [regex]::Match($dwmachineText, $settingsPattern)
if (-not $settingsMatch.Success) {
    throw 'Could not find the opening <Settings> element. No changes were written to dwmachine.config.'
}

$insertIndex = $settingsMatch.Index + $settingsMatch.Length
$dwmachineText = $dwmachineText.Insert($insertIndex, $newLine + $settingLine)

# Validate the proposed XML before overwriting the original file.
try {
    $null = [xml]$dwmachineText
}
catch {
    throw "The proposed dwmachine.config content is not valid XML. The backup is at '$dwmachineBackup'. $($_.Exception.Message)"
}

Write-Utf8NoBom -Path $dwmachinePath -Content $dwmachineText
Test-XmlFile -Path $dwmachinePath
Write-Host 'Added ContentConfigPath as the first entry beneath <Settings> in dwmachine.config.' -ForegroundColor Green

if (Test-Path -LiteralPath $contentSettingsPath -PathType Leaf) {
    $contentSettingsBackup = "$contentSettingsPath.$timestamp.bak"
    Copy-Item -LiteralPath $contentSettingsPath -Destination $contentSettingsBackup -Force
    Write-Host "Backup created: $contentSettingsBackup" -ForegroundColor Green
}

$contentSettingsXml = @"
<?xml version="1.0" encoding="utf-8"?>
<configuration>
  <configSections>
    <section name="ContentConfig" type="DocuWare.Content.Shared.Implementation.ContentConfig, DocuWare.Content.Shared.Implementation" />
    <section name="Unity" type="Microsoft.Practices.Unity.Configuration.UnityConfigurationSection, Unity.Configuration" />
  </configSections>
  <ContentConfig LockExpirationCleanupPeriod="00:01:00" DocumentsForAutoIntellixCount="5" PagesToProcessTogetherForTextshot="8" ImagingSingleOperationTimeout="00:00:45" LongRunnningImagingOperationTimeout="00:01:00" SearchTotalCountLimit="$SearchTotalCountLimit">
    <SectionFileConfiguration ReleasePeriod="00:01:00" DeleteRetryCount="3" PollingInterval="00:00:30" />
    <FulltextConfiguration MaxHitsCount="1000" SearchFullTextOnly="false" SkipWildcardSearchFallback="false" FullTextCoreCreationParametersFormatString="name= {0}&amp;instanceDir=.&amp;dataDir= {1}&amp;loadOnStartup=false&amp;transient=false" />
    <CenteraConfiguration BufferSize="64" />
    <TableFieldsConfiguration DefaultColumnsLimit="50" DefaultRowsLimit="1000" />
  </ContentConfig>
  <Unity xmlns="http://schemas.microsoft.com/practices/2010/unity">
    <container name="FulltextProvider">
      <register type="DocuWare.Fulltext.IFullTextFactory, DocuWare.FulltextCommon" mapTo="DocuWare.Fulltext.Solr.DefaultFullTextFactory, DocuWare.SOLRFulltext" />
      <!--<register type="DocuWare.Fulltext.IFullTextFactory, DocuWare.FulltextCommon" mapTo="DocuWare.Fulltext.Elastic.ElasticFulltextFactory, DocuWare.ElasticFulltext" />-->
    </container>
  </Unity>
</configuration>
"@

# Validate the new settings content before creating/replacing the file.
try {
    $null = [xml]$contentSettingsXml
}
catch {
    throw "The generated Docuware.Content.settings content is not valid XML. $($_.Exception.Message)"
}

Write-Utf8NoBom -Path $contentSettingsPath -Content $contentSettingsXml

if (-not (Test-Path -LiteralPath $contentSettingsPath -PathType Leaf)) {
    throw "Docuware.Content.settings was not created at: $contentSettingsPath"
}

Test-XmlFile -Path $contentSettingsPath
Write-Host "Created or updated: $contentSettingsPath" -ForegroundColor Green

Write-Warning 'Configuration is complete. Stop all DocuWare services, run IISRESET, and then restart the DocuWare services before testing.'

Write-Host 'Completed successfully.' -ForegroundColor Cyan
