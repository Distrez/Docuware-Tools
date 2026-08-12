Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ============================
# SETTINGS
# ============================

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

# Data provider and desired checkVersion value are selected interactively below.
# https://support.docuware.com/en-us/knowledgebase/article/KBA-36256
$selectedProviderName = $null
$selectedProviderLabel = $null
$desiredCheckVersion = $null

# Roots to scan
$searchRoots = @(
    'C:\Program Files (x86)\DocuWare\Authentication Server',
    'C:\Program Files\DocuWare\Web',
    'C:\Program Files\DocuWare\Background Process Service',
    'C:\Program Files\DocuWare\Server Manager',
    'C:\Program Files (x86)\DocuWare\Setup Components',
    'C:\Program Files (x86)\DocuWare\Power Tools'
)

# Encoding step: convert to UTF-8 (NO BOM) only if BOM exists
$ConvertToUtf8NoBom_OnlyIfBomExists = $true

# Logs
$logDirectory = 'C:\Temp\DocuWare-DataProvider-CheckVersion-Logs'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
$csvPath = Join-Path $logDirectory "DataProvider_CheckVersion_ZeroReformat_$timestamp.csv"


# ============================
# USER PROMPTS
# ============================

Write-Host ""
Write-Host "DocuWare dataProvider checkVersion configuration" -ForegroundColor Cyan
Write-Host "This script will update checkVersion for the selected DocuWare dataProvider." -ForegroundColor Cyan
Write-Host ""

do {
    Write-Host "Database Provider Options:"
    Write-Host "  1. MSSQL - dataProvider name `"SqlClient`""
    Write-Host "  2. MySQL - dataProvider name `"MySQLClient`""
    Write-Host ""

    $providerChoice = Read-Host "Enter 1 for MSSQL or 2 for MySQL"
}
until ($providerChoice -in @('1', '2'))

switch ($providerChoice) {
    '1' {
        $selectedProviderName = 'SqlClient'
        $selectedProviderLabel = 'MSSQL'
    }
    '2' {
        $selectedProviderName = 'MySQLClient'
        $selectedProviderLabel = 'MySQL'
    }
}

Write-Host ""
Write-Host ("Selected provider: {0} / {1}" -f $selectedProviderLabel, $selectedProviderName) -ForegroundColor Green
Write-Host ""

do {
    $checkVersionChoice = Read-Host "Set checkVersion to True or False? Enter True or False"
}
until ($checkVersionChoice -match '(?i)^(true|false)$')

# Normalize to lowercase for consistency.
# Final capitalization does not matter.
$desiredCheckVersion = $checkVersionChoice.ToLowerInvariant()

Write-Host ""
Write-Host "Configuration selected:" -ForegroundColor Cyan
Write-Host ("  Provider Label:       {0}" -f $selectedProviderLabel)
Write-Host ("  dataProvider name:    {0}" -f $selectedProviderName)
Write-Host ("  checkVersion value:   {0}" -f $desiredCheckVersion)
Write-Host ("  Log path:             {0}" -f $csvPath)
Write-Host ""

do {
    $continueChoice = Read-Host "Continue with these settings? Enter Y to continue or N to cancel"
}
until ($continueChoice -match '(?i)^(y|n)$')

if ($continueChoice -match '(?i)^n$') {
    Write-Host "Operation cancelled by user. No files were changed." -ForegroundColor Yellow
    return
}


# ============================
# HELPERS
# ============================

function Get-BomType {
    param([byte[]]$Bytes)

    if ($Bytes.Length -ge 4) {
        if ($Bytes[0] -eq 0x00 -and $Bytes[1] -eq 0x00 -and $Bytes[2] -eq 0xFE -and $Bytes[3] -eq 0xFF) { return 'UTF32BE' }
        if ($Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE -and $Bytes[2] -eq 0x00 -and $Bytes[3] -eq 0x00) { return 'UTF32LE' }
    }

    if ($Bytes.Length -ge 3) {
        if ($Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) { return 'UTF8BOM' }
    }

    if ($Bytes.Length -ge 2) {
        if ($Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE) { return 'UTF16LE' }
        if ($Bytes[0] -eq 0xFE -and $Bytes[1] -eq 0xFF) { return 'UTF16BE' }
    }

    return $null
}

