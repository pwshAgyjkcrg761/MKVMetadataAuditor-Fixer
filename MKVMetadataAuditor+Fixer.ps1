# ==============================================================================
# SCRIPT: MKVMetadataAuditor+Fixer.ps1
# VERSION: 2026.06.01__15.25.00
# TARGET: PowerShell 7.6.2 LTS
#
# Copyright (C) 2026 pwshAgyjkcrg761
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
# 4. VERBATIM ANCHOR PROTOCOL:
#    - To facilitate "Find" in Notepad++, always provide "Verbatim Anchors."
#    - "Verbatim Anchors" are the exact lines of existing code immediately BEFORE and AFTER the insertion point.
#    - Do not summarize, truncate, or refactor the existing code used as an anchor.
#    - Copy the existing spaces, comments, and symbols exactly as they appear in the file.
# ==============================================================================
# </PROTECTED>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$false, Position=0, ValueFromRemainingArguments=$true)]
    [Alias("path")]
    [string[]]$PathParts,
    
    [switch]$Fix,        # Activates the Fixer module
    [switch]$FixNoBackup,    # Disables the automatic 1-by-1 backup
    
    # Global Debugging Param
    [alias("Dev", "DevD", "DBG", "DDBG")]
    [switch]$DevDebug,
    
    [Alias("nr")]
    [switch]$disableRecurse, # New flag to disable sub-directory scanning
    [switch]$DelLog,         # New flag to clear the logs folder
    [Alias("Hon")]
    [switch]$Honorifics,          # New switch for Honorifics mode
    [Alias("ovrd")]
    [switch]$overrideDefaults,
    
    [Alias("h10p")]
    [switch]$AvcHigh10Search,
    
    [switch]$fast,
    [Alias("lfp")]
    [switch]$LogFullPath,
    
    [alias("SFTO", "SubTrackOrder", "TrackOrder")]
    [switch]$SubtitleFactorTrackOrder,
    
    [alias("DSA", "Deep", "DeepAudit")]
    [switch]$DeepSubtitleAudit,
    
    [alias("DSADebugEx", "DeepDebugEx", "DeepAuditDbgEx", "DSADE")]
    [switch]$DeepSubtitleAuditDebugExtraction,
    
    [alias("DSANLD", "DeepSANLD", "NoLngD", "NLD", "LanguageDetectionOff", "LDO")]
    [switch]$DeepSubtitleAuditNOLanguageDetection,
    
    # New Automation Params
    [Alias("vid")] [string]$videoLanguage,
    [Alias("vidf")] [switch]$videoForceUpdate,
    [Alias("aud")] [string]$audioLanguagePriority,
    [Alias('audf')] [Switch]$audioLanguageUpdate,
    [Alias("sub")] [string]$subtitleLanguagePriority,
    [Alias("sc")]  [string]$subtitleCodecPriority,
    [Alias("fg")]  [string]$subtitleFansubGroupPriority,
    
    # Clear Defaults - Delete JSON Files
    [Alias("clr")]  [Switch]$ClearDefaults,
    [Alias("clrw")] [Switch]$ClearWesternDefaults,
    [Alias("cla")] [Switch]$ClearAllDefaults,
    
    # New Western Mode Flags
    [Alias("west", "WesternMode", "w")]
    [switch]$Western,
    [Alias("ovrdw")]
    [Switch]$OverrideWesternDefaults,
    
    # Western Mode Hearing Impaired Subs
    [Alias("sdh", "hi", "hicc", "cc")]
    [switch]$SubtitlesHearingImpaired,
    
    # Load the Excluded Paths file
    [Alias("ep")]
    [switch]$excludePaths,
    
    [Alias("V", "Verify")]
    [switch]$VerifyUpdates,
    
    [Alias("Ver")]
    [switch]$Version,
    
    #[Parameter(Mandatory=$false)]
    [switch]$Help,

    #[Parameter(Mandatory=$false)]
    [switch]$Manual
    
)

# --- GLOBAL VERSION DEFINITION ---
$scriptVersion = "2026.06.01__15.25.00"

# --- VERSION REPORTER ---
if ($Version) {
    Write-Host "MKVMetadataAuditor+Fixer.ps1 v$scriptVersion" -ForegroundColor Cyan
    exit
}

# --- MODULE INITIALIZATION ---
$modulePath = Join-Path $PSScriptRoot "MKVMetadataAuditor+Fixer_Modules"
. (Join-Path $modulePath "MKVMetadataAuditor+Fixer.Core.ps1")
. (Join-Path $modulePath "MKVMetadataAuditor+Fixer.Scanner.ps1")
. (Join-Path $modulePath "MKVMetadataAuditor+Fixer.DeepSubtitleAudit.ps1")
. (Join-Path $modulePath "MKVMetadataAuditor+Fixer.SearchH10P.ps1")
. (Join-Path $modulePath "MKVMetadataAuditor+Fixer.Auditor.ps1")
. (Join-Path $modulePath "MKVMetadataAuditor+Fixer.Fixer.ps1")
. (Join-Path $modulePath "MKVMetadataAuditor+Fixer.UI.ps1")



# --- HELP & MANUAL SYSTEM ---
if ($Help -or $Manual) {
    Show-ProjectManual -scriptVersion $scriptVersion
}


# --- UNKNOWN FLAG PROTECTION ---
# This catches anything starting with '-' that wasn't caught by the Param block
foreach ($part in $PathParts) {
    if ($part -like "-*") {
        Write-Host "`n[ERROR] Unknown flag detected: $part" -ForegroundColor DarkRed
        Write-Host "Please use -Help to see a list of valid commands.`n" -ForegroundColor DarkYellow
        exit
    }
}

# --- DEPENDENCY CHECK ---
if ($FixNoBackup -and -not $Fix) {
    Write-Host "`n[ERROR] Modifier flag detected without -Fix." -ForegroundColor DarkRed
    Write-Host "The -FixNoBackup flag requires the -Fix switch to be active.`n" -ForegroundColor DarkYellow
    exit
}

if ($DeepSubtitleAuditDebugExtraction -and -not $DeepSubtitleAudit) {
    Write-Host "`n[ERROR] Modifier flag detected without -DeepSubtitleAudit." -ForegroundColor DarkRed
    Write-Host "The -DeepSubtitleAuditDebugExtraction flag requires the -DeepSubtitleAudit switch to be active.`n" -ForegroundColor DarkYellow
    exit
}

# --- SEARCH FLAG RESTRICTION ---
#       Modified for Global Debug 
if (($PSBoundParameters.ContainsKey('fast') -or $PSBoundParameters.ContainsKey('LogFullPath')) -and -not $AvcHigh10Search) {
    Write-Host "`n[ERROR] Search-specific flag(s) detected." -ForegroundColor DarkRed
    Write-Host "The flags -fast and -lfp require -h10p (AvcHigh10Search) to be active.`n" -ForegroundColor DarkYellow
    exit
}

if ($LogFullPath -and -not $fast) {
    Write-Host "`n[ERROR] Invalid flag combination." -ForegroundColor DarkRed
    Write-Host "The -lfp (LogFullPath) flag can only be used in conjunction with -fast.`n" -ForegroundColor DarkYellow
    exit
}

if ($VerifyUpdates -and -not $Fix) {
    Write-Host "`n[ERROR] Invalid flag combination." -ForegroundColor DarkRed
    Write-Host "The -VerifyUpdates flag requires the -Fix switch to be active.`n" -ForegroundColor DarkYellow
    exit
}

# --- FLAG VALIDATION ---

if ($SubtitlesHearingImpaired -and -not $Western) {
    Write-Host ""
    Write-Host " [!] ERROR: SDH/HI/CC flags are only supported in -Western mode." -ForegroundColor DarkRed
    Write-Host " Please add one of the following to your command or remove the SDH flags." -ForegroundColor DarkYellow
    Write-Host " -Western | -w | -west | -WesternMode" -ForegroundColor DarkGreen
    Write-Host ""
    exit
}

if ($OverrideWesternDefaults -and -not $Western) {
    Write-Host ""
    Write-Host " [!] ERROR: -OverrideWesternDefaults is only supported in -Western mode." -ForegroundColor DarkRed
    Write-Host " Please add one of the following to your command." -ForegroundColor DarkYellow
    Write-Host " -Western | -w | -west | -WesternMode" -ForegroundColor DarkGreen
    Write-Host ""
    exit
}

# AVC High 10 Profile Whitelist Validation
if ($AvcHigh10Search) {
    
    # Block the -fast + -nr combination to prevent a "1-file-only" scan
    if ($fast -and $disableRecurse) {
        Write-Host ""
        Write-Host " [!] ERROR: Invalid flag combination." -ForegroundColor DarkRed
        Write-Host " -fast and -nr (No-Recurse) cannot be used together in Search Mode." -ForegroundColor DarkYellow
        Write-Host " -fast scans only the first file per folder. Combined with -nr, this" -ForegroundColor Gray
        Write-Host " would result in only a single file being scanned in the entire session." -ForegroundColor Gray
        Write-Host ""
        exit
    }
    
    # Define exactly what IS allowed
    $allowedH10pFlags = @('AvcHigh10Search', 'Fast', 'disableRecurse', 'Path', 'h10p', 'h10pDebug', 'PathParts', 'ep', 'excludePaths', 'LogFullPath', 'lfp', 'DevDebug')

    # Check every flag the user actually typed
    foreach ($param in $PSBoundParameters.Keys) {
        if ($param -notin $allowedH10pFlags) {
            Write-Host ""
            Write-Host " [!] ERROR: Invalid flag combination." -ForegroundColor DarkRed
            Write-Host " When using -h10p, you cannot use -$param." -ForegroundColor DarkYellow
            Write-Host " Permitted with -h10p: -Fast, -disableRecurse, and -Path." -ForegroundColor Gray
            Write-Host ""
            exit
        }
    }
}

# --- PLACE THE TRAP HERE INSTEAD ---
if ($host.Name -eq "ConsoleHost") { $ErrorActionPreference = "Continue" }
# -----------------------------------

#$ProgressPreference = 'SilentlyContinue' # Speeds up network directory scanning
$ProgressPreference = 'Continue'


# Initialize Sort Engine
Initialize-NaturalSort

# Tool Discovery
$tools = Get-MKVToolPaths
$mkvpropedit = $tools.propedit
$mkvmerge    = $tools.merge
$mkvextract  = $tools.extract
$mediainfo   = $tools.mediainfo

