# ==============================================================================
# SCRIPT: auditor+fixer.ps1
# VERSION: v2026.05.12_11.31.00
# TARGET: PowerShell 7.6.1 LTS
#
# Copyright (C) 2026 pwsh.Agyjkcrg761
# 
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# ==============================================================================
# <PROTECTED>
# ==============================================================================
# AI INSTRUCTIONS: 
# 1. HEADER: Update Version comment.
#    - VERSIONING: Update using CHICAGO TIME (Central Time). 
#    - CRITICAL: Do not use AI system time. Use the time provided in the most 
#      recent user prompt or link (Ref: https://www.timeanddate.com/worldclock/usa/chicago).
#    - STAMP ACCURACY: Ensure the minutes match the current Chicago clock exactly.
# 2. DO NOT modify or refactor any code inside <PROTECTED> tags.
# 3. SCRIPT OUTPUT:
#    - When printing the script only print snippets unless asked for entire script.
#    - Always use a codebox with a copy button.
#    - Show a clear beginning and end to the new code with and example of where to insert.
# ==============================================================================
# </PROTECTED>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$false, Position=0, ValueFromRemainingArguments=$true)] 
    [string[]]$PathParts,
    
    [switch]$Fix,        # Activates the Fixer module
    [switch]$FixDebug,
    [switch]$FixNoBackup,    # Disables the automatic 1-by-1 backup
    [Alias("Honorifics")]
    [switch]$Hon,          # New switch for Honorifics mode
    [Alias("ovrd")]
    [switch]$overrideDefaults,
    
    # New Automation Params
    [Alias("vid")] [string]$videoLanguage,
    [Alias("vidf")] [switch]$videoForceUpdate,
    [Alias("aud")] [string]$audioLanguagePriority,
    [Alias("sub")] [string]$subtitleLanguagePriority,
    [Alias("sc")]  [string]$subtitleCodecPriority,
    
    # New Western Mode Flags
    [Alias("west", "WesternMode")]
    [switch]$Western,
    [Alias("ovrdw")]
    [Switch]$OverrideWesternDefaults,
    
    # Western Mode Hearing Impaired Subs
    [switch]$sdh,
    [switch]$hi,
    [switch]$hicc,
    [switch]$cc,
    [switch]$SubtitlesHearingImpaired,
    
    #[Parameter(Mandatory=$false)]
    [switch]$Help,

    #[Parameter(Mandatory=$false)]
    [switch]$Manual
    
)

