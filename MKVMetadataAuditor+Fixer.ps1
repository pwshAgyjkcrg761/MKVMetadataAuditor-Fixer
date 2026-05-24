# ==============================================================================
# SCRIPT: MKVMetadataAuditor+Fixer.ps1
# VERSION: 2026.05.24__15.48.45
# TARGET: PowerShell 7.6.1 LTS
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
    [switch]$FixDebug,
    [switch]$FixNoBackup,    # Disables the automatic 1-by-1 backup
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
    
    [alias("h10pDebug")]
    [switch]$AvcHigh10SearchDebug,
    
    [alias("SFTO", "SubTrackOrder", "TrackOrder")]
    [switch]$SubtitleFactorTrackOrder,
    
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
$scriptVersion = "2026.05.24__15.48.45"

# --- VERSION REPORTER ---
if ($Version) {
    Write-Host "MKVMetadataAuditor+Fixer.ps1 v$scriptVersion" -ForegroundColor Cyan
    exit
}

# --- NATURAL SORT ENGINE (WINDOWS API) ---
$NaturalSortDefinition = @'
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;

public class NaturalSort {
    [DllImport("shlwapi.dll", CharSet = CharSet.Unicode)]
    public static extern int StrCmpLogicalW(string psz1, string psz2);
}
'@
if (-not ([System.Management.Automation.PSTypeName]"NaturalSort").Type) {
    Add-Type -TypeDefinition $NaturalSortDefinition
}

function Sort-Natural {
    param([Parameter(ValueFromPipeline=$true)]$InputObject)
    begin { $all = [System.Collections.Generic.List[PSObject]]::new() }
    process { if ($null -ne $_) { $all.Add($_) } }
    end {
        if ($all.Count -gt 1) {
            $all.Sort({ param($a,$b) [NaturalSort]::StrCmpLogicalW($a.FullName, $b.FullName) })
        }
        return $all
    }
}

function Sort-NaturalFiles {
    param([Parameter(ValueFromPipeline=$true)]$InputObject)
    begin { $all = [System.Collections.Generic.List[PSObject]]::new() }
    process { if ($null -ne $_) { $all.Add($_) } }
    end {
        if ($all.Count -gt 1) {
            $all.Sort({ param($a,$b) [NaturalSort]::StrCmpLogicalW($a.Name, $b.Name) })
        }
        return $all
    }
}

# --- HELP & MANUAL REFACTORED COLOR REGULATOR BLOCK ---
# $True means DarkCyan, $False means DarkMagenta
$global:altColorToggle = $true  

$PrintManualBlock = {
    param(
        [string]$FlagLine,
        [string[]]$DescLines,
        [string]$ForceDescColor = $null
    )
    
    # 1. Print the Flag in DarkGreen
    Write-Host $FlagLine -ForegroundColor DarkGreen
    
    # 2. Determine description color (Use forced color if passed, otherwise alternate)
    $currentColor = if ($ForceDescColor) { 
        $ForceDescColor 
    } else { 
        if ($global:altColorToggle) { "DarkCyan" } else { "DarkMagenta" } 
    }
    
    # 3. Print the description lines
    foreach ($line in $DescLines) {
        Write-Host $line -ForegroundColor $currentColor
    }
    
    # 4. Flip the alternating color toggle if we used a standard alternating color
    if (-not $ForceDescColor) {
        $global:altColorToggle = -not $global:altColorToggle
    }
}