# --- FINAL VALIDATION ---
$missingTools = @()
if (-not (Test-Path -LiteralPath $mkvpropedit)) { $missingTools += "mkvpropedit.exe" }
if (-not (Test-Path -LiteralPath $mkvmerge))    { $missingTools += "mkvmerge.exe" }
if (-not (Test-Path -LiteralPath $mediainfo))   { $missingTools += "MediaInfo.exe" }

if ($missingTools.Count -gt 0) {
    Write-Host "[!] ERROR: The following tools were not found in PATH or default locations:" -ForegroundColor DarkRed
    $missingTools | ForEach-Object { Write-Host "  - $_" -ForegroundColor DarkYellow }
    Write-Host "`nPlease install MKVToolNix and MediaInfo CLI or ensure they are in your System PATH." -ForegroundColor Cyan
    Pause; exit
}

# [CHANGE] v2026.05.29__15.11.02 - Debug Tool Path Visibility
if ($DevDebug) {
    Write-Host "`n [DEBUG] Tool Discovery:" -ForegroundColor DarkYellow
    Write-Host "  -> mkvmerge:    $mkvmerge" -ForegroundColor Gray
    Write-Host "  -> mkvpropedit: $mkvpropedit" -ForegroundColor Gray
    Write-Host "  -> mkvextract:  $mkvextract" -ForegroundColor Gray
    Write-Host "  -> MediaInfo:   $mediainfo`n" -ForegroundColor Gray
}

if ($PSVersionTable.PSVersion -lt [version]"7.6.2") {
    Write-Host "ERROR: Running on version $($PSVersionTable.PSVersion). This script requires at least 7.6.2." -ForegroundColor DarkRed
    Pause; exit
}

# 1. Path & Log Initialization
$inputPaths = New-Object System.Collections.Generic.List[string]

# Consolidate PathParts check
if (($null -eq $PathParts -or $PathParts.Count -eq 0) -and -not ($DelLog -or $ClearDefaults -or $ClearWesternDefaults -or $ClearAllDefaults)) {
    Write-Host "ERROR: No folder detected. Use the 'Send To' menu or drag a folder onto this script." -ForegroundColor DarkRed
    Pause; exit
} elseif ($PathParts.Count -gt 0) {
    foreach ($part in ($PathParts | Sort-Object)) { 
        $cleaned = $part.Trim('"')
        [void]$inputPaths.Add($cleaned) 
    }
}

# --- LOG FOLDER DEFINITION & CLEANUP ---
# Define all directory variables
$rootLog = Join-Path $PSScriptRoot "MKVMetadataAuditor+Fixer_logs"

if ($DelLog) {
    if (Test-Path -LiteralPath $rootLog) {
        Write-Host " [!] Clearing logs folder..." -ForegroundColor Cyan
        Remove-Item -LiteralPath $rootLog -Recurse -Force
        Write-Host " [✓] Logs deleted." -ForegroundColor Green
    } else {
        Write-Host " [!] Logs folder not found. Nothing to delete." -ForegroundColor DarkYellow
    }
    # Exit if we only wanted to delete logs
    if ($inputPaths.Count -eq 0) { exit }
}

$pLogDir = Join-Path $rootLog "Path_Logs"; $dLogDir = Join-Path $rootLog "Detail_Logs"
$mLogDir = Join-Path $rootLog "Mismatch_Logs"; $cLogDir = Join-Path $rootLog "Comparison_Logs"
$fLogDir = Join-Path $rootLog "FIX_QUEUE"
$h10pLogDir = Join-Path $rootLog "AVC_High_10_Profile_Logs"
$vLogDir = Join-Path $rootLog "Updates_Verification_Logs"

# Define the timestamp once for all logs
$ts = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Create the folders
foreach ($dir in @($rootLog,$pLogDir,$dLogDir,$mLogDir,$cLogDir,$fLogDir,$h10pLogDir,$vLogDir)) { 
    if (-not (Test-Path $dir)) { New-Item $dir -ItemType Directory | Out-Null } 
}

# Define the individual log files using that single $ts
$pathLog = Join-Path $pLogDir "MKVMetadataAuditor+Fixer_Paths_$($ts)-log.txt"
$detailLog = Join-Path $dLogDir "MKVMetadataAuditor+Fixer_Details_$($ts)-log.txt"
$missLog = Join-Path $mLogDir "MKVMetadataAuditor+Fixer_Mismatches_$($ts)-log.txt"
$compLog = Join-Path $cLogDir "MKVMetadataAuditor+Fixer_Comparison_$($ts)-log.txt"
$fixerLog = Join-Path $fLogDir "MKVMetadataAuditor+Fixer_FIX_QUEUE_$($ts)-log.txt"
$h10pLog = Join-Path $h10pLogDir "MKVMetadataAuditor+Fixer_AVC_High_10_$($ts)-log.txt"
$verifyLog = Join-Path $vLogDir "MKVMetadataAuditor+Fixer_Updates_Verification_$($ts)-log.txt"

# --- GLOBAL TEMP CONFIGURATION ---
$script:GlobalTemp = Join-Path $env:TEMP "MKVMetadataAuditor+Fixer"

# Startup Cleanup: Clear old artifacts from previous sessions
if (Test-Path $script:GlobalTemp) { 
    Remove-Item -LiteralPath $script:GlobalTemp -Recurse -Force -ErrorAction SilentlyContinue 
}
New-Item -Path $script:GlobalTemp -ItemType Directory | Out-Null

$h10pList = New-Object System.Collections.Generic.List[string]
$h10pCount = 0

# --- EXCLUSION INITIALIZATION ---
$excludeFile = Join-Path $PSScriptRoot "MKVMetadataAuditor+Fixer__Excluded-Paths.txt"
$exclusions = Get-ExclusionList -ExcludeFile $excludeFile

# --- CONFIGURATION DEFAULTS ---
$configFile = Join-Path $PSScriptRoot "MKVMetadataAuditor+Fixer--FixerDefaults.json"

# --- WESTERN PROFILE HANDLER ---
$westernFile = Join-Path $PSScriptRoot "MKVMetadataAuditor+Fixer--WesternDefaults.json"

# --- CONFIG DELETION ENGINE ---
if ($ClearDefaults -or $ClearWesternDefaults -or $ClearAllDefaults) {
    Write-Host ""
    if ($ClearDefaults -or $ClearAllDefaults) {
        if (Test-Path -LiteralPath $configFile) { 
            Remove-Item -LiteralPath $configFile -Force 
            Write-Host " [✓] Deleted: Anime Defaults ($($configFile | Split-Path -Leaf))" -ForegroundColor Green
        } else { Write-Host " [!] Anime Defaults file not found." -ForegroundColor DarkGray }
    }
    if ($ClearWesternDefaults -or $ClearAllDefaults) {
        if (Test-Path -LiteralPath $westernFile) { 
            Remove-Item -LiteralPath $westernFile -Force 
            Write-Host " [✓] Deleted: Western Defaults ($($westernFile | Split-Path -Leaf))" -ForegroundColor Green
        } else { Write-Host " [!] Western Defaults file not found." -ForegroundColor DarkGray }
    }
    Write-Host " Config cleanup complete. Exiting..." -ForegroundColor Cyan
    exit
}