function Read-TextWithEncodingDetection {
    param([Parameter(Mandatory)] [string] $Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $bomType = Get-BomType -Bytes $bytes
    $hasBom = [bool]$bomType

    $fs = [System.IO.File]::Open(
        $Path,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::ReadWrite
    )

    try {
        # detectEncodingFromByteOrderMarks = $true
        $sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8, $true)

        try {
            $text = $sr.ReadToEnd()
            $enc  = $sr.CurrentEncoding
        }
        finally {
            $sr.Dispose()
        }
    }
    finally {
        $fs.Dispose()
    }

    [PSCustomObject]@{
        Text     = $text
        Encoding = $enc
        HasBom   = $hasBom
        BomType  = $bomType
    }
}

function Write-TextPreserveEncoding {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Text,
        [Parameter(Mandatory)] [System.Text.Encoding] $Encoding,
        [Parameter(Mandatory)] [bool] $HasBom
    )

    $body = $Encoding.GetBytes($Text)

    if ($HasBom -and $Encoding.GetPreamble().Length -gt 0) {
        $bom = $Encoding.GetPreamble()
        $out = New-Object byte[] ($bom.Length + $body.Length)

        [System.Buffer]::BlockCopy($bom, 0, $out, 0, $bom.Length)
        [System.Buffer]::BlockCopy($body, 0, $out, $bom.Length, $body.Length)

        [System.IO.File]::WriteAllBytes($Path, $out)
    }
    else {
        [System.IO.File]::WriteAllBytes($Path, $body)
    }
}

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Text
    )

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllBytes($Path, $utf8NoBom.GetBytes($Text))
}

function Mask-XmlComments {
    param([Parameter(Mandatory)] [string] $Text)

    # Replace <!-- ... --> with same-length spaces so indices remain aligned.
    $rx = New-Object System.Text.RegularExpressions.Regex(
        '<!--.*?-->',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )

    $rx.Replace($Text, { param($m) (' ' * $m.Value.Length) })
}

function Find-FirstActiveDataProviderTag {
    param(
        [Parameter(Mandatory)] [string] $Text,
        [Parameter(Mandatory)] [string] $ProviderName
    )

    $masked = Mask-XmlComments -Text $Text

    # Match full start tag: <dataProvider ...>
    # Then filter to the selected provider name:
    #   MSSQL: name="SqlClient"
    #   MySQL: name="MySQLClient"
    $rxTag = New-Object System.Text.RegularExpressions.Regex(
        '<\s*dataProvider\b[^>]*>',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )

    $matches = $rxTag.Matches($masked)

    if ($matches.Count -eq 0) {
        return $null
    }

    $escapedProviderName = [System.Text.RegularExpressions.Regex]::Escape($ProviderName)

    foreach ($m in $matches) {
        $tagText = $masked.Substring($m.Index, $m.Length)

        # Require name="<ProviderName>" or name='<ProviderName>', allowing whitespace around =
        $namePattern = "(?i)\sname\s*=\s*(['""])$escapedProviderName\1"

        if ($tagText -match $namePattern) {
            return [PSCustomObject]@{
                Start = $m.Index
                End   = ($m.Index + $m.Length - 1)
            }
        }
    }

    return $null
}