# --- HELP & MANUAL SYSTEM ---
if ($Help -or $Manual) {
    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
               " MKVMetadataAuditor+Fixer.ps1 v$scriptVersion  ",
               " MANUAL & USAGE GUIDE" | ForEach-Object { Write-Host $_ -ForegroundColor DarkMagenta }
    Write-Host " Copyright (C) 2026 pwsh.Agyjkcrg761`n" -ForegroundColor DarkCyan
    
     " This program is free software: you can redistribute it and/or",
     " modify it under the terms of the GNU General Public License as",
     " published by the Free Software Foundation, either version 3 of",
     " the License, or (at your option) any later version."  | ForEach-Object { Write-Host $_ -ForegroundColor DarkMagenta }
    Write-Host "============================================================" -ForegroundColor Cyan
    
    Write-Host "`n OVERVIEW:" -ForegroundColor DarkYellow
     "  This utility is a high-fidelity media management tool designed to ensure",
     "  structural consistency across MKV libraries. It operates in two stages:",
     "  1. AUDIT: Scans files to identify 'Mismatch Groups' and track errors.",
     "  2. FIX:  Uses Mkvpropedit to align tracks with your preferred defaults.",
     "  3. SEARCH: Locates specific video profiles like AVC High 10 (10-bit).`n",

    "`n  This script intelligently handles track scoring, automatically penalizing",
    "  'Signs & Songs' tracks while prioritizing full dialogue and honorifics.",
    
    "  The AVC High 10 Search (-h10p) bypasses standard auditing to quickly",
    "  isolate legacy 10-bit encodes that may cause hardware compatibility",
    "  issues, supporting both deep-dive and fast-scan logic.`n"   | ForEach-Object { Write-Host $_ -ForegroundColor DarkCyan }
    
    Write-Host " DEPENDENCIES:" -ForegroundColor DarkYellow
    "  • MKVToolNix (mkvmerge): Used for deep-probing file headers and", 
    "    extracting detailed track metadata for the audit.", 
    "  • MKVToolNix (mkvpropedit): The primary tool for the 'Fix' engine,", 
    "    allowing instant metadata edits without remuxing the file.", 
    "  • MediaInfo: Utilized specifically during AVC High 10 searches", 
    "    to verify video profiles and bit-depth accuracy.`n" | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }
    
    Write-Host "`n USAGE:" -ForegroundColor DarkYellow
    Write-Host "  .\MKVMetadataAuditor+Fixer.ps1 [Flags] -Path 'G:\Media'" -ForegroundColor DarkGreen
    
    Write-Host "`n USAGE EXAMPLES:`n" -ForegroundColor DarkYellow
    
    Write-Host "  Standard Audit (No Changes):`n" -ForegroundColor DarkGray
    Write-Host "    .\MKVMetadataAuditor+Fixer.ps1 -Path 'G:\Media\Anime'`n" -ForegroundColor DarkMagenta
    
    Write-Host "  Automated Fix (JPN Audio / ENG Subs / Honorifics):`n" -ForegroundColor DarkGray
    Write-Host "    .\MKVMetadataAuditor+Fixer.ps1 -Fix -aud jpn -sub eng -Hon -ovrd -Path 'G:\Media\Anime'`n" -ForegroundColor DarkCyan
    
    Write-Host "  Update Video Language (Chinese) & Save to Config:`n" -ForegroundColor DarkGray
    Write-Host "    .\MKVMetadataAuditor+Fixer.ps1 -Fix -vid chi -vidf -ovrd -Path 'G:\Media\Anime'`n" -ForegroundColor DarkMagenta

    Write-Host "  Direct Fix (No Backup) with Codec Priority:`n" -ForegroundColor DarkGray
    Write-Host "    .\MKVMetadataAuditor+Fixer.ps1 -Fix -FixNoBackup -sc 'ass,srt' -ovrd -Path 'G:\Media\Anime'`n" -ForegroundColor DarkCyan
    
    Write-Host "  AVC High 10 Deep Scan Library Sweep (Fast Mode):`n" -ForegroundColor DarkGray
    Write-Host "    .\MKVMetadataAuditor+Fixer.ps1 -h10p -fast -Path 'G:\Media\Anime'`n" -ForegroundColor DarkMagenta
    
    Write-Host "`n CORE FLAGS:`n" -ForegroundColor DarkYellow

    &$PrintManualBlock "  -Path <string>" @(
    "      Defines the target directory. The script will recursively scan all",
    "      subfolders for MKV files to perform bulk auditing.`n"
)

    &$PrintManualBlock "  -Fix" @(
    "      Enables 'Write Mode'. Without this, the script runs in read-only",
    "      audit mode, generating logs without modifying any files.`n"
)    
                    
    &$PrintManualBlock "  -FixDebug" @(
    "      Prints the exact Mkvpropedit command strings to the console before",
    "      execution and displays subtitle scoring logic—ideal for verifying complex changes.`n"
)    
    
    &$PrintManualBlock "  -FixNoBackup" @(
    "      Disables the '_updated' sibling folder creation. Use with caution,",
    "      as this overwrites metadata directly on the source files.`n"
) -ForceDescColor "DarkRed"
    
    &$PrintManualBlock "  -overrideDefaults | -ovrd" @(
    "      Mandatory when using automation flags. It allows the script to",
    "      write your current session parameters into the JSON config file.`n"
)
    
    Write-Host "`n MODE FLAGS:`n" -ForegroundColor DarkYellow

    &$PrintManualBlock "  -Western | -w | -west | -WesternMode" @(
    "      Sets defaults for Western media (English audio/subs).`n"
)

    &$PrintManualBlock "  -AvcHigh10Search | -h10p" @(
    "      Search Mode: Scans for AVC High 10 (10-bit) video streams. Use",
    "      with -fast for quicker scanning.`n"
)    

    &$PrintManualBlock "  -AvcHigh10SearchDebug | -h10pDebug" @(
    "      Enables verbose terminal output during the Search Mode scan,", 
    "      displaying every file path being processed in real-time.`n"
)
    
    &$PrintManualBlock "  -fast" @(
    "      Speeds up the AVC High 10 Search by skipping extended metadata",
    "      checks. In this mode, progress tracks Folders processed.`n"
)
    
    &$PrintManualBlock "  -LogFullPath | -lfp" @(
    "      Forces the log to write the full file path instead of just the folder",
    "      path during a fast AVC High 10 search. Requires -fast.`n"
)

    &$PrintManualBlock "  -disableRecurse | -nr" @(
    "      Disables subfolder scanning. Only the root of the provided -Path", 
    "      will be processed.`n"
)
    
    Write-Host "`n TRACK PRIORITIES & AUTOMATION:`n" -ForegroundColor DarkYellow
    
    &$PrintManualBlock "  -videoLanguage | -vid <string>" @(
    "      Targets the video track language. Note: This is applied",
    "      automatically if the file requires other fixes. -vidf is",
    "      only required if the file is already 'perfect'.`n"
)

    &$PrintManualBlock "  -videoForceUpdate | -vidf" @(
    "      The safety toggle for video metadata. This must be present",
    "      to confirm you want to change the video track language on",
    "      files that otherwise pass the audit.`n"
)
    
    &$PrintManualBlock "  -audioLanguageUpdate | -audf" @(
    "      The safety toggle for audio metadata. This must be present",
    "      to confirm you want to change the audio track language on",
    "      files that otherwise pass the audit.`n"
)
    
    &$PrintManualBlock "  -audioLanguagePriority | -aud <string>" @(
    "      Sets the 3-letter ISO code (e.g., 'jpn') for your primary audio.",
    "      It will automatically set this track as the 'Default' choice.`n"
)
    
    &$PrintManualBlock "  -subtitleLanguagePriority | -sub <string>" @(
    "      Sets the primary subtitle language. The script uses weighted",
    "      scoring to find the best dialogue track in this language.`n"
)
    
    &$PrintManualBlock "  -subtitleCodecPriority | -sc <string>" @(
    "      A comma-separated list (e.g., 'ass,srt') that dictates which",
    "      subtitle formats to prefer when multiple tracks are available.`n"
)
    
    &$PrintManualBlock "  -Honorifics | -Hon" @(
    "      Injects a +300 score bonus to tracks labeled with 'honorifics'",
    "      or 'enm', ensuring they are selected over standard dialogue.`n"
)

    &$PrintManualBlock "  -SubtitleFactorTrackOrder | -SFTO | -SubTrackOrder | -TrackOrder" @(
    "      Instructs the weighted scoring algorithm to factor in the physical",
    "      track placement when determining priorities for subtitle selection.`n"
)
    
    &$PrintManualBlock "  -FansubGroupPriority | -fg <string>" @(
    "      Sets preferred fansub groups for subtitle track prioritization",
    "      (e.g., -fg 'commie'). Pass an empty string (`"`") to clear the",
    "      list and reset preferences via command line.`n"
)
    
    Write-Host "`n WESTERN SPECIFIC:`n" -ForegroundColor DarkYellow

    &$PrintManualBlock "  -SubtitlesHearingImpaired | -sdh | -hi | -hicc | -cc" @(
    "      Forces the script to prioritize 'Hearing Impaired' or 'SDH'",
    "      subtitle tracks for Western media.`n"
)
    
    &$PrintManualBlock "  -OverrideWesternDefaults | -ovrdw" @(
    "      Allows the script to save custom Western mode parameters to",
    "      the JSON configuration.`n"
)

    Write-Host "`n ADVANCED & LOG MANAGEMENT FLAGS:`n" -ForegroundColor DarkYellow

    &$PrintManualBlock "  -VerifyUpdates | -V | -Verify" @(
    "      Chains an automated second-pass verification audit immediately after",
    "      fixing, confirming header adjustments match intent perfectly. Requires -Fix.`n"
)
    
    &$PrintManualBlock "  -help | -manual" @(
    "      Displays this manual for MKVMetadataAuditor+Fixer.ps1. The one you are",
    "      reading right now.`n"
)
    
    &$PrintManualBlock "  -DelLog" @(
    "      Clears all files within the logs directory (MKVMetadataAuditor+Fixer_logs) before",
    "      starting the operation.`n"
) -ForceDescColor "DarkRed"
    
    &$PrintManualBlock "  -ClearDefaults | -clr" @(
    "      Deletes the saved Anime configuration JSON template to reset rules back",
    "      to factory script conditions.`n"
)

    &$PrintManualBlock "  -ClearWesternDefaults | -clrw" @(
    "      Deletes the custom Western configuration file to purge specialized rules.`n"
)

    &$PrintManualBlock "  -ClearAllDefaults | -cla" @(
    "      Total system purge of both Anime and Western configuration JSON structures.`n"
)
    
    &$PrintManualBlock "  -excludePaths | -ep" @(
    "      Enables the exclusion engine. When active, the script will skip folders",
    "      listed in 'MKVMetadataAuditor+Fixer__Excluded-Paths.txt'.`n"
)
    
    &$PrintManualBlock "  -Version | -Ver" @(
    "      Displays the script's current version number and exits immediately.`n"
)    

    Write-Host "`n NOTES:" -ForegroundColor DarkYellow
    "  * SCORING: Automatically penalizes 'Signs/Songs' tracks.",
    "  * CONFIG: -ovrd is REQUIRED when using automation flags to save to JSON.",
    "  * LOGS: Detailed reports are saved to: MKVMetadataAuditor+Fixer_logs\Detail_Logs"  | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }
    
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host " Press any key to exit..." -ForegroundColor DarkYellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
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
if (($FixNoBackup -or $FixDebug) -and -not $Fix) {
    Write-Host "`n[ERROR] Modifier flag detected without -Fix." -ForegroundColor DarkRed
    Write-Host "The -FixNoBackup and -FixDebug flags require the -Fix switch to be active.`n" -ForegroundColor DarkYellow
    exit
}