if ($Western) {
    # If Western mode is on but the file is missing, create it from the Anime template
    if (-not (Test-Path $westernFile)) {
        if (Test-Path $configFile) {
            $base = Get-Content $configFile | ConvertFrom-Json
            $base.Audio.PreferredLanguage = "eng"
            $base.Video.TargetLanguage = "eng"
            $base.Subtitles.PreferredLanguage = ""
            $base | ConvertTo-Json -Depth 10 | Out-File $westernFile -Encoding utf8
            Write-Host " [!] Created Western Defaults from template." -ForegroundColor DarkYellow
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
        $translatedPriority = foreach ($part in $subtitleCodecPriority.Split(',').Trim().ToLower()) {
            if ($codecMap.ContainsKey($part)) { $codecMap[$part] } else { $part }
        }
        $fixerConfig.Subtitles.CodecPriority = @($translatedPriority) + ($fixerConfig.Subtitles.CodecPriority | Where-Object { $_ -notin $translatedPriority })
        $needsUpdate = $true 
    }

    if ($needsUpdate) {
        $fixerConfig | ConvertTo-Json -Depth 10 | Out-File $westernFile -Encoding utf8
        Write-Host " [SAVED] Western defaults have been updated." -ForegroundColor Green
    }
}

# Base hardcoded defaults
$defaultSettings = [ordered]@{
    Audio = @{ PreferredLanguage = "jpn"; SetDefault = $true; IgnoreCommentary = $true }
    Subtitles = [ordered]@{ 
        PreferredLanguage = "eng"; SetDefault = $true; 
        CodecPriority = @("S_TEXT/ASS", "S_TEXT/SSA", "S_TEXT/UTF8", "S_SRT", "S_HDMV/PGS", "S_VOBSUB")
        IgnoreNames = "Signs|Songs|SDH|HI/CC|CC"
        FansubGroupPriority = @()
        
        "__COMMENT__FansubGroups_Classic_Heavy_Styling_And_Typesetting" = @("Commie", "UTW", "FFF", "gg", "Mazui", "Eclipse", "Ayako", "Static-Subs", "Central Anime", "Live-ev evil")
        "__COMMENT__FansubGroups_Modern_And_Active_Release_Groups"      = @("SubsPlease", "Erai-raws", "HorribleSubs", "DameDesuYo", "Asenshi", "Pas", "GJM", "Tsundere", "Chihiro", "MSubs", "Seto Otaku")
        "__COMMENT__FansubGroups_BDRip_Archival_And_Remux_Groups"       = @("Coalgirls", "Thora", "Kametsu", "Underwater", "SallySubs", "Yousei-raws", "DeadNews", "Beatrice-Raws", "ReinForce", "Moozzi2", "Doki")
    }
    Global = @{ ResetAllFlags = $true; RenameSDHtoCC = $true; FixMislabeledEng = $true; SDH = $false; HI = $false; HICC = $false; CC = $false }
}

# 1. MAPPING DICTIONARIES
$langMap = @{
    "english" = "eng"; "en" = "eng"; "eng" = "eng"
    "japanese" = "jpn"; "jp" = "jpn"; "jpn" = "jpn"
    "korean"  = "kor"; "ko" = "kor"; "kor" = "kor"
    "chinese" = "chi"; "zh" = "chi"; "zho" = "chi"; "chi" = "chi"
}

$codecMap = @{
    "ass" = "S_TEXT/(ASS|SSA)"
    "ssa" = "S_TEXT/(ASS|SSA)"
    "srt" = "S_TEXT/UTF8|S_SRT"
    "utf8" = "S_TEXT/UTF8|S_SRT"
    "pgs" = "S_HDMV/PGS"
    "vob" = "S_VOBSUB"
}

# --- GLOBAL REGEX PATTERNS ---
# Shared across Auditor, Fixer scoring, and DSA logic
$script:RegexDiag = "Dialog|Full|Japanese Audio|Main"
# Streamlined Sign logic: Opening/Ending/OP/ED added.
$script:RegexSign = "Sign|Song|Lyric|Opening|Ending|OP|ED|Partial|Forced|Translation|ASSR|S&S|S\s&\sS|Dubtitle"

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

# Fansub Group Priority Array Translation
if ($subtitleFansubGroupPriority) {
    $rawGroups = $subtitleFansubGroupPriority.Split(',').Trim()
    $defaultSettings.Subtitles.FansubGroupPriority = @($rawGroups)
}

# 2.5 VALIDATION: Require the appropriate override switch for parameter usage
$usedFlags = @()
if ($PSBoundParameters.ContainsKey('videoLanguage')) { $usedFlags += "-vid" }
if ($PSBoundParameters.ContainsKey('audioLanguagePriority')) { $usedFlags += "-aud" }
if ($PSBoundParameters.ContainsKey('subLanguagePriority'))   { $usedFlags += "-sub" }
if ($PSBoundParameters.ContainsKey('subtitleCodecPriority'))     { $usedFlags += "-sc" }
if ($PSBoundParameters.ContainsKey('subtitleFansubGroupPriority')) { $usedFlags += "-fg" }

# Determine which override switch is required based on the mode
$isMissingOverride = if ($Western) { 
    $usedFlags.Count -gt 0 -and -not $OverrideWesternDefaults 
} else { 
    $usedFlags.Count -gt 0 -and -not $overrideDefaults 
}

if ($isMissingOverride) {
    $requiredSwitch = if ($Western) { "-ovrdw" } else { "-ovrd" }
    
    Write-Host "==================================================" -ForegroundColor DarkRed
    Write-Host "ERROR: Parameter Override Required" -ForegroundColor DarkRed
    Write-Host "The following flags were used: $($usedFlags -join ' ')" -ForegroundColor DarkYellow
    Write-Host "To use these, you MUST also include the $requiredSwitch switch." -ForegroundColor White
    Write-Host "This ensures your changes are saved to the correct config file." -ForegroundColor White
    Write-Host "==================================================" -ForegroundColor DarkRed
    Pause; exit
}

# 3. SAVE / LOAD LOGIC
$configSource = "Built-in Defaults"
if ($overrideDefaults) {
    if ($PSBoundParameters.ContainsKey('subtitleFansubGroupPriority')) {
        $defaultSettings.Subtitles.FansubGroupPriority = @($subtitleFansubGroupPriority.Split(',').Trim())
    }
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
if (-not $DevDebug) { Clear-Host }
$uiversion = $scriptVersion

# Determine Display Mode, Action, and Override Status
$GlobalDebugStatus = if ($DevDebug) { " [DEBUG]" } else { "" }

if ($AvcHigh10Search -or $h10p) {
    $fastStatus = if ($fast) { " Fast" } else { "" }
    $recurseStatus = if ($disableRecurse) { " [No-Recurse]" } else { "" }
    $h10pLogFullPathStatus = if ($LogFullPath) { " Log Full Path" } else { "" }
    $displayMode = "AVC High 10 Search Mode$fastStatus$recurseStatus$h10pLogFullPathStatus$GlobalDebugStatus"
} else {
    $modeBase = if ($Western) { "Western Mode" } else { "Anime Mode (default)" }
    $sdhStatus = if ($SubtitlesHearingImpaired) { " SDH" } else { "" }
    $action = if ($Fix) { "Audit & Fix" } else { "Audit" }
    $recurseStatus = if ($disableRecurse) { " [No-Recurse]" } else { "" }
    $nobackupStatus = if ($FixNoBackup) { " NO BACKUP!" } else { "" }
    $ovrdStatus = if ($overrideDefaults -or $OverrideWesternDefaults) { " override defaults" } else { "" }
    $verifyStatus = if ($VerifyUpdates) { " + Verification" } else { "" }
    $displayMode = "$modeBase $action$nobackupStatus$ovrdStatus$sdhStatus$recurseStatus$verifyStatus$GlobalDebugStatus"
}

Write-Host "=================================================="
Write-Host "MKVMetadataAuditor+Fixer.ps1 v$uiversion" -ForegroundColor Cyan
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
if ($SubtitleFactorTrackOrder) {
        Write-Host "  Track Order:  " -NoNewline; Write-Host "Active (-SFTO)" -ForegroundColor Cyan
    }
if ($DeepSubtitleAudit) {
    $dsaDisp = "Active (-DSA)"
    if ($DeepSubtitleAuditDebugExtraction) { $dsaDisp += " + Forced Extraction" }
    Write-Host "  Deep Audit:   " -NoNewline; Write-Host "$dsaDisp" -ForegroundColor Cyan
}
if ($DevDebug) {
    Write-Host "  Global Debug: " -NoNewline; Write-Host "Active (-Dev)" -ForegroundColor DarkYellow
}
if ($Honorifics) {
    Write-Host "  Honorifics:   " -NoNewline; Write-Host "$(if ($Honorifics) { "On" } else { "Off" })" -ForegroundColor Blue
}
if ($fixerConfig.Subtitles.FansubGroupPriority -and $fixerConfig.Subtitles.FansubGroupPriority.Count -gt 0) {
    Write-Host "  Fansub Pref:  " -NoNewline; Write-Host "$($fixerConfig.Subtitles.FansubGroupPriority -join ', ')" -ForegroundColor Cyan
}
Write-Host "--------------------------------------------------"
#Write-Host "Script Location: " -NoNewline; Write-Host "$PSScriptRoot" -ForegroundColor DarkYellow
#Write-Host "--------------------------------------------------"
# [CHANGE] v2026.05.14_19.14.00 - Accurate UI Exclusion Count
if ($excludePaths) {
    Write-Host " Exclusions Loaded: " -NoNewline -ForegroundColor Blue
    Write-Host "$($exclusions.Count)" -ForegroundColor DarkGray
    Write-Host "--------------------------------------------------"
}
Write-Host "Source Folder(s):" -ForegroundColor Green
foreach ($p in $inputPaths) { 
    if (Test-Path -LiteralPath $p) { Write-Host "  -> $p" -ForegroundColor Blue }
    else { Write-Host "  [!] NOT FOUND: $p" -ForegroundColor DarkRed }
}

if ($Fix) {
    Write-Host "Destination Folder(s):" -ForegroundColor Green
    if ($FixNoBackup) {
        # Flash loop: alternates between DarkRed and DarkYellow 6 times
        for ($i = 0; $i -lt 6; $i++) {
            $flashColor = if ($i % 2 -eq 0) { "DarkRed" } else { "DarkYellow" }
            Write-Host -NoNewline "`r  -> SOURCE WILL BE OVERWRITTEN" -ForegroundColor $flashColor
            Start-Sleep -Milliseconds 250
        }
        # Finalize on solid Red to ensure the warning remains visible
        Write-Host "`r  -> SOURCE WILL BE OVERWRITTEN" -ForegroundColor DarkRed
    } else {
        foreach ($p in $inputPaths) { 
            $destPath = $p.TrimEnd('\') + "_updated"
            Write-Host "  -> $destPath" -ForegroundColor Blue
            
            # Warn if the updated directory already exists
            if (Test-Path -LiteralPath $destPath) {
                for ($i = 0; $i -lt 4; $i++) {
                    $flashColor = if ($i % 2 -eq 0) { "DarkRed" } else { "DarkYellow" }
                    Write-Host -NoNewline "`r     [!] WARNING: Destination folder already exists and will be overwritten!" -ForegroundColor $flashColor
                    #Start-Sleep -Milliseconds 250
                }
                Write-Host "`r     [!] WARNING: Destination folder already exists and will be overwritten!" -ForegroundColor DarkGray
            } # <-- Closes: if (Test-Path...)
        } # <-- Closes: foreach ($p in $inputPaths)
    } # <-- Closes: else { ... (the non-FixNoBackup block)
} # <-- Closes: if ($Fix)

if ($VerifyUpdates) {
    Write-Host "Verification Mode:" -ForegroundColor Green
    if ($Fix -and -not $FixNoBackup) {
        foreach ($p in $inputPaths) {
            $verifyDest = $p.TrimEnd('\') + "_updated"
            Write-Host "  -> Post-Fix Audit Target: $verifyDest" -ForegroundColor Cyan
        }
    } else {
        Write-Host "  -> Post-Fix Audit Target: [Source Folders Directly]" -ForegroundColor Cyan
    }
}
Write-Host "--------------------------------------------------"

# Determine Start Message
$startMessage = if ($AvcHigh10Search -and $Fast -and $LogFullPath) { 
    "Begin AVC High 10 Profile Search Fast with Log Full File Path?" 
} elseif ($AvcHigh10Search -and $Fast) { 
    "Begin AVC High 10 Profile Search Fast?"
} elseif ($AvcHigh10Search) { 
    "Begin AVC High 10 Profile Search?"
} elseif ($Fix -and $FixNoBackup -and $VerifyUpdates) { 
    "Begin Auditing and Fixing with NO BACKUP then Verify?"    
} elseif ($Fix -and $FixNoBackup) { 
    "Begin Auditing then Fixing with NO BACKUP?"
} elseif ($Fix -and $VerifyUpdates) { 
    "Begin Auditing and Fixing then Verify?" 
} elseif ($Fix) { 
    "Begin Auditing then Fixing?" 
} else { 
    "Begin Auditing?" 
}

# Determine Color
$msgColor = if ($FixNoBackup -and $Fix) { "DarkRed" } else { "Gray" }

# Print message without a newline, then call Read-Host
Write-Host "$startMessage " -ForegroundColor $msgColor -NoNewline
$choice = Read-Host "(Y/N)"

if ($choice -notmatch "^[yY]$") {
    Write-Host "Operation cancelled by user." -ForegroundColor DarkYellow
    Pause; exit
}
Write-Host "Starting..." -ForegroundColor DarkGreen
# --- END STARTUP DISPLAY ---

# 2. Functions

# --- DEFINE AUDIT JOBS ---
$AuditJobs = New-Object System.Collections.Generic.List[PSObject]
$AuditJobs.Add([PSCustomObject]@{ TargetPaths = $inputPaths; ActiveLog = $detailLog; Mode = "Standard" })

if ($VerifyUpdates -and -not $AvcHigh10Search -and $verifyPaths.Count -gt 0) {
    $AuditJobs.Add([PSCustomObject]@{ TargetPaths = $verifyPaths; ActiveLog = $verifyLog; Mode = "Verification" })
}

# --- GLOBAL JOB LOOP ---
# Using a 'for' loop allows the script to see new jobs added to the list during execution
for ($j = 0; $j -lt $AuditJobs.Count; $j++) {
    $CurrentJob = $AuditJobs[$j]
    
    
    # Redirection: Point active variables to the current Job context
    # This allows your existing logic to run unmodified
    $inputPaths = $CurrentJob.TargetPaths
    $detailLog  = $CurrentJob.ActiveLog
    $script:FilesModifiedInJob = 0
    
    # Safety: Ensure Fix mode only runs on the Standard audit, never on Verification
    $IsFixRun = ($Fix -and ($CurrentJob.Mode -eq "Standard"))

if ($CurrentJob.Mode -eq "Verification") {
        
        Write-Host "--------------------------------------------------" -ForegroundColor Cyan
        Write-Host " Running Updates Verification Audit..." -ForegroundColor DarkMagenta
        Write-Host " Target: $($inputPaths -join ', ')" -ForegroundColor DarkGray        
        Write-Host "--------------------------------------------------" -ForegroundColor Cyan
        
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

# --- FOLDER DISCOVERY ---
$targetFolders = Get-TargetFolders -InputPaths $inputPaths -DisableRecurse $disableRecurse

$fastHeaderWritten = $false

# v2026.05.13_16.32.00 - Log Buffer and Timer
$logBuffer = New-Object System.Collections.Generic.List[string]
$lastFlushTime = [DateTime]::Now

# Folder Loop
$videoExtensions = @("*.mkv", "*.mp4", "*.m4v", "*.avi", "*.wmv", "*.flv", "*.mov", "*.ts", "*.m2ts", "*.ogm")
$Host.PrivateData.ProgressForegroundColor = "Cyan"
if ($fast) {
    $totalSessionItems = $targetFolders.Count
} else {
    Write-Host " [i] Initializing session: Counting video files..." -ForegroundColor DarkCyan
    $sessionFileList = New-Object System.Collections.Generic.List[string]
    $folderCounter = 0
    
    foreach ($folder in $targetFolders) {
        $folderCounter++
        Write-Progress -Activity "Initializing Session" -Status "Scanning Folder $folderCounter of $($targetFolders.Count)" -PercentComplete ([int]($folderCounter / $targetFolders.Count * 100))
        
        $found = Get-ChildItem -LiteralPath $folder.FullName -Include $videoExtensions -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
        if ($found) { $found | ForEach-Object { $sessionFileList.Add([string]$_) } }
    }
    $totalSessionItems = ($sessionFileList | Select-Object -Unique).Count
    Write-Host " [i] Total video files found: $totalSessionItems" -ForegroundColor DarkGreen
    Write-Progress -Activity "Initializing Session" -Completed
}
$sessionProgressIndex = 0
foreach ($folderPath in $targetFolders) {
    # [MODULE] Check for Exclusions
    if (Test-IsExcluded -CurrentPath $folderPath.FullName -Exclusions $exclusions -Active $excludePaths) {
        Write-Host " [SKIP] Folder excluded by rule: $($folderPath.Name)" -ForegroundColor DarkGray
            
        # [CHANGE] v2026.05.29__13.26.15 - Formatted Exclusion Block for Detail Log
        $isUNC = $folderPath.FullName.StartsWith("\\")
        $pathParts = $folderPath.FullName.Split('\', [System.StringSplitOptions]::RemoveEmptyEntries)
        $border = "-" * 99
        
        $skipOutput = New-Object System.Collections.Generic.List[string]
        $skipOutput.Add("") # Blank line before
        $skipOutput.Add($border)
        
        $currentLine = "EXCLUDED PATH: '"
        for ($i = 0; $i -lt $pathParts.Count; $i++) {
            $segment = if ($i -eq ($pathParts.Count - 1)) { $pathParts[$i] } else { $pathParts[$i] + "\" }
            if ($i -eq 0 -and $isUNC) { $segment = "\\" + $segment }
            
            # Wrap at 95 to allow for closing quote and safety margin
            if (($currentLine + $segment).Length -gt 95 -and $currentLine -ne "EXCLUDED PATH: '") {
                $skipOutput.Add($currentLine)
                $currentLine = "                " + $segment # 16-space indent to align after ':'
            } else {
                $currentLine += $segment
            }
        }
        $currentLine += "'" # Close the path quote
        $skipOutput.Add($currentLine)
        $skipOutput.Add("") # Gap before message
        $skipOutput.Add("This path was skipped because it is listed in MKVMetadataAuditor+Fixer__Excluded-Paths.txt.")
        $skipOutput.Add($border)
        $skipOutput.Add("") # Blank line after
        $skipOutput.Add("") # Blank line after
        
        $skipOutput | Out-File $detailLog -Append -Encoding utf8
        
        continue
    }
    
    Write-Host "Checking: $($folderPath.FullName)..." -ForegroundColor Gray # <--- LIVE FEEDBACK
    $global:GroupMap = @{}
    $global:Counter = 1
    $folder = Get-Item -LiteralPath $folderPath.FullName
    $mkvFiles = Get-ChildItem -LiteralPath $folder.FullName -Filter "*.mkv" | Sort-NaturalFiles
    if ($mkvFiles.Count -eq 0) { continue }
    
    # --- DYNAMIC PADDING (PER FOLDER) ---
    # [FIX] v2026.05.15_15.02.00 - Bypass probes if searching to match Finder speed
    if (-not $AvcHigh10Search) {
        $allCodecs = foreach ($f in $mkvFiles) { (& $mkvmerge -J $f.FullName | ConvertFrom-Json).tracks.codec }
        $codecPadding = [Math]::Max(5, ($allCodecs | Measure-Object -Property Length -Maximum).Maximum)
        
        $allTrackNames = foreach ($f in $mkvFiles) { (& $mkvmerge -J $f.FullName | ConvertFrom-Json).tracks.properties.track_name }
        $namePadding = [Math]::Max(4, ($allTrackNames | Measure-Object -Property Length -Maximum).Maximum)
    } else {
        # Defaults to prevent errors in shared logic
        $codecPadding = 10
        $namePadding = 20
    }
    $propPadding = 9
    
    # High10P SCAN (MediaInfo)
    # This runs BEFORE the auditor/grouping logic so it actually sees the files
    # --- SEARCH LOGIC (REPLACE THE High 10 SECTION INSIDE THE FOLDER LOOP) ---

    
    # v2026.05.13_16.08.00 - Finalized Spacing & One-Time Fast Header
    if ($AvcHigh10Search) {
        $scanFiles = if ($fast) { $mkvFiles | Select-Object -First 1 } else { $mkvFiles }
        $currentFileIndex = 0
        
        foreach ($f in $scanFiles) {
            $sessionProgressIndex++
            
            # Call the custom Auditor function
            # Update the progress bar only every 10 files (or if it's the last file)
            if ($sessionProgressIndex % 10 -eq 0 -or $sessionProgressIndex -eq $totalSessionItems) {
                $statusMsg = if ($fast) { "Processing Folders" } else { "Processing Files" }
                Write-InlineProgress -Current $sessionProgressIndex -Total $totalSessionItems -Message $statusMsg
            }
            
            # Write-Progress -Activity "Total Session Progress" -Status $statusMsg -PercentComplete $percent
            # If debugging, ensure we move to a new line so the bar remains visible
            if ($DevDebug) { 
                Write-Host "`n [DEBUG] File Path: $($f.FullName)" -ForegroundColor Gray
                Write-Host " [DEBUG] File Name: $($f.Name)" -ForegroundColor DarkGray 
            }
            if (Test-IsHigh10 -FilePath $f.FullName -MediaInfoPath $mediainfo) {
                $h10pCount++
                
                # Logic: If Fast mode and no FullPath requested, log the Folder Path for the exclusion list.
                $entryToAdd = if ($fast -and -not $LogFullPath) { $folderPath.FullName.TrimEnd('\') } else { $f.FullName }
                $h10pList.Add($entryToAdd)
                
                Write-Host "`n"
                Write-Host "  [!] Found AVC High 10: $($f.Name)" -ForegroundColor DarkYellow
            }
        }
        Write-Host "" # Clears the inline progress line
        
        # v2026.05.13_16.32.00 - Periodic 60-Second Flush
        if ($h10pList.Count -gt 0) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"

            if ($fast) {
                # Add content to buffer for Fast Mode
                if (-not $fastHeaderWritten) {
                    $logBuffer.AddRange((Get-H10PLogHeader -Fast))
                    $fastHeaderWritten = $true
                }
                foreach ($line in $h10pList) { $logBuffer.Add($line) }
            } else {
                # Add content to buffer for Standard Mode
                $leadingSpace = (Test-Path $h10pLog) -or ($logBuffer.Count -gt 0) ? "`r`n" : ""
                $logBuffer.Add("$leadingSpace----------------------------------------------")
                $logBuffer.Add($timestamp)
                $logBuffer.Add("Folder: $($folderPath.FullName)")
                $logBuffer.Add("AVC High 10 Profile Found")
                $logBuffer.Add("Recommend convert to HEVC Main 10")
                $logBuffer.Add("----------------------------------------------")
                $logBuffer.Add("")
                foreach ($line in $h10pList) { $logBuffer.Add($line) }
            }
            $h10pList.Clear()
        }

        # CHECK TIMER: If 60 seconds passed, flush to disk
        if (([DateTime]::Now - $lastFlushTime).TotalSeconds -ge 60 -and $logBuffer.Count -gt 0) {
            Write-Host " [i] 60s Elapsed: Flushing log buffer to disk..." -ForegroundColor Cyan
            $logBuffer | Out-File -FilePath $h10pLog -Append -Encoding utf8
            $logBuffer.Clear()
            $lastFlushTime = [DateTime]::Now
        }

        continue 
    }

    # --- TABLE PRINTING FUNCTION ---
    $script:PrintTable = [scriptblock]{
        param($groupJson, $title, $compareJson)
        
        Get-ProjectTable -Selector { param($type, $reset) Get-AuditSelector $type -Reset:$reset } `
                         -groupJson $groupJson -title $title -compareJson $compareJson `
                         -codecPadding $codecPadding -propPadding $propPadding -namePadding $namePadding `
                         -entry $entry
    }

    # --- GROUPING LOGIC ---
    if ($AvcHigh10Search) {
        Write-Host " [✓] AVC High 10 Scan complete for this folder." -ForegroundColor DarkGreen
    } else {
        $mkvCount = $mkvFiles.Count
        $orderedGroups = New-Object System.Collections.Generic.List[PSObject]
        
        for ($i = 0; $i -lt $mkvCount; $i++) {
            $f = $mkvFiles[$i]
            # 1. Update the user with the progress bar immediately
            Write-InlineProgress -Current ($i + 1) -Total $mkvCount -Message "Analyzing Files"
            
            if ($DevDebug) {
                Write-Host "`n`n`n [DEBUG] File Path: $($f.FullName)" -ForegroundColor Gray
                Write-Host " [DEBUG] File Name: $($f.Name)" -ForegroundColor DarkGray
            }
            
            # 2. Log path to file
            $f.FullName | Out-File $pathLog -Append -Encoding utf8
            
            # 3. Get JSON and build signature
            $json = & $mkvmerge -J $f.FullName | ConvertFrom-Json
            # [CHANGE] v2026.05.29__15.48.15 - Add Selector (Sel) to Audit Signature
            Get-AuditSelector -Reset
            $sig = (($json.tracks | ForEach-Object { 
                $p = $_.properties
                $sel = Get-AuditSelector $_.type
                "$($_.id)|$sel|$($_.type)|$($_.codec)|$($p.language)|Def:$([bool]$p.default_track)|Frc:$([bool]$p.forced_track)|HI:$([bool]$p.flag_hearing_impaired)|$($p.track_name)" 
            }) -join "`n")
            
            # Signature Debugging
            if ($DevDebug) {
                Write-Host " [DEBUG] Generating Track Signature..." -ForegroundColor DarkCyan
                $sig.Split("`n") | ForEach-Object { Write-Host "    $($_.Trim())" -ForegroundColor Gray }
                Write-Host "`n"
            }
            
            # --- SEPARATE AVC HIGH 10 SEARCH ---
            if ($AvcHigh10Search -and (Test-Path -LiteralPath $mediainfo)) {
                $profile = & $mediainfo --Inform="Video;%Format_Profile%" "$($f.FullName)"
                if ($profile -match "High@10") {
                    $h10pCount++
                    $h10pList.Add($f.FullName)
                    Write-Host " [!] Found AVC High 10: $($f.Name)" -ForegroundColor DarkYellow
                }
            }
            
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
        
        # v2026.05.13_10.43.00 - Real-time Console Feedback
        if ($AvcHigh10Search) {
            Write-Host "" # New line
            if ($h10pList.Count -gt 0) {
                Write-Host " [!] Found $($h10pList.Count) High 10 files in: $($folder.Name)" -ForegroundColor DarkYellow
            } else {
                Write-Host " [✓] No High 10 files in: $($folder.Name)" -ForegroundColor DarkGreen
            }
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
            $reasons = Get-AuditFlags -tracks $currentGroup.Json.tracks -IsWestern $Western -fixerConfig $fixerConfig -Honorifics $Honorifics -SubtitlesHearingImpaired $SubtitlesHearingImpaired

            
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
            
            
            # --- PATH WRAPPING LOGIC (90 CHAR LIMIT) ---
            $headerPrefix = if ($isPrimary) { "--- $label [$shortName] MKV AUDIT: " } else { "--- $label [$shortName] +MISMATCHED+ MKV: " }
            
            $isUNC = $repFile.FullName.StartsWith("\\")
            
            # Split the full path including the filename
            $pathParts = $repFile.FullName.Split('\', [System.StringSplitOptions]::RemoveEmptyEntries)
            
            $wrappedPathLines = New-Object System.Collections.Generic.List[string]
            $currentLine = $headerPrefix

            for ($i = 0; $i -lt $pathParts.Count; $i++) {
                # Add a backslash to every segment EXCEPT the last one (the filename)
                $segment = if ($i -eq ($pathParts.Count - 1)) { $pathParts[$i] } else { $pathParts[$i] + "\" }
                
                # Manual fix for UNC paths (re-inject leading \\ to the first segment)
                if ($i -eq 0 -and $isUNC) { $segment = "\\" + $segment }
                
                # Check if adding this segment exceeds 90 characters
                if (($currentLine + $segment).Length -gt 90 -and $currentLine -ne $headerPrefix) {
                    $wrappedPathLines.Add($currentLine)
                    $currentLine = $segment
                } else {
                    $currentLine += $segment
                }
            }
            # Close out the last line with the footer dashes
            $currentLine = $currentLine.TrimEnd() + " ---"
            $wrappedPathLines.Add($currentLine)
            
            if ($isPrimary) {
                foreach ($line in $wrappedPathLines) { $entry.Add($line) }
                $entry.Add("FILE NAME: $($repFile.Name)")
                # If there are NO audit flags, it is Reference Only.
                # If there ARE flags, show only the flags and drop the Reference label.
                if ($reasons -eq "") {
                    $entry.Add("REASON: 💎[Reference Only]")
                } else {
                    # Split only on spaces that follow a closing bracket
                    $reasonParts = [regex]::Split($reasons, "(?<=\])\s")
                    $currentReasonLine = "REASON: "
                    foreach ($rPart in $reasonParts) {
                        if (($currentReasonLine + " " + $rPart).Length -gt 90 -and $currentReasonLine -ne "REASON: ") {
                            $entry.Add($currentReasonLine)
                            $currentReasonLine = "        " + $rPart # Indent wrapped lines
                        } else {
                            $currentReasonLine = if ($currentReasonLine -eq "REASON: ") { $currentReasonLine + $rPart } else { $currentReasonLine + " " + $rPart }
                        }
                    }
                    $entry.Add($currentReasonLine)
                }
                
                $matchStatus = if ($mismatches -eq 0) {
                    "✔+++All Files in Folder Match: YES ($($mkvFiles.Count))+++✔" 
                } else { 
                    "❌+++All Files in Folder Match: NO (0)+++❌" 
                }
                $entry.Add($matchStatus)
            } else {
                # Mismatched Header (Secondary 02+)
                foreach ($line in $wrappedPathLines) { $entry.Add($line) }
                $entry.Add("Primary: $($primaryGroup.Files[0].Name)")
                
                # Updated to show Reference Only for Secondary groups too
                if ($reasons -eq "") {
                    $entry.Add("REASON: 💎[Reference Only]")
                } else {
                    $reasonParts = [regex]::Split($reasons, "(?<=\])\s")
                    $currentReasonLine = "REASON: "
                    foreach ($rPart in $reasonParts) {
                        if (($currentReasonLine + " " + $rPart).Length -gt 90 -and $currentReasonLine -ne "REASON: ") {
                            $entry.Add($currentReasonLine)
                            $currentReasonLine = "        " + $rPart
                        } else {
                            $currentReasonLine = if ($currentReasonLine -eq "REASON: ") { $currentReasonLine + $rPart } else { $currentReasonLine + " " + $rPart }
                        }
                    }
                    $entry.Add($currentReasonLine)
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
                # 1. Initialize the list FIRST so we can log skips to it
                $fixDetails = New-Object System.Collections.Generic.List[string]
                $Params = @() 
                $needsChange = $false 
                $bestAudioSel = $null; $bestSubSel = $null; $foundPrefAudio = $false
                $subCandidates = @()
                
                # 2. Define videoCount
                $videoCount = ($currentGroup.Json.tracks | Where-Object { $_.type -eq "video" } | Measure-Object).Count
                
                # --- [AUDIO FORCE PRE-CHECK] ---
                $undAudioCount = ($currentGroup.Json.tracks | Where-Object { $_.type -eq "audio" -and $_.properties.language -eq "und" } | Measure-Object).Count
                $totalAudioCount = ($currentGroup.Json.tracks | Where-Object { $_.type -eq "audio" } | Measure-Object).Count
                # Logic: Allow force if user provided -audf and it's a single-audio file (regardless of current lang)
                $canForceAudio = ($audioLanguageUpdate -and $totalAudioCount -eq 1)
                
                # 3. GLOBAL SKIP FOR MULTI-VIDEO FILES
                if ($videoCount -gt 1) {
                    [void]$fixDetails.Add("FILE: $($fToFix.FullName)")
                    [void]$fixDetails.Add("  [!] SKIPPING FILE: Multiple video tracks detected ($videoCount).")
                    [void]$fixDetails.Add("") # Add spacing
                    $fixDetails | Out-File $fixerLog -Append -Encoding utf8
                    continue 
                }

                # 4. Standard File Logging (for files that aren't skipped)
                [void]$fixDetails.Add("FILE: $($fToFix.FullName)")

                # --- [CRITICAL FIX] RESOLVE TARGET LANGUAGE ONCE PER FILE ---
                $rawInput = if ($videoLanguage) { $videoLanguage } else { $fixerConfig.Video.TargetLanguage }
                $resolvedTarget = if ($null -ne $rawInput) {
                    $key = "$rawInput".ToLower().Trim()
                    if ($langMap.ContainsKey($key)) { $langMap[$key] } else { $key }
                } else { $null }

                # 1. IDENTIFY TARGETS
                Get-AuditSelector -Reset
                $subRelativeIndex = 0
                
                # NEW: Define videoCount here so the check below works
                $videoCount = ($currentGroup.Json.tracks | Where-Object { $_.type -eq "video" } | Measure-Object).Count
                
                foreach ($t in $currentGroup.Json.tracks) {
                    $sel = Get-AuditSelector $t.type
                    
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
                    # $targetAudLang = if ($Western) { "eng" } else { $fixerConfig.Audio.PreferredLanguage }
                    
                    $targetAudLang = if ($fixerConfig.Audio.PreferredLanguage) { $fixerConfig.Audio.PreferredLanguage } 
                                     elseif ($Western) { "eng" } 
                                     else { "jpn" }
                                     
                    # --- AUDIO FORCE LOGIC (-audf) ---
                    if ($t.type -eq "audio" -and $canForceAudio) {
                        $mkvID = $t.id + 1
                        $Params += @('--edit', "track:$mkvID", '--set', "language=$targetAudLang", '--set', "flag-default=1")
                        $needsChange = $true
                        $bestAudioSel = $sel    # Register this as the "Winner"
                        $foundPrefAudio = $true # Prevent other tracks from being picked
                        [void]$fixDetails.Add("  ACTION: SET_LANG=$targetAudLang | SET_DEFAULT=1 | TRACK: $mkvID | REASON: Audio Force (-audf)")
                        continue # Skip standard audio checks and Global Reset for this track
                    }

                    # --- SINGLE UNDEFINED AUDIO AUTO-PICK ---
                    if ($t.type -eq "audio" -and $totalAudioCount -eq 1 -and -not $foundPrefAudio) {
                        $bestAudioSel = $sel
                        $foundPrefAudio = $true
                        [void]$fixDetails.Add("  ACTION: PICK_DEFAULT | TRACK: $($t.id + 1) | REASON: Single Audio Track")
                    }      
                    
                    if ($t.type -eq "audio" -and -not $foundPrefAudio -and $t.properties.language -eq $targetAudLang) {
                        if (-not ($fixerConfig.Audio.IgnoreCommentary -and ($t.properties.track_name -match "Commentary|Interview"))) {
                            $bestAudioSel = $sel; $foundPrefAudio = $true
                        }
                    }
                    
                    # --- SUBTITLES ---
                    if ($t.type -eq "subtitles") {
                        $trackName = if ($t.properties.track_name) { $t.properties.track_name.ToLower() } else { "" }
                        
                        
                        # --- [DSA] DEEP SUBTITLE AUDIT ENGINE (LOG & DIALOGUE UPDATE) ---
                        if ($DeepSubtitleAudit) {
                            $fileGuid = "DSA_" + $fToFix.Name.GetHashCode().ToString('X')
                            
                            # --- STAGE 1: DISCOVERY ---
                            if ($null -eq $currentGroup.PSObject.Properties[$fileGuid]) {
                                $allSubs = $currentGroup.Json.tracks | Where-Object { $_.type -eq "subtitles" }
                                
                                # EXPANDED CODEC REGEX: Included 'SubStationAlpha' and 'SubRip' to ensure stylized subs trigger DSA
                                $textSubs = $allSubs | Where-Object { ($_.codec -match "S_TEXT|UTF8|SRT|ASS|SSA|SubStationAlpha|SubRip|PGS|VobSub") }
                                
                                # ELIGIBILITY: Exactly 2 text tracks required
                                if ($textSubs.Count -eq 2) {
                                    if ($DevDebug) { Write-Host "  [DSA] Discovery: Found 2 text tracks. Initializing Analysis for: $($fToFix.Name)" -ForegroundColor Cyan }
                                    $currentGroup | Add-Member -MemberType NoteProperty -Name $fileGuid -Value @{ "Tracks" = $textSubs; "Weights" = @{} } -Force
                                } else {
                                    # LOGIC: If file doesn't have exactly 2 text tracks, mark as ineligible to save CPU on next loop
                                    $currentGroup | Add-Member -MemberType NoteProperty -Name $fileGuid -Value $null -Force
                                }
                            }

                            $dsaCtx = $currentGroup.PSObject.Properties[$fileGuid].Value
                            if ($null -ne $dsaCtx) {
                                $ambiguousTracks = $dsaCtx.Tracks

                                # 2. PROBING PHASE (Weights and Language Detection)
                                if ($dsaCtx.Weights.Count -eq 0) {
                                    $id1 = $ambiguousTracks[0].id; $id2 = $ambiguousTracks[1].id
                                    $w1 = 0; $w2 = 0; $isResolved = $false
                                    $targetRatio = 3.0

                                    if (-not $DeepSubtitleAuditDebugExtraction) {
                                        $h1 = if ($ambiguousTracks[0].properties.tag_number_of_frames) { [int64]$ambiguousTracks[0].properties.tag_number_of_frames } 
                                              elseif ($ambiguousTracks[0].properties.statistics_tags.NUMBER_OF_FRAMES) { [int64]$ambiguousTracks[0].properties.statistics_tags.NUMBER_OF_FRAMES } else { 0 }
                                        $h2 = if ($ambiguousTracks[1].properties.tag_number_of_frames) { [int64]$ambiguousTracks[1].properties.tag_number_of_frames } 
                                              elseif ($ambiguousTracks[1].properties.statistics_tags.NUMBER_OF_FRAMES) { [int64]$ambiguousTracks[1].properties.statistics_tags.NUMBER_OF_FRAMES } else { 0 }
                                        
                                        if ($h1 -gt 0 -and $h2 -gt 0) {
                                            $hRatio = [Math]::Max($h1, $h2) / [Math]::Max(1, [Math]::Min($h1, $h2))
                                            if ($hRatio -ge $targetRatio) {
                                                # Check if headers already claim Dual-English
                                                $isHeaderDualEng = ($ambiguousTracks[0].properties.language -eq "eng" -and $ambiguousTracks[1].properties.language -eq "eng")
                                                
                                                if ($isHeaderDualEng) {
                                                    if ($DevDebug) { Write-Host "  [DSA] Header Probe SUCCESS (Ratio: $($hRatio.ToString('F2')))" -ForegroundColor Green }
                                                    $w1 = $h1; $w2 = $h2; $isResolved = $true
                                                } else {
                                                    # If languages are mixed (e.g. JPN/ENG), we don't trust the header. 
                                                    # By NOT setting $isResolved, we force the Stage 2 Extraction to run and verify the language.
                                                    if ($DevDebug) { Write-Host "  [DSA] Header Ratio Valid ($($hRatio.ToString('F2'))), but Language Mismatch detected. Forcing Extraction Probe..." -ForegroundColor DarkYellow }
                                                }
                                            }
                                        }
                                    }

                                    if (-not $isResolved) {
                                        $tempDir = Join-Path $script:GlobalTemp "DSA_Probe_$($fToFix.Name.GetHashCode().ToString('X'))"
                                        if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
                                        New-Item -Path $tempDir -ItemType Directory | Out-Null
                                        
                                        # Map specific binary extensions for Image-based subs
                                        $ext1 = Get-SubtitleExtension -Codec $ambiguousTracks[0].codec
                                        $ext2 = Get-SubtitleExtension -Codec $ambiguousTracks[1].codec
                                        
                                        $tmpFile1 = Join-Path $tempDir "track1.$ext1"; $tmpFile2 = Join-Path $tempDir "track2.$ext2"
                                        
                                        & $mkvextract "$($fToFix.FullName)" tracks "$($id1):$tmpFile1" "$($id2):$tmpFile2" | Out-Null
                                        
                                        # For VobSub, mkvextract creates .sub and .idx. We target the .sub bitstream.
                                        $probeFile1 = $tmpFile1; $probeFile2 = $tmpFile2
                                        
                                        # Identify if we are dealing with Image-based subs (PGS/VobSub)
                                        $isImageSub = ($ambiguousTracks[0].codec -match "PGS|VobSub")

                                        if ($null -ne $probeFile1 -and (Test-Path -LiteralPath $probeFile1)) {
                                            $clean1 = Extract-DialogueText -Path $probeFile1 -OutPath (Join-Path $tempDir "track1_cleaned.txt") -DevDebug $DevDebug
                                            $clean2 = Extract-DialogueText -Path $probeFile2 -OutPath (Join-Path $tempDir "track2_cleaned.txt") -DevDebug $DevDebug

                                            # If Image-Based (PGS/VOB), set weights to the binary file size
                                            if ($isImageSub) {
                                                $w1 = (Get-Item -LiteralPath $probeFile1).Length
                                                $w2 = (Get-Item -LiteralPath $probeFile2).Length
                                                $isResolved = $true
                                            }

                                            # --- MULTI-LANGUAGE DETECTION ENGINE ---
                                            # Note: -and -not $isImageSub ensures binary files don't crash the detector
                                            if (-not $DeepSubtitleAuditNOLanguageDetection -and -not $isImageSub) {
                                                $res1 = Detect-SubtitleLanguage -Text $clean1 -Honorifics:$Honorifics
                                                $res2 = Detect-SubtitleLanguage -Text $clean2 -Honorifics:$Honorifics
                                                $pair = @($res1, $res2)
                                                for ($i=0; $i -lt 2; $i++) {
                                                    $detected = $pair[$i]
                                                    # PROTECTION: If already 'enm' and we detected 'eng', don't overwrite.
                                                    $isAlreadyHon = ($ambiguousTracks[$i].properties.language -eq "enm" -and $detected -eq "eng")
                                                    
                                                    if (-not $isAlreadyHon -and $ambiguousTracks[$i].properties.language -ne $detected -and $detected -ne "und") {
                                                        if ($DevDebug) { Write-Host "  [DSA] Lng Fix: Track $($ambiguousTracks[$i].id) ($($ambiguousTracks[$i].properties.language) -> $detected)" -ForegroundColor DarkCyan }
                                                        $ambiguousTracks[$i].properties.language = $detected
                                                        if ($Fix) { $Params += @('--edit', "track:$($ambiguousTracks[$i].id + 1)", '--set', "language=$detected") }
                                                    }
                                                }
                                            }

                                            $b1 = (Get-Item $probeFile1).Length; $b2 = (Get-Item $probeFile2).Length
                                            $bRatio = [Math]::Max($b1, $b2) / [Math]::Max(1, [Math]::Min($b1, $b2))
                                            if ($bRatio -ge $targetRatio) {
                                                if ($DevDebug) { Write-Host "  [DSA] Bitstream Probe SUCCESS (Ratio: $($bRatio.ToString('F2')))" -ForegroundColor Green }
                                                $w1 = $b1; $w2 = $b2; $isResolved = $true
                                            } else {
                                                if ($DevDebug) { Write-Host "  [DSA] Bitstream ratio too low ($($bRatio.ToString('F2'))). Performing Text-Only Deep Probe..." -ForegroundColor DarkCyan }
                                                $w1 = $clean1.Length; $w2 = $clean2.Length
                                                $tRatio = if ($w1 -gt 0 -and $w2 -gt 0) { [Math]::Max($w1, $w2) / [Math]::Max(1, [Math]::Min($w1, $w2)) } else { 0 }
                                                if ($tRatio -ge 2.0) {
                                                    if ($DevDebug) { Write-Host "  [DSA] Text Probe SUCCESS (Ratio: $($tRatio.ToString('F2')))" -ForegroundColor Green }
                                                    $isResolved = $true; $targetRatio = 2.0
                                                }
                                            }
                                        }

                                        # --- CLEANUP / PRESERVATION ---
                                        if ($DevDebug) {
                                            Write-Host "    [DEBUG] Final Weight ID:$id1 ($w1) | ID:$id2 ($w2)" -ForegroundColor Gray
                                            Write-Host "    [DEBUG] Preservation Active: Files kept at -> $tempDir" -ForegroundColor DarkCyan
                                        } else {
                                            # Standard Mode: Clean up extraction artifacts immediately
                                            if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
                                        }
                                    }

                                    $dsaCtx.Weights[$id1] = $w1; $dsaCtx.Weights[$id2] = $w2
                                    $currentGroup | Add-Member -MemberType NoteProperty -Name ($fileGuid + "_Ratio") -Value $targetRatio -Force
                                }

                                # --- STAGE 3: DECISION LOGIC ---
                                $w1 = $dsaCtx.Weights[$ambiguousTracks[0].id]
                                $w2 = $dsaCtx.Weights[$ambiguousTracks[1].id]
                                $dynRatio = $currentGroup.PSObject.Properties[$fileGuid + "_Ratio"].Value
                                
                                if ($w1 -gt 0 -and $w2 -gt 0) {
                                    $ratio = [Math]::Max($w1, $w2) / [Math]::Min($w1, $w2)
                                    
                                    # TRUTH CHECK: Use the detected languages (updated by Probe)
                                    # Naming/Swapping logic will ONLY proceed if both tracks are confirmed English.
                                    # For other languages (chi, kor, rus, etc.), the script will have already updated the 
                                    # language flag in Stage 2, but will skip the Stage 3 naming block.
                                    $isDualEng = ($ambiguousTracks[0].properties.language -match "eng|enm" -and $ambiguousTracks[1].properties.language -match "eng|enm")
                                    
                                    if ($ratio -ge $dynRatio -and $isDualEng) {
                                        # ASSIGN ROLES: Physically identify which track is Large and which is Small
                                        $largeTrack = if ($w1 -gt $w2) { $ambiguousTracks[0] } else { $ambiguousTracks[1] }
                                        $smallTrack = if ($w1 -gt $w2) { $ambiguousTracks[1] } else { $ambiguousTracks[0] }
                                        
                                        $nameL = if ($largeTrack.properties.track_name) { $largeTrack.properties.track_name } else { "" }
                                        $nameS = if ($smallTrack.properties.track_name) { $smallTrack.properties.track_name } else { "" }
                                        
                                        # IDENTIFY VALIDITY: Using Global Regex Patterns
                                        $hasDiagL = $nameL -match $script:RegexDiag
                                        $hasSignL = $nameL -match $script:RegexSign
                                        $hasDiagS = $nameS -match $script:RegexDiag
                                        $hasSignS = $nameS -match $script:RegexSign
                                        
                                        $actionMsg = ""

                                        # CONDITION 1: SWAP REQUIRED
                                        if (($nameL -match $script:RegexSign) -and ($nameS -match $script:RegexDiag)) {
                                            $needsChange = $true
                                            # SAFETY: Using Add-Member to inject the Handled flag into the JSON object
                                            $largeTrack.properties | Add-Member -NotePropertyName "DSA_Handled" -NotePropertyValue $true -Force
                                            $smallTrack.properties | Add-Member -NotePropertyName "DSA_Handled" -NotePropertyValue $true -Force
                                            if ($Fix) {
                                                $Params += @('--edit', "track:$($largeTrack.id + 1)", '--set', "name=$nameS")
                                                $Params += @('--edit', "track:$($smallTrack.id + 1)", '--set', "name=$nameL")
                                            }
                                            $actionMsg = "[DSA] SWAP: Swapping '$nameS' to Large and '$nameL' to Small"
                                        }
                                        # CONDITION 2: MISLABELED / GARBAGE / MISSING
                                        elseif (-not $hasDiagL -or -not $hasSignS) {
                                            $needsChange = $true
                                            # SAFETY: Using Add-Member to inject the Handled flag into the JSON object
                                            $largeTrack.properties | Add-Member -NotePropertyName "DSA_Handled" -NotePropertyValue $true -Force
                                            $smallTrack.properties | Add-Member -NotePropertyName "DSA_Handled" -NotePropertyValue $true -Force
                                            
                                            # SMART RENAMING:
                                            # If a name already has the correct keyword (like 'Full Subs [Ember]'), keep it.
                                            # If it lacks the keyword (garbage or wrong), use a clean default.
                                            $newNameL = if ($hasDiagL) { $nameL } else { "Full Dialogue" }
                                            $newNameS = if ($hasSignS) { $nameS } else { "Signs & Songs" }
                                            
                                            # SAFETY: Ensure we don't accidentally set both tracks to the same string
                                            if ($newNameL -eq $newNameS) { $newNameL = "Full Dialogue"; $newNameS = "Signs & Songs" }

                                            if ($Fix) {
                                                $Params += @('--edit', "track:$($largeTrack.id + 1)", '--set', "name=$newNameL")
                                                $Params += @('--edit', "track:$($smallTrack.id + 1)", '--set', "name=$newNameS")
                                            }
                                            $actionMsg = "[DSA] FIX: Corrected Garbage/Missing names (Large: '$newNameL', Small: '$newNameS')"
                                        }
                                        # CONDITION 3: ALREADY CORRECT
                                        else {
                                            $actionMsg = "[DSA] VERIFIED: Track names contain correct role keywords (Ratio: $($ratio.ToString('F2')))"
                                        }

                                        if ($t.id -eq $ambiguousTracks[0].id) {
                                            if ($DevDebug) { Write-Host "  $actionMsg" -ForegroundColor Green }
                                            [void]$fixDetails.Add("  $actionMsg")
                                        }
                                    } elseif ($ratio -ge $dynRatio -and -not $isDualEng) {
                                        if ($DevDebug -and $t.id -eq $ambiguousTracks[0].id) { Write-Host "  [DSA] Sizing valid ($($ratio.ToString('F2'))), but tracks are not Dual-English. Skipping Naming." -ForegroundColor Yellow }
                                    }
                                }
                            }
                        }
                        # --- END DSA ENGINE --- 
                        
                        $trackLang = $t.properties.language.ToLower()
                        
                        # 1. ALWAYS capture current default status so we can strip it later if needed
                        $isCurrentlyDefault = ($t.properties.default_track -eq $true)
                        $subRelativeIndex++
                        $scoring = Get-TrackScore -t $t -fixerConfig $fixerConfig `
                                                 -subRelativeIndex $subRelativeIndex `
                                                 -Honorifics $Honorifics `
                                                 -SubtitleFactorTrackOrder $SubtitleFactorTrackOrder `
                                                 -Western $Western `
                                                 -SubtitlesHearingImpaired $SubtitlesHearingImpaired

                        # 4. ADD TO LIST (No filter here - we need to see the "bad" tracks to fix them)
                        $subCandidates += [PSCustomObject]@{
                            ID         = $t.id
                            Sel        = $sel
                            Score      = $scoring.Score
                            Lang       = $trackLang
                            Name       = $t.properties.track_name
                            WasDefault = $isCurrentlyDefault
                            Rules      = $scoring.Rules
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
                        
                    }
                } # <--- END TRACK LOOP
                
                # --- DEBUG: SCORING VISIBILITY ---
                if ($DevDebug -and $subCandidates.Count -gt 0) {
                    Write-Host "  [DEBUG] Subtitle Scoring Candidates:" -ForegroundColor Cyan
                    [void]$fixDetails.Add("  [DEBUG] Subtitle Scoring Breakdown:")
                    foreach ($cand in ($subCandidates | Sort-Object Score -Descending)) {
                        # [CHANGE] v2026.05.29__15.58.42 - Include Sel in scoring debug telemetry
                        $msg = "    -> ID:$($cand.ID) | Sel:$($cand.Sel) | Score: $($cand.Score) | Lang: $($cand.Lang) | Rules: [$($cand.Rules)] | Name: $($cand.Name)"
                        Write-Host $msg -ForegroundColor Cyan
                        [void]$fixDetails.Add($msg)
                    }
                }
                
                # --- CHOOSE BEST SUBTITLE & RESET OTHER SUB FLAGS ---
                if ($subCandidates.Count -gt 0) {
                        # If Western mode is on AND you haven't specified a language preference in the JSON
                    if ($Western -and [string]::IsNullOrWhiteSpace($fixerConfig.Subtitles.PreferredLanguage)) {
                        $sdhRequested = ($SubtitlesHearingImpaired)
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
                                    # Strip default and forced flags from non-winners (Preserving HI Flag)
                                    if ($lostTrack.properties.default_track -or $lostTrack.properties.forced_track) {
                                        $loseID = $sub.ID + 1
                                        $Params += @('--edit', "track:$loseID", '--set', "flag-default=0", '--set', "flag-forced=0")
                                        $needsChange = $true
                                        [void]$fixDetails.Add("  ACTION: STRIP_FLAGS | TRACK: $loseID | REASON: Western SDH Conflict")
                                    }
                                }
                            }
                        } else {
                            # Default Western behavior: Strip all subtitle flags
                            foreach ($sub in $subCandidates) {
                                $thisTrack = $currentGroup.Json.tracks | Where-Object { $_.id -eq $sub.ID }
                                # Strip default and forced flags (Preserving HI Flag)
                                if ($thisTrack.properties.default_track -or $thisTrack.properties.forced_track) {
                                    $loseID = $sub.ID + 1
                                    $Params += @('--edit', "track:$loseID", '--set', "flag-default=0", '--set', "flag-forced=0")
                                    $needsChange = $true
                                    [void]$fixDetails.Add("  ACTION: STRIP_FLAGS | TRACK: $loseID | REASON: Western Mode (Clean)")
                                }
                            }
                        }
                    } else {
                        # ANIME MODE: Existing Scoring Logic
                    $winner = $subCandidates | Sort-Object Score -Descending | Select-Object -First 1
                    $targetSubLang = if ($fixerConfig.Subtitles.PreferredLanguage) { $fixerConfig.Subtitles.PreferredLanguage } 
                                     elseif ($Western) { "eng" } 
                                     else { "eng" }
                    # $targetSubLang = "eng" 
                    $subReason = if ($Honorifics -and ($winner.Score -ge 100)) { "Preferred Honorifics ($($winner.Lang))" } else { "Primary ENG Sub" }
                    
                    $currentWinnerData = $currentGroup.Json.tracks | Where-Object { $_.id -eq $winner.ID }
                    
                    # 1. Validation Logic
                    # Determine the "Correct" target language for this specific winner
                    # If it's an honorifics track, we standardize to 'enm'. Otherwise, use the user preference.
                    $honRegex = "(?<!no\s|non-|without\s|removed\s)(honorifics|honors)"
                    $isWinnerHon = ($winner.Name -match $honRegex) -or ($winner.Lang -eq "enm")
                    $correctLangForWinner = if ($Honorifics -and $isWinnerHon) { "enm" } elseif ($winner.Lang -eq "enm") { "enm" } else { $targetSubLang }
                    
                    # PROTECTION: Change label if current doesn't match Correct AND it's a "promotable" source (und/enm/name-match)
                    $langNeedsFix = ($currentWinnerData.properties.language -ne $correctLangForWinner) -and 
                                    (($currentWinnerData.properties.language -eq "und") -or $isWinnerHon)
                    
                    # PREFERRED OR NOTHING: Only set default if Lang matches target OR is an honorifics variant
                    $isWinnerValidForDefault = ($winner.Lang -eq $targetSubLang) -or ($winner.Lang -eq "und") -or $isWinnerHon

                    $targetDefaultValue = if ($isWinnerValidForDefault) { 1 } else { 0 }
                    
                    # 1. Check if the Winner needs updating (Lang, Default, or unwanted Forced/HICC)
                    $winnerNeedsFix = ($langNeedsFix) -or 
                                      ($currentWinnerData.properties.default_track -ne $targetDefaultValue) -or
                                      ($currentWinnerData.properties.language -ne $targetSubLang) -or
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
                    if (($winnerNeedsFix -or $losersNeedStrip) -and -not $currentWinnerData.properties.DSA_Handled) {
                        $needsChange = $true
                        $winID = $winner.ID + 1
                        
                        # LOGIC: Only apply language update if DSA hasn't handled it
                        $langNeedsFix = ($currentWinnerData.properties.language -ne $correctLangForWinner) -and -not $currentWinnerData.properties.DSA_Handled
                        
                    # Add Winner Fix
                    $Params += @('--edit', "track:$winID", '--set', "flag-default=$targetDefaultValue", '--set', "flag-forced=0")
                    $logActions = "SET_DEFAULT=$targetDefaultValue"
                    
                    if ($langNeedsFix) {
                            $Params += @('--set', "language=$correctLangForWinner")
                            $logActions += " | SET_LANG=$correctLangForWinner"
                        }
                        
                    if (-not $isWinnerValidForDefault) { $subReason = "Preferred Lang Not Found (Setting All Defaults to 0)" }
                        [void]$fixDetails.Add("  ACTION: $logActions | TRACK: $winID | REASON: $subReason")
                    
                    

                    # Add Loser Strips (Preserving Name and HI Flag)
                        foreach ($sub in $subCandidates) {
                            if ($sub.ID -ne $winner.ID) {
                                $lostTrack = $currentGroup.Json.tracks | Where-Object { $_.id -eq $sub.ID }
                                $loseID = $sub.ID + 1
                                
                                # Strip default and forced flags only
                                $Params += @('--edit', "track:$loseID", '--set', "flag-default=0", '--set', "flag-forced=0")
                            
                            }
                        } # Closes foreach
                    } # Closes Mechanical Trigger
                } # Closes ELSE (Anime Mode)
            } # Closes Subtitle Logic Block (if $subCandidates.Count -gt 0) # Closes Subtitle Logic Block


                # 3. EXECUTION
                if ($IsFixRun -and $needsChange) {
                    if ($FixNoBackup) { $targetFile = $fToFix.FullName } 
                    else {
                        # Dynamically find which input path contains this file
                        $anchorRoot = $inputPaths | Where-Object { $fToFix.FullName.StartsWith($_) } | Sort-Object Length -Descending | Select-Object -First 1
                        
                        # Fallback to first path if logic fails (safety)
                        if (-not $anchorRoot) { $anchorRoot = $inputPaths[0] }
                        
                        Invoke-MkvBackup -FilePath $fToFix.FullName -RootPath $anchorRoot
                        
                        $parentDir = Split-Path $anchorRoot -Parent
                        $rootName = Split-Path $anchorRoot -Leaf
                        $backupRootPath = Join-Path $parentDir "$($rootName)_updated"
                        
                        $relativeDir = ""
                        $fParent = Split-Path $fToFix.FullName -Parent
                        if ($fParent.Length -gt $anchorRoot.Length) {
                            $relativeDir = $fParent.Substring($anchorRoot.Length).TrimStart('\')
                        }
                        
                        $targetFile = Join-Path $backupRootPath $relativeDir (Split-Path $fToFix.FullName -Leaf)
                    }

                    if ($targetFile -and (Test-Path -LiteralPath $targetFile)) {
                        if ($DevDebug) {
                            $fullCmd = "mkvpropedit `"$targetFile`" $($Params -join ' ')"
                            Write-Host "  [DEBUG] $fullCmd" -ForegroundColor DarkYellow
                            [void]$fixDetails.Add("  DEBUG_CMD: $fullCmd")
                        }
                        & $mkvpropedit "$targetFile" @Params | Out-Null
                        $script:FilesModifiedInJob++
                        [void]$fixDetails.Add("  STATUS: Changes applied to -> $targetFile")
                    }
                }
                [void]$fixDetails.Add(""); $fixDetails | Out-File $fixerLog -Append -Encoding utf8
            } # <--- END FILES LOOP
        } # <--- END GROUPS LOOP
    } # <--- v2026.05.13_11.23.00 - END OF THE "ELSE" AUDITOR BYPASS

    
    
    # --- STANDARD AUDITOR LOGGING ---
    # This only runs if $AvcHigh10Search is FALSE because of the 'continue' above
    $spacer = "`r`n.• ♬ ͜͝ ̣̣♡.• ♬ ͜͝ ̣̣♡.• ♬ ͜͝ ̣̣♡..• ♬ ͜͝ ̣̣♡.• ♬ ͜͝ ̣̣♡.• ♬ ͜͝ ̣̣♡..• ♬ ͜͝ ̣̣♡.• ♬ ͜͝ ̣̣♡.• ♬ ͜͝ ̣̣♡.`r`n"
    $spacer | Out-File $detailLog -Append -Encoding utf8
    
    $compEntry = New-Object System.Collections.Generic.List[string]
    $compEntry.Add("Folder: $($folderPath.FullName)")
    $compEntry.Add($matchStatus)
    $compEntry.Add("Total: $($mkvFiles.Count) | Matches Primary: $($primaryGroup.Files.Count) | Mismatches: $mismatches`r`n")
    $compEntry | Out-File $compLog -Append -Encoding utf8
    
} # <--- END FOLDER LOOP

if ($CurrentJob.Mode -eq "Standard" -and -not $AvcHigh10Search) {
    Write-Host "`n [✓] Standard Audit Complete." -ForegroundColor Green
    if ($Fix) {
        if ($script:FilesModifiedInJob -gt 0) {
            Write-Host " [✓] Fixer Operations Complete. Files Modified: $script:FilesModifiedInJob" -ForegroundColor Green
        } else {
            Write-Host " [i] Fixer Operations Complete. All files passed audit (No changes required)." -ForegroundColor Cyan
        }
    }
}

# --- DYNAMIC JOB DISCOVERY ---
    # After the 'Standard' pass ends, if Verify is enabled, look for the folders we just created
    if ($CurrentJob.Mode -eq "Standard" -and $VerifyUpdates -and -not $AvcHigh10Search) {
        $verifyPaths = New-Object System.Collections.Generic.List[string]
        
        if ($Fix -and -not $FixNoBackup) {
            foreach ($p in $CurrentJob.TargetPaths) {
                $targetUpdatePath = $p.TrimEnd('\') + "_updated"
                if (Test-Path -LiteralPath $targetUpdatePath) { [void]$verifyPaths.Add($targetUpdatePath) }
            }
        } else {
            # If NoBackup or Audit-only, the verify paths are just the original input paths
            $verifyPaths = $CurrentJob.TargetPaths
        }

        if ($verifyPaths.Count -gt 0) {
            $AuditJobs.Add([PSCustomObject]@{ TargetPaths = $verifyPaths; ActiveLog = $verifyLog; Mode = "Verification" })
        }
    }

if ($CurrentJob.Mode -eq "Verification") {
        Write-Host "`n [✓] Verification pass complete." -ForegroundColor Green
        Write-Host " Log:    $detailLog" -ForegroundColor DarkGray
        Write-Host "==================================================" -ForegroundColor Cyan
    }

} # <--- END JOB LOOP (Closing the 'for' loop)

# v2026.05.13_16.32.00 - Final Flush after loop ends
if ($logBuffer.Count -gt 0) {
    $logBuffer | Out-File -FilePath $h10pLog -Append -Encoding utf8
    $logBuffer.Clear()
}






# --- FINAL GLOBAL SUMMARY ---
if ($h10pCount -gt 0) {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor DarkYellow
    Write-Host " AVC HIGH 10 PROFILE SUMMARY" -ForegroundColor DarkYellow
    Write-Host " Total Files Found: $h10pCount" -ForegroundColor Gray
    Write-Host " Log: $h10pLog" -ForegroundColor Gray
    Write-Host "==================================================" -ForegroundColor DarkYellow
}

Write-Host "Complete." -ForegroundColor DarkCyan

# --- GLOBAL SESSION CLEANUP ---
if (Test-Path $script:GlobalTemp) {
    if ($DevDebug) {
        Write-Host " [DEBUG] Temp files preserved at: $script:GlobalTemp" -ForegroundColor DarkGray
    } else {
        # Standard Mode: Wipe the entire root temp folder on exit
        Remove-Item -LiteralPath $script:GlobalTemp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Pause