function Patch-DataProviderCheckVersion {
    param(
        [Parameter(Mandatory)] [string] $TagText,
        [Parameter(Mandatory)] [string] $DesiredValue
    )

    $changed = $false
    $newTag = $TagText

    # Match existing checkVersion attr:
    #   checkVersion="..."
    #   checkVersion='...'
    # Allows whitespace around =
    $pattern = '(?i)(\scheckVersion\s*=\s*)([''"])(.*?)(\2)'
    $m = [System.Text.RegularExpressions.Regex]::Match($newTag, $pattern)

    if ($m.Success) {
        $curVal = $m.Groups[3].Value

        if ($curVal -ne $DesiredValue) {
            $changed = $true
        }

        $prefix = $m.Groups[1].Value
        $quote  = $m.Groups[2].Value

        # Preserve original quote style.
        $replacement = $prefix + $quote + $DesiredValue + $quote

        $newTag = $newTag.Remove($m.Index, $m.Length).Insert($m.Index, $replacement)
    }
    else {
        # checkVersion attribute is missing.
        #
        # Per request, the script does NOT add checkVersion by default.
        # If the KBA requires adding the attribute when missing, uncomment the block below.
        #
        # $ins = " checkVersion=`"$DesiredValue`""
        # $newTag2 = [System.Text.RegularExpressions.Regex]::Replace(
        #     $newTag,
        #     '(\s*/?>)\s*$',
        #     ($ins + '$1'),
        #     1
        # )
        #
        # if ($newTag2 -ne $newTag) {
        #     $newTag = $newTag2
        #     $changed = $true
        # }
    }

    [PSCustomObject]@{
        NewTag  = $newTag
        Changed = $changed
        Missing = (-not $m.Success)
    }
}