# --- HELP & MANUAL SYSTEM ---
if ($Help -or $Manual) {
    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " auditor+fixer.ps1 - MANUAL & USAGE GUIDE" -ForegroundColor DarkMagenta
    Write-Host " Copyright (C) 2026 pwsh.Agyjkcrg761`n" -ForegroundColor DarkCyan
    
    Write-Host " This program is free software: you can redistribute it and/or" -ForegroundColor DarkMagenta
    Write-Host " modify it under the terms of the GNU General Public License as" -ForegroundColor DarkMagenta
    Write-Host " published by the Free Software Foundation, either version 3 of" -ForegroundColor DarkMagenta
    Write-Host " the License, or (at your option) any later version." -ForegroundColor DarkMagenta
    Write-Host "============================================================" -ForegroundColor Cyan
    
    Write-Host "`n OVERVIEW:" -ForegroundColor DarkYellow
    Write-Host "  This utility is a high-fidelity media management tool designed to ensure" -ForegroundColor DarkCyan
    Write-Host "  structural consistency across MKV libraries. It operates in two stages:" -ForegroundColor DarkCyan
    Write-Host "  1. AUDIT: Scans files to identify 'Mismatch Groups' and track errors." -ForegroundColor DarkCyan
    Write-Host "  2. FIX:  Uses Mkvpropedit to align tracks with your preferred defaults." -ForegroundColor DarkCyan

    Write-Host "`n  The script intelligently handles track scoring, automatically penalizing" -ForegroundColor DarkCyan
    Write-Host "  'Signs & Songs' tracks while prioritizing full dialogue and honorifics." -ForegroundColor DarkCyan
    
    Write-Host "`n USAGE:" -ForegroundColor DarkYellow
    Write-Host "  .\auditor+fixer.ps1 [Flags] -Path 'G:\Media'" -ForegroundColor DarkGreen
    
    Write-Host "`n USAGE EXAMPLES:`n" -ForegroundColor DarkYellow
    
    Write-Host "  Standard Audit (No Changes):`n" -ForegroundColor DarkGray
    Write-Host "    .\auditor+fixer.ps1 -Path 'G:\Media\Anime'`n" -ForegroundColor DarkMagenta
    
    Write-Host "  Automated Fix (JPN Audio / ENG Subs / Honorifics):`n" -ForegroundColor DarkGray
    Write-Host "    .\auditor+fixer.ps1 -Fix -aud jpn -sub eng -Hon -ovrd -Path 'G:\Media\Anime'`n" -ForegroundColor DarkCyan
    
    Write-Host "  Update Video Language (Chinese) & Save to Config:`n" -ForegroundColor DarkGray
    Write-Host "    .\auditor+fixer.ps1 -Fix -vid chi -vidf -ovrd -Path 'G:\Media\Anime'`n" -ForegroundColor DarkMagenta

    Write-Host "  Direct Fix (No Backup) with Codec Priority:`n" -ForegroundColor DarkGray
    Write-Host "    .\auditor+fixer.ps1 -Fix -FixNoBackup -sc 'ass,srt' -ovrd -Path 'G:\Media\Anime'`n" -ForegroundColor DarkCyan
    
    Write-Host "`n CORE FLAGS:`n" -ForegroundColor DarkYellow

    Write-Host "  -Path <string>" -ForegroundColor DarkMagenta
    Write-Host "      Defines the target directory. The script will recursively scan all" -ForegroundColor DarkMagenta
    Write-Host "      subfolders for MKV files to perform bulk auditing.`n" -ForegroundColor DarkMagenta

    Write-Host "  -Fix" -ForegroundColor DarkCyan
    Write-Host "      Enables 'Write Mode'. Without this, the script runs in read-only" -ForegroundColor DarkCyan
    Write-Host "      audit mode, generating logs without modifying any files.`n" -ForegroundColor DarkCyan
                    
    Write-Host "  -FixDebug" -ForegroundColor DarkMagenta
    Write-Host "      Prints the exact Mkvpropedit command strings to the console before" -ForegroundColor DarkMagenta
    Write-Host "      execution—ideal for verifying complex logic changes.`n" -ForegroundColor DarkMagenta
    
    Write-Host "  -FixNoBackup" -ForegroundColor DarkRed
    Write-Host "      Disables the '_updated' sibling folder creation. Use with caution," -ForegroundColor DarkRed
    Write-Host "      as this overwrites metadata directly on the source files.`n" -ForegroundColor DarkRed
    
    Write-Host "  -overrideDefaults | -ovrd" -ForegroundColor DarkCyan
    Write-Host "      Mandatory when using automation flags. It allows the script to" -ForegroundColor DarkCyan
    Write-Host "      write your current session parameters into the JSON config file.`n" -ForegroundColor DarkCyan
    
    Write-Host "`n TRACK PRIORITIES & AUTOMATION:`n" -ForegroundColor DarkYellow
    
    Write-Host "  -videoLanguage | -vid <string>" -ForegroundColor DarkCyan
    Write-Host "      Targets the video track language. Note: This requires the -vidf" -ForegroundColor DarkCyan
    Write-Host "      flag to trigger a physical metadata update.`n" -ForegroundColor DarkCyan

    Write-Host "  -videoForceUpdate | -vidf" -ForegroundColor DarkMagenta
    Write-Host "      The safety toggle for video metadata. This must be present to" -ForegroundColor DarkMagenta
    Write-Host "      confirm you want to change the video track language.`n" -ForegroundColor DarkMagenta
    
    Write-Host "  -audioLanguagePriority | -aud <string>" -ForegroundColor DarkCyan
    Write-Host "      Sets the 3-letter ISO code (e.g., 'jpn') for your primary audio." -ForegroundColor DarkCyan
    Write-Host "      It will automatically set this track as the 'Default' choice.`n" -ForegroundColor DarkCyan
    
    Write-Host "  -subtitleLanguagePriority | -sub <string>" -ForegroundColor DarkMagenta
    Write-Host "      Sets the primary subtitle language. The script uses weighted" -ForegroundColor DarkMagenta
    Write-Host "      scoring to find the best dialogue track in this language.`n" -ForegroundColor DarkMagenta
    
    Write-Host "  -subtitleCodecPriority | -sc <string>" -ForegroundColor DarkCyan
    Write-Host "      A comma-separated list (e.g., 'ass,srt') that dictates which" -ForegroundColor DarkCyan
    Write-Host "      subtitle formats to prefer when multiple tracks are available.`n" -ForegroundColor DarkCyan
    
    Write-Host "  -Hon | -Honorifics" -ForegroundColor DarkMagenta
    Write-Host "      Injects a +300 score bonus to tracks labeled with 'honorifics'" -ForegroundColor DarkMagenta
    Write-Host "      or 'enm', ensuring they are selected over standard dialogue.`n" -ForegroundColor DarkMagenta

    Write-Host "`n GENERAL:`n" -ForegroundColor DarkYellow
    
    Write-Host "  -help | -manual" -ForegroundColor DarkCyan
    Write-Host "      Displays this manual for auditor+fixer.ps1. The one you are" -ForegroundColor DarkCyan
    Write-Host "      reading right now.`n" -ForegroundColor DarkCyan
    

    Write-Host "`n NOTES:" -ForegroundColor DarkYellow
    Write-Host "  * SCORING: Automatically penalizes 'Signs/Songs' tracks." -ForegroundColor DarkGray
    Write-Host "  * CONFIG: -ovrd is REQUIRED when using automation flags to save to JSON." -ForegroundColor DarkGray
    Write-Host "  * LOGS: Detailed reports are saved to: $rootLog" -ForegroundColor DarkGray
    
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host " Press any key to exit..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

# --- UNKNOWN FLAG PROTECTION ---
# This catches anything starting with '-' that wasn't caught by the Param block
foreach ($part in $PathParts) {
    if ($part -like "-*") {
        Write-Host "`n[ERROR] Unknown flag detected: $part" -ForegroundColor Red
        Write-Host "Please use -Help to see a list of valid commands.`n" -ForegroundColor Yellow
        exit
    }
}

# --- DEPENDENCY CHECK ---
if (($FixNoBackup -or $FixDebug) -and -not $Fix) {
    Write-Host "`n[ERROR] Modifier flag detected without -Fix." -ForegroundColor Red
    Write-Host "The -FixNoBackup and -FixDebug flags require the -Fix switch to be active.`n" -ForegroundColor Yellow
    exit
}

# 1. Join PathParts if they were passed separately (like via Send To)
$Path = $PathParts -join " "

# 2. Check if the path is empty or just whitespace
if ([string]::IsNullOrWhiteSpace($Path)) {
    Write-Host "`n[ERROR] No target path provided." -ForegroundColor Red
    Write-Host "Please provide a folder path or use -Help for instructions.`n" -ForegroundColor Yellow
    exit
}

# 3. Check if the path actually exists on the system
if (-not (Test-Path -LiteralPath $Path)) {
    Write-Host "`n[ERROR] Path not found: $Path" -ForegroundColor Red
    exit
}

# --- PLACE THE TRAP HERE INSTEAD ---
if ($host.Name -eq "ConsoleHost") { $ErrorActionPreference = "Continue" }
# -----------------------------------

$ProgressPreference = 'SilentlyContinue' # Speeds up network directory scanning

# Constants & Tool Paths
$mkvpropedit = "C:\Program Files\MKVToolNix\mkvpropedit.exe"
$mkvmerge    = "C:\Program Files\MKVToolNix\mkvmerge.exe"

if ($PSVersionTable.PSVersion -lt [version]"7.6.1") {
    Write-Host "ERROR: Running on version $($PSVersionTable.PSVersion). This script requires at least 7.6.1." -ForegroundColor Red
    Pause; exit
}

# 1. Path & Log Initialization
$inputPaths = New-Object System.Collections.Generic.List[string]
if ($null -eq $PathParts -or $PathParts.Count -eq 0) {
    Write-Host "ERROR: No folder detected. Use the 'Send To' menu or drag a folder onto this script." -ForegroundColor Red
    Pause; exit
} else {
    foreach ($part in ($PathParts | Sort-Object)) { 
        $cleaned = $part.Trim('"')
        if (Test-Path -LiteralPath $cleaned) { $inputPaths.Add($cleaned) }
    }
}

$rootLog = Join-Path $PSScriptRoot "auditor+fixer_logs"
$pLogDir = Join-Path $rootLog "Path_Logs"; $dLogDir = Join-Path $rootLog "Detail_Logs"
$mLogDir = Join-Path $rootLog "Mismatch_Logs"; $cLogDir = Join-Path $rootLog "Comparison_Logs"
$fLogDir = Join-Path $rootLog "FIX_QUEUE"
foreach ($dir in @($rootLog,$pLogDir,$dLogDir,$mLogDir,$cLogDir,$fLogDir)) { 
    if (-not (Test-Path $dir)) { New-Item $dir -ItemType Directory | Out-Null } 
}

$ts = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$pathLog = Join-Path $pLogDir "auditor+fixer_Paths_$($ts)-log.txt"
$detailLog = Join-Path $dLogDir "auditor+fixer_Details_$($ts)-log.txt"
$missLog = Join-Path $mLogDir "auditor+fixer_Mismatches_$($ts)-log.txt"
$compLog = Join-Path $cLogDir "auditor+fixer_Comparison_$($ts)-log.txt"
$fixerLog = Join-Path $fLogDir "auditor+fixer_FIX_QUEUE_$($ts)-log.txt"


# --- CONFIGURATION DEFAULTS ---
$configFile = Join-Path $PSScriptRoot "auditor-fixer--FixerDefaults.json"

# --- WESTERN PROFILE HANDLER ---
$westernFile = Join-Path $PSScriptRoot "auditor-fixer--WesternDefaults.json"

if ($Western) {
    # If Western mode is on but the file is missing, create it from the Anime template
    if (-not (Test-Path $westernFile)) {
        if (Test-Path $configFile) {
            $base = Get-Content $configFile | ConvertFrom-Json
            $base.Audio.PreferredLanguage = "eng"
            $base.Video.TargetLanguage = "eng"
            $base.Subtitles.PreferredLanguage = ""
            $base | ConvertTo-Json -Depth 10 | Out-File $westernFile -Encoding utf8
            Write-Host " [!] Created Western Defaults from template." -ForegroundColor Yellow
        }
    }
    # Point the script to the Western file instead of the Anime one
    if (Test-Path $westernFile) { $configFile = $westernFile }
}

# Now load whichever file was selected
if (Test-Path $configFile) {
    $fixerConfig = Get-Content $configFile | ConvertFrom-Json
}

# --- SAVE OVERRIDES TO WESTERN JSON ---
if ($Western -and $OverrideWesternDefaults -and ($null -ne $fixerConfig)) {
    $needsUpdate = $false
    if ($PSBoundParameters.ContainsKey('videoLanguage')) { $fixerConfig.Video.TargetLanguage = $videoLanguage; $needsUpdate = $true }
    if ($PSBoundParameters.ContainsKey('audioLanguagePriority')) { $fixerConfig.Audio.PreferredLanguage = $audioLanguagepriority; $needsUpdate = $true }
    if ($PSBoundParameters.ContainsKey('subtitleLanguagePriority'))   { $fixerConfig.Subtitles.PreferredLanguage = $subtitleLanguagepriority; $needsUpdate = $true }
    if ($PSBoundParameters.ContainsKey('subtitleCodecPriority'))     { 
        $fixerConfig.Subtitles.CodecPriority = @($subtitleCodecPriority) + ($fixerConfig.Subtitles.CodecPriority | Where-Object { $_ -ne $subtitleCodecPriority })
        $needsUpdate = $true 
    }

    if ($needsUpdate) {
        $fixerConfig | ConvertTo-Json -Depth 10 | Out-File $westernFile -Encoding utf8
        Write-Host " [SAVED] Western defaults have been updated." -ForegroundColor Green
    }
}

# Base hardcoded defaults
$defaultSettings = @{
    Audio = @{ PreferredLanguage = "jpn"; SetDefault = $true; IgnoreCommentary = $true }
    Subtitles = @{ 
        PreferredLanguage = "eng"; SetDefault = $true; 
        CodecPriority = @("S_TEXT/ASS", "S_TEXT/SSA", "S_TEXT/UTF8", "S_SRT", "S_HDMV/PGS", "S_VOBSUB")
        IgnoreNames = "Signs|Songs|SDH|HI/CC|CC"
    }
    Global = @{ ResetAllFlags = $true; RenameSDHtoCC = $true; FixMislabeledEng = $true }
}

# 1. MAPPING DICTIONARIES
$langMap = @{
    "english" = "eng"; "en" = "eng"; "eng" = "eng"
    "japanese" = "jpn"; "jp" = "jpn"; "jpn" = "jpn"
    "korean"  = "kor"; "ko" = "kor"; "kor" = "kor"
    "chinese" = "chi"; "zh" = "chi"; "zho" = "chi"; "chi" = "chi"
}

$codecMap = @{
    "ass" = "S_TEXT/ASS"; "ssa" = "S_TEXT/SSA"
    "srt" = "S_TEXT/UTF8"; "utf8" = "S_TEXT/UTF8"
    "pgs" = "S_HDMV/PGS"; "vob" = "S_VOBSUB"
}

# 2. APPLY OVERRIDES FROM COMMAND LINE
# Ensure the Video object exists in the defaults
$defaultSettings.Video = @{ TargetLanguage = "jpn" } # Initialize baseline

if ($videoLanguage) { 
    $key = $videoLanguage.ToLower().Trim()
    $defaultSettings.Video.TargetLanguage = if ($langMap.ContainsKey($key)) { $langMap[$key] } else { $key }
}

# Audio Language Translation
if ($audioLanguagePriority) { 
    $key = $audioLanguagePriority.ToLower().Trim()
    $defaultSettings.Audio.PreferredLanguage = if ($langMap.ContainsKey($key)) { $langMap[$key] } else { $key }
}

# Subtitle Language Translation
if ($subtitleLanguagePriority) { 
    $key = $subtitleLanguagePriority.ToLower().Trim()
    $defaultSettings.Subtitles.PreferredLanguage = if ($langMap.ContainsKey($key)) { $langMap[$key] } else { $key }
}

# Subtitle Codec Translation
if ($subtitleCodecPriority) { 
    $rawParts = $subtitleCodecPriority.Split(',').Trim().ToLower()
    $translated = foreach ($part in $rawParts) {
        if ($codecMap.ContainsKey($part)) { $codecMap[$part] } else { $part }
    }
    $defaultSettings.Subtitles.CodecPriority = @($translated)
}

# 2.5 VALIDATION: Require the appropriate override switch for parameter usage
$usedFlags = @()
if ($PSBoundParameters.ContainsKey('videoLanguage')) { $usedFlags += "-vid" }
if ($PSBoundParameters.ContainsKey('audioLanguage')) { $usedFlags += "-aud" }
if ($PSBoundParameters.ContainsKey('subLanguage'))   { $usedFlags += "-sub" }
if ($PSBoundParameters.ContainsKey('subCodec'))     { $usedFlags += "-sc" }

# Determine which override switch is required based on the mode
$isMissingOverride = if ($Western) { 
    $usedFlags.Count -gt 0 -and -not $OverrideWesternDefaults 
} else { 
    $usedFlags.Count -gt 0 -and -not $overrideDefaults 
}

if ($isMissingOverride) {
    $requiredSwitch = if ($Western) { "-ovrdw" } else { "-ovrd" }
    
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host "ERROR: Parameter Override Required" -ForegroundColor Red
    Write-Host "The following flags were used: $($usedFlags -join ' ')" -ForegroundColor Yellow
    Write-Host "To use these, you MUST also include the $requiredSwitch switch." -ForegroundColor White
    Write-Host "This ensures your changes are saved to the correct config file." -ForegroundColor White
    Write-Host "==================================================" -ForegroundColor Red
    Pause; exit
}

# 3. SAVE / LOAD LOGIC
$configSource = "Built-in Defaults"
if ($overrideDefaults) {
    $defaultSettings | ConvertTo-Json -Depth 10 | Out-File $configFile -Encoding utf8
    $configSource = "Updated & Saved to JSON"
}

if (Test-Path $configFile) {
    $fixerConfig = Get-Content $configFile | ConvertFrom-Json
    $configSource = "Loaded from JSON"
    if (-not $fixerConfig.PSObject.Properties['Video']) {
        $fixerConfig | Add-Member -MemberType NoteProperty -Name "Video" -Value $defaultSettings.Video
    }
} else {
    $fixerConfig = $defaultSettings | ConvertTo-Json -Depth 10 | ConvertFrom-Json
}

# --- STARTUP DISPLAY ---
Clear-Host
$version = "2026.05.12_11.31.00"

# Determine Display Mode, Action, and Override Status
$modeBase = if ($Western) { "Western Mode" } else { "Anime Mode (default)" }
$action = if ($Fix) { "Audit & Fix" } else { "Audit" }
$nobackupStatus = if ($FixNoBackup) { " NO BACKUP!" } else { "" }
$debugStatus = if ($FixDebug) { " Debug" } else { "" }
$ovrdStatus = if ($overrideDefaults -or $OverrideWesternDefaults) { " override defaults" } else { "" }
$displayMode = "$modeBase $action$nobackupStatus$debugStatus$ovrdStatus"

Write-Host "=================================================="
Write-Host "auditor+fixer.ps1 v$version" -ForegroundColor Cyan
Write-Host "=================================================="
Write-Host $displayMode -ForegroundColor Blue
if ($FixNoBackup) {
    Write-Host " [!] WARNING: Backups are DISABLED. This will overwrite your original files!" -ForegroundColor DarkYellow
}
Write-Host "--------------------------------------------------"
Write-Host "Config Status: " -NoNewline; Write-Host $configSource -ForegroundColor DarkMagenta
Write-Host "Config Path:   " -NoNewline; Write-Host $configFile -ForegroundColor DarkGray
Write-Host "--------------------------------------------------"
Write-Host "LOADED OPTIONS:" -ForegroundColor DarkGreen
Write-Host "  Video Target: " -NoNewline; Write-Host "$($fixerConfig.Video.TargetLanguage)" -ForegroundColor Blue
Write-Host "  Audio Target: " -NoNewline; Write-Host "$($fixerConfig.Audio.PreferredLanguage)" -ForegroundColor DarkMagenta
Write-Host "  Sub Target:   " -NoNewline; Write-Host "$($fixerConfig.Subtitles.PreferredLanguage)" -ForegroundColor Blue
Write-Host "  Sub Codecs:   " -NoNewline; Write-Host "$($fixerConfig.Subtitles.CodecPriority -join ', ')" -ForegroundColor DarkMagenta
Write-Host "--------------------------------------------------"
#Write-Host "Script Location: " -NoNewline; Write-Host "$PSScriptRoot" -ForegroundColor Yellow
#Write-Host "--------------------------------------------------"
Write-Host "Target Folder(s):" -ForegroundColor Green
foreach ($p in $inputPaths) { Write-Host "  -> $p" -ForegroundColor Blue }
Write-Host "--------------------------------------------------"

$choice = Read-Host "Begin processing? (Y/N)"
if ($choice -notmatch "^[yY]$") {
    Write-Host "Operation cancelled by user." -ForegroundColor DarkYellow
    Pause; exit
}
Write-Host "Starting..." -ForegroundColor DarkGreen
# --- END STARTUP DISPLAY ---

# 2. Functions
$global:trackCounters = @{ "video" = 1; "audio" = 1; "subtitles" = 1 }
function Get-Selector {
    param($type, [switch]$Reset)
    if ($Reset) { $global:trackCounters = @{ "video" = 1; "audio" = 1; "subtitles" = 1 }; return "" }
    $val = $global:trackCounters[$type]
    $letter = switch ($type) { "video" { "v" } "audio" { "a" } "subtitles" { "s" } }
    $global:trackCounters[$type]++
    return "$letter$val"
}

# function Get-Selector {
    # param($type, [switch]$Reset)
    # if ($Reset) { $global:trackCounters = @{ "video" = 1; "audio" = 1; "subtitles" = 1 }; return "" }
    # $val = $global:trackCounters[$type]
    # $letter = switch ($type) { "video" { "v" } "audio" { "a" } "subtitles" { "s" } }
    # $global:trackCounters[$type]++
    # return "$letter$val"
# }

function Invoke-MkvBackup {
    param([string]$FilePath, [string]$RootPath)
    
    # 1. Identify the relationship between the file and the dragged folder (RootPath)
    $fileItem = Get-Item -LiteralPath $FilePath
    
    # 2. Determine the Backup Root Name
    # We anchor to the parent of the folder you dropped so the _updated folder is a sibling
    $parentDir = Split-Path $RootPath -Parent
    $rootName = Split-Path $RootPath -Leaf
    $backupRootPath = Join-Path $parentDir "$($rootName)_updated"
    
    # 3. Calculate the relative internal structure
    $relativeDir = ""
    if ($FilePath.StartsWith($RootPath)) {
        $relativeDir = (Split-Path $FilePath -Parent).Substring($RootPath.Length).TrimStart('\')
    }
    
    # 4. Construct the final target directory
    $finalDestinationDir = Join-Path $backupRootPath $relativeDir
    
    # 5. Create the folder tree if it doesn't exist
    if (-not (Test-Path -LiteralPath $finalDestinationDir)) { 
        New-Item -Path $finalDestinationDir -ItemType Directory -Force | Out-Null 
    }
    
    # 6. Copy the file
    $fileName = Split-Path $FilePath -Leaf
    Write-Host "  [BACKUP] Copying: $fileName..." -ForegroundColor Gray
    Copy-Item -LiteralPath $FilePath -Destination (Join-Path $finalDestinationDir $fileName) -Force
}

function Get-AuditFlags($tracks, $IsWestern) {
    $reasons = ""; 
    $jpnAud = $tracks | Where-Object { $_.type -eq "audio" -and $_.properties.language -eq "jpn" }
    $engAud = $tracks | Where-Object { $_.type -eq "audio" -and $_.properties.language -eq "eng" }
    $subs = $tracks | Where-Object { $_.type -eq "subtitles" }
    
    # --- AVC HIGH 10 PROFILE CHECK ---
    $vTrack = $tracks | Where-Object { $_.type -eq "video" } | Select-Object -First 1
    if ($null -ne $vTrack) {
        $privData = if ($null -ne $vTrack.properties.codec_private) { $vTrack.properties.codec_private } else { $vTrack.properties.codec_private_data }
        if ($null -ne $privData -and $privData.Length -ge 4) {
            if ($privData.Substring(2, 2) -eq "6e") { $reasons += "🔟[AVC High 10 Profile] " }
        }
    }

    # --- SHARED CHECKS ---
    if ($tracks | Where-Object { $_.properties.forced_track }) { $reasons += "🚨[Forced Track] " }
    if ($tracks | Where-Object { ($_.type -match "audio|subtitles") -and $_.properties.language -eq "und" }) { $reasons += "❔[Und Lang] " }

    $trackTypes = $tracks | Select-Object -ExpandProperty type -Unique
    foreach ($type in $trackTypes) {
        $defaults = $tracks | Where-Object { $_.type -eq $type -and $_.properties.default_track }
        if ($defaults.Count -gt 1) { $reasons += "⚔️[Conflict: Multiple $($type.ToUpper()) Defaults] " }
    }

    # --- MODE SPECIFIC LOGIC ---
    if ($IsWestern) {
        # WESTERN MODE FLAGS
        # Improved ENG Audio Check
        # Flags if English audio is missing OR if it exists but isn't default
        if (-not ($engAud | Where-Object { $_.properties.default_track })) { 
            $reasons += "🎙️[ENG Audio Not Default] " 
        }
        
        # --- SUBTITLE LOGIC: PREFERENCE & FALLBACK ---
        $defaultSub = $subs | Where-Object { $_.properties.default_track }
        $hasEngSDH = $subs | Where-Object { 
            ($_.properties.language -eq "eng") -and 
            ($_.properties.track_name -match "SDH|HI|CC" -or $_.properties.flag_hearing_impaired) 
        }

        # 1. Critical Audit: Is ANY English Subtitle set to default? (Ignoring Forced)
        if (-not ($defaultSub | Where-Object { $_.properties.language -eq "eng" -and $_.properties.track_name -notmatch "Forced" })) {
            $reasons += "🔇[Sub: None Default] "
        }

        # 2. Preference Audit: If SDH flags are used, check if we can "upgrade" to SDH
        if ($sdh -or $hi -or $hicc -or $cc -or $SubtitlesHearingImpaired) {
            if ($hasEngSDH) {
                $isSDHDefault = $hasEngSDH | Where-Object { $_.properties.default_track }
                if (-not $isSDHDefault) {
                    $reasons += "✨[SDH Available] "
                }
            } else {
                # Only flag missing if specifically asked to audit for SDH
                $reasons += "🚫[Missing ENG SDH/CC] "
            }
        }
    } else {
        # ANIME MODE FLAGS (Includes your specific HI/CC and Signs/Songs logic)
        if ($jpnAud -and -not ($jpnAud | Where-Object { $_.properties.default_track })) { $reasons += "🎙[JPN Audio Not Default] " }
        if ($jpnAud -and $subs.Count -eq 0) { $reasons += "⚠️[JPN Audio/No Subs] " }
        
        if ($subs.Count -gt 0) {
            $dSubs = $subs | Where-Object { $_.properties.default_track }
            if ($dSubs | Where-Object { $_.properties.track_name -match "Signs|Songs|Lyrics|Forced" -and $_.properties.track_name -notmatch "Dialogue" }) { $reasons += "🎵[Sub: Signs/Songs Default] " }
            if ($jpnAud -and -not ($subs | Where-Object { $_.properties.language -eq "eng" -and $_.properties.default_track })) { $reasons += "🔇[No ENG Sub Default] " }
            
            # HI/CC Checks
            if ($subs | Where-Object { $_.properties.language -eq "eng" -and $_.properties.flag_hearing_impaired }) { $reasons += "👂[ENG Sub HI/CC] " }
            if ($subs | Where-Object { $_.properties.track_name -match "SDH" }) { $reasons += "🙉[SDH Name] " }
            if ($subs | Where-Object { $_.properties.flag_hearing_impaired }) { $reasons += "👀[Sub HI/CC] " }
        }
        if ($subs | Where-Object { $_.properties.language -eq "jpn" }) { $reasons += "⛩️[JPN Sub Present] " }
    }
    
    return $reasons.Trim()
}

function Get-TrackProps($t) {
    $p = ""
    if ($t.properties.default_track) { $p += "[DEFAULT]" }
    if ($t.properties.forced_track) { $p += "[FORCED]" }
    if ($t.properties.flag_hearing_impaired) { $p += "[HI/CC]" }
    return $p
}

function Get-HeaderBlock($codecPadding, $propPadding, $namePadding) {
    $h = "Codec".PadRight($codecPadding) + " | " + "   ID".PadRight(12) + " | " + "Sel.".PadRight(4) + " | " + "Type".PadRight(9) + " | " + "Lng" + " | " + "Flags".PadRight($propPadding) + " | " + "Name".PadRight($namePadding)
    $bar = "-" * $h.Length
    return $bar, $h
}

function Write-InlineProgress {
    param(
        [int]$Current,
        [int]$Total,
        [string]$Message
    )
    $percent = [Math]::Min(100, [Math]::Max(0, [int]($Current / $Total * 100)))
    $width = 30 
    $done = [Math]::Min($width, [int]($percent / 100 * $width))
    $left = $width - $done
    
    $bar = ("█" * $done) + ("░" * $left)
    # Using ${Message} ensures the colon is treated as plain text
    # PadRight(100) ensures the entire line is cleared before writing the new one
    $progressLine = "`r[SHIELD] ${Message}: [$bar] $percent% ($Current/$Total)".PadRight(100)
    
    Write-Host -NoNewline $progressLine -ForegroundColor Cyan
}

# 3. Main Processing Loop
# Includes the base folders themselves PLUS all sub-directories
$targetFolders = Get-ChildItem -LiteralPath $inputPaths -Directory -Recurse | Sort-Object FullName
if ($inputPaths.Count -gt 0) {
    $targetFolders = @($inputPaths | ForEach-Object { Get-Item -LiteralPath $_ }) + $targetFolders | Select-Object -Unique
}
foreach ($folderPath in $targetFolders) {
    Write-Host "Checking: $($folderPath.FullName)..." -ForegroundColor Gray # <--- LIVE FEEDBACK
    $global:GroupMap = @{}
    $global:Counter = 1
    $folder = Get-Item -LiteralPath $folderPath.FullName
    $mkvFiles = Get-ChildItem -LiteralPath $folder.FullName -Filter "*.mkv" | Sort-Object Name
    if ($mkvFiles.Count -eq 0) { continue }
    
    # --- DYNAMIC PADDING (PER FOLDER) ---
    $allCodecs = foreach ($f in $mkvFiles) { (& $mkvmerge -J $f.FullName | ConvertFrom-Json).tracks.codec }
    $codecPadding = [Math]::Max(5, ($allCodecs | Measure-Object -Property Length -Maximum).Maximum)
    
    $allTrackNames = foreach ($f in $mkvFiles) { (& $mkvmerge -J $f.FullName | ConvertFrom-Json).tracks.properties.track_name }
    $namePadding = [Math]::Max(4, ($allTrackNames | Measure-Object -Property Length -Maximum).Maximum)
    $propPadding = 9

# --- TABLE PRINTING FUNCTION ---
    $script:PrintTable = [scriptblock]{
        param($groupJson, $title, $compareJson)
        if ($title -ne "") { $entry.Add(""); $entry.Add("$title") }
        
        # --- DYNAMIC DASH LOGIC ---
        # 25 for standard, 29 for comparison (accounts for >>> <<< brackets)
        $idAdjustment = if ($null -ne $compareJson) { 29 } else { 25 }
        
        # 1. Solid border for top and bottom
        $line = "-" * ("Codec".PadRight($codecPadding) + " | " + "   ID".PadRight(12) + " | " + "Sel.".PadRight(4) + " | " + "Type".PadRight(9) + " | " + "Lng" + " | " + "Flags".PadRight($propPadding) + " | " + "Name".PadRight($namePadding)).Length

        # 2. The Header text row
        $header = "$("Codec".PadRight($codecPadding)) | $("   ID".PadRight(12)) | $("Sel.".PadRight(4)) | $("Type".PadRight(9)) | Lng | $("Flags".PadRight($propPadding)) | $("Name".PadRight($namePadding))"
        
        # 3. The Separator row (Math wrapped in $() to prevent conversion errors)
        $sep = "$("-" * $codecPadding)-|-$("-" * 12)-|-$("-" * 4)-|-$("-" * 9)-|-----|-$("-" * $propPadding)-|-$("-" * $namePadding)"
        
        $entry.Add($line)
        $entry.Add($header)
        $entry.Add($sep)
        
        Get-Selector -Reset
        foreach ($t in $groupJson.tracks) {
            $sel = Get-Selector $t.type
            $isDiff = $false
            if ($null -ne $compareJson) {
                $pTrack = $compareJson.tracks | Where-Object { $_.id -eq $t.id }
                if ($null -ne $pTrack) {
                    $pSig = "$($pTrack.id)|$($pTrack.type)|$($pTrack.properties.language)|$($pTrack.properties.default_track)|$($pTrack.properties.track_name)"
                    $cSig = "$($t.id)|$($t.type)|$($t.properties.language)|$($t.properties.default_track)|$($t.properties.track_name)"
                    if ($pSig -ne $cSig) { $isDiff = $true }
                }
            }

            $idStr = if ($isDiff) { ">>>ID:$($t.id)<<<" } else { "   ID:$($t.id)" }
            $codec = "$($t.codec.PadRight($codecPadding))"
            $props = (Get-TrackProps $t).PadRight($propPadding)
            $tName = if ($t.properties.track_name) { $t.properties.track_name } else { "" }
            $entry.Add("$codec | $($idStr.PadRight(12)) | $($sel.PadRight(4)) | $($t.type.PadRight(9)) | $($t.properties.language) | $props | $($tName.PadRight($namePadding))")
        }
        $entry.Add($line)
    }

    # --- GROUPING LOGIC ---
    $mkvCount = $mkvFiles.Count
    $orderedGroups = New-Object System.Collections.Generic.List[PSObject]
    
    for ($i = 0; $i -lt $mkvCount; $i++) {
        $f = $mkvFiles[$i]
        # 1. Update the user with the progress bar immediately
        Write-InlineProgress -Current ($i + 1) -Total $mkvCount -Message "Analyzing Files"
        
        # 2. Log path to file
        $f.FullName | Out-File $pathLog -Append -Encoding utf8
        
        # 3. Get JSON and build signature
        $json = & $mkvmerge -J $f.FullName | ConvertFrom-Json
        $sig = (($json.tracks | ForEach-Object { "$($_.id)|$($_.type)|$($_.codec)|$($_.properties.language)|$($_.properties.default_track)|$($_.properties.track_name)" }) -join "`n")
        
        # 4. Assign to existing group or create new one
        $existingGroup = $orderedGroups | Where-Object { $_.Sig -eq $sig }
        if ($null -eq $existingGroup) {
            $orderedGroups.Add([PSCustomObject]@{ 
                Sig = $sig; 
                Files = New-Object System.Collections.Generic.List[PSObject]; 
                Json = $json 
            })
            $existingGroup = $orderedGroups[-1]
        }
        $existingGroup.Files.Add($f)
    }

    $primaryGroup = $orderedGroups[0]
    $mismatches = $mkvFiles.Count - $primaryGroup.Files.Count
    
    # Print folder header to mismatch log if needed
    if ($mismatches -gt 0) {
        $spacer = if (Test-Path $missLog) { "`r`n" } else { "" }
        "${spacer}Folder: $($folder.FullName)" | Out-File $missLog -Append -Encoding utf8
    }

    # --- PROCESS GROUPS ---
    $totalGroups = $orderedGroups.Count
    for ($g = 0; $g -lt $totalGroups; $g++) {
        $currentGroup = $orderedGroups[$g]
        
        # Progress Bar Update
        Write-InlineProgress -Current ($g + 1) -Total $totalGroups -Message "Processing Groups"
        
        $sig = $currentGroup.Sig
        if (-not $global:GroupMap.ContainsKey($sig)) { $global:GroupMap[$sig] = $global:GroupMap.Count + 1 }
        $stableIndex = $global:GroupMap[$sig]
        $isPrimary = ($g -eq 0)
        $repFile = $currentGroup.Files[0]
        $reasons = Get-AuditFlags -tracks $currentGroup.Json.tracks -IsWestern $Western
        
        $entry = New-Object System.Collections.Generic.List[string]
        if ($g -gt 0) { $entry.Add("") }

        # --- HEADER LABELS (FULL 1-10 RESTORED) ---
        $label = switch ($stableIndex) {
            1 { "🌟PRIMARY 01🌟" }
            2 { "🔍SECONDARY 02" }
            3 { "📂TERTIARY 03" }
            4 { "📋QUATERNARY 04" }
            5 { "📌QUINARY 05" }
            6 { "🖇️SENARY 06" }
            7 { "📝SEPTENARY 07" }
            8 { "📔OCTONARY 08" }
            9 { "📁NONARY 09" }
            10 { "📜DENARY 10" }
            Default { "MISMATCH GROUP $stableIndex" }
        }
        
        # Limit filename in title to 40 characters
        $shortName = if ($repFile.Name.Length -gt 40) { $repFile.Name.Substring(0, 40) } else { $repFile.Name }
        
        
        if ($isPrimary) {
            $entry.Add("--- $label [$shortName] MKV AUDIT: $($repFile.FullName) ---")
            $entry.Add("FILE NAME: $($repFile.Name)")
            # If there are NO audit flags, it is Reference Only.
            # If there ARE flags, show only the flags and drop the Reference label.
            if ($reasons -eq "") {
                $entry.Add("REASON: 💎[Reference Only]")
            } else {
                $entry.Add("REASON: $reasons")
            }
            
            $matchStatus = if ($mismatches -eq 0) { 
                "✔+++All Files in Folder Match: YES ($($mkvFiles.Count))+++✔" 
            } else { 
                "❌+++All Files in Folder Match: NO (0)+++❌" 
            }
            $entry.Add($matchStatus)
        } else {
            # Mismatched Header (Secondary 02+)
            $entry.Add("--- $label [$shortName] +MISMATCHED+ MKV: $($repFile.FullName) ---")
            $entry.Add("Primary: $($primaryGroup.Files[0].Name)")
            
            # Updated to show Reference Only for Secondary groups too
            if ($reasons -eq "") {
                $entry.Add("REASON: 💎[Reference Only]")
            } else {
                $entry.Add("REASON: $reasons")
            }
            
        } 

        # --- OUTPUT TRIGGER ---
        if (-not $isPrimary) {
            & $script:PrintTable $primaryGroup.Json "PRIMARY MKV TRACKS [$($primaryGroup.Files[0].Name)]:" $currentGroup.Json
            & $script:PrintTable $currentGroup.Json "CURRENT TRACKS [$($repFile.Name)]:" $primaryGroup.Json
        } else {
            & $script:PrintTable $currentGroup.Json "" $null
        }

    

        # --- MATCHES SECTION WITH 1-10 NUMBERING ---
        $entry.Add("")
        $entry.Add("===Matches ${label} [$shortName]: $($currentGroup.Files.Count.ToString('00'))===")
        for ($i = 0; $i -lt $currentGroup.Files.Count; $i++) {
            $entry.Add("  - $($currentGroup.Files[$i].Name)")
        }

        # --- APPEND TO MASTER LOG ---
        $entry | Out-File $detailLog -Append -Encoding utf8
        
        # --- APPEND TO MISMATCH LOG (ONLY IF NOT PRIMARY) ---
        # If the folder has ANY mismatches, include EVERY group (Primary + Mismatches)
        if ($mismatches -gt 0) {
            $entry | Out-File $missLog -Append -Encoding utf8
        }
        
        # --- GENERATE FIXER QUEUE & EXECUTE SMART FIX ---
        foreach ($fToFix in $currentGroup.Files) {
            $fixDetails = New-Object System.Collections.Generic.List[string]
            $Params = @() 
            $needsChange = $false 
            $bestAudioSel = $null; $bestSubSel = $null; $foundPrefAudio = $false
            $subCandidates = @()

            [void]$fixDetails.Add("FILE: $($fToFix.FullName)")

            # --- [CRITICAL FIX] RESOLVE TARGET LANGUAGE ONCE PER FILE ---
            $rawInput = if ($videoLanguage) { $videoLanguage } else { $fixerConfig.Video.TargetLanguage }
            $resolvedTarget = if ($null -ne $rawInput) {
                $key = "$rawInput".ToLower().Trim()
                if ($langMap.ContainsKey($key)) { $langMap[$key] } else { $key }
            } else { $null }

            # 1. IDENTIFY TARGETS
            Get-Selector -Reset
            foreach ($t in $currentGroup.Json.tracks) {
                $sel = Get-Selector $t.type
                
                # --- VIDEO LOGIC ---
                if ($t.type -eq "video") {
                    # 1. Resolve the target language from the -vid command or the JSON config
                    $targetLangInput = if ($videoLanguage) { $videoLanguage } else { $fixerConfig.Video.TargetLanguage }
                    $target = if ($langMap.ContainsKey($targetLangInput.ToLower())) { $langMap[$targetLangInput.ToLower()] } else { $targetLangInput }

                    # 2. Check if the file track actually needs a change (language or default flag)
                    $isIncorrect = ($t.properties.language -ne $target) -or ($t.properties.default_track -ne $true)

                    if ($isIncorrect) {
                        # 3. Skip if Western mode is active and the target is blank (Hands-off mode)
                        $skipVideo = $Western -and [string]::IsNullOrWhiteSpace($target)

                        if (-not $skipVideo) {
                            # 4. Add the mkvpropedit command
                            $mkvID = $t.id + 1
                            $Params += @('--edit', "track:$mkvID", '--set', "language=$target", '--set', "flag-default=1")

                            # 5. LOGGING: Identify if this was a forced update or a passive match
                            $logReason = if ($videoForceUpdate) { "Video Force (-vidf)" } else { "Passive Update (-vid)" }
                            [void]$fixDetails.Add("  ACTION: SET_LANG=$target | SET_DEFAULT=1 | TRACK: $mkvID | REASON: $logReason")

                            # 6. Only trigger the actual file write if -vidf was used
                            if ($videoForceUpdate) { $needsChange = $true }
                        }
                    }
                    continue 
                }

                # --- AUDIO/SUB TARGETING ---
                $targetAudLang = if ($Western) { "eng" } else { $fixerConfig.Audio.PreferredLanguage }
                
                if ($t.type -eq "audio" -and -not $foundPrefAudio -and $t.properties.language -eq $targetAudLang) {
                    if (-not ($fixerConfig.Audio.IgnoreCommentary -and ($t.properties.track_name -match "Commentary|Interview"))) {
                        $bestAudioSel = $sel; $foundPrefAudio = $true
                    }
                }
                
                # --- SUBTITLES ---
                if ($t.type -eq "subtitles") {
                    $trackName = if ($t.properties.track_name) { $t.properties.track_name.ToLower() } else { "" }
                    $trackLang = $t.properties.language.ToLower()
                    
                    # 1. ALWAYS capture current default status so we can strip it later if needed
                    $isCurrentlyDefault = ($t.properties.default_track -eq $true)
                    
                    # 2. Determine if it's a priority track (Codec Match)
                    $isCodecMatch = $false
                    foreach ($c in $fixerConfig.Subtitles.CodecPriority) {
                        if ($t.codec -match $c) { $isCodecMatch = $true; break }
                    }

                    # 3. SCORING
                    $score = 0
                    if ($isCodecMatch) { $score += 50 }
                    
                    # Priority for Dialogue / Penalty for Signs & Songs
                    if ($trackName -match "Dialogue|Full Sub") { $score += 150 }
                    if ($trackName -match "Signs|Songs|Lyrics") { $score -= 200 } # Heavy penalty
                    
                    if ($Hon -and (($trackName -match "honorifics|honors") -or ($trackLang -eq "enm"))) { $score += 300 }
                    if ($trackLang -eq $fixerConfig.Subtitles.PreferredLanguage) { $score += 1 }
                    
                    # --- SDH/HI/CC Promotion Scoring ---
                    if ($sdh -or $hi -or $hicc -or $cc -or $SubtitlesHearingImpaired) {
                        $isSDH = ($trackName -match "SDH|HI|CC" -or $t.properties.flag_hearing_impaired)
                        if ($trackLang -eq "eng" -and $isSDH) {
                            $score += 500  # Massive boost to ensure SDH is selected as the top candidate
                        }
                    }
                    
                    # --- Western "Full Sub" Tie-Breaker ---
                    if ($Western -and -not $sdhWinner) {
                        # If it's English, not forced, and doesn't match signs/songs, it's likely the full sub
                        if ($trackLang -eq "eng" -and -not $t.properties.forced_track -and $trackName -notmatch "Signs|Songs|Lyrics") {
                            $score += 200 
                        }
                    }

                    # 4. ADD TO LIST (No filter here - we need to see the "bad" tracks to fix them)
                    $subCandidates += [PSCustomObject]@{
                        ID         = $t.id
                        Score      = $score
                        Lang       = $trackLang
                        Name       = $t.properties.track_name
                        WasDefault = $isCurrentlyDefault
                    }
                    continue 
                } # <--- This is the first brace you were seeing

                # --- APPLY GLOBAL FLAG RESETS (Audio only here, Subs handled after loop) ---
                if ($fixerConfig.Global.ResetAllFlags -and ($t.type -eq "audio")) {
                    $mkvID = $t.id + 1 # Calculate absolute ID
                    
                    # Check if this specific track is the one we want as default
                    $targetDefault = if ($sel -eq $bestAudioSel) { 1 } else { 0 }
                    
                    if ($t.properties.default_track -ne $targetDefault) { 
                        $Params += @('--edit', "track:$mkvID", '--set', "flag-default=$targetDefault")
                        $needsChange = $true 
                    }
                    if ($t.properties.forced_track) { 
                        $Params += @('--edit', "track:$mkvID", '--set', 'flag-forced=0')
                        $needsChange = $true 
                    }
                    if ($t.properties.flag_hearing_impaired) { 
                        $Params += @('--edit', "track:$mkvID", '--set', 'flag-hearing-impaired=0')
                        $needsChange = $true 
                    }
                }
            } # <--- END TRACK LOOP
            
            # --- CHOOSE BEST SUBTITLE & RESET OTHER SUB FLAGS ---
            if ($subCandidates.Count -gt 0) {
                    # If Western mode is on AND you haven't specified a language preference in the JSON
                if ($Western -and [string]::IsNullOrWhiteSpace($fixerConfig.Subtitles.PreferredLanguage)) {
                    $sdhRequested = ($sdh -or $hi -or $hicc -or $cc -or $SubtitlesHearingImpaired)
                    $sdhWinner = $subCandidates | Sort-Object Score -Descending | Select-Object -First 1

                    # Only promote if SDH was requested AND the winner actually is an SDH track
                    $isActualSDH = ($sdhWinner.Name -match "SDH|HI|CC" -or ($currentGroup.Json.tracks | Where-Object { $_.id -eq $sdhWinner.ID }).properties.flag_hearing_impaired)

                    if ($sdhRequested -and $isActualSDH) {
                        $winID = $sdhWinner.ID + 1
                        $isAlreadyHI = ($currentGroup.Json.tracks | Where-Object { $_.id -eq $sdhWinner.ID }).properties.flag_hearing_impaired
                        
                        if (-not $sdhWinner.WasDefault -or -not $isAlreadyHI) {
                            $Params += @('--edit', "track:$winID", '--set', "flag-default=1", '--set', "flag-forced=0", '--set', "flag-hearing-impaired=1")
                            $needsChange = $true
                            [void]$fixDetails.Add("  ACTION: SET_DEFAULT=1 + HI_FLAG | TRACK: $winID | REASON: Western SDH Promotion")
                        }

                        foreach ($sub in $subCandidates) {
                            if ($sub.ID -ne $sdhWinner.ID) {
                                $lostTrack = $currentGroup.Json.tracks | Where-Object { $_.id -eq $sub.ID }
                                # Strip default, forced, AND hearing impaired flags from non-winners
                                if ($lostTrack.properties.default_track -or $lostTrack.properties.forced_track -or $lostTrack.properties.flag_hearing_impaired) {
                                    $loseID = $sub.ID + 1
                                    $Params += @('--edit', "track:$loseID", '--set', "flag-default=0", '--set', "flag-forced=0", '--set', "flag-hearing-impaired=0")
                                    $needsChange = $true
                                    [void]$fixDetails.Add("  ACTION: STRIP_FLAGS | TRACK: $loseID | REASON: Western SDH Conflict")
                                }
                            }
                        }
                    } else {
                        # Default Western behavior: Strip all subtitle flags
                        foreach ($sub in $subCandidates) {
                            $thisTrack = $currentGroup.Json.tracks | Where-Object { $_.id -eq $sub.ID }
                            # Modified to also strip the hearing impaired flag during generic cleanup
                            if ($thisTrack.properties.default_track -or $thisTrack.properties.forced_track -or $thisTrack.properties.flag_hearing_impaired) {
                                $loseID = $sub.ID + 1
                                $Params += @('--edit', "track:$loseID", '--set', "flag-default=0", '--set', "flag-forced=0", '--set', "flag-hearing-impaired=0")
                                $needsChange = $true
                                [void]$fixDetails.Add("  ACTION: STRIP_FLAGS | TRACK: $loseID | REASON: Western Mode (Clean)")
                            }
                        }
                    }
                } else {
                    # ANIME MODE: Existing Scoring Logic
                $winner = $subCandidates | Sort-Object Score -Descending | Select-Object -First 1
                $targetSubLang = "eng" 
                $subReason = if ($Hon -and ($winner.Score -ge 100)) { "Preferred Honorifics ($($winner.Lang))" } else { "Primary ENG Sub" }
                
                $currentWinnerData = $currentGroup.Json.tracks | Where-Object { $_.id -eq $winner.ID }
                
                # 1. Check if the Winner needs updating (Lang, Default, or unwanted Forced/HICC)
                $winnerNeedsFix = ($currentWinnerData.properties.language -ne $targetSubLang) -or 
                                  ($currentWinnerData.properties.default_track -ne $true) -or
                                  ($currentWinnerData.properties.forced_track -eq $true) -or
                                  ($currentWinnerData.properties.flag_hearing_impaired -eq $true)
                
                # 2. Check if ANY other track is wrongly set to Default, Forced, HI/CC, or has SDH in name
                $losersNeedStrip = $false
                foreach ($sub in $subCandidates) {
                    if ($sub.ID -ne $winner.ID) {
                        $lostTrack = $currentGroup.Json.tracks | Where-Object { $_.id -eq $sub.ID }
                        $hasSDH = $lostTrack.properties.name -like "*SDH*"
                        
                        if ($lostTrack.properties.default_track -or 
                            $lostTrack.properties.forced_track -or 
                            $lostTrack.properties.flag_hearing_impaired -or
                            $hasSDH) { 
                            $losersNeedStrip = $true 
                            break 
                        }
                    }
                }

                # 3. MECHANICAL TRIGGER: If either condition is true, build the command
                if ($winnerNeedsFix -or $losersNeedStrip) {
                    $needsChange = $true
                    
                    # FIX: Define $winID before using it
                    $winID = $winner.ID + 1
                    
                    # Add Winner Fix
                $Params += @('--edit', "track:$winID", '--set', "language=$targetSubLang", '--set', "flag-default=1", '--set', "flag-forced=0", '--set', "flag-hearing-impaired=0")
                [void]$fixDetails.Add("  ACTION: SET_LANG=$targetSubLang | SET_DEFAULT=1 | TRACK: $winID | REASON: $subReason")

                # Add Loser Strips & Rename SDH to CC
                    foreach ($sub in $subCandidates) {
                        if ($sub.ID -ne $winner.ID) {
                            $lostTrack = $currentGroup.Json.tracks | Where-Object { $_.id -eq $sub.ID }
                            $loseID = $sub.ID + 1
                            
                            # Try to find the name in either common property location
                            $currentName = $lostTrack.properties.name
                            if (-not $currentName) { $currentName = $lostTrack.properties.track_name }

                            # Start the edit for this track
                            $Params += @('--edit', "track:$loseID", '--set', "flag-default=0", '--set', "flag-forced=0", '--set', "flag-hearing-impaired=0")
                            
                            # If we found a name and it contains SDH, apply the fix
                            if ($currentName -and $currentName -like "*SDH*") {
                                $newName = $currentName -replace "SDH", "CC"
                                $Params += @('--set', "name=$newName")
                            }
                        }
                    } # Closes foreach
                } # Closes Mechanical Trigger
            } # Closes ELSE (Anime Mode)
        } # Closes Subtitle Logic Block (if $subCandidates.Count -gt 0) # Closes Subtitle Logic Block


            # 3. EXECUTION
            if ($Fix -and $needsChange) {
                if ($FixNoBackup) { $targetFile = $fToFix.FullName } 
                else {
                    # Anchor to the first path in $inputPaths (the one you dropped)
                    $anchorRoot = $inputPaths[0]
                    Invoke-MkvBackup -FilePath $fToFix.FullName -RootPath $anchorRoot
                    
                    $parentDir = Split-Path $anchorRoot -Parent
                    $rootName = Split-Path $anchorRoot -Leaf
                    $backupRootPath = Join-Path $parentDir "$($rootName)_updated"
                    
                    $relativeDir = (Split-Path $fToFix.FullName -Parent).Substring($anchorRoot.Length).TrimStart('\')
                    $targetFile = Join-Path $backupRootPath $relativeDir (Split-Path $fToFix.FullName -Leaf)
                }

                if ($targetFile -and (Test-Path -LiteralPath $targetFile)) {
                    if ($FixDebug) {
                        $fullCmd = "mkvpropedit `"$targetFile`" $($Params -join ' ')"
                        Write-Host "  [DEBUG] $fullCmd" -ForegroundColor Yellow
                        [void]$fixDetails.Add("  DEBUG_CMD: $fullCmd")
                    }
                    & $mkvpropedit "$targetFile" @Params | Out-Null
                    [void]$fixDetails.Add("  STATUS: Changes applied to -> $targetFile")
                }
            }
            [void]$fixDetails.Add(""); $fixDetails | Out-File $fixerLog -Append -Encoding utf8
        } # <--- END FILES LOOP
    } # <--- END GROUPS LOOP

    $spacer = "`r`n.• ♬ ͜͝ ̣̣♡.• ♬ ͜͝ ̣̣♡.• ♬ ͜͝ ̣̣♡..• ♬ ͜͝ ̣̣♡.• ♬ ͜͝ ̣̣♡.• ♬ ͜͝ ̣̣♡..• ♬ ͜͝ ̣̣♡.• ♬ ͜͝ ̣̣♡.• ♬ ͜͝ ̣̣♡.`r`n"
    $spacer | Out-File $detailLog -Append -Encoding utf8
    
    $compEntry = New-Object System.Collections.Generic.List[string]
    $compEntry.Add("Folder: $($folderPath.FullName)")
    $compEntry.Add($matchStatus)
    $compEntry.Add("Total: $($mkvFiles.Count) | Matches Primary: $($primaryGroup.Files.Count) | Mismatches: $mismatches`r`n")
    $compEntry | Out-File $compLog -Append -Encoding utf8
} # <--- END FOLDER LOOP

Write-Host "Complete." -ForegroundColor Cyan
Pause