# --- SEARCH FLAG RESTRICTION ---
$searchOnlyFlags = @()
if ($PSBoundParameters.ContainsKey('fast')) { $searchOnlyFlags += "-fast" }
if ($PSBoundParameters.ContainsKey('AvcHigh10SearchDebug')) { $searchOnlyFlags += "-h10pDebug" }
if ($PSBoundParameters.ContainsKey('LogFullPath')) { $searchOnlyFlags += "-lfp" }

if ($searchOnlyFlags.Count -gt 0 -and -not $AvcHigh10Search) {
    Write-Host "`n[ERROR] Search-specific flag(s) detected: $($searchOnlyFlags -join ', ')" -ForegroundColor DarkRed
    Write-Host "The flags -fast, -h10pDebug, and -lfp require -h10p (AvcHigh10Search) to be active.`n" -ForegroundColor DarkYellow
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
    $allowedH10pFlags = @('AvcHigh10Search', 'AvcHigh10SearchDebug', 'Fast', 'disableRecurse', 'Path', 'h10p', 'h10pDebug', 'PathParts', 'ep', 'excludePaths', 'LogFullPath', 'lfp')

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

# --- TOOL PATH DISCOVERY ---
$mkvpropedit = Get-Command mkvpropedit.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
$mkvmerge    = Get-Command mkvmerge.exe    -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
$mediainfo   = Get-Command MediaInfo.exe   -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source




# Fallback: If not in PATH, check your specific default location
if (-not $mkvpropedit) { $mkvpropedit = "C:\Program Files\MKVToolNix\mkvpropedit.exe" }
if (-not $mkvmerge)    { $mkvmerge    = "C:\Program Files\MKVToolNix\mkvmerge.exe" }
if (-not $mediainfo)   { $mediainfo   = "C:\Program Files\MediaInfo\MediaInfo.exe" }

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

if ($PSVersionTable.PSVersion -lt [version]"7.6.1") {
    Write-Host "ERROR: Running on version $($PSVersionTable.PSVersion). This script requires at least 7.6.1." -ForegroundColor DarkRed
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

$h10pList = New-Object System.Collections.Generic.List[string]
$h10pCount = 0

# Load Exclusions
# [CHANGE] v2026.05.14_18.45.00 - Integration of Excluded Paths (Silent Load)
$excludeFile = Join-Path $PSScriptRoot "MKVMetadataAuditor+Fixer__Excluded-Paths.txt"

if (-not (Test-Path $excludeFile)) {
    @("# FILE: MKVMetadataAuditor+Fixer__Excluded-Paths.txt",
      "# SCRIPT: MKVMetadataAuditor+Fixer.ps1",
      "# DESCRIPTION: Add full folder paths here to skip them during audit.",
      "# FORMAT: One path per line. No wildcards. No trailing slashes.",
      "# ",
      "# Example below this line. Remove the # to enable the line.",
      "#B:\Media\Movies\Sample_Folder",
      "") | Out-File $excludeFile -Encoding utf8
}

$exclusions = @()
if ($excludePaths) {
    if (Test-Path $excludeFile) { 
        $exclusions = Get-Content $excludeFile | ForEach-Object { $_.Trim() } | Where-Object { 
            -not [string]::IsNullOrWhiteSpace($_) -and -not $_.StartsWith("#") 
        } | ForEach-Object { $_.TrimEnd('\') }
    }
}

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
Clear-Host
$uiversion = $scriptVersion

# Determine Display Mode, Action, and Override Status
if ($AvcHigh10Search -or $h10p) {
    $fastStatus = if ($fast) { " Fast" } else { "" }
    $recurseStatus = if ($disableRecurse) { " [No-Recurse]" } else { "" }
    $h10pDebugStatus = if ($AvcHigh10SearchDebug) { " Debug" } else { "" }
    $h10pLogFullPathStatus = if ($LogFullPath) { " Log Full Path" } else { "" }
    $displayMode = "AVC High 10 Search Mode$fastStatus$h10pDebugStatus$recurseStatus$h10pLogFullPathStatus"
} else {
    $modeBase = if ($Western) { "Western Mode" } else { "Anime Mode (default)" }
    $sdhStatus = if ($SubtitlesHearingImpaired) { " SDH" } else { "" }
    $action = if ($Fix) { "Audit & Fix" } else { "Audit" }
    $recurseStatus = if ($disableRecurse) { " [No-Recurse]" } else { "" }
    $nobackupStatus = if ($FixNoBackup) { " NO BACKUP!" } else { "" }
    $FixdebugStatus = if ($FixDebug) { " Debug" } else { "" }
    $ovrdStatus = if ($overrideDefaults -or $OverrideWesternDefaults) { " override defaults" } else { "" }
    $verifyStatus = if ($VerifyUpdates) { " + Verification" } else { "" }
    $displayMode = "$modeBase $action$nobackupStatus$FixdebugStatus$ovrdStatus$sdhStatus$recurseStatus$verifyStatus"
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


$global:trackCounters = @{ "video" = 1; "audio" = 1; "subtitles" = 1 }
function Get-Selector {
    param($type, [switch]$Reset)
    if ($Reset) { $global:trackCounters = @{ "video" = 1; "audio" = 1; "subtitles" = 1 }; return "" }
    $val = $global:trackCounters[$type]
    $letter = switch ($type) { "video" { "v" } "audio" { "a" } "subtitles" { "s" } }
    $global:trackCounters[$type]++
    return "$letter$val"
}


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
    $parentPath = Split-Path $FilePath -Parent
    if ($FilePath.StartsWith($RootPath) -and $parentPath.Length -gt $RootPath.Length) {
        $relativeDir = $parentPath.Substring($RootPath.Length).TrimStart('\')
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
    
    $videoTracks = $tracks | Where-Object { $_.type -eq "video" }
    if (($videoTracks | Measure-Object).Count -gt 1) { $reasons += "🎞️[Multiple Video Tracks] " }
    
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
        if ($SubtitlesHearingImpaired) {
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
            if ($dSubs | Where-Object { $_.properties.track_name -match "Sign|Song|Lyric|Forced" -and $_.properties.track_name -notmatch "Dialogue" }) { $reasons += "🎵[Sub: Signs/Songs Default] " }
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
    $flags = New-Object System.Collections.Generic.List[string]
    if ($t.properties.default_track) { [void]$flags.Add("[DEFAULT]") }
    if ($t.properties.forced_track) { [void]$flags.Add("[FORCED]") }
    if ($t.properties.flag_hearing_impaired) { [void]$flags.Add("[HI/CC]") }
    return $flags
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
$targetFolders = if ($disableRecurse) {
    # Strictly only use the input paths provided, no sub-directory gathering
    $inputPaths | ForEach-Object { Get-Item -LiteralPath $_ }
} else {
    Get-ChildItem -LiteralPath $inputPaths -Directory -Recurse
}
if ($inputPaths.Count -gt 0) {
    $targetFolders = @($inputPaths | ForEach-Object { Get-Item -LiteralPath $_ }) + $targetFolders | Select-Object -Unique
}

# Final pass: Ensure all discovered folders are sorted using Natural Windows Logic
$targetFolders = $targetFolders | Sort-Natural

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
    # [CHANGE] v2026.05.14_18.25.00 - Exclusion Loop Bypass
    if ($excludePaths -and $exclusions.Count -gt 0) {
        $currentPathClean = $folderPath.FullName.TrimEnd('\')
        if ($exclusions -contains $currentPathClean) {
            Write-Host " [SKIP] Folder excluded by rule: $($folderPath.Name)" -ForegroundColor DarkGray
            continue
        }
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
            if ($AvcHigh10SearchDebug) { 
                Write-Host "`n [DEBUG] Scanning: $($f.Name)" -ForegroundColor Gray 
            }
            if (Test-Path -LiteralPath $mediainfo) {
                $profile = (& $mediainfo --Inform="Video;%Format_Profile%" "$($f.FullName)").ToString().Trim()
                if ($profile -match "High.*10") {
                    $h10pCount++
                    
                    # Logic: If Fast mode and no FullPath requested, log the Folder Path for the exclusion list.
                    $entryToAdd = if ($fast -and -not $LogFullPath) { $folderPath.FullName.TrimEnd('\') } else { $f.FullName }
                    $h10pList.Add($entryToAdd)
                    
                    Write-Host "`n"
                    
                    Write-Host "  [!] Found AVC High 10: $($f.Name)" -ForegroundColor DarkYellow
                }
            }
        }
        Write-Host "" # Clears the inline progress line
        
        # v2026.05.13_16.32.00 - Periodic 60-Second Flush
        if ($h10pList.Count -gt 0) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"

            if ($fast) {
                # Add content to buffer for Fast Mode
                if (-not $fastHeaderWritten) {
                    $logBuffer.Add("----------------------------------------------")
                    $logBuffer.Add($timestamp)
                    $logBuffer.Add("Fast Scan - First File in Each Folder Only")
                    $logBuffer.Add("AVC High 10 Profile Found")
                    $logBuffer.Add("Recommend convert to HEVC Main 10")
                    $logBuffer.Add("----------------------------------------------")
                    $logBuffer.Add("")
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
                    $pSig = "$($pTrack.id)|$($pTrack.type)|$($pTrack.codec)|$($pTrack.properties.language)|$($pTrack.properties.default_track)|$($pTrack.properties.track_name)"
                    $cSig = "$($t.id)|$($t.type)|$($t.codec)|$($t.properties.language)|$($t.properties.default_track)|$($t.properties.track_name)"
                    if ($pSig -ne $cSig) { $isDiff = $true }
                }
            }

            $idStr = if ($isDiff) { ">>>ID:$($t.id)<<<" } else { "   ID:$($t.id)" }
            $codec = "$($t.codec.PadRight($codecPadding))"
            $tName = if ($t.properties.track_name) { $t.properties.track_name } else { "" }

            $flags = @(Get-TrackProps $t) # Force to array to handle single-item returns
            $firstFlag = if ($flags.Count -gt 0) { [string]$flags[0] } else { "" }
            
            # Print primary track info row
            $entry.Add("$codec | $($idStr.PadRight(12)) | $($sel.PadRight(4)) | $($t.type.PadRight(9)) | $($t.properties.language) | $(($firstFlag).PadRight($propPadding)) | $($tName.PadRight($namePadding))")

            # Stack additional flags on subsequent lines if they exist
            if ($flags.Count -gt 1) {
                for ($i = 1; $i -lt $flags.Count; $i++) {
                    $entry.Add("$(" ".PadRight($codecPadding)) | $(" ".PadRight(12)) | $(" ".PadRight(4)) | $(" ".PadRight(9)) |     | $([string]($flags[$i]).PadRight($propPadding)) | $(" ".PadRight($namePadding))")
                }
            }
        }
        $entry.Add($line)
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
            
            # 2. Log path to file
            $f.FullName | Out-File $pathLog -Append -Encoding utf8
            
            # 3. Get JSON and build signature
            $json = & $mkvmerge -J $f.FullName | ConvertFrom-Json
            $sig = (($json.tracks | ForEach-Object { "$($_.id)|$($_.type)|$($_.codec)|$($_.properties.language)|$($_.properties.default_track)|$($_.properties.track_name)" }) -join "`n")
            
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
                Get-Selector -Reset
                $subRelativeIndex = 0
                
                # NEW: Define videoCount here so the check below works
                $videoCount = ($currentGroup.Json.tracks | Where-Object { $_.type -eq "video" } | Measure-Object).Count
                
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
                        $trackLang = $t.properties.language.ToLower()
                        
                        # 1. ALWAYS capture current default status so we can strip it later if needed
                        $isCurrentlyDefault = ($t.properties.default_track -eq $true)
                        
                        # 2. Determine if it's a priority track (Codec Match)
                        $isCodecMatch = $false
                        $codecScoreBonus = 0
                        $trackCodecId = if ($t.properties.codec_id) { $t.properties.codec_id } else { $t.codec }
                        for ($i = 0; $i -lt $fixerConfig.Subtitles.CodecPriority.Count; $i++) {
                            $c = $fixerConfig.Subtitles.CodecPriority[$i]
                            if ($trackCodecId -match $c -or $t.codec -match $c) {
                                $isCodecMatch = $true
                                # Scale score down from 100 based on index position (Index 0 gets 100, Index 5 gets 25)
                                $codecScoreBonus = [Math]::Max(0, 100 - ($i * 15))
                                break
                            }
                        }
                        
                        # 3. SCORING
                        $score = 0
                        $ruleLog = New-Object System.Collections.Generic.List[string]
                        $subRelativeIndex++

                        if ($SubtitleFactorTrackOrder) {
                            $posPenaltyWeight = 40  # CONFIGURABLE: Points deducted per track position
                            $posPenalty = ($subRelativeIndex - 1) * $posPenaltyWeight
                            if ($posPenalty -gt 0) {
                                $score -= $posPenalty
                                [void]$ruleLog.Add("TrackOrder(-$posPenalty)")
                            }
                        }
                        
                        if ($isCodecMatch) { 
                            $score += $codecScoreBonus 
                            [void]$ruleLog.Add("CodecMatch(+$codecScoreBonus)")
                        }
                        
                        # Priority for Dialogue / Penalty for Signs & Songs
                        if ($trackName -match "Dialogue|Full Sub|Full Dialogue|Japanese Audio") { 
                            $score += 150 
                            [void]$ruleLog.Add("Dialogue(+150)")
                        
                        } 
                        
                        if ($trackName -match "Sign|Song|Lyric|English Audio|Partial|Forced") { 
                            $score -= 200 # Heavy penalty
                            [void]$ruleLog.Add("SignsSongs(-200)")
                        
                        } 
                        
                        if ($Honorifics -and (($trackName -match "honorific|honor") -or ($trackLang -eq "enm"))) { 
                            $score += 300 
                            [void]$ruleLog.Add("Honorifics(+300)")
                        }
                        
                        # Tiered Language Scoring
                        $isPrefLang = ($trackLang -eq $fixerConfig.Subtitles.PreferredLanguage)
                         # Special Case: treat 'enm' or name-match as 'eng' ONLY if Honorifics mode is active
                         # Uses Negative Lookbehind to avoid matching "No-Honorifics" or "Non-Honorifics"
                        $honRegex = "(?<!no\s|non-|without\s|removed\s)(honorifics|honors)"
                        $isHonorificsTrack = ($trackLang -eq "enm") -or ($trackName -match $honRegex)
                        if (-not $isPrefLang -and $Honorifics -and $fixerConfig.Subtitles.PreferredLanguage -eq "eng" -and $isHonorificsTrack) {
                            $isPrefLang = $true
                        }

                        if ($isPrefLang) { 
                            $score += 5000 
                            [void]$ruleLog.Add("UserChoiceLang(+$($trackLang):+5000)")
                        } elseif ($trackLang -eq "und" -or ($trackLang -eq "enm" -and -not $isPrefLang)) {
                            # If enm is found but Hon mode is off, treat it as a Tier 2 fallback (like Undefined)
                            $score += 1000
                            [void]$ruleLog.Add("EnglishVariantFallback(+$($trackLang):+1000)")
                        }
                        
                        # Fansub Group Priority Scoring (Anime Mode Only)
                        if (-not $Western -and $fixerConfig.Subtitles.FansubGroupPriority -and $fixerConfig.Subtitles.FansubGroupPriority.Count -gt 0 -and $trackName) {
                            for ($i = 0; $i -lt $fixerConfig.Subtitles.FansubGroupPriority.Count; $i++) {
                                $groupTarget = $fixerConfig.Subtitles.FansubGroupPriority[$i]
                                if ($trackName -like "*$groupTarget*") {
                                    $score += (10000 - ($i * 1000))
                                    [void]$ruleLog.Add("Fansub(${groupTarget}:+$bonus)")
                                    break
                                }
                            }
                        }
                        
                        # --- SDH/HI/CC Promotion Scoring ---
                        if ($SubtitlesHearingImpaired) {
                            $isSDH = ($trackName -match "SDH|HI|CC" -or $t.properties.flag_hearing_impaired)
                            if ($trackLang -eq "eng" -and $isSDH) {
                                $score += 500  # Massive boost to ensure SDH is selected as the top candidate
                                [void]$ruleLog.Add("SDH_Boost(+500)")
                            }
                        }
                        
                        # --- Western "Full Sub" Tie-Breaker ---
                        if ($Western -and -not $sdhWinner) {
                            # Dynamically verify against the profile language preference instead of hardcoded 'eng'
                            if ($trackLang -eq $fixerConfig.Subtitles.PreferredLanguage -and -not $t.properties.forced_track -and $trackName -notmatch "Sign|Song|Lyric") {
                                $score += 200 
                                [void]$ruleLog.Add("WesternFullSub(+200)")
                            }
                        }
                        
                        

                        # 4. ADD TO LIST (No filter here - we need to see the "bad" tracks to fix them)
                        $subCandidates += [PSCustomObject]@{
                            ID         = $t.id
                            Score      = $score
                            Lang       = $trackLang
                            Name       = $t.properties.track_name
                            WasDefault = $isCurrentlyDefault
                            Rules      = ($ruleLog -join ' | ')
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
                if ($FixDebug -and $subCandidates.Count -gt 0) {
                    Write-Host "  [DEBUG] Subtitle Scoring Candidates:" -ForegroundColor Cyan
                    [void]$fixDetails.Add("  [DEBUG] Subtitle Scoring Breakdown:")
                    foreach ($cand in ($subCandidates | Sort-Object Score -Descending)) {
                        $msg = "    -> ID:$($cand.ID) | Score: $($cand.Score) | Lang: $($cand.Lang) | Rules: [$($cand.Rules)] | Name: $($cand.Name)"
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
                    $correctLangForWinner = if ($isWinnerHon) { "enm" } else { $targetSubLang }
                    
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
                    if ($winnerNeedsFix -or $losersNeedStrip) {
                        $needsChange = $true
                        
                        # FIX: Define $winID before using it
                        $winID = $winner.ID + 1
                        
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
                        if ($FixDebug) {
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
Pause