function Convert-ToUtf8NoBom-IfBom {
    param([Parameter(Mandatory)] [string] $Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $bomType = Get-BomType -Bytes $bytes

    if (-not $bomType) {
        return [PSCustomObject]@{
            Converted = $false
            BomType   = $null
            FromEnc   = $null
        }
    }

    $file = Read-TextWithEncodingDetection -Path $Path
    Write-Utf8NoBom -Path $Path -Text $file.Text

    return [PSCustomObject]@{
        Converted = $true
        BomType   = $bomType
        FromEnc   = $file.Encoding.WebName
    }
}


# ============================
# DISCOVERY DLL ADJACENCY
# ============================

Write-Host ""
Write-Host "Discovering DocuWare DAL config files..." -ForegroundColor Cyan

$rootsToScan = $searchRoots | Where-Object { Test-Path $_ } | Sort-Object -Unique
Write-Host ("Roots to scan: {0}" -f $rootsToScan.Count)

$cfgSet = New-Object 'System.Collections.Generic.HashSet[string]'

foreach ($root in $rootsToScan) {
    Write-Host "  Scanning $root" -ForegroundColor DarkCyan

    try {
        foreach ($dllPath in [System.IO.Directory]::EnumerateFiles($root, 'DocuWare.DAL.dll', [System.IO.SearchOption]::AllDirectories)) {
            $configPath = "$dllPath.config"

            # Only patch files named exactly DocuWare.DAL.dll.config
            if (
                [System.IO.File]::Exists($configPath) -and
                ([System.IO.Path]::GetFileName($configPath) -eq 'DocuWare.DAL.dll.config')
            ) {
                [void]$cfgSet.Add($configPath)
            }
        }
    }
    catch {
        Write-Host "    Warning skipped some paths: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

$configPaths = @($cfgSet) | Sort-Object
Write-Host ("Found {0} DocuWare.DAL.dll.config file(s)." -f $configPaths.Count) -ForegroundColor Green

if (-not $configPaths.Count) {
    Write-Host "No matching DocuWare.DAL.dll.config files found. Exiting." -ForegroundColor Yellow
    return
}


# ============================
# PROCESS ZERO REFORMAT
# ============================

$log = New-Object System.Collections.Generic.List[psobject]

foreach ($path in $configPaths) {
    Write-Host "Processing $path"

    $entry = [PSCustomObject]@{
        Path                 = $path
        SelectedProvider     = $selectedProviderName
        DesiredCheckVersion  = $desiredCheckVersion
        PatchStatus          = $null
        EncodingStatus       = $null
        BomType              = $null
        FromEncoding         = $null
        BackupCreated        = $false
        Timestamp            = Get-Date
        ErrorMessage         = $null
    }

    try {
        # One-time backup BEFORE changes.
        $backupPath = "$path.bak"

        if (-not (Test-Path $backupPath)) {
            Copy-Item -LiteralPath $path -Destination $backupPath
            $entry.BackupCreated = $true
        }

        # Read file using encoding detection.
        $file = Read-TextWithEncodingDetection -Path $path
        $text = $file.Text

        # Find active, uncommented:
        #   <dataProvider name="SqlClient" ...>
        # or:
        #   <dataProvider name="MySQLClient" ...>
        # depending on user selection.
        $tag = Find-FirstActiveDataProviderTag `
            -Text $text `
            -ProviderName $selectedProviderName

        if (-not $tag) {
            $entry.PatchStatus = 'MissingSelectedDataProvider'
        }
        else {
            $tagText = $text.Substring($tag.Start, $tag.End - $tag.Start + 1)

            $patch = Patch-DataProviderCheckVersion `
                -TagText $tagText `
                -DesiredValue $desiredCheckVersion

            if ($patch.Changed) {
                $newText = $text.Substring(0, $tag.Start) + $patch.NewTag + $text.Substring($tag.End + 1)

                # Write back with original encoding/BOM to avoid non-target changes.
                Write-TextPreserveEncoding `
                    -Path $path `
                    -Text $newText `
                    -Encoding $file.Encoding `
                    -HasBom $file.HasBom

                $entry.PatchStatus = 'Patched'
            }
            elseif ($patch.Missing) {
                $entry.PatchStatus = 'MissingCheckVersion'
            }
            else {
                $entry.PatchStatus = 'AlreadyCompliant'
            }
        }

        # Optional encoding conversion: only if BOM exists.
        if ($ConvertToUtf8NoBom_OnlyIfBomExists) {
            $conv = Convert-ToUtf8NoBom-IfBom -Path $path

            if ($conv.Converted) {
                $entry.EncodingStatus = 'Converted_ToUtf8NoBOM'
                $entry.BomType = $conv.BomType
                $entry.FromEncoding = $conv.FromEnc
            }
            else {
                $entry.EncodingStatus = 'Skipped_NoBOM'
            }
        }
        else {
            $entry.EncodingStatus = 'NotRequested'
        }
    }
    catch {
        $entry.PatchStatus = 'Error'
        $entry.EncodingStatus = 'Error'
        $entry.ErrorMessage = $_.Exception.Message
    }

    $log.Add($entry)
}


# ============================
# OUTPUT LOG AND SUMMARY
# ============================

$log | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

$patched      = @($log | Where-Object PatchStatus -eq 'Patched').Count
$compliant    = @($log | Where-Object PatchStatus -eq 'AlreadyCompliant').Count
$missingDp    = @($log | Where-Object PatchStatus -eq 'MissingSelectedDataProvider').Count
$missingCheck = @($log | Where-Object PatchStatus -eq 'MissingCheckVersion').Count
$converted    = @($log | Where-Object EncodingStatus -eq 'Converted_ToUtf8NoBOM').Count
$skipped      = @($log | Where-Object EncodingStatus -eq 'Skipped_NoBOM').Count
$errors       = @($log | Where-Object { $_.PatchStatus -eq 'Error' -or $_.EncodingStatus -eq 'Error' }).Count

Write-Host ""
Write-Host "Completed." -ForegroundColor Cyan
Write-Host ("  Selected provider:                {0}" -f $selectedProviderName)
Write-Host ("  Desired checkVersion:             {0}" -f $desiredCheckVersion)
Write-Host ("  Patched:                          {0}" -f $patched)
Write-Host ("  AlreadyCompliant:                 {0}" -f $compliant)
Write-Host ("  MissingSelectedDataProvider:      {0}" -f $missingDp)
