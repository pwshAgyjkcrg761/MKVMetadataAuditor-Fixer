# ==============================================================================
# SCRIPT: MKVMetadataAuditor+Fixer.ps1
# VERSION: 2026.06.17__11.35.00
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
# AI INSTRUCTIONS v2026.06.13__13.53.01 : 
# 1. HEADER: Update Version comment.
#    - VERSIONING: Update using CHICAGO TIME (Central Time), 24 hour clock.
#    - OUTPUT: When printing the updated version, only provide the new version
#      number. Do not describe the change as complex or explain the edit.
#    - CRITICAL: Do not use AI system time. Use the time provided in the most 
#      recent user prompt or link (Ref: https://www.timeanddate.com/worldclock/usa/chicago).
#    - STAMP ACCURACY: Ensure the minutes match the current Chicago clock exactly.
# 2. DO NOT modify or refactor any code inside <PROTECTED> tags.
# 3. SCRIPT OUTPUT (SURGICAL FIXES ONLY):
#    - Provide minimal, highly targeted, surgical edits. Do not rewrite large blocks or entire functions unless explicitly requested.
#    - When printing the script, only print snippets unless asked for the entire script.
#    - Always use a codebox with a copy button.
#    - If there are multiple modifications, present them strictly ONE step at a time,
#      and wait for user confirmation before proceeding to the next step.
#
# 4. VERBATIM ANCHOR PROTOCOL:
#    - To facilitate "Find" in Notepad++ always structure edits with:
#     - "Verbatim Anchor (Before)" - The exact lines of existing code immediately before the change.
#     - "Verbatim Anchor (After)" - The exact lines of existing code immediately after the change.
#     - "Snippet to REPLACE" - The exact code block to be deleted.
#     - "What to PASTE in its place" - The new code block to be inserted.
#   - Do not summarize, truncate, or refactor the existing code used as an anchor.
#   - Copy spaces, comments, and symbols exactly as they appear in the file.
#   - Keep anchors and replacement snippets as small and precise as possible to isolate only the necessary change.
#
# 5. CONTENT PRESERVATION:
#    - Do not remove, modify, or strip out telemetry data or DevDebug information 
#      from any provided code.
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
    
    [Alias("nohw")]
    [switch]$NoHwVideoSearch,
    
    [switch]$fast,
    [Alias("lfp")]
    [switch]$LogFullPath,
    
    [Alias("seq")]
    [switch]$Sequential,
    
    [alias("SFTO", "SubTrackOrder", "TrackOrder")]
    [switch]$SubtitleFactorTrackOrder,
    
    [alias("DSA", "Deep", "DeepAudit")]
    [switch]$DeepSubtitleAudit,
    
    [alias("DSADebugEx", "DeepDebugEx", "DeepAuditDbgEx", "DSADE")]
    [switch]$DeepSubtitleAuditDebugExtraction,
    
    [alias("DSANLD", "DeepSANLD", "NoLngD", "NLD", "LanguageDetectionOff", "LDO")]
    [switch]$DeepSubtitleAuditNOLanguageDetection,
    
    [alias("DSALDL2", "DeepSALDL2", "LngDL2", "LDL2", "LanguageDetectionL2")]
    [switch]$DeepSubtitleAuditLanguageDetectionLimit2,
    
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

# --- IMPLICIT SWITCH LOGIC ---
if ($FixNoBackup) { $Fix = $true }
if ($DeepSubtitleAuditDebugExtraction -or $DeepSubtitleAuditLanguageDetectionLimit2 -or $DeepSubtitleAuditNOLanguageDetection) { $DeepSubtitleAudit = $true }

# --- GLOBAL VERSION DEFINITION ---
$scriptVersion = "2026.06.17__11.35.00"

# --- VERSION REPORTER ---
if ($Version) {
    Write-Host "MKVMetadataAuditor+Fixer.ps1 v$scriptVersion" -ForegroundColor Cyan
    exit
}

# --- FUNCTION DEFINITIONS ---

# [FROM: MKVMetadataAuditor+Fixer.Core.ps1]
function Initialize-NaturalSort {
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
}

function Initialize-MediaInfo {
    param([string]$DllPath)
    
    $MediaInfoDefinition = @"
    using System;
    using System.Runtime.InteropServices;

    public enum StreamKind { General, Video, Audio, Text, Other, Image, Menu, Max }
    public enum InfoKind { Name, Text, Measure, Options, NameText, MeasureText, Max }

    public class MediaInfo {
        [DllImport("MediaInfo.dll", CharSet = CharSet.Unicode)]
        public static extern IntPtr MediaInfo_New();
        [DllImport("MediaInfo.dll", CharSet = CharSet.Unicode)]
        public static extern void MediaInfo_Delete(IntPtr Handle);
        [DllImport("MediaInfo.dll", CharSet = CharSet.Unicode)]
        public static extern IntPtr MediaInfo_Open(IntPtr Handle, string FileName);
        [DllImport("MediaInfo.dll", CharSet = CharSet.Unicode)]
        public static extern void MediaInfo_Close(IntPtr Handle);
        [DllImport("MediaInfo.dll", CharSet = CharSet.Unicode, PreserveSig = true)]
        public static extern IntPtr MediaInfo_Get(IntPtr Handle, StreamKind Kind, UIntPtr StreamNumber, string Parameter, InfoKind KindOfInfo, InfoKind KindOfSearch);
        [DllImport("MediaInfo.dll", CharSet = CharSet.Unicode)]
        public static extern IntPtr MediaInfo_Option(IntPtr Handle, string Option, string Value);
    }
"@
    
    # Pre-load the DLL if a specific path was found; otherwise, rely on System PATH
    if ([string]::IsNullOrWhiteSpace($DllPath)) { $DllPath = "MediaInfo.dll" }

    try {
        # Attempt 1: Load via the absolute path discovered
        [void][System.Runtime.InteropServices.NativeLibrary]::Load($DllPath)
    } catch {
        try {
            # Attempt 2: Fallback to bare-name load (Lets OS search System PATH)
            [void][System.Runtime.InteropServices.NativeLibrary]::Load("MediaInfo.dll")
        } catch {
            Write-Host "`n [!] ERROR: MediaInfo.dll found but failed to load:" -ForegroundColor DarkRed
            Write-Host "     -> Path: $DllPath" -ForegroundColor DarkYellow
            
            Write-Host "`n [TIP] This is usually caused by a bitness mismatch (e.g. 32-bit DLL" -ForegroundColor Cyan
            Write-Host "       in 64-bit PowerShell) or missing VC++ Redistributable files." -ForegroundColor Cyan
            Pause; exit
        }
    }

    if (-not ([System.Management.Automation.PSTypeName]"MediaInfo").Type) {
        Add-Type -TypeDefinition $MediaInfoDefinition
    }
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

function Get-MKVToolPaths {
    $Resolve = {
        param($cmd)
        $path = Get-Command $cmd -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
        if ($path -and (Test-Path -LiteralPath $path)) { return $path }
        return $null
    }

    $tools = @{
        propedit     = &$Resolve "mkvpropedit.exe"
        merge        = &$Resolve "mkvmerge.exe"
        extract      = &$Resolve "mkvextract.exe"
        mediainfoDll = &$Resolve "MediaInfo.dll"
        mediainfoExe = &$Resolve "mediainfo.exe"
    }

    # Fallbacks
    if (-not $tools.propedit -or -not (Test-Path -LiteralPath $tools.propedit)) { $tools.propedit = "C:\Program Files\MKVToolNix\mkvpropedit.exe" }
    if (-not $tools.merge -or -not (Test-Path -LiteralPath $tools.merge))    { $tools.merge    = "C:\Program Files\MKVToolNix\mkvmerge.exe" }
    if (-not $tools.extract)  { $tools.extract  = "C:\Program Files\MKVToolNix\mkvextract.exe" }
    
    # MediaInfo.dll Search
    if (-not $tools.mediainfoDll) {
        $dllSearchPaths = New-Object System.Collections.Generic.List[string]
        $dllSearchPaths.Add((Join-Path $PSScriptRoot "MediaInfo.dll"))
        $dllSearchPaths.Add("C:\Program Files\MediaInfo.dll\MediaInfo.dll")
        $dllSearchPaths.Add("C:\Program Files\MediaInfo\MediaInfo.dll")
        
        # Verify initial candidates before adding ENV paths
        $validBase = $dllSearchPaths | Where-Object { Test-Path -LiteralPath $_ }
        if ($validBase) { $tools.mediainfoDll = $validBase[0]; return $tools }

        $envPaths = $env:Path.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries)
        foreach ($p in $envPaths) { 
            try {
                $expanded = [System.Environment]::ExpandEnvironmentVariables($p)
                $cleanPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($expanded)
                $dllSearchPaths.Add((Join-Path $cleanPath "MediaInfo.dll")) 
            } catch {}
        }

        foreach ($path in $dllSearchPaths) {
            if (Test-Path -LiteralPath $path) { 
                $tools.mediainfoDll = $path
                break 
            }
        }
    }

    return $tools
}

# [FROM: MKVMetadataAuditor+Fixer.Scanner.ps1]
function Get-ExclusionList {
    param([string]$ExcludeFile)
    
    if (-not (Test-Path $ExcludeFile)) {
        @("# FILE: MKVMetadataAuditor+Fixer__Excluded-Paths.txt",
          "# SCRIPT: MKVMetadataAuditor+Fixer.ps1",
          "# DESCRIPTION: Add full folder paths here to skip them during audit.",
          "# FORMAT: One path per line. No wildcards. No trailing slashes.",
          "# ",
          "# Example below this line. Remove the # to enable the line.",
          "# B:\Media\Movies\Sample_Folder",
          "") | Out-File $ExcludeFile -Encoding utf8
        return @()
    }

    return Get-Content $ExcludeFile | ForEach-Object { $_.Trim() } | Where-Object { 
        -not [string]::IsNullOrWhiteSpace($_) -and -not $_.StartsWith("#") 
    } | ForEach-Object { $_.TrimEnd('\') }
}

function Get-TargetFolders {
    param(
        [string[]]$InputPaths,
        [switch]$DisableRecurse,
        [switch]$DevDebug
    )
    
    $resolvedFolders = New-Object System.Collections.Generic.List[PSObject]
    $seenPaths = New-Object System.Collections.Generic.HashSet[string]

    foreach ($path in $InputPaths) {
        try {
            
            # Resolve directly if the path is a file
            if ([System.IO.File]::Exists($path)) {
                $fi = [System.IO.FileInfo]::new($path)
                if ($seenPaths.Add($fi.FullName)) { [void]$resolvedFolders.Add($fi) }
                continue
            }

            # Use .NET Direct API to bypass PowerShell provider limitations with characters like '!' and '['
            $di = [System.IO.DirectoryInfo]::new($path)
            if (-not $di.Exists) { continue }

            # Add the root itself
            if ($seenPaths.Add($di.FullName)) { [void]$resolvedFolders.Add($di) }

            if (-not $DisableRecurse) {
                # Use EnumerationOptions to bypass inaccessible/system directories gracefully
                $enumOptions = [System.IO.EnumerationOptions]::new()
                $enumOptions.RecurseSubdirectories = $true
                $enumOptions.IgnoreInaccessible = $true
                
                $subFolders = $di.EnumerateDirectories("*", $enumOptions)
                foreach ($sub in $subFolders) {
                    if ($seenPaths.Add($sub.FullName)) { [void]$resolvedFolders.Add($sub) }
                }
            }
        } catch {
            if ($DevDebug) { Write-Host " [DevDebug-Scanner] Error resolving path: $path - $($_.Exception.Message)" -ForegroundColor Red }
        }
    }

    if ($DevDebug) {
        Write-Host " [DevDebug-Scanner] Total Folders Discovered: $($resolvedFolders.Count)" -ForegroundColor Gray
    }

    return $resolvedFolders | Sort-Natural
}

function Test-IsExcluded {
    param(
        [string]$CurrentPath,
        [string[]]$Exclusions,
        [switch]$Active
    )
    if (-not $Active -or $Exclusions.Count -eq 0) { return $false }
    return $Exclusions -contains $CurrentPath.TrimEnd('\')
}

# [FROM: MKVMetadataAuditor+Fixer.SearchH10P.ps1]
function Test-IsNoHw {
    param(
        [string]$FilePath,
        [string]$MediaInfoDllPath,
        [string]$MediaInfoExePath,
        [switch]$DevDebug
    )
    
    # PATH EVALUATION: Identify long paths for CLI routing
    $isLongPath = $FilePath.Length -ge 250
    $miFilePath = $FilePath

    $dllOpenSuccess = $false
    $chroma  = ""
    $space   = ""
    $prof    = ""
    $vFormat = ""

    # ROUTE 1: MediaInfo.dll (Only for short paths)
    if (-not $isLongPath) {
        if ($DevDebug) {
            Write-Host "[DevDebug-NoHW] Routing to DLL (Length: $($FilePath.Length)) ↓↓↓" -ForegroundColor Gray
            Write-Host "`n`nPath: $FilePath`n`n" -ForegroundColor Gray
        }
        
        $handle = [MediaInfo]::MediaInfo_New()
    
    # Nested Helper for Safe String Marshalling
    $GetVal = {
        param($h, $kind, $id, $param)
        $ptr = [MediaInfo]::MediaInfo_Get($h, $kind, $id, $param, [InfoKind]::Text, [InfoKind]::Name)
        if ($ptr -ne [IntPtr]::Zero) { return [System.Runtime.InteropServices.Marshal]::PtrToStringUni($ptr) }
        return ""
    }

    try {
            # Note: DLL uses standard Path internally; prefixing handled by the DLL if supported
            if ([MediaInfo]::MediaInfo_Open($handle, $FilePath) -ne 0) {
                $dllOpenSuccess = $true
                $vCountStr = &$GetVal $handle ([StreamKind]::General) 0 "VideoCount"
                
                if ([string]::IsNullOrWhiteSpace($vCountStr) -or $vCountStr -eq "0") {
                     [MediaInfo]::MediaInfo_Close($handle); [MediaInfo]::MediaInfo_Delete($handle)
                     return [PSCustomObject]@{ IsNoHw = $false; IsReadable = $false; Error = "No Video Tracks Found" }
                }

                $chroma  = &$GetVal $handle ([StreamKind]::Video) 0 "ChromaSubsampling"
                $space   = &$GetVal $handle ([StreamKind]::Video) 0 "ColorSpace"
                $prof    = &$GetVal $handle ([StreamKind]::Video) 0 "Format_Profile"
                $vFormat = &$GetVal $handle ([StreamKind]::Video) 0 "Format"
            }
        } catch {} finally {
            if ($dllOpenSuccess) { [MediaInfo]::MediaInfo_Close($handle) }
            [MediaInfo]::MediaInfo_Delete($handle)
        }
    }

    # ROUTE 2: MediaInfo.exe CLI (For long paths OR DLL failures)
    if (-not $dllOpenSuccess -and $MediaInfoExePath) {
        
        # Apply Extended-Length Prefixing for Windows CLI
        if ($IsWindows -and $miFilePath -notlike "\\?\*") {
            if ($miFilePath.StartsWith("\\")) {
                $miFilePath = "\\?\UNC\" + $miFilePath.Substring(2)
            } else {
                $miFilePath = "\\?\" + $miFilePath
            }
        }

        if ($DevDebug) { 
            $reason = if ($isLongPath) { "Long Path (Length: $($FilePath.Length))" } else { "DLL Open Failure" }
            Write-Host "    [DevDebug-NoHW] Routing to CLI ($reason)" -ForegroundColor Gray
            Write-Host "    [DevDebug-NoHW] Final CLI Path: $miFilePath" -ForegroundColor DarkGray
        }
        try {
            # Use -- to prevent '&' or other characters from being treated as operators
            $raw = & $MediaInfoExePath --Output="Video;%Format_Profile%|%ChromaSubsampling%|%ColorSpace%|%Format%" -- $miFilePath 2>$null
            if ($raw) {
                $parts = $raw.Split('|')
                if ($parts.Length -eq 4) {
                    $prof    = $parts[0].Trim()
                    $chroma  = $parts[1].Trim()
                    $space   = $parts[2].Trim()
                    $vFormat = $parts[3].Trim()
                    $dllOpenSuccess = $true
                }
            }
        } catch {}
    }

    if (-not $dllOpenSuccess) {
        return [PSCustomObject]@{ IsNoHw = $false; IsReadable = $false; Error = "File Open Failed" }
    }

    $isHi10 = ($prof -match "High 10")
    $is422  = ($chroma -eq "4:2:2")
    $is444  = ($chroma -eq "4:4:4")
    $isRGB  = ($space -eq "RGB")

    return [PSCustomObject]@{ 
        IsNoHw     = ($isHi10 -or $is444 -or $is422 -or $isRGB)
        IsReadable = $true
        Format     = $vFormat
        Profile    = $prof
        Chroma     = $chroma
        Space      = $space
        Flags      = @(
            if ($isHi10) { "AVC Hi10P" }
            if ($is422)  { "Chroma 4:2:2" }
            if ($is444)  { "Chroma 4:4:4" }
            if ($isRGB)  { "RGB" }
        ) -join ', '
    }
}

function Get-NoHwLogHeader {
    param([switch]$Fast, [string]$RootPath, [string[]]$Flags)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm"
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("-" * 89)
    $ts | ForEach-Object { $lines.Add($_) }
    $lines.Add("Folder: $RootPath")
    if ($Fast) { $lines.Add("Fast Scan - First File in Each Folder Only") }
    
    $nohwOnly = @($Flags | Where-Object { $_ -notmatch "Corrupt" } | Sort-Object { $_ -replace '^[^\[]+', '' })
    $corruptOnly = @($Flags | Where-Object { $_ -match "Corrupt" })
    
    if ($nohwOnly.Count -gt 0) { $lines.Add("Found: " + ($nohwOnly -join ' ')) }
    if ($corruptOnly.Count -gt 0) {
        $prefix = if ($nohwOnly.Count -gt 0) { "       " } else { "Found: " }
        foreach ($cEntry in $corruptOnly) { $lines.Add("$prefix$cEntry") }
    }
    
    $lines.Add("Recommend convert to HEVC Main 10, Chroma Subsampling: 4:2:0, Color Space: YUV")
    $lines.Add("-" * 89)
    return $lines
}

# [FROM: MKVMetadataAuditor+Fixer.DeepSubtitleAudit.ps1]
function Get-SubtitleExtension {
    param([string]$Codec)
    if ($Codec -match "PGS") { return "sup" }
    if ($Codec -match "VobSub") { return "sub" }
    if ($Codec -match "UTF8|SRT") { return "srt" }
    return "ass"
}

function Detect-SubtitleLanguage {
    param(
        [string]$Text, 
        [string]$CurrentLang, 
        [switch]$Honorifics, 
        [switch]$DevDebug,
        [string]$TrackID,
        [string]$Selector,
        [string]$TrackName
    )

    if ($DevDebug) {
        $nameDisplay = if ($TrackName) { " ($TrackName)" } else { " (Unnamed)" }
        # Map ID to human-readable Track (ID + 1)
        $trackNum = [int]$TrackID + 1
        Write-Host "    [DevDebug-DSA] Language Detection Probe | ID: $TrackID - Track $trackNum - [$Selector]$nameDisplay" -ForegroundColor Cyan
    }

    if ([string]::IsNullOrWhiteSpace($text)) { 
        if ($DevDebug) { Write-Host "      -> No usable text found after dialogue extraction (Stripped)." -ForegroundColor DarkYellow }
        return "und:0:0" 
    }
    
    $total = $text.Length
    
    # 1. Non-Latin Unique Scripts
    $korCount = [regex]::Matches($text, "[\uAC00-\uD7AF]").Count
    $jpnCount = [regex]::Matches($text, "[\u3040-\u309F\u30A0-\u30FF]").Count
    $chiCount = [regex]::Matches($text, "[\u4E00-\u9FFF]").Count

    if ($DevDebug) {
        $pKor = [Math]::Round(($korCount / $total) * 100, 2); $pJpn = [Math]::Round(($jpnCount / $total) * 100, 2); $pChi = [Math]::Round(($chiCount / $total) * 100, 2)
        Write-Host "      -> Metrics: Chars Analyzed: $total" -ForegroundColor Gray
        Write-Host "      -> Script Density: Korean: $pKor% | Japanese: $pJpn% | Chinese: $pChi%" -ForegroundColor Gray
        
    }

    if ($korCount / $total -gt 0.15) { if ($DevDebug) { Write-Host "      -> MATCH: Korean (Hangul)" -ForegroundColor Green }; return "kor:0:0" }
    if ($jpnCount / $total -gt 0.05) { if ($DevDebug) { Write-Host "      -> MATCH: Japanese (Kana)" -ForegroundColor Green }; return "jpn:0:0" }
    if ($chiCount / $total -gt 0.15) { if ($DevDebug) { Write-Host "      -> MATCH: Chinese (Han)" -ForegroundColor Green }; return "chi:0:0" }

    
    # 2. Latin-Based Language Detection
    $latin = [regex]::Matches($text, "[\u0000-\u007F\u0080-\u00FF\u0100-\u017F\u1E00-\u1EFF]").Count
    if ($latin / $total -gt 0.5) {
        if ($DevDebug) { Write-Host "      -> Latin Script Density: $([Math]::Round(($latin / $total) * 100, 2))%" -ForegroundColor Gray }
        
        # English Verification Logic (Hardened Stopwords)
        $engStopwords = "\b(the|you|with|this|they|have|from|your|that|what|will|would|should|could|there|their|through|and|but|or|which|because|these|those|been|had|has|were|was|who|whom|does|did|a|an)\b"
        $engMatches = [regex]::Matches($text, $engStopwords).Count
        $theCount = [regex]::Matches($text, "\bthe\b").Count
        $honMatches = if ($Honorifics) { [regex]::Matches($text, "-(?:san|kun|chan|sama|dono|senpai|kohai|sensei|niisan|niichan|neesan|neechan|jiisan|jiichan|baasan|baachan|shisou|heika|denka|kakka|tan|chama)\b").Count } else { 0 }

        if ($DevDebug) {
            Write-Host "      -> English Metrics: Stopwords: $engMatches (Target: 20+ with anchors, or 28+ total)" -ForegroundColor Gray
            Write-Host "      -> English Anchors: 'The' Count: $theCount | Honorifics: $honMatches" -ForegroundColor Gray
        }
        
        # Confidence Model:
        # A: Base Lexicon (20+) + Structural Anchor (2+ "the" OR 1+ Honorific)
        # B: High Volume Lexicon (28+) regardless of anchors (Safely handles short "the"-less scripts)
        $isEnglish = ($engMatches -ge 28) -or ($engMatches -ge 20 -and ($theCount -ge 2 -or $honMatches -ge 1))

        if ($isEnglish) {
            if ($Honorifics -and $honMatches -ge 1) { 
                if ($DevDebug) { Write-Host "      -> MATCH: English (Japanese Honorifics) [enm] (Header: eng)" -ForegroundColor Green }
                return "enm:${honMatches}:${theCount}" 
            }
            if ($DevDebug) { Write-Host "      -> MATCH: English [eng]" -ForegroundColor Green }
            return "eng:0:${theCount}" 
        }

        # Safety Fallback
        if ($DevDebug) { Write-Host "      -> NO MATCH: Fallback to header language ($CurrentLang)" -ForegroundColor DarkYellow }
        return "${CurrentLang}:0:0"
    }
    return "und:0:0"
}

function Extract-DialogueText {
    param($Path, [string]$OutPath, [switch]$DevDebug, [int]$MaxLength = [int]::MaxValue)
    if ($Path -match "\.(sup|sub)$") { return "IMAGE_SUB_BYPASS" }

    # Compile Regex patterns once for maximum loop speed
    if (-not $script:RegexCleanBrackets) {
        $script:RegexCleanBrackets = [regex]::new('\{.*?\}', 'Compiled')
        $script:RegexCleanSlashN   = [regex]::new('\\[Nnh]', 'Compiled')
        $script:RegexCleanHTML     = [regex]::new('<.*?>', 'Compiled')
        $script:RegexLetterMatch   = [regex]::new('\p{L}[,.?!]', 'Compiled')
        $script:RegexDrawCheck     = [regex]::new('\\(?:p[1-9]|clip|iclip|move|org|t)\b', 'Compiled')
        $script:RegexSyncCheck     = [regex]::new('(?:sync|karaoke|fx|ktp|auto)', 'Compiled')
        $script:RegexTechCheck     = [regex]::new('(?i)(?:circle|square|box|rectangle|line|triangle|oval|star|polygon|cm|mm|width|height|depth|circ|vert|horiz)', 'Compiled')
        $script:RegexCoordinateDraw = [regex]::new('(?i)^[mb]\s-?\d+', 'Compiled')
    }

    $sb = [System.Text.StringBuilder]::new()
    
    $encoding = [System.Text.Encoding]::UTF8
    try {
        $fs = [System.IO.File]::OpenRead($Path)
        $buffer = [byte[]]::new(1024)
        $bytesRead = $fs.Read($buffer, 0, 1024)
        $fs.Close()
        $hasNull = $false
        for ($i = 0; $i -lt $bytesRead; $i++) {
            if ($buffer[$i] -eq 0) { $hasNull = $true; break }
        }
        if ($hasNull) {
            $encoding = [System.Text.Encoding]::Default
        }
    } catch {}

    $lines = [System.IO.File]::ReadLines($Path, $encoding)
    $isASS = $Path -match "\.(ass|ssa)$"
    $history = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $lines) {
        if ($isASS) {
            if (-not $line.StartsWith("Dialogue:")) { continue }
            if ($script:RegexDrawCheck.IsMatch($line)) { continue }
            
            $parts = $line.Split(',', 10)
            if ($parts.Length -eq 10) {
                if ($script:RegexSyncCheck.IsMatch($parts[8])) { continue }
                $txt = $parts[9]
                if ($script:RegexCoordinateDraw.IsMatch($txt) -or $script:RegexTechCheck.IsMatch($txt)) { continue }
                
                $readable = $script:RegexCleanBrackets.Replace($txt, '')
                $readable = $script:RegexCleanSlashN.Replace($readable, ' ')
                $trimmed = $readable.Trim()
                if ($history.Contains($trimmed) -or -not $script:RegexLetterMatch.IsMatch($trimmed)) { continue }
                [void]$sb.AppendLine($trimmed); $history.Add($trimmed)
                if ($history.Count -gt 10) { $history.RemoveAt(0) }
                if ($sb.Length -ge $MaxLength) { break }
            }
        } else {
            if ([string]::IsNullOrWhiteSpace($line) -or $line.Contains("-->")) { continue }
            
            # Fast numeric check to skip subtitle index lines without regex
            $isNumeric = $true
            for ($i = 0; $i -lt $line.Length; $i++) {
                if (-not [char]::IsDigit($line[$i])) { $isNumeric = $false; break }
            }
            if ($isNumeric) { continue }
            
            $readable = $script:RegexCleanHTML.Replace($line, '')
            $readable = $script:RegexCleanBrackets.Replace($readable, '')
            $trimmed = $readable.Trim()
            if ($history.Contains($trimmed) -or -not $script:RegexLetterMatch.IsMatch($trimmed)) { continue }
            [void]$sb.AppendLine($trimmed); $history.Add($trimmed)
            if ($history.Count -gt 10) { $history.RemoveAt(0) }
            if ($sb.Length -ge $MaxLength) { break }
        }
    }
    $finalText = $sb.ToString()
    if ($DevDebug -and $OutPath) { $finalText | Out-File $OutPath -Encoding utf8 }
    return $finalText
}



# [FROM: MKVMetadataAuditor+Fixer.Auditor.ps1]
$global:trackCounters = @{ "video" = 1; "audio" = 1; "subtitles" = 1 }
function Get-AuditSelector {
    param($type, [switch]$Reset)
    if ($Reset) { $global:trackCounters = @{ "video" = 1; "audio" = 1; "subtitles" = 1 }; return "" }
    if ([string]::IsNullOrWhiteSpace($type) -or -not $global:trackCounters.ContainsKey($type.ToLower())) { return "?" }
    $key = $type.ToLower()
    $val = $global:trackCounters[$key]
    $letter = switch ($type) { "video" { "v" } "audio" { "a" } "subtitles" { "s" } }
    $global:trackCounters[$key]++
    return "$letter$val"
}

function Get-AuditFlags {
    param($tracks, $IsWestern, $fixerConfig, $Honorifics, $SubtitlesHearingImpaired, $FilePath, $MediaInfoDllPath, $MediaInfoExePath)
    
    # Use Global Regex Patterns from Main Controller
    $RegexDiag = $script:RegexDiag
    $RegexSign = $script:RegexSign

    $reasons = "";
    if (($tracks | Measure-Object).Count -eq 0) { $reasons += "💀 [Corrupt/No Tracks Found] "; return $reasons.Trim() }    
    $jpnAud = $tracks | Where-Object { $_.type -eq "audio" -and $_.properties.language -eq "jpn" }
    $engAud = $tracks | Where-Object { $_.type -eq "audio" -and $_.properties.language -eq "eng" }
    $subs = $tracks | Where-Object { $_.type -eq "subtitles" }
    
    $prefAudLang = if ($fixerConfig.Audio.PreferredLanguage) { $fixerConfig.Audio.PreferredLanguage } elseif ($IsWestern) { "eng" } else { "jpn" }
    if (-not ($tracks | Where-Object { $_.type -eq "audio" -and $_.properties.language -eq $prefAudLang })) { 
        $reasons += "🚫🎙️[Pref Audio NOT Found: $($prefAudLang.ToUpper())] " 
    }

    $prefSubLang = if ($fixerConfig.Subtitles.PreferredLanguage) { $fixerConfig.Subtitles.PreferredLanguage } elseif (-not $IsWestern) { "eng" }
    if ($prefSubLang -and -not ($subs | Where-Object { $_.properties.language -eq $prefSubLang })) {
        if (-not ($Honorifics -and $prefSubLang -eq "eng" -and ($subs | Where-Object { $_.properties.language -eq "enm" }))) {
            $reasons += "❌👁️ [Pref Subtitles NOT Found: $($prefSubLang.ToUpper())] "
        }
    }
    
    $targetAuds = $tracks | Where-Object { $_.type -eq "audio" -and $_.properties.language -eq $prefAudLang }
    if ($targetAuds -and -not ($targetAuds | Where-Object { $_.properties.default_track })) {
        $reasons += "⚠️🎙️[Pref Audio NOT Default: $($prefAudLang.ToUpper())] "
    }

    $targetSubs = $subs | Where-Object { $_.properties.language -eq $prefSubLang }
    if ($Honorifics -and $prefSubLang -eq "eng") {
        $targetSubs = $subs | Where-Object { $_.properties.language -match "eng|enm" }
    }
    if ($targetSubs -and -not ($targetSubs | Where-Object { $_.properties.default_track })) {
        $reasons += "⚠️👁️[Pref Subtitles NOT Default: $($prefSubLang.ToUpper())] "
    }
    
        # --- DEEP VIDEO INSPECTION (NoHW Flags via Unified Logic) ---
    $noHwStatus = Test-IsNoHw -FilePath $FilePath -MediaInfoDllPath $MediaInfoDllPath -MediaInfoExePath $MediaInfoExePath
    if ($noHwStatus.IsReadable -and $noHwStatus.IsNoHw) {
        if ($noHwStatus.Profile -match "High 10") { $reasons += "🔟 [NoHW: AVC Hi10P] " }
        if ($noHwStatus.Chroma -eq "4:2:2")       { $reasons += "🎨 [NoHW: Chroma 4:2:2] " }
        if ($noHwStatus.Chroma -eq "4:4:4")       { $reasons += "🎨 [NoHW: Chroma 4:4:4] " }
        if ($noHwStatus.Space -eq "RGB")         { $reasons += "🌈 [NoHW: RGB] " }
    }

    if ($tracks | Where-Object { $_.properties.forced_track }) { $reasons += "🚨[Forced Track] " }
    $videoTracks = $tracks | Where-Object { $_.type -eq "video" }
    if (($videoTracks | Measure-Object).Count -gt 1) { $reasons += "🎞️[Multiple Video Tracks] " }
    if ($tracks | Where-Object { ($_.type -match "audio|subtitles") -and $_.properties.language -eq "und" }) { $reasons += "❔[Und Lang] " }

    $trackTypes = $tracks | Select-Object -ExpandProperty type -Unique
    foreach ($type in $trackTypes) {
        $defaults = $tracks | Where-Object { $_.type -eq $type -and $_.properties.default_track }
        if ($defaults.Count -gt 1) { $reasons += "⚔️[Conflict: Multiple $($type.ToUpper()) Defaults] " }
    }

    if ($IsWestern) {
        if (-not ($engAud | Where-Object { $_.properties.default_track })) { $reasons += "🎙️[ENG Audio Not Default] " }
        $defaultSub = $subs | Where-Object { $_.properties.default_track }
        if (-not ($defaultSub | Where-Object { $_.properties.language -eq "eng" -and $_.properties.track_name -notmatch "Forced" })) {
            $reasons += "🔇[Sub: None Default] "
        }

        if ($SubtitlesHearingImpaired) {
            $hasEngSDH = $subs | Where-Object { 
                ($_.properties.language -eq "eng") -and 
                ($_.properties.track_name -match "SDH|HI|CC" -or $_.properties.flag_hearing_impaired) 
            }
            if ($hasEngSDH) {
                if (-not ($hasEngSDH | Where-Object { $_.properties.default_track })) { $reasons += "✨[SDH Available] " }
            } else { $reasons += "🚫[Missing ENG SDH/CC] " }
        }
    } else {
        if ($jpnAud -and $subs.Count -eq 0) { $reasons += "⚠️[JPN Audio/No Subs] " }
        if ($subs.Count -gt 0) {
            $dSubs = $subs | Where-Object { $_.properties.default_track }
            if ($dSubs | Where-Object { $_.properties.track_name -match $RegexSign -and $_.properties.track_name -notmatch $RegexDiag }) { $reasons += "🎵[Sub: Signs/Songs Default] " }
            if ($subs | Where-Object { $_.properties.language -eq "eng" -and $_.properties.flag_hearing_impaired }) { $reasons += "👂[ENG Sub HI/CC] " }
            if ($subs | Where-Object { $_.properties.track_name -match "SDH" }) { $reasons += "🙉[SDH Name] " }
            if ($subs | Where-Object { $_.properties.flag_hearing_impaired }) { $reasons += "👀[Sub HI/CC] " }
        }
        if ($subs | Where-Object { $_.properties.language -eq "jpn" }) { $reasons += "⛩️[JPN Sub Present] " }
    }
    return $reasons.Trim()
}

function Get-TrackProps {
    param($t)
    $flags = New-Object System.Collections.Generic.List[string]
    if ($t.properties.default_track) { [void]$flags.Add("[DEFAULT]") }
    if ($t.properties.forced_track) { [void]$flags.Add("[FORCED]") }
    if ($t.properties.flag_hearing_impaired) { [void]$flags.Add("[HI/CC]") }
    return $flags
}

# [FROM: MKVMetadataAuditor+Fixer.Fixer.ps1]
function Invoke-MkvBackup {
    param([string]$FilePath, [string]$RootPath)
    
    # Check if the original RootPath is a file
    $isFile = [System.IO.File]::Exists($RootPath)
    $resolvedRoot = if ($isFile) { Split-Path $RootPath -Parent } else { $RootPath }
    
    $fileItem = Get-Item -LiteralPath $FilePath

    if ($isFile) {
        $backupRootPath = Join-Path $resolvedRoot "_updated"
    } else {
        $parentDir = Split-Path $resolvedRoot -Parent
        $rootName = Split-Path $resolvedRoot -Leaf
        $backupRootPath = Join-Path $parentDir "$($rootName)_updated"
    }
    $relativeDir = ""
    $parentPath = Split-Path $FilePath -Parent
    if ($FilePath.StartsWith($RootPath) -and $parentPath.Length -gt $RootPath.Length) {
        $relativeDir = $parentPath.Substring($RootPath.Length).TrimStart('\')
    }
    $finalDestinationDir = Join-Path $backupRootPath $relativeDir
    if (-not (Test-Path -LiteralPath $finalDestinationDir)) { 
        New-Item -Path $finalDestinationDir -ItemType Directory -Force | Out-Null 
    }
    $fileName = Split-Path $FilePath -Leaf
    Write-Host "  [BACKUP] Copying: $fileName..." -ForegroundColor Gray
    Copy-Item -LiteralPath $FilePath -Destination (Join-Path $finalDestinationDir $fileName) -Force
}

function Get-TrackScore {
    param(
        $t,
        $fixerConfig,
        [int]$subRelativeIndex,
        [switch]$Honorifics,
        [switch]$SubtitleFactorTrackOrder,
        [switch]$Western,
        [switch]$SubtitlesHearingImpaired
    )
    
    # Use Global Regex Patterns from Main Controller
    $RegexDiag = $script:RegexDiag
    $RegexSign = $script:RegexSign

    $score = 0
    $ruleLog = New-Object System.Collections.Generic.List[string]
    $trackName = if ($t.properties.track_name) { $t.properties.track_name.ToLower() } else { "" }
    $trackLang = $t.properties.language.ToLower()

    # 1. Track Order Penalty
    if ($SubtitleFactorTrackOrder) {
        $posPenaltyWeight = 40
        $posPenalty = ($subRelativeIndex - 1) * $posPenaltyWeight
        if ($posPenalty -gt 0) {
            $score -= $posPenalty
            [void]$ruleLog.Add("TrackOrder(-$posPenalty)")
        }
    }

    # 2. Codec Priority Scoring
    $isCodecMatch = $false
    $codecScoreBonus = 0
    $trackCodecId = if ($t.properties.codec_id) { $t.properties.codec_id } else { $t.codec }
    for ($i = 0; $i -lt $fixerConfig.Subtitles.CodecPriority.Count; $i++) {
        $c = $fixerConfig.Subtitles.CodecPriority[$i]
        if ($trackCodecId -match $c -or $t.codec -match $c) {
            $isCodecMatch = $true
            $codecScoreBonus = [Math]::Max(0, 100 - ($i * 15))
            break
        }
    }
    if ($isCodecMatch) { 
        $score += $codecScoreBonus 
        [void]$ruleLog.Add("CodecMatch(+$codecScoreBonus)")
    }

    # 3. Content Type Scoring
    if ($trackName -match $RegexDiag) { 
        $score += 150 
        [void]$ruleLog.Add("Dialogue(+150)")
    } 
    if ($trackName -match $RegexSign) { 
        $score -= 200 
        [void]$ruleLog.Add("SignsSongs(-200)")
    } 

    # 4. Honorifics Scoring
    if ($Honorifics) {
        $isNameMatch = ($trackName -match $script:RegexHon)
        $isProvenHon = ($trackLang -eq "enm" -or $t.DSA_DetectedLang -eq "enm")
        
        $densityBonus = if ($t.DSA_HonCount) { $t.DSA_HonCount } else { 0 }
        
        if ($isNameMatch -or $isProvenHon) { 
            $hScore = 300
            if ($isProvenHon) { $hScore += 50 } # Tie-breaker for DSA verified tracks
            $hScore += $densityBonus            # Add linguistic density bonus
            
            $score += $hScore 
            $label = if ($isProvenHon) { "Honorifics_Detected(+$hScore)" } else { "Honorifics_Name(+$hScore)" }
            if ($densityBonus -gt 0) { $label += "[Density:+$densityBonus]" }
            [void]$ruleLog.Add($label)
        }
    }

    # 5. Language Scoring
    $isPrefLang = ($trackLang -eq $fixerConfig.Subtitles.PreferredLanguage)
    $dsaDetected = $t.DSA_DetectedLang
    $isHonorificsTrack = ($trackLang -eq "enm" -or $dsaDetected -eq "enm" -or $trackName -match $script:RegexHon)
    
    if (-not $isPrefLang -and $Honorifics -and $fixerConfig.Subtitles.PreferredLanguage -eq "eng" -and $isHonorificsTrack) {
        $isPrefLang = $true
    }

    if ($isPrefLang) { 
        $score += 5000 
        [void]$ruleLog.Add("UserChoiceLang(+$($trackLang):+5000)")
    } elseif ($trackLang -eq "und" -or ($trackLang -eq "enm" -and -not $isPrefLang)) {
        $score += 1000
        [void]$ruleLog.Add("EnglishVariantFallback(+$($trackLang):+1000)")
    }

    # 6. Fansub Group Priority
    if (-not $Western -and $fixerConfig.Subtitles.FansubGroupPriority -and $fixerConfig.Subtitles.FansubGroupPriority.Count -gt 0 -and $trackName) {
        for ($i = 0; $i -lt $fixerConfig.Subtitles.FansubGroupPriority.Count; $i++) {
            $groupTarget = $fixerConfig.Subtitles.FansubGroupPriority[$i]
            if ($trackName -like "*$groupTarget*") {
                $bonus = (10000 - ($i * 1000))
                $score += $bonus
                [void]$ruleLog.Add("Fansub(${groupTarget}:+$bonus)")
                break
            }
        }
    }

    # 7. SDH and Western Tweaks
    if ($SubtitlesHearingImpaired) {
        $isSDH = ($trackName -match "SDH|HI|CC" -or $t.properties.flag_hearing_impaired)
        if ($trackLang -eq "eng" -and $isSDH) {
            $score += 500
            [void]$ruleLog.Add("SDH_Boost(+500)")
        }
    }
    
    if ($Western) {
        $isDialogue = ($trackName -match $RegexDiag -or [string]::IsNullOrWhiteSpace($trackName))
        $isSign = ($trackName -match $RegexSign)
        if ($trackLang -eq $fixerConfig.Subtitles.PreferredLanguage -and -not $t.properties.forced_track -and $isDialogue -and -not $isSign) {
            $score += 200 
            $langLabel = ($trackLang[0].ToString().ToUpper() + $trackLang.Substring(1).ToLower())
            [void]$ruleLog.Add("${langLabel}FullSub(+200)")
        }
    }

    return [PSCustomObject]@{ Score = $score; Rules = ($ruleLog -join ' | ') }
}

# [FROM: MKVMetadataAuditor+Fixer.UI.ps1]
function Get-ProjectTable {
    param(
        [scriptblock]$Selector,
        $groupJson, 
        $title, 
        $compareJson, 
        $codecPadding, 
        $propPadding, 
        $namePadding,
        [System.Collections.Generic.List[string]]$entry
    )
    
    if ($title -ne "") { $entry.Add(""); $entry.Add("$title") }
    
    $line = "-" * ("Codec".PadRight($codecPadding) + " | " + "   ID".PadRight(12) + " | " + "Sel.".PadRight(4) + " | " + "Type".PadRight(9) + " | " + "Lng" + " | " + "Flags".PadRight($propPadding) + " | " + "Name".PadRight($namePadding)).Length
    $header = "$("Codec".PadRight($codecPadding)) | $("   ID".PadRight(12)) | $("Sel.".PadRight(4)) | $("Type".PadRight(9)) | Lng | $("Flags".PadRight($propPadding)) | $("Name".PadRight($namePadding))"
    $sep = "$("-" * $codecPadding)-|-$("-" * 12)-|-$("-" * 4)-|-$("-" * 9)-|-----|-$("-" * $propPadding)-|-$("-" * $namePadding)"
    
    $entry.Add($line)
    $entry.Add($header)
    $entry.Add($sep)
    
    # Reset the selector at the start of each table
    $Selector.Invoke($null, $true)

    foreach ($t in $groupJson.tracks) {
        $sel = $Selector.Invoke($t.type)
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

        $flags = @(Get-TrackProps $t)
        $firstFlag = if ($flags.Count -gt 0) { [string]$flags[0] } else { "" }
        
        $entry.Add("$codec | $($idStr.PadRight(12)) | $($sel.PadRight(4)) | $($t.type.PadRight(9)) | $($t.properties.language) | $(($firstFlag).PadRight($propPadding)) | $($tName.PadRight($namePadding))")

        if ($flags.Count -gt 1) {
            for ($i = 1; $i -lt $flags.Count; $i++) {
                $entry.Add("$(" ".PadRight($codecPadding)) | $(" ".PadRight(12)) | $(" ".PadRight(4)) | $(" ".PadRight(9)) |     | $([string]($flags[$i]).PadRight($propPadding)) | $(" ".PadRight($namePadding))")
            }
        }
    }
    $entry.Add($line)
}

function Show-ProjectManual {
    param($scriptVersion)

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
        
        # 2. Determine description color
        $currentColor = if ($ForceDescColor) { $ForceDescColor } else { 
            if ($global:altColorToggle) { "DarkCyan" } else { "DarkMagenta" } 
        }
        
        # 3. Print the description lines
        foreach ($line in $DescLines) {
            Write-Host $line -ForegroundColor $currentColor
        }
        
        if (-not $ForceDescColor) {
            $global:altColorToggle = -not $global:altColorToggle
        }
    }

    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
               " MKVMetadataAuditor+Fixer.ps1 v$scriptVersion  ",
               " MANUAL & USAGE GUIDE" | ForEach-Object { Write-Host $_ -ForegroundColor DarkMagenta }
    Write-Host " Copyright (C) 2026 pwshAgyjkcrg761`n" -ForegroundColor DarkCyan
    
     " This program is free software: you can redistribute it and/or",
     " modify it under the terms of the GNU General Public License as",
     " published by the Free Software Foundation, either version 3 of",
     " the License, or (at your option) any later version."  | ForEach-Object { Write-Host $_ -ForegroundColor DarkMagenta }
    Write-Host "============================================================" -ForegroundColor Cyan
    
    Write-Host "`n OVERVIEW:" -ForegroundColor DarkYellow
     "  This utility is a high-fidelity media management tool designed to ensure",
     "  structural consistency across MKV libraries. It operates by analyzing",
     "  the underlying metadata headers of your files without remuxing or",
     "  re-encoding the actual streams, ensuring 1:1 data integrity.",
     "",
     "  The script logic is divided into three specialized operational phases:",
     "  1. AUDIT: Scans files to identify 'Mismatch Groups' and track errors.",
     "  2. FIX:  Uses Mkvpropedit to align tracks with your preferred defaults.",
     "  3. SEARCH: Locates hardware-incompatible profiles like AVC High 10.",
     "",
     "  SCORING ENGINE:",
     "  The script employs a sophisticated weighted scoring algorithm to",
     "  determine which subtitle track should be the 'Default'. It automatically",
     "  penalizes 'Signs & Songs' tracks (-200) while prioritizing full dialogue",
     "  (+150). It further factors in Codec Priority (up to +100), Honorifics",
     "  bonus (+300), and even physical Track Order penalties (-40 per slot).",
     "  This ensures that even in complex files with 10+ tracks, the most",
     "  complete English dialogue track is selected for the viewer.`n" | ForEach-Object { Write-Host $_ -ForegroundColor DarkMagenta }

    Write-Host " DEEP SUBTITLE AUDIT (DSA):" -ForegroundColor DarkYellow
    "  When track names are missing or generic (e.g., 'English'), the DSA",
    "  engine performs a bitstream analysis. It extracts dialogue samples to",
    "  calculate character density and file size ratios. By identifying the",
    "  larger 'Full Dialogue' stream vs. the smaller 'Signs & Songs' stream,",
    "  it can automatically rename tracks and fix language tags with near-",
    "  perfect accuracy.`n" | ForEach-Object { Write-Host $_ -ForegroundColor DarkCyan }
    
    Write-Host " DEPENDENCIES:" -ForegroundColor DarkYellow
    "  • MKVToolNix (mkvmerge): Used for deep-probing file headers and", 
    "    extracting detailed track metadata for the audit.",
    "  • MKVToolNix (mkvextract): Utilized by the Deep Subtitle Audit engine",
    "    to dump raw subtitle streams for size comparison analysis.",    
    "  • MKVToolNix (mkvpropedit): The primary tool for the 'Fix' engine,", 
    "    allowing instant metadata edits without remuxing the file.", 
    "  • MediaInfo: Utilized specifically during NoHW searches", 
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
    Write-Host "    .\MKVMetadataAuditor+Fixer.ps1 -FixNoBackup -sc 'ass,srt' -ovrd -Path 'G:\Media\Anime'`n" -ForegroundColor DarkCyan
    
    Write-Host "  Hardware Compatibility Deep Scan (NoHW Search):`n" -ForegroundColor DarkGray
    Write-Host "    .\MKVMetadataAuditor+Fixer.ps1 -nohw -fast -Path 'G:\Media\Anime'`n" -ForegroundColor DarkMagenta
    
    Write-Host "`n CORE FLAGS:`n" -ForegroundColor DarkYellow

    &$PrintManualBlock "  -Path <string>" @(
    "      Defines the target directory. The script will recursively scan all",
    "      subfolders for MKV files to perform bulk auditing.`n"
)

    &$PrintManualBlock "  -Fix" @(
    "      Enables 'Write Mode'. Without this, the script runs in read-only",
    "      audit mode, generating logs without modifying any files.`n"
)    
                        
    &$PrintManualBlock "  -FixNoBackup" @(
    "      Disables the safety-net creation of the '_updated' mirror folder.",
    "      By default, the script protects your library by writing all",
    "      changes to a sibling directory, leaving your original files untouched.",
    "      Enabling this flag forces a 'Surgical Overwrite' directly on your",
    "      source media. This is significantly faster and saves disk space",
    "      but is irreversible if your scoring logic is misconfigured.`n"
) -ForceDescColor "DarkRed"
    
    &$PrintManualBlock "  -overrideDefaults | -ovrd" @(
    "      Acts as the 'Configuration Safety Lock'. To prevent accidental",
    "      changes to your long-term library rules, any track priorities",
    "      passed via the command line (like -aud or -sub) will be ignored",
    "      unless this flag is present. When used, it commits your current",
    "      session parameters to the JSON config file, making them the new",
    "      permanent defaults for all future audits.`n"
)
    
    Write-Host "`n MODE FLAGS:`n" -ForegroundColor DarkYellow

    &$PrintManualBlock "  -Western | -w | -west | -WesternMode" @(
    "      Sets defaults for Western media (English audio/subs).`n"
)

    &$PrintManualBlock "  -NoHwVideoSearch | -nohw" @(
    "      Initiates a specialized compatibility audit targeting video profiles",
    "      that lack Hardware Acceleration (NoHW) on consumer devices.",
    "      It specifically isolates legacy AVC High 10 (10-bit) encodes,",
    "      Chroma 4:2:2, Chroma 4:4:4, and RGB color spaces. These profiles",
    "      frequently cause stuttering or playback failure on Smart TVs,",
    "      mobile phones, and older streaming boxes.`n"
)    
    
    &$PrintManualBlock "  -fast" @(
    "      Speeds up the NoHW Search by skipping extended metadata",
    "      checks. In this mode, progress tracks Folders processed.`n"
)
    
    &$PrintManualBlock "  -LogFullPath | -lfp" @(
    "      Forces the log to write the full file path instead of just the folder",
    "      path during a fast NoHW search. Requires -fast.`n"
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

    &$PrintManualBlock "  -SubtitleFactorTrackOrder | -SFTO | -TrackOrder" @(
    "      Activates a 'Positional Penalty' within the scoring engine.",
    "      When active, every subtitle track is penalized -40 points for each",
    "      position it occupies away from the top. This is extremely effective",
    "      for media groups that consistently place their primary dialogue",
    "      track as the first subtitle entry, as it prevents high-scoring",
    "      specialty tracks appearing later from accidentally winning.`n"
)
    
    &$PrintManualBlock "  -FansubGroupPriority | -fg <string>" @(
    "      Sets preferred fansub groups for subtitle track prioritization",
    "      (e.g., -fg 'commie'). Pass an empty string (`"`") to clear the",
    "      list and reset preferences via command line.`n"
)

    &$PrintManualBlock "  -DeepSubtitleAudit | -DSA | -Deep | -DeepAudit" @(
    "      Enables the 'Intelligence Tier' of the auditor. This is designed",
    "      specifically for files with missing or ambiguous track names.",
    "      It operates in three distinct stages:",
    "      1. HEADER PROBE: Checks if internal statistics can resolve the role.",
    "      2. EXTRACTION: Dumps raw subtitle samples to the TEMP directory.",
    "      3. ANALYSIS: Compares bitstream character density and file ratios.",
    "      Files with a size ratio of 2.0x (Text) or 3.0x (Image) are automatically",
    "      identified; the larger stream is tagged as 'Full Dialogue' and the",
    "      smaller as 'Signs & Songs'. When combined with -Fix, it will",
    "      permanently rename the tracks to match these discoveries.`n"
)

    &$PrintManualBlock "  -DeepSubtitleAuditDebugExtraction | -DSADE" @(
    "      Forces the DSA engine to perform a full bitstream extraction even when",
    "      statistical headers (like NUMBER_OF_FRAMES) are present. While text-based",
    "      tracks already require extraction for Language Detection, this flag is",
    "      essential for forcing a physical size check on Image tracks (PGS/VobSub)",
    "      or when Language Detection is disabled via -NLD.`n"
)

    &$PrintManualBlock "  -DeepSubtitleAuditLanguageDetectionLimit2 | -DSALDL2 | -LDL2" @(
    "      Limits the DSA engine to files containing only 1 or 2 subtitle tracks.",
    "      When active, files with 3 or more subtitles will be skipped entirely",
    "      by the Deep Audit engine.`n"
)


    &$PrintManualBlock "  -DeepSubtitleAuditNOLanguageDetection | -DSANLD | -NLD" @(
    "      Disables the linguistic probe within the DSA engine. When active,",
    "      the script will skip checking for Japanese Kana, Hangul, or English",
    "      honorifics, relying solely on bitstream size ratios to identify",
    "      dialogue tracks. Useful for speeding up audits on libraries where",
    "      language tags are already trusted.`n"
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
    "      Enables 'Closed-Loop Verification'. Immediately after the fixing",
    "      phase concludes, the script automatically launches a new audit",
    "      session targeting the newly created '_updated' files (or the source",
    "      if -FixNoBackup is active). This second pass confirms that all",
    "      Mismatch Groups have been resolved and that the resulting headers",
    "      now perfectly align with your requested configuration.`n"
)    
    
    &$PrintManualBlock "  -Sequential | -seq" @(
    "      Disables parallel processing and forces the script to analyze",
    "      one file at a time. This is useful for troubleshooting performance",
    "      issues, identifying specific file locks, or reducing system",
    "      resource competition on legacy hardware.`n"

)

    &$PrintManualBlock "  -DevDebug | -Dev | -DevD | -DBG" @(
    "      Exposes the 'Black Box' of the script's internal logic. It disables",
    "      UI suppression and surfaces detailed telemetry, including:",
    "      1. TOOL PATHS: Verifies system paths for MKVToolNix and MediaInfo."
    "      2. SCORING BREAKDOWN: Prints the exact arithmetic used to score",
    "         every track (e.g., CodecMatch:+100 | Dialogue:+150).",
    "      3. DSA TRACING: Displays real-time sizing ratios and character",
    "         counts during Deep Subtitle extractions.",
    "      4. ERROR LOGGING: Captures raw CLI output from backend tools to",
    "         troubleshoot corrupted headers or file access issues.`n"
)
    
    &$PrintManualBlock "  -help | -manual" @(
    "      Displays this manual for MKVMetadataAuditor+Fixer.ps1. The one you are",
    "      reading right now.`n"
)
    
    &$PrintManualBlock "  -DelLog" @(
    "      Performs a 'Fresh Start' by purging the MKVMetadataAuditor+Fixer_logs",
    "      directory before the scan begins. This is highly recommended when",
    "      running audits on different libraries to prevent session logs from",
    "      cluttering the folder and making it difficult to find current results.`n"
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


# --- SEARCH FLAG RESTRICTION ---
#       Modified for Global Debug 
if (($PSBoundParameters.ContainsKey('fast') -or $PSBoundParameters.ContainsKey('LogFullPath')) -and -not $NoHwVideoSearch) {
    Write-Host "`n[ERROR] Search-specific flag(s) detected." -ForegroundColor DarkRed
    Write-Host "The flags -fast and -lfp require -nohw (NoHwVideoSearch) to be active.`n" -ForegroundColor DarkYellow
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

# NoHW Video Search Whitelist Validation
if ($NoHwVideoSearch) {
    
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
    $allowedNoHwFlags = @('NoHwVideoSearch', 'Fast', 'disableRecurse', 'Path', 'nohw', 'PathParts', 'ep', 'excludePaths', 'LogFullPath', 'lfp', 'DevDebug', 'Sequential', 'seq')

    # Check every flag the user actually typed
    foreach ($param in $PSBoundParameters.Keys) {
        if ($param -notin $allowedNoHwFlags) {
            Write-Host ""
            Write-Host " [!] ERROR: Invalid flag combination." -ForegroundColor DarkRed
            Write-Host " When using -nohw, you cannot use -$param." -ForegroundColor DarkYellow
            Write-Host " Permitted with -nohw: -Fast, -disableRecurse, and -Path." -ForegroundColor Gray
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

# Tool Discovery (Gather paths before initializing engines)
$tools = Get-MKVToolPaths
$mkvpropedit  = $tools.propedit
$mkvmerge     = $tools.merge
$mkvextract   = $tools.extract
$mediainfoDll = $tools.mediainfoDll
$mediainfoExe = $tools.mediainfoExe

# --- FINAL VALIDATION ---
$missingTools = New-Object System.Collections.Generic.List[string]

if ([string]::IsNullOrWhiteSpace($mkvpropedit) -or -not (Test-Path -LiteralPath $mkvpropedit)) { [void]$missingTools.Add("mkvpropedit.exe (MKVToolNix)") }
if ([string]::IsNullOrWhiteSpace($mkvmerge) -or -not (Test-Path -LiteralPath $mkvmerge))    { [void]$missingTools.Add("mkvmerge.exe (MKVToolNix)") }

# Check for DLL: Try the discovered path first, then manually scan System PATH
$dllExists = if ([string]::IsNullOrWhiteSpace($mediainfoDll)) { $false } else { Test-Path -LiteralPath $mediainfoDll }
if (-not $dllExists) {
    $dllExists = @($env:Path.Split(';', [System.StringSplitOptions]::RemoveEmptyEntries) | Where-Object { Test-Path (Join-Path $_ "MediaInfo.dll") }).Count -gt 0
}
if (-not $dllExists) { [void]$missingTools.Add("MediaInfo.dll (MediaInfo)") }

# [MOD] NoHw Mode: Require MediaInfo CLI for Long Path routing
if ($NoHwVideoSearch) {
    if ([string]::IsNullOrWhiteSpace($mediainfoExe) -or -not (Test-Path -LiteralPath $mediainfoExe)) {
        [void]$missingTools.Add("mediainfo.exe (CLI required for Long Path support)")
    }
}

# 2. Unified Missing Report (Decision point)
if ($missingTools.Count -gt 0) {
    Write-Host "`n [!] ERROR: The following dependencies are missing:" -ForegroundColor DarkRed
    $missingTools.Sort({ param($a,$b) [NaturalSort]::StrCmpLogicalW($a, $b) })
    $missingTools | ForEach-Object { Write-Host "     -> $_" -ForegroundColor DarkYellow }
    
    Write-Host "`n [TIP] If you recently installed these tools or modified your System PATH," -ForegroundColor Cyan
    Write-Host "       please reboot your computer to ensure the changes are applied." -ForegroundColor Cyan
    
    $needed = New-Object System.Collections.Generic.List[string]
    if ($missingTools -match "MKVToolNix") { [void]$needed.Add("MKVToolNix") }
    if ($missingTools -match "MediaInfo")  { [void]$needed.Add("MediaInfo") }
    
    Write-Host "`n Please install $($needed -join ' and ') to proceed." -ForegroundColor Gray
    Pause; exit
}

# 3. Final Initialization (Only triggers if everything above was found)
Initialize-MediaInfo -DllPath $mediainfoDll

# [CHANGE] v2026.05.29__15.11.02 - Debug Tool Path Visibility
if ($DevDebug) {
    Write-Host "`n [DevDebug-Main] Tool Discovery:" -ForegroundColor DarkYellow
    Write-Host "  -> mkvmerge:    $mkvmerge" -ForegroundColor Gray
    Write-Host "  -> mkvpropedit: $mkvpropedit" -ForegroundColor Gray
    Write-Host "  -> mkvextract:  $mkvextract" -ForegroundColor Gray
    Write-Host "  -> MediaInfo DLL: $mediainfoDll" -ForegroundColor Gray
    Write-Host "  -> MediaInfo CLI: $mediainfoExe`n" -ForegroundColor Gray
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

# (Block moved for diagnostic capture)

# (Sequential override moved to hardware tuning block)

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
$noHwLogDir = Join-Path $rootLog "NoHw_Logs"
$vLogDir = Join-Path $rootLog "Updates_Verification_Logs"
$tLogDir = Join-Path $rootLog "DevDebug-Terminal_Logs"

# Define the timestamp once for all logs
$ts = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

# Create the folders
foreach ($dir in @($rootLog,$pLogDir,$dLogDir,$mLogDir,$cLogDir,$fLogDir,$noHwLogDir,$vLogDir,$tLogDir)) { 
    if (-not (Test-Path $dir)) { New-Item $dir -ItemType Directory | Out-Null } 
}

# Define the individual log files using that single $ts
$pathLog = Join-Path $pLogDir "MKVMetadataAuditor+Fixer_Paths_$($ts)-log.txt"
$detailLog = Join-Path $dLogDir "MKVMetadataAuditor+Fixer_Details_$($ts)-log.txt"
$missLog = Join-Path $mLogDir "MKVMetadataAuditor+Fixer_Mismatches_$($ts)-log.txt"
$compLog = Join-Path $cLogDir "MKVMetadataAuditor+Fixer_Comparison_$($ts)-log.txt"
$fixerLog = Join-Path $fLogDir "MKVMetadataAuditor+Fixer_FIX_QUEUE_$($ts)-log.txt"
$noHwLog = Join-Path $noHwLogDir "MKVMetadataAuditor+Fixer_NoHw_$($ts)-log.txt"
$verifyLog = Join-Path $vLogDir "MKVMetadataAuditor+Fixer_Updates_Verification_$($ts)-log.txt"
$terminalLog = Join-Path $tLogDir "MKVMetadataAuditor+Fixer_DevDebug-Terminal_$($ts)-log.txt"

# --- START TERMINAL CAPTURE ---
if ($DevDebug) {
    Start-Transcript -Path $terminalLog -Append -Force | Out-Null
}

# --- THROTTLE LIMIT AUTO-TUNING & PERSISTENT CACHE ---
$script:OptimalThrottleLimit = 4 
$script:ThrottleReason = "Default (Conservative)"
$cacheFile = Join-Path $PSScriptRoot "MKVMetadataAuditor+Fixer.drive_cache.json"

if ($Sequential) {
    $script:OptimalThrottleLimit = 1
    $script:ThrottleReason = "User Forced (Sequential)"
} elseif ($inputPaths.Count -gt 0) {
    if ($DevDebug) { Write-Host "`n [DevDebug-Tuning] Probe Start..." -ForegroundColor DarkCyan }
    
    $path = $inputPaths[0]
    $root = if ($path.StartsWith("\\")) { $path.Split('\')[0..3] -join '\' } else { [System.IO.Path]::GetPathRoot($path) }
    
    # 1. Check Persistence Cache
    $cache = @{}
    $isCacheValid = $false
    if (Test-Path $cacheFile) {
        try {
            $now = Get-Date
            $today6AM = $now.Date.AddHours(6)
            $last6AM = if ($now -lt $today6AM) { $today6AM.AddDays(-1) } else { $today6AM }
            
            if ((Get-Item $cacheFile).LastWriteTime -ge $last6AM) {
                $cache = Get-Content $cacheFile | ConvertFrom-Json -AsHashtable
                if ($cache.ContainsKey($root)) {
                    $script:OptimalThrottleLimit = $cache[$root].Limit
                    $script:ThrottleReason = $cache[$root].Reason + " (Cached)"
                    $isCacheValid = $true
                }
            }
        } catch {}
    }

    # 2. Hardware Probe (Only if not cached or sequential)
    if (-not $isCacheValid) {
        try {
            if ($DevDebug) { Write-Host " [DevDebug-Tuning] Path: $path" -ForegroundColor Gray }
            if ($path.StartsWith("\\")) {
                $script:OptimalThrottleLimit = 3
                $script:ThrottleReason = "Network (UNC Path)"
            } else {
                $drive = [System.IO.DriveInfo]::new($root)
                if ($DevDebug) { Write-Host " [DevDebug-Tuning] Root: $root | Type: $($drive.DriveType)" -ForegroundColor Gray }

                if ($drive.DriveType -eq "Network") {
                    $script:OptimalThrottleLimit = 3
                    $script:ThrottleReason = "Network (Mapped Drive)"
                } elseif ($IsWindows) {
                    $id = $root.TrimEnd('\')
                    $p = Get-CimInstance -Query "Associators of {Win32_LogicalDisk.DeviceID='$id'} where AssocClass=Win32_LogicalDiskToPartition" -ErrorAction SilentlyContinue
                    $d = Get-CimInstance -Query "Associators of {Win32_DiskPartition.DeviceID='$($p.DeviceID)'} where AssocClass=Win32_DiskDriveToDiskPartition" -ErrorAction SilentlyContinue
                    
                    if ($null -ne $d.Index) {
                        if ($DevDebug) { Write-Host " [DevDebug-Tuning] CIM Map: Part:$($p.DeviceID) | Index:$($d.Index)" -ForegroundColor Gray }
                        $phys = Get-PhysicalDisk | Where-Object { "$($_.DeviceId)" -eq "$($d.Index)" } -ErrorAction SilentlyContinue
                        if ($phys) {
                            $bus = "$($phys.BusType)"; $media = "$($phys.MediaType)"
                            if ($DevDebug) { Write-Host " [DevDebug-Tuning] StorageAPI: $($phys.FriendlyName) | Bus:$bus | Media:$media | Spindle:$($phys.SpindleSpeed)" -ForegroundColor Gray }
                            
                            $isFast = ($phys.SpindleSpeed -eq 0) -or ($media -match "SSD") -or ($bus -match "NVMe|SSD")
                            if ($bus -match "USB") { 
                                $isFast = ($media -match "SSD") 
                                if ($DevDebug) { Write-Host " [DevDebug-Tuning] USB Device Logic: Explicit SSD Required -> Match: $isFast" -ForegroundColor Gray }
                            }

                            if ($isFast) { $script:OptimalThrottleLimit = [Environment]::ProcessorCount; $script:ThrottleReason = "Local SSD/NVMe (Full Parallel)" }
                            else { $script:OptimalThrottleLimit = 2; $script:ThrottleReason = "Local HDD (Reduced Parallel)" }
                        } else { 
                            if ($DevDebug) { Write-Host " [DevDebug-Tuning] StorageAPI failed for index $($d.Index)" -ForegroundColor DarkYellow }
                            $script:ThrottleReason = "Local Disk (Generic)" 
                        }
                    } else { 
                        if ($DevDebug) { Write-Host " [DevDebug-Tuning] CIM mapping failed for drive $id" -ForegroundColor DarkYellow }
                        $script:ThrottleReason = "Local Disk (WMI Map Fail)" 
                    }
                }
            }
            # Update Cache
            $cache[$root] = @{ Limit = $script:OptimalThrottleLimit; Reason = $script:ThrottleReason }
            $cache | ConvertTo-Json | Out-File $cacheFile -Encoding utf8
        } catch {
            if ($DevDebug) { Write-Host " [DevDebug-Tuning] ERROR: $($_.Exception.Message)" -ForegroundColor Red }
        }
    }
}

if ($DevDebug) { Write-Host " [DevDebug-Tuning] Final Selection: $script:OptimalThrottleLimit Threads | Reason: $script:ThrottleReason`n" -ForegroundColor DarkCyan }

# --- GLOBAL TEMP CONFIGURATION ---
$script:GlobalTemp = Join-Path $env:TEMP "MKVMetadataAuditor+Fixer"

# Startup Cleanup: Clear old artifacts from previous sessions
if (Test-Path $script:GlobalTemp) { 
    Remove-Item -LiteralPath $script:GlobalTemp -Recurse -Force -ErrorAction SilentlyContinue 
}
New-Item -Path $script:GlobalTemp -ItemType Directory -Force | Out-Null

$noHwList = New-Object System.Collections.Generic.List[string]
$sessionFlags = New-Object System.Collections.Generic.HashSet[string]
$sessionNoHwList = New-Object System.Collections.Generic.List[string]
$noHwCount = 0
$corruptCount = 0

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
# Added word boundaries (\b) to OP and ED to prevent matching strings like "Modified" or "Styled".
$script:RegexSign = "Sign|Song|Lyric|Opening|Ending|\bOP\b|\bED\b|Partial|Forced|Translation|ASSR|S&S|S\s&\sS|Dubtitle"

# [2026.06.13] Centralized Honorifics & Sanitizer
$script:RegexHon = "(?<!\b(?:no|non|without|removed)[-\s(]*)(?:honorific|honor)"
$script:RegexSanitizer = "(?i)\b(full|dialogue|dialog|honorifics?|honor|signs|songs|english|eng|subs|subtitles|main|lyrics|translated|translation|with|without)\b"

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

if ($NoHwVideoSearch) {
    $fastStatus = if ($fast) { " Fast" } else { "" }
    $recurseStatus = if ($disableRecurse) { " [No-Recurse]" } else { "" }
    $noHwLogFullPathStatus = if ($LogFullPath) { " Log Full Path" } else { "" }
    $displayMode = "NoHW Video Search Mode$fastStatus$recurseStatus$noHwLogFullPathStatus$GlobalDebugStatus"
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
if (-not $NoHwVideoSearch) {
Write-Host "Config Status: " -NoNewline; Write-Host $configSource -ForegroundColor DarkMagenta
Write-Host "Config Path:   " -NoNewline; Write-Host $configFile -ForegroundColor DarkGray

Write-Host "--------------------------------------------------"
}

$hasOptions = (-not $NoHwVideoSearch) -or ($fast -or $LogFullPath -or $DevDebug)
if ($hasOptions) {
    Write-Host "LOADED OPTIONS:" -ForegroundColor DarkGreen
    
    if (-not $NoHwVideoSearch) {
        Write-Host "  Video Target: " -NoNewline; Write-Host "$($fixerConfig.Video.TargetLanguage)" -ForegroundColor Blue
        Write-Host "  Audio Target: " -NoNewline; Write-Host "$($fixerConfig.Audio.PreferredLanguage)" -ForegroundColor DarkMagenta
        Write-Host "  Sub Target:   " -NoNewline; Write-Host "$($fixerConfig.Subtitles.PreferredLanguage)" -ForegroundColor Blue
        Write-Host "  Sub Codecs:   " -NoNewline; Write-Host "$($fixerConfig.Subtitles.CodecPriority -join ', ')" -ForegroundColor DarkMagenta
        
        if ($SubtitleFactorTrackOrder) {
            Write-Host "  Track Order:  " -NoNewline; Write-Host "Active (-SFTO)" -ForegroundColor Cyan
        }
        
        if ($DeepSubtitleAudit) {
            $dsaDisp = "Active"
            $dsaFlags = New-Object System.Collections.Generic.List[string]
            if ($PSBoundParameters.ContainsKey('DeepSubtitleAudit')) { [void]$dsaFlags.Add("Full Pass") }
            if ($DeepSubtitleAuditDebugExtraction) { [void]$dsaFlags.Add("Forced Extraction") }
            if ($DeepSubtitleAuditLanguageDetectionLimit2) { [void]$dsaFlags.Add("2-Track Limit") }
            if ($DeepSubtitleAuditNOLanguageDetection) { [void]$dsaFlags.Add("No Lng Detect") }
            
            if ($dsaFlags.Count -gt 0) { $dsaDisp += " ($($dsaFlags -join ' + '))" }
            Write-Host "  Deep Audit:   " -NoNewline; Write-Host "$dsaDisp" -ForegroundColor Cyan
        }

        if ($Honorifics) {
            Write-Host "  Honorifics:   " -NoNewline; Write-Host "$(if ($Honorifics) { "On" } else { "Off" })" -ForegroundColor Blue
        }

        if ($fixerConfig.Subtitles.FansubGroupPriority -and $fixerConfig.Subtitles.FansubGroupPriority.Count -gt 0) {
            Write-Host "  Fansub Pref:  " -NoNewline; Write-Host "$($fixerConfig.Subtitles.FansubGroupPriority -join ', ')" -ForegroundColor Cyan
        }
    }

    if ($NoHwVideoSearch) {
        if ($Fast) { Write-Host "  Fast Mode:    " -NoNewline; Write-Host "On (-fast)" -ForegroundColor Magenta }
        if ($LogFullPath) { Write-Host "  Full Path Log:" -NoNewline; Write-Host "On (-lfp)" -ForegroundColor DarkCyan  }
    }

    if ($DevDebug) { 
        Write-Host "  Global Debug: " -NoNewline; Write-Host "Active (-Dev)" -ForegroundColor DarkYellow 
        Write-Host "  Parallel Tune:" -NoNewline; Write-Host " $script:OptimalThrottleLimit Threads ($script:ThrottleReason)" -ForegroundColor Gray
    }
    
    Write-Host "--------------------------------------------------"
}

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
            $destPath = if ([System.IO.File]::Exists($p)) {
                Join-Path (Split-Path $p -Parent) "_updated"
            } else {
                $p.TrimEnd('\') + "_updated"
            }
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
            $verifyDest = if ([System.IO.File]::Exists($p)) {
                Join-Path (Split-Path $p -Parent) "_updated"
            } else {
                $p.TrimEnd('\') + "_updated"
            }
            Write-Host "  -> Post-Fix Audit Target: $verifyDest" -ForegroundColor Cyan
        }
    } else {
        Write-Host "  -> Post-Fix Audit Target: [Source Folders Directly]" -ForegroundColor Cyan
    }
}
Write-Host "--------------------------------------------------"

# Determine Start Message
$startMessage = if ($NoHwVideoSearch -and $Fast -and $LogFullPath) { 
    "Begin NoHW Search (Fast) with Full Path Logging?" 
} elseif ($NoHwVideoSearch -and $Fast) { 
    "Begin NoHW Video Search Fast?"
} elseif ($NoHwVideoSearch) { 
    "Begin NoHW Search?"
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

if ($VerifyUpdates -and -not $NoHwVideoSearch -and $verifyPaths.Count -gt 0) {
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
    # Prevent Divide-by-Zero if no files are found
    if ($Total -eq 0) { $percent = 0 } 
    else { $percent = [Math]::Min(100, [Math]::Max(0, [int]($Current / $Total * 100))) }
    $width = 30 
    $done = [Math]::Min($width, [int]($percent / 100 * $width))
    $left = $width - $done
    
    $bar = ("█" * $done) + ("░" * $left)
    # Time Calculations
    $elapsed = [DateTime]::Now - $script:SessionStartTime
    $te = "{0:hh\:mm\:ss}" -f $elapsed
    
    $tr = "--:--:--"
    if ($Current -gt 0) {
        $secPerFile = $elapsed.TotalSeconds / $Current
        $remainingSecs = $secPerFile * ($Total - $Current)
        $tr = "{0:hh\:mm\:ss}" -f [TimeSpan]::FromSeconds($remainingSecs)
    }

    # Adaptive splitting for long descriptions to prevent terminal wrapping
    if ($Message -match '^(.*?)\s*(\(.*)$') {
        $line1 = "         " + $Matches[1]
        $line2 = "[SHIELD] " + $Matches[2]
        $progressLine = "$line1`r`n${line2}: [$bar] $percent% ($Current/$Total) | TE: $te | ETR: $tr"
    } else {
        $progressLine = "[SHIELD] ${Message}: [$bar] $percent% ($Current/$Total) | TE: $te | ETR: $tr"
    }

    Write-Host "`n$progressLine`n" -ForegroundColor Cyan
}

# 3. Main Processing Loop
# Includes the base folders themselves PLUS all sub-directories

# --- FOLDER DISCOVERY ---
$targetFolders = Get-TargetFolders -InputPaths $inputPaths -DisableRecurse:$disableRecurse -DevDebug:$DevDebug

$fastHeaderWritten = $false

# v2026.05.13_16.32.00 - Log Buffer and Timer
$logBuffer = New-Object System.Collections.Generic.List[string]
$lastFlushTime = [DateTime]::Now

$videoExtensions = @(
    "*.mkv", "*.mp4", "*.m4v", "*.avi", "*.wmv", 
    "*.flv", "*.mov", "*.ts", "*.m2ts", "*.ogm",
    "*.webm", "*.mts", "*.tp", "*.trp", "*.h264", 
    "*.264", "*.avc", "*.3gp", "*.3g2", "*.mpeg", 
    "*.mpg", "*.divx", "*.xvid", "*.rm", "*.rmvb",
    "*.f4v", "*.qt", "*.m4b", "*.m4r", "*.mxf", 
    "*.vob"
)
$searchFilter = if ($NoHwVideoSearch) { $videoExtensions } else { "*.mkv" }

$Host.PrivateData.ProgressForegroundColor = "Cyan"
if ($fast) {
    $totalSessionItems = $targetFolders.Count
} else {
    Write-Host " [i] Initializing session: Counting video files..." -ForegroundColor DarkCyan
    $sessionFileList = New-Object System.Collections.Generic.List[string]
    $folderCounter = 0
    $script:SessionStartTime = [DateTime]::Now
    
    foreach ($folder in $targetFolders) {
        $folderCounter++
        Write-Progress -Activity "Initializing Session" -Status "Scanning Folder $folderCounter of $($targetFolders.Count)" -PercentComplete ([int]($folderCounter / $targetFolders.Count * 100))
        
        if ($DevDebug) { Write-Host " [DevDebug-Scanner] Scanning Folder: $($folder.FullName)" -ForegroundColor DarkGray }

        # Differentiate between FileInfo and DirectoryInfo containers
        if ($folder -is [System.IO.DirectoryInfo]) {
            # Note: -Include is used when searching for multiple extensions
            $found = Get-ChildItem -LiteralPath $folder.FullName -Include $searchFilter -File -Force -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
            if ($found) { $found | ForEach-Object { $sessionFileList.Add([string]$_) } }
        } else {
            # Check if direct file input matches the current search scope
            $isMatch = $false
            foreach ($ext in $searchFilter) { if ($folder.Name -like $ext) { $isMatch = $true; break } }
            if ($isMatch) { $sessionFileList.Add($folder.FullName) }
        }
    }
    
    
    $totalSessionItems = ($sessionFileList | Select-Object -Unique).Count
    Write-Host " [i] Total video files found: $totalSessionItems" -ForegroundColor DarkGreen
    Write-Progress -Activity "Initializing Session" -Completed
}
$sessionProgressIndex = 0
if ($NoHwVideoSearch) {
    # Initialize log with placeholder to ensure the file exists for appending
    @("--- SCAN IN PROGRESS ---", "Results will be finalized at the end of the session.", "") | Out-File -LiteralPath $noHwLog -Encoding utf8
}

foreach ($folderPath in $targetFolders) {
    # [MODULE] Check for Exclusions
    if (Test-IsExcluded -CurrentPath $folderPath.FullName -Exclusions $exclusions -Active:$excludePaths) {
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
    
    if (-not $NoHwVideoSearch -or $DevDebug) {
        Write-Host "Checking: $($folderPath.FullName)..." -ForegroundColor Gray # <--- LIVE FEEDBACK
    }
    $global:GroupMap = @{}
    $global:Counter = 1
    $folder = Get-Item -LiteralPath $folderPath.FullName
    if ($folder -is [System.IO.DirectoryInfo]) {
        # Using -Include for multi-extension support when -AvcHigh10Search is active
        $mkvFiles = Get-ChildItem -LiteralPath $folder.FullName -Include $searchFilter -File | Sort-NaturalFiles
    } else {
        # Logic for when a single file is passed to the script
        $isMatch = $false
        foreach ($ext in $searchFilter) { if ($folder.Name -like $ext) { $isMatch = $true; break } }
        if ($isMatch) {
            $mkvFiles = @($folder)
        } else {
            $mkvFiles = @()
        }
    }
    
    if ($mkvFiles.Count -eq 0) { continue }
    
    # --- DYNAMIC PADDING (PER FOLDER) ---
    # v2026.05.15_15.02.00 - Bypass probes if searching to match Finder speed
    if (-not $NoHwVideoSearch -and $mkvFiles.Count -gt 0) {
        $allCodecs = foreach ($f in $mkvFiles) { (& $mkvmerge -J $f.FullName | ConvertFrom-Json).tracks.codec }
        $codecPadding = [Math]::Max(5, ($allCodecs | Measure-Object -Property Length -Maximum).Maximum)
        
        $allTrackNames = foreach ($f in $mkvFiles) { (& $mkvmerge -J $f.FullName | ConvertFrom-Json).tracks.properties.track_name }
        $namePadding = [Math]::Max(4, ($allTrackNames | Measure-Object -Property Length -Maximum).Maximum)
    } else {
        $codecPadding = 10
        $namePadding = 20
    }
    $propPadding = 9
    
    # NoHW Video SCAN (MediaInfo)
        # This runs BEFORE the auditor/grouping logic so it actually sees the files
        # --- SEARCH LOGIC (NoHW Compatibility Engine) ---

        
        # v2026.05.13_16.08.00 - Finalized Spacing & One-Time Fast Header
        if ($NoHwVideoSearch) {
            $scanFiles = if ($fast) { $mkvFiles | Select-Object -First 1 } else { $mkvFiles }
            $foundFlags = New-Object System.Collections.Generic.HashSet[string]
            
            # Extract functions as scriptblocks for child runspaces (as stateless string)
            $testIsNoHwDef = [string]${function:Test-IsNoHw}

            # Run slow MediaInfo scans in parallel
            $parallelResults = $scanFiles | ForEach-Object -Parallel {
                $f = $_
                $mediainfoDllPath = $using:mediainfoDll
                $testIsNoHwSb = [scriptblock]::Create($using:testIsNoHwDef)
                
                $status = &$testIsNoHwSb -FilePath $f.FullName -MediaInfoDllPath $mediainfoDllPath -MediaInfoExePath $using:mediainfoExe -DevDebug:$using:DevDebug
                
                [PSCustomObject]@{
                    FullName = $f.FullName
                    Name     = $f.Name
                    Status   = $status
                }
            } -ThrottleLimit $script:OptimalThrottleLimit

            # Sequentially process results to guarantee accurate sorting, logs, and console highlights
            foreach ($res in $parallelResults) {
                $sessionProgressIndex++
                if ($sessionProgressIndex % 10 -eq 0 -or $sessionProgressIndex -eq $totalSessionItems) {
                    $statusMsg = if ($fast) { "Processing Folders" } else { "Processing Files" }
                    Write-InlineProgress -Current $sessionProgressIndex -Total $totalSessionItems -Message $statusMsg
                }
                
                if ($DevDebug) { 
                    Write-Host "`n [DevDebug-NoHW] File Path: $($res.FullName)" -ForegroundColor Gray
                    Write-Host " [DevDebug-NoHW] File Name: $($res.Name)" -ForegroundColor DarkGray
                }

                $status = $res.Status
                
                if ($DevDebug) {
                    if (-not $status.IsReadable) { 
                        Write-Host " [DevDebug-NoHW] Status: ERROR | $($status.Error)" -ForegroundColor Red 
                    } else {
                        Write-Host " [DevDebug-NoHW] Status: $($status.Format) | $($status.Profile) | $($status.Chroma) | $($status.Space)" -ForegroundColor Gray
                    }
                }

                if (-not $status.IsReadable) {
                    $corruptCount++
                    [void]$foundFlags.Add("💀[Corrupt/No Tracks Found]")
                    $errPath = if ($fast -and -not $LogFullPath) { $folderPath.FullName.TrimEnd('\') } else { $res.FullName }
                    $noHwList.Add("💀 [ERROR] UNREADABLE: $errPath - Reason: $($status.Error)")
                    Write-Host "`n  [!] CORRUPT/UNREADABLE FILE FOUND: $($res.Name)" -ForegroundColor DarkRed
                }
                elseif ($status.IsNoHw) {
                    $noHwCount++
                    
                    # Collect Detected Flags for the Folder Entry
                    if ($status.Flags -match "Hi10P") { [void]$foundFlags.Add("🔟[NoHW: AVC Hi10P]") }
                    if ($status.Flags -match "4:2:2") { [void]$foundFlags.Add("🎨[NoHW: Chroma 4:2:2]") }
                    if ($status.Flags -match "4:4:4") { [void]$foundFlags.Add("🎨[NoHW: Chroma 4:4:4]") }
                    if ($status.Flags -match "RGB")   { [void]$foundFlags.Add("🌈[NoHW: RGB]") }

                    $entryToAdd = if ($fast -and -not $LogFullPath) { $folderPath.FullName.TrimEnd('\') } else { $res.FullName }
                    $noHwList.Add($entryToAdd)
                    
                    Write-Host "`n  [!] Found NoHW ($($status.Flags)): $($res.Name)" -ForegroundColor DarkYellow
                }
            }
            # Dynamic Session Aggregation
            foreach ($flag in $foundFlags) { [void]$sessionFlags.Add($flag) }
            foreach ($item in $noHwList)   { $sessionNoHwList.Add($item) }
            $noHwList.Clear()
            Write-Host "" # Clears the inline progress line

            # CHECK TIMER: If 60 seconds passed, flush session results to disk for data safety
            if (([DateTime]::Now - $lastFlushTime).TotalSeconds -ge 60 -and $sessionNoHwList.Count -gt 0) {
                Write-Host " [i] 60s Elapsed: Flushing discoveries to disk for safety..." -ForegroundColor Cyan
                # Use .NET AppendAllLines to guarantee one entry per line, bypassing PS formatting
                [System.IO.File]::AppendAllLines($noHwLog, [string[]]$sessionNoHwList)
                $sessionNoHwList.Clear()
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
    if ($NoHwVideoSearch) {
        Write-Host " [✓] AVC High 10 Scan complete for this folder." -ForegroundColor DarkGreen
    } else {
        $mkvCount = $mkvFiles.Count
        $orderedGroups = New-Object System.Collections.Generic.List[PSObject]
        
        # Prepare helper function block for external runspaces (as stateless string)
        $testIsNoHwDef = [string]${function:Test-IsNoHw}
        $analyzerMsg = if ($CurrentJob.Mode -eq "Verification") { "Verifying Updates" } else { "Analyzing Files" }
        Write-InlineProgress -Current 0 -Total $mkvCount -Message "$analyzerMsg (Parallel Probe)"

        # Run heavy probes in parallel
        $probeResults = $mkvFiles | ForEach-Object -Parallel {
            $f = $_
            $mkvmergePath = $using:mkvmerge
            $mediainfoDllPath = $using:mediainfoDll
            $testIsNoHwSb = [scriptblock]::Create($using:testIsNoHwDef)

            $json = & $mkvmergePath -J $f.FullName | ConvertFrom-Json
            $noHwStatus = &$testIsNoHwSb -FilePath $f.FullName -MediaInfoDllPath $mediainfoDllPath -MediaInfoExePath $using:mediainfoExe -DevDebug:$using:DevDebug

            [PSCustomObject]@{
                FullName   = $f.FullName
                Json       = $json
                NoHwStatus = $noHwStatus
            }
        } -ThrottleLimit $script:OptimalThrottleLimit

        # Create a fast lookup map from our parallel probe
        $probeMap = @{}
        foreach ($res in $probeResults) {
            $probeMap[$res.FullName] = $res
        }

        # Sequentially map groups to preserve absolute alphabetical sorting
        for ($i = 0; $i -lt $mkvCount; $i++) {
            $f = $mkvFiles[$i]
            Write-InlineProgress -Current ($i + 1) -Total $mkvCount -Message $analyzerMsg
            
            if ($DevDebug) {
                Write-Host "`n`n`n [DevDebug-Main] File Path: $($f.FullName)" -ForegroundColor Gray
                Write-Host " [DevDebug-Main] File Name: $($f.Name)" -ForegroundColor DarkGray
            }
            
            # 2. Log path to file
            $f.FullName | Out-File $pathLog -Append -Encoding utf8
            
            # 3. Retrieve pre-probed data instantly from memory
            $cached = $probeMap[$f.FullName]
            $json = $cached.Json
            $noHwStatus = $cached.NoHwStatus

            $f | Add-Member -NotePropertyName "PristineJson" -NotePropertyValue $json -Force
            
            Get-AuditSelector -Reset
            $sig = (($json.tracks | ForEach-Object { 
                $p = $_.properties
                $tType = if ($_.type) { $_.type } else { "unknown" }
                $sel = Get-AuditSelector $tType
                $hwSig = if ($_.type -eq "video" -and $noHwStatus.IsReadable) { "|NoHW:$($noHwStatus.Flags)" } else { "" }
                "$($_.id)|$sel|$($tType)|$($_.codec)|$($p.language)|Def:$([bool]$p.default_track)|Frc:$([bool]$p.forced_track)|HI:$([bool]$p.flag_hearing_impaired)|$($p.track_name)$hwSig" 
            }) -join "`n")
            
            # Signature Debugging
            if ($DevDebug) {
                Write-Host " [DevDebug-Main] Generating Track Signature..." -ForegroundColor DarkCyan
                $sig.Split("`n") | ForEach-Object { Write-Host "    $($_.Trim())" -ForegroundColor Gray }
            }
            
            # --- SEPARATE NOHW VIDEO SEARCH ---
            if ($NoHwVideoSearch -and (Test-Path -LiteralPath $mediainfoDll)) {
                $status = $noHwStatus
                if ($status.IsNoHw) {
                    $noHwCount++
                    $noHwList.Add($f.FullName)
                    Write-Host " [!] Found NoHW ($($status.Flags)): $($f.Name)" -ForegroundColor DarkYellow
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
            $f | Add-Member -NotePropertyName "ParentGroup" -NotePropertyValue $existingGroup -Force
        }
        
        # v2026.05.13_10.43.00 - Real-time Console Feedback
        if ($NoHwVideoSearch) {
            Write-Host "" # New line
            if ($noHwList.Count -gt 0) {
                Write-Host " [!] Found $($noHwList.Count) NoHW files in: $($folder.Name)" -ForegroundColor DarkYellow
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
            $reasons = Get-AuditFlags -tracks $currentGroup.Json.tracks -IsWestern $Western -fixerConfig $fixerConfig -Honorifics $Honorifics -SubtitlesHearingImpaired $SubtitlesHearingImpaired -FilePath $repFile.FullName -MediaInfoDllPath $mediainfoDll -MediaInfoExePath $mediainfoExe

            
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
        } # <--- END GROUPS LOOP

        # --- PARALLEL DSA PRE-CALCULATION PHASE ---
        $dsaLookupMap = @{}
        if ($DeepSubtitleAudit -and ($CurrentJob.Mode -ne "Verification" -or $DevDebug)) {
            $parentGlobalTemp = $script:GlobalTemp
            $getSubtitleExtensionDef = [string]${function:Get-SubtitleExtension}
            $extractDialogueTextDef = [string]${function:Extract-DialogueText}
            $detectSubtitleLanguageDef = [string]${function:Detect-SubtitleLanguage}

            Write-InlineProgress -Current 0 -Total $mkvCount -Message "Deep Subtitle Analysis (Parallel)"

            $dsaParallelResults = $mkvFiles | ForEach-Object -Parallel {
                $f = $_
                $mkvextractPath = $using:mkvextract
                
                # Setup localized, thread-safe memory logging buffer
                $script:LocalLogsList = [System.Collections.Generic.List[PSCustomObject]]::new()
                
                # Define local proxy to intercept and silence background thread outputs
                function Write-Host {
                    param(
                        [Parameter(ValueFromRemainingArguments=$true)]$Message,
                        [string]$ForegroundColor = "White"
                    )
                    $script:LocalLogsList.Add([PSCustomObject]@{
                        Text  = ($Message -join ' ')
                        Color = $ForegroundColor
                    })
                }

                # Configuration variables passed into the runspace
                $dsaLimit2 = $using:DeepSubtitleAuditLanguageDetectionLimit2
                $dsaDebugEx = $using:DeepSubtitleAuditDebugExtraction
                $dsaNoLng = $using:DeepSubtitleAuditNOLanguageDetection
                $honorificsActive = $using:Honorifics
                $globalTempPath = $using:parentGlobalTemp
                $devDebugActive = $using:DevDebug

                # Pull parsed JSON already attached to the file object
                $json = $f.PristineJson

                $dsaResult = $null
                $getExtSb = [scriptblock]::Create($using:getSubtitleExtensionDef)
                $extractDialogueSb = [scriptblock]::Create($using:extractDialogueTextDef)
                $detectLanguageSb = [scriptblock]::Create($using:detectSubtitleLanguageDef)

                $allSubs = @($json.tracks | Where-Object { $_.type -eq "subtitles" })
                if ($allSubs.Count -ge 1) {
                    $isLdl2Restricted = ($dsaLimit2 -and $allSubs.Count -gt 2)
                    if (-not $isLdl2Restricted) {
                        $weights = @{}
                        $detectedLangs = @{}
                        $isResolved = $false
                        $targetRatio = 3.0

                        # [Stage 2.1] Header Probing Phase (Fast Path)
                        $isImgProbe = ($allSubs[0].codec -match "pgs|vobsub")
                        $skipHeaderForLngDetect = (-not $dsaNoLng -and -not $isImgProbe)

                        if ($devDebugActive -and $skipHeaderForLngDetect -and $allSubs.Count -eq 2) {
                            Write-Host "  [DevDebug-DSA] Header Probe Bypassed: Text extraction required for Language Detection (-NLD is not active)." -ForegroundColor DarkCyan
                        }

                        if (-not $dsaDebugEx -and -not $skipHeaderForLngDetect) {
                            foreach ($sub in $allSubs) {
                                $frames = if ($sub.properties.tag_number_of_frames) { [int64]$sub.properties.tag_number_of_frames } 
                                          elseif ($sub.properties.statistics_tags.NUMBER_OF_FRAMES) { [int64]$sub.properties.statistics_tags.NUMBER_OF_FRAMES } else { 0 }
                                if ($frames -gt 0) { $weights[$sub.id] = $frames }
                            }
                            # Verification of Resolution happens later in the Decision Engine
                        }

                        # [Stage 2.2] Subtitle Extraction Phase (Slow Path)
                        if (-not $isResolved) {
                            # Guarantee unique workspace per thread to avoid race conditions
                            $tempDir = Join-Path $globalTempPath "DSA_Probe_Parallel_$($f.FullName.GetHashCode().ToString('X'))"
                            if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
                            New-Item -Path $tempDir -ItemType Directory | Out-Null
                            
                            $extractArgs = New-Object System.Collections.Generic.List[string]
                            $probeMap = @{}
                            foreach ($sub in $allSubs) {
                                $isImg = ($sub.codec -match "PGS|VobSub")
                                $isLoneImg = $isImg -and -not ($allSubs | Where-Object { $_.id -ne $sub.id -and $_.codec -eq $sub.codec -and $_.properties.language -eq $sub.properties.language })
                                if ($isLoneImg) {
                                    if ($devDebugActive) { Write-Host "  [DevDebug-DSA] Skip Extraction: Track $($sub.id + 1) is a lone Picture track (No pair for ratio)." -ForegroundColor DarkGray }
                                    continue
                                }
                                
                                $ext = &$getExtSb -Codec $sub.codec
                                $tmpPath = Join-Path $tempDir "track$($sub.id + 1).$ext"
                                $extractArgs.Add("$($sub.id):$tmpPath")
                                $probeMap[$sub.id] = $tmpPath
                            }
                            
                            if ($extractArgs.Count -gt 0) {
                                if ($devDebugActive) {
                                    Write-Host "  [DevDebug-DSA] Extracting $($extractArgs.Count) tracks for analysis..." -ForegroundColor DarkCyan
                                }
                                & $mkvextractPath "$($f.FullName)" tracks @extractArgs | Out-Null
                            }
                            
                            foreach ($sub in $allSubs) {
                                $probeFile = $probeMap[$sub.id]
                                if ($null -ne $probeFile -and (Test-Path -LiteralPath $probeFile)) {
                                    $isImageSub = ($sub.codec -match "PGS|VobSub")
                                    if (-not $isImageSub) {
                                        $maxNeeded = [int]::MaxValue
                                        if ($allSubs.Count -eq 1) {
                                            $maxNeeded = if ($dsaNoLng) { 1500 } else { 15000 }
                                        } elseif ($allSubs.Count -gt 2) {
                                            $maxNeeded = 15000
                                        }
                                        $cleanOut = if ($devDebugActive) { Join-Path $tempDir "track$($sub.id + 1)_cleaned.txt" } else { $null }
                                        $cleanText = &$extractDialogueSb -Path $probeFile -OutPath $cleanOut -DevDebug:$devDebugActive -MaxLength $maxNeeded
                                        
                                        # Parallel Language Detection Logic
                                        if (-not $dsaNoLng) {
                                            $subIdx = [array]::IndexOf($allSubs, $sub) + 1
                                            $tmpSel = "s$subIdx"
                                            $sampleText = if ($cleanText.Length -gt 15000) { $cleanText.Substring(0, 15000) } else { $cleanText }
                                            $rawDetected = &$detectLanguageSb -Text $sampleText `
                                                                              -CurrentLang $sub.properties.language `
                                                                              -Honorifics:$honorificsActive `
                                                                              -DevDebug:$devDebugActive `
                                                                              -TrackID $sub.id `
                                                                              -Selector $tmpSel `
                                                                              -TrackName $sub.properties.track_name
                                            
                                            $detectedParts = $rawDetected.Split(':')
                                            $detected = $detectedParts[0]
                                            $honCount = [int]$detectedParts[1]
                                            $theCount = [int]$detectedParts[2]

                                            if ($honCount -gt 0) {
                                                $sub | Add-Member -NotePropertyName "DSA_HonCount" -NotePropertyValue $honCount -Force
                                            }
                                            if ($theCount -ge 0) {
                                                $sub | Add-Member -NotePropertyName "DSA_LinguisticDensity" -NotePropertyValue $theCount -Force
                                            }
                                            $detectedLangs[$sub.id] = $detected
                                        }
                                        $weights[$sub.id] = $cleanText.Length
                                    } else {
                                        $weights[$sub.id] = (Get-Item -LiteralPath $probeFile).Length
                                    }
                                }
                        }

                        if ($devDebugActive) {
                            # Log Resolution SUCCESS (if applicable) for the log stream
                            $pairs = $allSubs | Group-Object { 
                                $isText = $_.codec -match "s_text|utf8|srt|ass|ssa|substationalpha|subrip"
                                $family = if ($isText) { "TEXT" } else { $_.codec }
                                $effL = if ($detectedLangs.ContainsKey($_.id) -and $detectedLangs[$_.id] -ne "und") { $detectedLangs[$_.id] } else { $_.properties.language }
                                "$family|$effL"
                            }
                            foreach ($grp in $pairs) {
                                if ($grp.Count -eq 2) {
                                    $w1 = $weights[$grp.Group[0].id]; $w2 = $weights[$grp.Group[1].id]
                                    if ($w1 -gt 0 -or $w2 -gt 0) {
                                        $ratio = [Math]::Max($w1, $w2) / [Math]::Max(1, [Math]::Min($w1, $w2))
                                        $minReq = if ($grp.Group[0].codec -match "s_text|utf8|srt|ass|ssa|substationalpha|subrip") { 2.0 } else { 3.0 }
                                        if ($ratio -ge $minReq) { Write-Host "[DevDebug-DSA] Bitstream/Text Probe SUCCESS (Ratio: $($ratio.ToString('F2')))" -ForegroundColor Green }
                                        else { Write-Host "    [DevDebug-DSA] Ratio too low for subgroup resolution ($($ratio.ToString('F2')) < $minReq)" -ForegroundColor DarkGray }
                                    }
                                } elseif ($grp.Count -gt 2) {
                                    Write-Host "[DevDebug-DSA] Bitstream/Text Probe SUCCESS (Multi-Track Outlier Detection)" -ForegroundColor Green
                                }
                            }
                            foreach ($sub in $allSubs) {
                                if ($weights.ContainsKey($sub.id)) {
                                    $sIdx = [array]::IndexOf($allSubs, $sub) + 1
                                    $kb = [Math]::Round($weights[$sub.id] / 1024, 3)
                                    Write-Host "    [DevDebug-DSA] Final Weight ID:$($sub.id) - Track $($sub.id + 1) - [s$sIdx]...($kb KB)" -ForegroundColor Gray
                                }
                            }
                            Write-Host "    [DevDebug-DSA] Preservation Active: Files kept at -> $tempDir" -ForegroundColor DarkCyan
                            foreach ($sub in $allSubs) {
                                Write-Host "  [DevDebug-DSA] Found Track:$($sub.id + 1) Name: $($sub.properties.track_name)" -ForegroundColor Gray
                            }
                        }

                        # Compute and validate final sizing ratio
                            # Subgroup Resolution Logic: Check for any pairs that meet the threshold
                            $pairs = $allSubs | Group-Object { 
                                $isText = $_.codec -match "s_text|utf8|srt|ass|ssa|substationalpha|subrip"
                                $family = if ($isText) { "TEXT" } else { $_.codec }
                                # Group by detected language to allow und/spa pairing
                                $effL = if ($detectedLangs.ContainsKey($_.id) -and $detectedLangs[$_.id] -ne "und") { $detectedLangs[$_.id] } else { $_.properties.language }
                                "$family|$effL"
                            }
                            foreach ($grp in $pairs) {
                                if ($grp.Count -eq 2) {
                                    $t1 = $grp.Group[0]; $t2 = $grp.Group[1]
                                    $w1 = $weights[$t1.id]; $w2 = $weights[$t2.id]
                                    if ($w1 -gt 0 -or $w2 -gt 0) {
                                        $ratio = [Math]::Max($w1, $w2) / [Math]::Max(1, [Math]::Min($w1, $w2))
                                        $minReq = if ($t1.codec -match "s_text|utf8|srt|ass|ssa|substationalpha|subrip") { 2.0 } else { 3.0 }
                                        if ($ratio -ge $minReq) { $isResolved = $true }
                                    }
                                } elseif ($grp.Count -gt 2) {
                                    $isResolved = $true
                                }
                            }
                        }
                    }
                # Capture linguistic density weights for commentary disqualification
                    $lingWeights = @{}
                    foreach($sub in $allSubs) { 
                        if ($sub.PSObject.Properties['DSA_LinguisticDensity']) { $lingWeights[$sub.id] = $sub.DSA_LinguisticDensity }
                    }

                    $dsaResult = [PSCustomObject]@{
                        Weights           = $weights
                        DetectedLangs     = $detectedLangs
                        LinguisticWeights = $lingWeights
                        IsResolved        = $isResolved
                        Logs              = @($script:LocalLogsList)
                    }
                }

                [PSCustomObject]@{
                    FullName  = $f.FullName
                    DSAResult = $dsaResult
                }
            } -ThrottleLimit $script:OptimalThrottleLimit

            # Build rapid lookup map for sequential consumption
            foreach ($res in $dsaParallelResults) {
                $dsaLookupMap[$res.FullName] = $res.DSAResult
            }
        }

        # --- GENERATE FIXER QUEUE & EXECUTE SMART FIX (SEQUENTIAL) ---
        $fixProgressCounter = 0
        foreach ($fToFix in $mkvFiles) {
            $fixProgressCounter++
            # [FIX] v2026.06.02_22.09.00 - Dynamic mode reader to eliminate inaccurate labels across passes
            $runProgressLabel = if ($CurrentJob.Mode -eq "Verification") { "Verifying Codec State" } elseif ($IsFixRun) { "Applying Fixes" } else { "Auditing Layout" }
            Write-InlineProgress -Current $fixProgressCounter -Total $mkvCount -Message $runProgressLabel
        

            $currentGroup = $fToFix.ParentGroup
            
            # [FIX] v2026.06.02 - Restore original file state to shared memory using direct assignment
            $fileGuid = "DSA_" + $fToFix.Name.GetHashCode().ToString('X')
            $dsaCtx = $currentGroup.PSObject.Properties[$fileGuid].Value
            
            # [FIX] Slates-Clean Revert: Revert names BEFORE the track loop begins so DSA discoveries are preserved for Fixer evaluation.
            if ($null -ne $dsaCtx) {
                foreach ($track in $fToFix.PristineJson.tracks) {
                    if ($dsaCtx.OriginalNames.ContainsKey($track.id)) {
                        $orig = $dsaCtx.OriginalNames[$track.id]
                        $track.properties.track_name = if ($orig -eq "[None]") { "" } else { $orig }
                    }
                    if ($dsaCtx.OriginalLangs.ContainsKey($track.id)) {
                        $track.properties.language = $dsaCtx.OriginalLangs[$track.id]
                    }
                }
            }

            foreach ($track in $fToFix.PristineJson.tracks) {
                # Clean up temporary DSA flags
                $track.PSObject.Properties.Remove("DSA_DetectedLang")
                if ($track.properties.PSObject.Properties["DSA_Handled"]) { 
                    $track.properties.PSObject.Properties.Remove("DSA_Handled") 
                }
            }

                # 1. Initialize the list FIRST so we can log skips to it
                $fixDetails = New-Object System.Collections.Generic.List[string]
                $Params = @() 
                $needsChange = $false 
                $bestAudioSel = $null; $bestSubSel = $null; $foundPrefAudio = $false
                $subCandidates = @()
                
                # 2. Define videoCount
                $videoCount = ($fToFix.PristineJson.tracks | Where-Object { $_.type -eq "video" } | Measure-Object).Count
                
                # --- [AUDIO FORCE PRE-CHECK] ---
                $undAudioCount = ($fToFix.PristineJson.tracks | Where-Object { $_.type -eq "audio" -and $_.properties.language -eq "und" } | Measure-Object).Count
                $totalAudioCount = ($fToFix.PristineJson.tracks | Where-Object { $_.type -eq "audio" } | Measure-Object).Count
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
                $dsaFileProcessed = $false
                
                # NEW: Define videoCount here so the check below works
                $videoCount = ($fToFix.PristineJson.tracks | Where-Object { $_.type -eq "video" } | Measure-Object).Count
                
                foreach ($t in $fToFix.PristineJson.tracks) {
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
                        if ($DeepSubtitleAudit -and -not $dsaFileProcessed -and ($CurrentJob.Mode -ne "Verification" -or $DevDebug)) {
                            $dsaFileProcessed = $true
                            $fileGuid = "DSA_" + $fToFix.Name.GetHashCode().ToString('X')
                            
                            # --- STAGE 1: DISCOVERY & ELIGIBILITY ---
                            if ($null -eq $currentGroup.PSObject.Properties[$fileGuid]) {
                                $allSubs = @($fToFix.PristineJson.tracks | Where-Object { $_.type -eq "subtitles" })

                                if ($DevDebug) {
                                    Write-Host "  [DevDebug-DSA] Checking file at path: $($fToFix.FullName)" -ForegroundColor Gray
                                    Write-Host "  [DevDebug-DSA] Scanning file: $($fToFix.Name) (Total Subs: $($allSubs.Count))" -ForegroundColor Gray
                                }

                                # [MOD] Discovery Gate: If -LDL2 is active, skip files with > 2 tracks entirely.
                                # Otherwise, allow probes for Honorifics on all tracks.
                                if ($allSubs.Count -ge 1) {
                                    if ($DeepSubtitleAuditLanguageDetectionLimit2 -and $allSubs.Count -gt 2) {
                                        if ($DevDebug) { Write-Host "  [DevDebug-DSA] Skipping: File has $($allSubs.Count) tracks (-LDL2 active)" -ForegroundColor DarkGray }
                                        $currentGroup | Add-Member -MemberType NoteProperty -Name $fileGuid -Value $null -Force
                                         
                                    }
                                    if ($DevDebug) { Write-Host "  [DevDebug-DSA] Discovery: File accepted for Language Probe (Count: $($allSubs.Count))" -ForegroundColor Cyan }

                                    # [TRUTH CAPTURE] Take the snapshot BEFORE language detection runs
                                    $origNames = @{}; $origLangs = @{}
                                    foreach ($sub in $allSubs) {
                                        $origNames[$sub.id] = if ([string]::IsNullOrWhiteSpace($sub.properties.track_name)) { "[None]" } else { $sub.properties.track_name }
                                        $origLangs[$sub.id] = $sub.properties.language
                                    }

                                    $currentGroup | Add-Member -MemberType NoteProperty -Name $fileGuid -Value @{ "Tracks" = $allSubs; "Weights" = @{}; "LinguisticWeights" = @{}; "OriginalNames" = $origNames; "OriginalLangs" = $origLangs; "IsResolved" = $false } -Force
                                } else {
                                    if ($DevDebug -and $isLdl2Restricted) { Write-Host "  [DevDebug-DSA] Skipping: File has $($allSubs.Count) tracks (Limit2 is Active)" -ForegroundColor DarkGray }
                                    elseif ($DevDebug) { Write-Host "  [DevDebug-DSA] Skipping: File does not contain subtitle tracks." -ForegroundColor DarkGray }
                                    $currentGroup | Add-Member -MemberType NoteProperty -Name $fileGuid -Value $null -Force
                                }
                            }

                            $dsaCtx = $currentGroup.PSObject.Properties[$fileGuid].Value
                            if ($null -ne $dsaCtx) {
                                $ambiguousTracks = $dsaCtx.Tracks

                                # Context Discovery: Check for global commentary environment
                                $isGlobalCommentaryEnv = $false
                                $auds = @($fToFix.PristineJson.tracks | Where-Object { $_.type -eq "audio" })
                                foreach ($aud in $auds) {
                                    if ($aud.properties.track_name -match "Commentary|Interview" -or $aud.properties.flag_commentary) {
                                        $isGlobalCommentaryEnv = $true; break
                                    }
                                }
                                # Secondary check: Multi-audio in primary languages
                                if (-not $isGlobalCommentaryEnv) {
                                    $audLangs = $auds | Group-Object { $_.properties.language }
                                    if ($audLangs | Where-Object { $_.Count -gt 1 -and $_.Name -match "jpn|eng|und" }) { 
                                        $isGlobalCommentaryEnv = $true 
                                        if ($DevDebug) { Write-Host "    [DevDebug-DSA] Commentary Env Detected: Multiple audio tracks found for language: $($_.Name)" -ForegroundColor DarkCyan }
                                    }
                                }

                                # --- STAGE 2: PROBING PHASE (Weights and Language Detection) ---
                                if ($dsaCtx.Weights.Count -eq 0) {
                                    $preCalculated = if ($null -ne $dsaLookupMap) { $dsaLookupMap[$fToFix.FullName] } else { $null }
                                    if ($null -ne $preCalculated) {
                                        # Use pre-calculated weights directly
                                        foreach ($key in $preCalculated.Weights.Keys) { $dsaCtx.Weights[$key] = $preCalculated.Weights[$key] }
                                        foreach ($key in $preCalculated.LinguisticWeights.Keys) { $dsaCtx.LinguisticWeights[$key] = $preCalculated.LinguisticWeights[$key] }
                                        $dsaCtx.IsResolved = $preCalculated.IsResolved

                                        # Chronologically play back all captured background logs
                                        if ($DevDebug -and $preCalculated.Logs) {
                                            foreach ($log in $preCalculated.Logs) {
                                                Write-Host $log.Text -ForegroundColor $log.Color
                                            }
                                        }

                                        # Use pre-calculated language tags
                                        foreach ($sub in $ambiguousTracks) {
                                            $detected = $preCalculated.DetectedLangs[$sub.id]
                                            if ($detected -and $detected -ne "und") {
                                                if (-not $sub.PSObject.Properties['DSA_DetectedLang']) {
                                                    $sub | Add-Member -NotePropertyName "DSA_DetectedLang" -NotePropertyValue $detected -Force
                                                }

                                                # [FIX] Oscillation Prevention: Treat 'eng' and 'enm' as equivalent matches.
                                                $isEngEnmEquivalent = ($sub.properties.language -match "eng|enm" -and $detected -match "eng|enm")
                                                                
                                                # [FIX] Convergence: Only fix header if not equivalent (prevents eng <-> enm loops)
                                                if (-not $isEngEnmEquivalent -and $sub.properties.language -ne $detected) {
                                                    $writeLang = if ($detected -eq "enm") { "eng" } else { $detected }
                                                    if ($DevDebug) { Write-Host "  [DevDebug-DSA] Lng Fix: Track $($sub.id + 1) ($($sub.properties.language) -> $writeLang)" -ForegroundColor Yellow }
                                                    # FORCE WRITE: Add to Params immediately to ensure disk update
                                                    if ($Fix) { $Params += @('--edit', "track:$($sub.id + 1)", '--set', "language=$writeLang") }
                                                    $sub.properties.language = $detected
                                                    $needsChange = $true
                                                }
                                            }
                                        }

                                        # Use pre-calculated resolution mappings
                                        if ($preCalculated.IsResolved -and $ambiguousTracks.Count -eq 2) {
                                            $w1 = $dsaCtx.Weights[$ambiguousTracks[0].id]
                                            $w2 = $dsaCtx.Weights[$ambiguousTracks[1].id]
                                            if ($w1 -gt 0 -or $w2 -gt 0) {
                                                $bRatio = [Math]::Max($w1, $w2) / [Math]::Max(1, [Math]::Min($w1, $w2))
                                                $isText1 = $ambiguousTracks[0].codec -match "s_text|utf8|srt|ass|ssa|substationalpha|subrip"
                                                $minReq = if ($isText1) { 2.0 } else { 3.0 }
                                                $currentGroup | Add-Member -MemberType NoteProperty -Name ($fileGuid + "_Ratio") -Value $minReq -Force
                                            }
                                        }
                                    } else {
                                        # Fallback to sequential extraction if parallel pre-calculation results are missing
                                        if ($DevDebug -and $DeepSubtitleAuditNOLanguageDetection) {
                                            Write-Host "  [DevDebug-DSA] Language Detection: DISABLED via flag (-NLD)" -ForegroundColor Gray
                                        }
                                        $isResolved = $false
                                        $targetRatio = 3.0

                                        # [Stage 2.1] FAST-PATH: Header Probe (Only valid for Dual-English pairs)
                                        $isImgProbe = ($ambiguousTracks[0].codec -match "pgs|vobsub")
                                        $skipHeaderForLngDetect = (-not $DeepSubtitleAuditNOLanguageDetection -and -not $isImgProbe)

                                        if ($ambiguousTracks.Count -eq 2 -and -not $DeepSubtitleAuditDebugExtraction -and -not $skipHeaderForLngDetect) {
                                            if ($DevDebug) { Write-Host "  [DevDebug-DSA] Probing headers for statistical metadata..." -ForegroundColor Gray }
                                            
                                            $h1 = if ($ambiguousTracks[0].properties.tag_number_of_frames) { [int64]$ambiguousTracks[0].properties.tag_number_of_frames } 
                                                  elseif ($ambiguousTracks[0].properties.statistics_tags.NUMBER_OF_FRAMES) { [int64]$ambiguousTracks[0].properties.statistics_tags.NUMBER_OF_FRAMES } else { 0 }
                                            $h2 = if ($ambiguousTracks[1].properties.tag_number_of_frames) { [int64]$ambiguousTracks[1].properties.tag_number_of_frames } 
                                                  elseif ($ambiguousTracks[1].properties.statistics_tags.NUMBER_OF_FRAMES) { [int64]$ambiguousTracks[1].properties.statistics_tags.NUMBER_OF_FRAMES } else { 0 }
                                            
                                            $isDualEngHeader = ($ambiguousTracks[0].properties.language -eq "eng" -and $ambiguousTracks[1].properties.language -eq "eng")

                                            if ($h1 -gt 0 -and $h2 -gt 0) {
                                                if ($isDualEngHeader) {
                                                    $hRatio = [Math]::Max($h1, $h2) / [Math]::Max(1, [Math]::Min($h1, $h2))
                                                    if ($hRatio -ge $targetRatio) {
                                                        if ($DevDebug) { Write-Host "  [DevDebug-DSA] Header Probe SUCCESS (Ratio: $($hRatio.ToString('F2')))" -ForegroundColor Green }
                                                        $dsaCtx.Weights[$ambiguousTracks[0].id] = $h1
                                                        $dsaCtx.Weights[$ambiguousTracks[1].id] = $h2
                                                        $isResolved = $true
                                                        # [FIX] Authorize Stage 3 naming logic for header-resolved files
                                                        $currentGroup | Add-Member -MemberType NoteProperty -Name ($fileGuid + "_Ratio") -Value $targetRatio -Force
                                                    } else {
                                                        if ($DevDebug) { Write-Host "  [DevDebug-DSA] Ratio too low ($($hRatio.ToString('F2'))). Skipping Naming logic." -ForegroundColor DarkGray }
                                                    }
                                                } else {
                                                    if ($DevDebug) { Write-Host "  [DevDebug-DSA] Header Probe Skip: Tracks not tagged as Dual-English." -ForegroundColor DarkYellow }
                                                }
                                            } else {
                                                if ($DevDebug) { Write-Host "  [DevDebug-DSA] Header Probe Skip: Statistical tags (NUMBER_OF_FRAMES) missing from MKV header." -ForegroundColor DarkYellow }
                                            }
                                        } elseif ($DevDebug -and $skipHeaderForLngDetect -and $ambiguousTracks.Count -eq 2) {
                                            Write-Host "  [DevDebug-DSA] Header Probe Bypassed: Text extraction required for Language Detection (-NLD is not active)." -ForegroundColor DarkCyan
                                        }

                                        # [Stage 2.2] EXTRACTION-PATH: Deep Bitstream/Text Analysis
                                        if (-not $isResolved) {
                                            $tempDir = Join-Path $script:GlobalTemp "DSA_Probe_$($fToFix.Name.GetHashCode().ToString('X'))"
                                            if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
                                            New-Item -Path $tempDir -ItemType Directory | Out-Null
                                            
                                            $extractArgs = New-Object System.Collections.Generic.List[string]
                                            $probeMap = @{}
                                            foreach ($sub in $ambiguousTracks) {
                                                $isImageSub = ($sub.codec -match "PGS|VobSub")
                                                # Extraction enabled for all track types to support deep subgroup pairing
                                                $ext = Get-SubtitleExtension -Codec $sub.codec
                                                $tmpPath = Join-Path $tempDir "track$($sub.id + 1).$ext"
                                                $extractArgs.Add("$($sub.id):$tmpPath")
                                                $probeMap[$sub.id] = $tmpPath
                                            }
                                            
                                            if ($DevDebug) { Write-Host "  [DevDebug-DSA] Extracting $($extractArgs.Count) tracks for analysis..." -ForegroundColor DarkCyan }
                                            & $mkvextract "$($fToFix.FullName)" tracks @extractArgs | Out-Null
                                            
                                            foreach ($sub in $ambiguousTracks) {
                                                $probeFile = $probeMap[$sub.id]
                                                if ($null -ne $probeFile -and (Test-Path -LiteralPath $probeFile)) {
                                                    $isImageSub = ($sub.codec -match "PGS|VobSub")
                                                    if (-not $isImageSub) {
                                                        $maxNeeded = [int]::MaxValue
                                                        if ($ambiguousTracks.Count -eq 1) {
                                                            $maxNeeded = if ($DeepSubtitleAuditNOLanguageDetection) { 1500 } else { 15000 }
                                                        } elseif ($ambiguousTracks.Count -gt 2) {
                                                            $maxNeeded = 15000
                                                        }
                                                        $cleanText = Extract-DialogueText -Path $probeFile -OutPath (Join-Path $tempDir "track$($sub.id + 1)_cleaned.txt") -DevDebug:$DevDebug -MaxLength $maxNeeded
                                                        
                                                        # Language Detection
                                                        if (-not $DeepSubtitleAuditNOLanguageDetection) {
                                                            # Resolve the 1-based selector (s1, s2, etc) for the display
                                                            $allSubs = @($fToFix.PristineJson.tracks | Where-Object { $_.type -eq "subtitles" })
                                                            $subIdx = [array]::IndexOf($allSubs, $sub) + 1
                                                            $tmpSel = "s$subIdx"

                                                            $sampleText = if ($cleanText.Length -gt 15000) { $cleanText.Substring(0, 15000) } else { $cleanText }
                                                            $rawDetected = Detect-SubtitleLanguage -Text $sampleText `
                                                                                                   -CurrentLang $sub.properties.language `
                                                                                                   -Honorifics:$Honorifics `
                                                                                                   -DevDebug:$DevDebug `
                                                                                                   -TrackID $sub.id `
                                                                                                   -Selector $tmpSel `
                                                                                                   -TrackName $sub.properties.track_name
                                                            
                                                            $detectedParts = $rawDetected.Split(':')
                                                            $detected = $detectedParts[0]
                                                            $honCount = [int]$detectedParts[1]
                                                            $theCount = [int]$detectedParts[2]

                                                            if ($honCount -gt 0) {
                                                                $sub | Add-Member -NotePropertyName "DSA_HonCount" -NotePropertyValue $honCount -Force
                                                            }
                                                            if ($theCount -ge 0) {
                                                                $dsaCtx.LinguisticWeights[$sub.id] = $theCount
                                                            }

                                                            # [FIX] Oscillation Prevention: Treat 'eng' and 'enm' as equivalent matches.
                                                            $isEngEnmEquivalent = ($sub.properties.language -match "eng|enm" -and $detected -match "eng|enm")
                                                            
                                                            # [MOD] Always record detection in memory (even if header is already 'eng') so Naming Engine can verify honorific status.
                                                            if ($detected -ne "und" -and -not $sub.PSObject.Properties['DSA_DetectedLang']) {
                                                                $sub | Add-Member -NotePropertyName "DSA_DetectedLang" -NotePropertyValue $detected -Force
                                                            }

                                                            # [FIX] Convergence: Only fix header if not equivalent (prevents eng <-> enm loops)
                                                            if (-not $isEngEnmEquivalent -and $sub.properties.language -ne $detected -and $detected -ne "und") {
                                                                $writeLang = if ($detected -eq "enm") { "eng" } else { $detected }
                                                                if ($DevDebug) { Write-Host "  [DevDebug-DSA] Lng Fix: Track $($sub.id + 1) ($($sub.properties.language) -> $writeLang)" -ForegroundColor Yellow }
                                                                # FORCE WRITE: Add to Params immediately to ensure disk update
                                                                if ($Fix) { $Params += @('--edit', "track:$($sub.id + 1)", '--set', "language=$writeLang") }
                                                                $sub.properties.language = $detected
                                                                $needsChange = $true
                                                            }
                                                        }
                                                        $dsaCtx.Weights[$sub.id] = $cleanText.Length
                                                    } else {
                                                        # Image Sub Weights (Binary Size)
                                                        $dsaCtx.Weights[$sub.id] = (Get-Item -LiteralPath $probeFile).Length
                                                    }
                                                }
                                            }

                                            # Cleanup artifacts
                                            if ($DevDebug) {
                                                # Calculate and print SUCCESS line first
                                                $pairs = $ambiguousTracks | Group-Object { 
                                                    $isText = $_.codec -match "s_text|utf8|srt|ass|ssa|substationalpha|subrip"
                                                    $family = if ($isText) { "TEXT" } else { $_.codec }
                                                    $effL = if ($_.DSA_DetectedLang -and $_.DSA_DetectedLang -ne "und") { $_.DSA_DetectedLang } else { $_.properties.language }
                                                    "$family|$effL"
                                                }
                                                foreach ($grp in $pairs) {
                                                    if ($grp.Count -eq 2) {
                                                        $w1 = $dsaCtx.Weights[$grp.Group[0].id]; $w2 = $dsaCtx.Weights[$grp.Group[1].id]
                                                        if ($w1 -gt 0 -or $w2 -gt 0) {
                                                            $ratio = [Math]::Max($w1, $w2) / [Math]::Max(1, [Math]::Min($w1, $w2))
                                                            $minReq = if ($grp.Group[0].codec -match "s_text|utf8|srt|ass|ssa|substationalpha|subrip") { 2.0 } else { 3.0 }
                                                            if ($ratio -ge $minReq) { Write-Host "[DevDebug-DSA] Bitstream/Text Probe SUCCESS (Ratio: $($ratio.ToString('F2')))" -ForegroundColor Green }
                                                            else { Write-Host "    [DevDebug-DSA] Ratio too low for subgroup resolution ($($ratio.ToString('F2')) < $minReq)" -ForegroundColor DarkGray }
                                                        }
                                                    } elseif ($grp.Count -gt 2) {
                                                        Write-Host "[DevDebug-DSA] Bitstream/Text Probe SUCCESS (Multi-Track Outlier Detection)" -ForegroundColor Green
                                                    }
                                                }
                                                $allSubs = @($fToFix.PristineJson.tracks | Where-Object { $_.type -eq "subtitles" })
                                                foreach ($sub in $ambiguousTracks) {
                                                    $sIdx = [array]::IndexOf($allSubs, $sub) + 1
                                                    $sSel = "s$sIdx"
                                                    $kb = [Math]::Round($dsaCtx.Weights[$sub.id] / 1024, 3)
                                                    Write-Host "    [DevDebug-DSA] Final Weight ID:$($sub.id) - Track $($sub.id + 1) - [$sSel]...($kb KB)" -ForegroundColor Gray
                                                }
                                                Write-Host "    [DevDebug-DSA] Preservation Active: Files kept at -> $tempDir" -ForegroundColor DarkCyan
                                                foreach ($sub in $ambiguousTracks) {
                                                    Write-Host "  [DevDebug-DSA] Found Track:$($sub.id + 1) Name: $($sub.properties.track_name)" -ForegroundColor Gray
                                                }
                                            } else {
                                                if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
                                            }

                                            # Sequential Resolution Check: Verify if any subgroups meet sizing/outlier thresholds
                                            $pairs = $ambiguousTracks | Group-Object { 
                                                $isText = $_.codec -match "s_text|utf8|srt|ass|ssa|substationalpha|subrip"
                                                $family = if ($isText) { "TEXT" } else { $_.codec }
                                                # Enable pairing for tracks with broken header tags (und/spa)
                                                $effL = if ($_.DSA_DetectedLang -and $_.DSA_DetectedLang -ne "und") { $_.DSA_DetectedLang } else { $_.properties.language }
                                                "$family|$effL"
                                            }
                                            foreach ($grp in $pairs) {
                                                if ($grp.Count -eq 2) {
                                                    $w1 = $dsaCtx.Weights[$grp.Group[0].id]; $w2 = $dsaCtx.Weights[$grp.Group[1].id]
                                                    if ($w1 -gt 0 -or $w2 -gt 0) {
                                                        $ratio = [Math]::Max($w1, $w2) / [Math]::Max(1, [Math]::Min($w1, $w2))
                                                        $minReq = if ($grp.Group[0].codec -match "s_text|utf8|srt|ass|ssa|substationalpha|subrip") { 2.0 } else { 3.0 }
                                                        if ($ratio -ge $minReq) { $dsaCtx.IsResolved = $true }
                                                    }
                                                } elseif ($grp.Count -gt 2) {
                                                    $dsaCtx.IsResolved = $true
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                # --- STAGE 3: DECISION LOGIC (SINGLE TRACK VALIDATION) ---
                                
                                # Aggressive Role Sanitization Filter
                                $roleFilter = $script:RegexSanitizer
                                $SanitizeName = { param($n) ($n -replace $roleFilter, ' ' -replace '[\(\)\[\]\{\}\-\.\:\&\+]', ' ').Trim() -replace '\s+', ' ' }

                                # Phase A: Universal Honorifics & Language Normalization (ALL tracks)
                                foreach ($tH in $ambiguousTracks) {
                                    $isHonDet = ($tH.DSA_DetectedLang -eq "enm" -or $tH.properties.language -eq "enm" -or $tH.properties.track_name -match $script:RegexHon)
                                    if ($isHonDet) {
                                        $curName = if ($tH.properties.track_name) { $tH.properties.track_name } else { "" }
                                        
                                        # 1. Language Normalization: Force header to 'eng'
                                        if ($tH.properties.language -ne "eng") {
                                            $needsChange = $true
                                            if ($Fix) { $Params += @('--edit', "track:$($tH.id + 1)", '--set', "language=eng") }
                                            $tH.properties.language = "eng"
                                        }

                                        # 1b. Role Validation: Check if name already contains correct keywords
                                        $isCorrect = if ($tH.DSA_DetectedLang -eq "enm") { $curName -match "Honorifics" -and $curName -match "Full Dialogue" }
                                                     elseif ($tH.DSA_DetectedLang -eq "eng") { $curName -match "Full Dialogue" -and $curName -notmatch "Honorifics" }
                                                     else { $curName -match "Honorifics" -and $curName -match "Full Dialogue" }

                                        if ($isCorrect) {
                                            if ($DevDebug) { Write-Host "    [DevDebug-DSA] VERIFIED: Track $($tH.id + 1) already contains correct honorifics role keywords. Skipping rename." -ForegroundColor Green }
                                            $tH.properties | Add-Member -NotePropertyName "DSA_Handled" -NotePropertyValue $true -Force
                                            continue 
                                        }

                                        # 2. Truth-Based Naming: If bitstream proved standard English, demote 'Honorifics' liar.
                                        $cleanGroupName = &$SanitizeName $curName
                                        $prefix = if ($tH.DSA_DetectedLang -eq "enm") { "Honorifics Full Dialogue" }
                                                  elseif ($tH.DSA_DetectedLang -eq "eng") { "Full Dialogue" }
                                                  else { "Honorifics Full Dialogue" } # Trust name for picture subs/skipped scans
                                        
                                        $newName = if ([string]::IsNullOrWhiteSpace($cleanGroupName)) { $prefix } else { "$prefix [$cleanGroupName]" }
                                        
                                        # Final Comparison: Only update if standardized name differs from current name
                                        if ($newName -ne $curName) {
                                            $needsChange = $true
                                            if ($Fix) {
                                                $Params += @('--edit', "track:$($tH.id + 1)", '--set', "name=$newName")
                                                $tH.properties | Add-Member -NotePropertyName "track_name" -NotePropertyValue $newName -Force
                                            }
                                            [void]$fixDetails.Add("  [DSA] UNIVERSAL-HONORIFIC: Tagged track $($tH.id + 1) as Honorifics.")
                                        }
                                        else {
                                            if ($DevDebug) { Write-Host "    [DevDebug-DSA] Track $($tH.id + 1) naming is already standardized. Skipping update." -ForegroundColor Gray }
                                        }
                                        $tH.properties | Add-Member -NotePropertyName "DSA_Handled" -NotePropertyValue $true -Force
                                    }
                                }

                                # Phase B: Restricted Role Tagging (1 or 2 tracks ONLY)
                                # Skip role guessing if LDL2 restriction is active or tracks handled in Phase A.
                                if ($ambiguousTracks.Count -eq 1) {
                                    $t1 = $ambiguousTracks[0]
                                    $w1 = $dsaCtx.Weights[$t1.id]
                                    $isText = $t1.codec -match "s_text|utf8|srt|ass|ssa|substationalpha|subrip"
                                    
                                    # Thresholds: Text (1500 chars) | Image (0.5 MB)
                                    $minThreshold = if ($isText) { 1500 } else { 524288 }
                                    $passedDensity = ($w1 -ge $minThreshold)
                                    $currentName = if ($t1.properties.track_name) { $t1.properties.track_name } else { "" }
                                    $actionMsg = ""

                                    if ($DevDebug) {
                                        $displayWeight = if ($isText) { $w1 } else { "$([Math]::Round($w1 / 1kb, 2)) KB" }
                                        $displayLimit  = if ($isText) { $minThreshold } else { "$([Math]::Round($minThreshold / 1kb, 2)) KB" }
                                        Write-Host "  [DevDebug-DSA] Single Track Analysis: Track:$($t1.id + 1) | Weight: $displayWeight | Threshold: $displayLimit" -ForegroundColor Gray
                                        Write-Host "  [DevDebug-DSA] Result: $(if ($passedDensity) { "Passed (Dialogue)" } else { "Failed (S&S/Low Density)" })" -ForegroundColor $(if ($passedDensity) { "Green" } else { "DarkYellow" })
                                    }

                                    if ($passedDensity) {
                                        $isHonLocal = ($t1.DSA_DetectedLang -eq "enm" -or $t1.properties.language -eq "enm" -or $currentName -match "Honorifics")
                                        $isCorrect = if ($isHonLocal) { $currentName -match "Honorifics" -and $currentName -match "Full Dialogue" }
                                                     else { $currentName -match "Full Dialogue" -and $currentName -notmatch "Honorifics" }

                                        if ($t1.properties.DSA_Handled -or $isCorrect) { 
                                            $actionMsg = "[DSA] SINGLE-VERIFIED: Track role is already correct."
                                        } else {
                                            $groupName = &$SanitizeName $currentName
                                            $role = if ($isHonLocal) { "Honorifics Full Dialogue" } else { "Full Dialogue" }
                                            $newName = if ([string]::IsNullOrWhiteSpace($groupName)) { $role } else { "$role [$groupName]" }

                                            if ($newName -ne $currentName) {
                                                $needsChange = $true
                                                if ($Fix) { $Params += @('--edit', "track:$($t1.id + 1)", '--set', "name=$newName") }
                                                $t1.properties | Add-Member -NotePropertyName "track_name" -NotePropertyValue $newName -Force
                                                $t1.properties | Add-Member -NotePropertyName "DSA_Handled" -NotePropertyValue $true -Force
                                                $actionMsg = "[DSA] SINGLE-FIX: Validated Dialogue Track (Renamed: '$newName')"
                                            }
                                        }
                                    } else {
                                        $actionMsg = "[DSA] SINGLE-SKIP: Track failed density check (Likely Signs & Songs). Naming bypassed."
                                    }

                                    if ($DevDebug) { Write-Host "  $($actionMsg -replace '^\[DSA\]', '[DevDebug-DSA]')" -ForegroundColor Cyan }
                                    [void]$fixDetails.Add("  $actionMsg")
                                }

                                # --- STAGE 3: DECISION LOGIC (EXACTLY 2 TRACKS ONLY) ---
                                if ($ambiguousTracks.Count -ge 2 -and $dsaCtx.IsResolved) {
                                    $subPairs = $ambiguousTracks | Group-Object { 
                                        $isText = $_.codec -match "s_text|utf8|srt|ass|ssa|substationalpha|subrip"
                                        $family = if ($isText) { "TEXT" } else { $_.codec }
                                        # Use detected language to correctly pair tracks with broken header tags
                                        $effL = if ($_.DSA_DetectedLang -and $_.DSA_DetectedLang -ne "und") { $_.DSA_DetectedLang } else { $_.properties.language }
                                        "$family|$effL"
                                    }
                                    foreach ($grp in $subPairs) {
                                        if ($grp.Count -eq 2) {
                                            $t1 = $grp.Group[0]; $t2 = $grp.Group[1]
                                            # Use ID-based weight lookup to bypass header language mismatches
                                            $w1 = if ($dsaCtx.Weights.ContainsKey($t1.id)) { $dsaCtx.Weights[$t1.id] } else { 0 }
                                            $w2 = if ($dsaCtx.Weights.ContainsKey($t2.id)) { $dsaCtx.Weights[$t2.id] } else { 0 }
                                            
                                            if ($w1 -gt 0 -or $w2 -gt 0) {
                                                $ratio = [Math]::Max($w1, $w2) / [Math]::Max(1, [Math]::Min($w1, $w2))
                                                $minReq = if ($t1.codec -match "s_text|utf8|srt|ass|ssa|substationalpha|subrip") { 2.0 } else { 3.0 }
                                                
                                                $largeTrack = if ($w1 -gt $w2) { $t1 } else { $t2 }
                                                $smallTrack = if ($w1 -gt $w2) { $t2 } else { $t1 }
                                                
                                                $nameL = if ($largeTrack.properties.track_name) { $largeTrack.properties.track_name } else { "" }
                                                $nameS = if ($smallTrack.properties.track_name) { $smallTrack.properties.track_name } else { "" }
                                                
                                                $effL1 = if ($t1.DSA_DetectedLang) { $t1.DSA_DetectedLang } else { $t1.properties.language }
                                                $effL2 = if ($t2.DSA_DetectedLang) { $t2.DSA_DetectedLang } else { $t2.properties.language }
                                                $isDualEng = ($effL1 -match "eng|enm" -and $effL2 -match "eng|enm")
                                                
                                                if ($ratio -ge $minReq -and $isDualEng) {
                                                    $actionMsg = ""
                                                    $handledL = $largeTrack.properties.DSA_Handled
                                                    $handledS = $smallTrack.properties.DSA_Handled

                                                    $hasDiagL = ($nameL -match $script:RegexDiag) -or $handledL
                                                    $hasSignL = ($nameL -match $script:RegexSign)
                                                    $hasDiagS = $nameS -match $script:RegexDiag
                                                    $hasSignS = $nameS -match $script:RegexSign
                                                    
                                                    $isHonDet = ($largeTrack.DSA_DetectedLang -eq "enm" -or $largeTrack.properties.language -eq "enm")
                                                    $isNameMissingHon = ($isHonDet -and $nameL -notmatch "(?i)honorific|honor")

                                                    if (($nameL -match $script:RegexSign) -and ($nameS -match $script:RegexDiag)) {
                                                        $needsChange = $true
                                                        $cleanL = &$SanitizeName $nameS; $cleanS = &$SanitizeName $nameL
                                                        $isHonL = ($largeTrack.DSA_DetectedLang -eq "enm" -or $largeTrack.properties.language -eq "enm" -or $nameS -match "Honorifics")
                                                        $roleL = if ($isHonL) { "Honorifics Full Dialogue" } else { "Full Dialogue" }
                                                        $newNameL = if ([string]::IsNullOrWhiteSpace($cleanL)) { $roleL } else { "$roleL [$cleanL]" }
                                                        $newNameS = if ([string]::IsNullOrWhiteSpace($cleanS)) { "Signs & Songs" } else { "Signs & Songs [$cleanS]" }
                                                        
                                                        if ($Fix) {
                                                            $Params += @('--edit', "track:$($largeTrack.id + 1)", '--set', "name=$newNameL")
                                                            $Params += @('--edit', "track:$($smallTrack.id + 1)", '--set', "name=$newNameS")
                                                        }
                                                        $largeTrack.properties | Add-Member -NotePropertyName "track_name" -NotePropertyValue $newNameL -Force
                                                        $smallTrack.properties | Add-Member -NotePropertyName "track_name" -NotePropertyValue $newNameS -Force
                                                        $isTextGrp = $t1.codec -match "s_text|utf8|srt|ass|ssa|substationalpha|subrip"
                                                        $grpName = if ($isTextGrp) { "TEXT" } else { $t1.codec }
                                                        $actionMsg = "[DSA] SWAP (Subgroup:$grpName): Swapping role keywords between Track:$($t1.id+1) and Track:$($t2.id+1)"
                                                    }
                                                    elseif (-not $hasDiagL -or -not $hasSignS -or ($nameL -match "^(?i)(English|Subtitles|Eng|Subs?|English Subtitles)?$") -or $isNameMissingHon) {
                                                        $isHonL = ($largeTrack.DSA_DetectedLang -eq "enm" -or $largeTrack.properties.language -eq "enm" -or $nameL -match "Honorifics")
                                                        $roleL = if ($isHonL) { "Honorifics Full Dialogue" } else { "Full Dialogue" }
                                                        
                                                        $cleanL = &$SanitizeName $nameL; $cleanS = &$SanitizeName $nameS
                                                        $newNameL = if ([string]::IsNullOrWhiteSpace($cleanL)) { $roleL } else { "$roleL [$cleanL]" }
                                                        $newNameS = if ([string]::IsNullOrWhiteSpace($cleanS)) { "Signs & Songs" } else { "Signs & Songs [$cleanS]" }
                                                        
                                                        if ($newNameL -eq $newNameS) { $newNameL = $roleL; $newNameS = "Signs & Songs" }

                                                        if ($newNameL -ne $nameL -or $newNameS -ne $nameS) {
                                                            $needsChange = $true
                                                            if ($Fix) {
                                                                if ($newNameL -ne $nameL) { $Params += @('--edit', "track:$($largeTrack.id + 1)", '--set', "name=$newNameL") }
                                                                if ($newNameS -ne $nameS) { $Params += @('--edit', "track:$($smallTrack.id + 1)", '--set', "name=$newNameS") }
                                                            }
                                                            $largeTrack.properties | Add-Member -NotePropertyName "track_name" -NotePropertyValue $newNameL -Force
                                                            $smallTrack.properties | Add-Member -NotePropertyName "track_name" -NotePropertyValue $newNameS -Force
                                                            $isTextGrp = $t1.codec -match "s_text|utf8|srt|ass|ssa|substationalpha|subrip"
                                                            $grpName = if ($isTextGrp) { "TEXT" } else { $t1.codec }
                                                            $actionMsg = "[DSA] FIX (Subgroup:$grpName): Corrected roles (Large: '$newNameL', Small: '$newNameS')"
                                                        } else {
                                                            $isTextGrp = $t1.codec -match "s_text|utf8|srt|ass|ssa|substationalpha|subrip"
                                                            $grpName = if ($isTextGrp) { "TEXT" } else { $t1.codec }
                                                            $actionMsg = "[DSA] VERIFIED (Subgroup:$grpName): Tracks meet ratio threshold ($($ratio.ToString('F2')))"
                                                        }
                                                    }
                                                    else { 
                                                        $isTextGrp = $t1.codec -match "s_text|utf8|srt|ass|ssa|substationalpha|subrip"
                                                        $grpName = if ($isTextGrp) { "TEXT" } else { $t1.codec }
                                                        $actionMsg = "[DSA] VERIFIED (Subgroup:$grpName): Tracks meet ratio threshold ($($ratio.ToString('F2')))" 
                                                    }

                                                    if ($DevDebug) { Write-Host "  $($actionMsg -replace '^\[DSA\]', '[DevDebug-DSA]')" -ForegroundColor $(if ($actionMsg -match "SWAP|FIX") { "DarkYellow" } else { "Green" }) }
                                                    [void]$fixDetails.Add("  $actionMsg")
                                                    $largeTrack.properties | Add-Member -NotePropertyName "DSA_Handled" -NotePropertyValue $true -Force
                                                    $smallTrack.properties | Add-Member -NotePropertyName "DSA_Handled" -NotePropertyValue $true -Force
                                                }
                                            }
                                        } else {
                                            # CASE 2: More than 2 Tracks (Outlier Detection)
                                            $grpWeights = $grp.Group | ForEach-Object { 
                                                $weight = if ($dsaCtx.Weights.ContainsKey($_.id)) { $dsaCtx.Weights[$_.id] } else { 0 }
                                                $lingW  = if ($dsaCtx.LinguisticWeights.ContainsKey($_.id)) { $dsaCtx.LinguisticWeights[$_.id] } else { 0 }
                                                [PSCustomObject]@{ T = $_; W = [int64]$weight; L = [int]$lingW } 
                                            } | Sort-Object W
                                            
                                            $maxWeight = $grpWeights[-1].W
                                            $minWeight = $grpWeights[0].W
                                            $isTextGrp = $grpWeights[0].T.codec -match "s_text|utf8|srt|ass|ssa|substationalpha|subrip"

                                            # Synchronized Outlier Threshold (45% sizing floor)
                                            $threshold = 0.45

                                            if ($minWeight -gt 0 -and $maxWeight -gt 0 -and ($minWeight / $maxWeight -lt $threshold)) {
                                                $grpName = if ($isTextGrp) { "TEXT" } else { $grpWeights[0].T.codec }
                                                
                                                # Identify Large Candidates (Tracks above threshold)
                                                $largeTracks = $grpWeights | Where-Object { ($_.W / $maxWeight) -ge $threshold } | Sort-Object L -Descending
                                                $firstLargeId = ($largeTracks | Select-Object -First 1).T.id

                                                # Pre-Scan: Detect existing Commentary/Interview tags in the subgroup
                                                $commentaryInGroup = ($grpWeights | Where-Object { $_.T.properties.track_name -match "Commentary|Interview" }).Count -gt 0

                                                foreach ($item in $grpWeights) {
                                                    $tO = $item.T; $curName = if ($tO.properties.track_name) { $tO.properties.track_name } else { "" }
                                                    $effL = if ($tO.DSA_DetectedLang) { $tO.DSA_DetectedLang } else { $tO.properties.language }
                                                    $isSmallSize = ($item.W / $maxWeight -lt $threshold)
                                                    
                                                    # Role Identification: Small size + Low Linguistic Density = Signs & Songs
                                                    $isSmall = $isSmallSize -and ($item.L -lt 30)
                                                    
                                                    # Role Identification: If "The" count is significantly lower than the leader (Common for Commentaries)
                                                    $isLingCommentary = ($item.L -ge 30) -and ($item.L / [Math]::Max(1, $largeTracks[0].L) -lt 0.75)
                                                    
                                                    $isLarge = -not $isSmallSize
                                                    $isHon = ($effL -eq "enm" -or $curName -match $script:RegexHon)
                                                    
                                                    # Naming Gate: Only rename unnamed tracks if they are the linguistic winner or proven outliers
                                                    $isFirstLarge = ($tO.id -eq $firstLargeId)
                                                    $isCloseToLeader = ($largeTracks.Count -gt 0) -and ($item.L / [Math]::Max(1, $largeTracks[0].L) -ge 0.85)
                                                    $skipRename = $isLarge -and $isGlobalCommentaryEnv -and -not $isFirstLarge -and -not $commentaryInGroup -and [string]::IsNullOrWhiteSpace($curName) -and -not $isCloseToLeader

                                                    if ($effL -match "eng|enm" -and -not $skipRename) {
                                                        $isCommentary = ($curName -match "Commentary|Interview")
                                                        $isSDH = ($curName -match "SDH|HI|CC" -or $tO.properties.flag_hearing_impaired)
                                                        
                                                        $role = if ($isSmall) { "Signs & Songs" } 
                                                                elseif ($isCommentary -or $isLingCommentary) { "Commentary" }
                                                                elseif ($isSDH) { "SDH/CC" }
                                                                else { if ($isHon) { "Honorifics Full Dialogue" } else { "Full Dialogue" } }
                                                        
                                                        # Correctness Gate: Skip if name already matches identified role
                                                        $isCorrect = if ($role -eq "Signs & Songs") { $curName -match "Signs" -and $curName -match "Songs" }
                                                                     elseif ($role -match "Honorifics") { $curName -match "Honorifics" -and $curName -match "Full Dialogue" }
                                                                     elseif ($role -eq "Full Dialogue") { $curName -match "Full Dialogue" -and $curName -notmatch "Honorifics" }
                                                                     else { $curName -match [regex]::Escape($role) }
                                                        
                                                        if ($isCorrect) { 
                                                            $tO.properties | Add-Member -NotePropertyName "DSA_Handled" -NotePropertyValue $true -Force
                                                            continue 
                                                        }

                                                        $cleanBase = &$SanitizeName $curName
                                                        $newName = if ([string]::IsNullOrWhiteSpace($cleanBase)) { $role } else { "$role [$cleanBase]" }
                                                        
                                                        if ($newName -ne $curName) {
                                                            $needsChange = $true
                                                            if ($Fix) { $Params += @('--edit', "track:$($tO.id+1)", '--set', "name=$newName") }
                                                            $tO.properties | Add-Member -NotePropertyName "track_name" -NotePropertyValue $newName -Force
                                                            $actionMsg = "[DSA] OUTLIER-FIX (Subgroup:$grpName): Identified Track:$($tO.id+1) as $role"
                                                            if ($DevDebug) { Write-Host "  [DevDebug-DSA] $actionMsg" -ForegroundColor DarkYellow }
                                                            [void]$fixDetails.Add("  $actionMsg")
                                                        }
                                                        $tO.properties | Add-Member -NotePropertyName "DSA_Handled" -NotePropertyValue $true -Force
                                                    }
                                                }
                                            }
                                        }
                                    }
                                } # Closes: if ($ambiguousTracks.Count -ge 2 -and ...) [Decision Engine]
                            } # Closes: if ($null -ne $dsaCtx) [Context Verification]
                        } # Closes: if ($DeepSubtitleAudit -and -not $dsaFileProcessed) [Main Gate]
                        # --- END DSA ENGINE ---
                        
                        # [TRUTH SYNC] Force-load DSA discoveries into loop variables for accurate scoring
                        $trackLang = if ($t.DSA_DetectedLang -and $t.DSA_DetectedLang -ne "und") { 
                            if ($t.DSA_DetectedLang -eq "enm") { "eng" } else { $t.DSA_DetectedLang } 
                        } else { $t.properties.language.ToLower() }
                        
                        # 1. ALWAYS capture current default status so we can strip it later if needed
                        $isCurrentlyDefault = ($t.properties.default_track -eq $true)
                        $subRelativeIndex++
                        $scoring = Get-TrackScore -t $t -fixerConfig $fixerConfig `
                                                 -subRelativeIndex $subRelativeIndex `
                                                 -Honorifics:$Honorifics `
                                                 -SubtitleFactorTrackOrder:$SubtitleFactorTrackOrder `
                                                 -Western:$Western `
                                                 -SubtitlesHearingImpaired:$SubtitlesHearingImpaired

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
                    Write-Host "" # Gap between DSA and Fixer
                    Write-Host "  [DevDebug-Fixer] Scoring file at path: $($fToFix.FullName)" -ForegroundColor Gray
                    Write-Host "  [DevDebug-Fixer] Subtitle Scoring Candidates:`n" -ForegroundColor Cyan
                    [void]$fixDetails.Add("  [DevDebug-Fixer] Subtitle Scoring Breakdown:")
                    foreach ($cand in ($subCandidates | Sort-Object Score -Descending)) {
                        # [CHANGE] v2026.06.15__09.22.41 - Include Track in scoring debug telemetry and organized for easier viewing.
                        $rulesDisp = $cand.Rules
                        if ($rulesDisp.Length -gt 70 -and $rulesDisp.Contains(' | ')) {
                            $splitIdx = $rulesDisp.IndexOf(' | ', [int]($rulesDisp.Length / 2))
                            if ($splitIdx -eq -1) { $splitIdx = $rulesDisp.LastIndexOf(' | ') }
                            if ($splitIdx -ne -1) { $rulesDisp = $rulesDisp.Insert($splitIdx + 3, "`n              ") }
                        }
                        $msg = "    -> ID:$($cand.ID) | Trk:$($cand.ID+1) | Sel:$($cand.Sel) | Score: $($cand.Score) | Lang: $($cand.Lang) | Name: $($cand.Name) `n       Rules: [$($rulesDisp)]`n"
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
                        $isActualSDH = ($sdhWinner.Name -match "SDH|HI|CC" -or ($fToFix.PristineJson.tracks | Where-Object { $_.id -eq $sdhWinner.ID }).properties.flag_hearing_impaired)

                        if ($sdhRequested -and $isActualSDH) {
                            $winID = $sdhWinner.ID + 1
                            $isAlreadyHI = ($fToFix.PristineJson.tracks | Where-Object { $_.id -eq $sdhWinner.ID }).properties.flag_hearing_impaired
                            
                            if (-not $sdhWinner.WasDefault -or -not $isAlreadyHI) {
                                $Params += @('--edit', "track:$winID", '--set', "flag-default=1", '--set', "flag-forced=0", '--set', "flag-hearing-impaired=1")
                                $needsChange = $true
                                [void]$fixDetails.Add("  ACTION: SET_DEFAULT=1 + HI_FLAG | TRACK: $winID | REASON: Western SDH Promotion")
                            }

                            foreach ($sub in $subCandidates) {
                                if ($sub.ID -ne $sdhWinner.ID) {
                                    $lostTrack = $fToFix.PristineJson.tracks | Where-Object { $_.id -eq $sub.ID }
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
                                $thisTrack = $fToFix.PristineJson.tracks | Where-Object { $_.id -eq $sub.ID }
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

                    $subReason = if ($Honorifics -and ($winner.Score -ge 100)) { "Preferred Honorifics ($($winner.Lang))" } else { "Primary ENG Sub" }
                    $currentWinnerData = $fToFix.PristineJson.tracks | Where-Object { $_.id -eq $winner.ID }
                    
                    # 1. Validation Logic
                    $honRegex = "(?<!no\s|non-|without\s|removed\s)(honorific|honor)"
                    
                    # Pull the DSA recommendation directly from the track object
                    $dsaDetected = ($fToFix.PristineJson.tracks | Where-Object { $_.id -eq $winner.ID }).DSA_DetectedLang
                    
                    # [FIX] Normalization Sync: Standardize 'enm' to 'eng' for the header language.
                    $isWinnerHon = ($winner.Name -match $honRegex) -or ($winner.Lang -eq "enm") -or ($dsaDetected -eq "enm")
                    
                    $correctLangForWinner = if ($dsaDetected -eq "enm") { "eng" }
                                            elseif ($dsaDetected -and $dsaDetected -ne "und") { $dsaDetected } 
                                            elseif ($Honorifics -and $isWinnerHon) { "eng" } 
                                            elseif ($winner.Lang -eq "enm") { "eng" } 
                                            else { $targetSubLang }

                    # PREFERRED OR NOTHING: Use Effective Language to authorize the Default flag
                    $winnerEffLang = if ($dsaDetected -and $dsaDetected -ne "und") { $dsaDetected } else { $winner.Lang }
                    $isWinnerValidForDefault = ($winnerEffLang -eq $targetSubLang) -or ($winnerEffLang -eq "und") -or $isWinnerHon
                    $targetDefaultValue = if ($isWinnerValidForDefault) { 1 } else { 0 }

                    # [FIX] Winner Needs Fix if current language doesn't match the corrected target language
                    $langNeedsFix = ($currentWinnerData.properties.language -ne $correctLangForWinner)

                    # 2. EVALUATE CHANGES: Check if Winner needs updating or if any Losers have dirty flags
                    $winnerNeedsFix = ($langNeedsFix) -or 
                                      ($currentWinnerData.properties.default_track -ne $targetDefaultValue) -or
                                      ($currentWinnerData.properties.forced_track -eq $true) -or
                                      ($currentWinnerData.properties.flag_hearing_impaired -eq $true)
                    
                    $losersNeedStrip = $false
                    foreach ($sub in $subCandidates) {
                        if ($sub.ID -ne $winner.ID) {
                            $lostTrack = $fToFix.PristineJson.tracks | Where-Object { $_.id -eq $sub.ID }
                            if ($lostTrack.properties.default_track -or $lostTrack.properties.forced_track -or $lostTrack.properties.flag_hearing_impaired) { 
                                $losersNeedStrip = $true; break 
                            }
                        }
                    }

                    # 3. MECHANICAL TRIGGER: Build the command
                    if ($winnerNeedsFix -or $losersNeedStrip) {
                        $needsChange = $true
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
                                $lostTrack = $fToFix.PristineJson.tracks | Where-Object { $_.id -eq $sub.ID }
                                $loseID = $sub.ID + 1
                                
                                # Strip default and forced flags only
                                $Params += @('--edit', "track:$loseID", '--set', "flag-default=0", '--set', "flag-forced=0")
                                
                                # [FIX] Truth-First: Force update header if detected language doesn't match
                                $detected = $lostTrack.DSA_DetectedLang
                                # Normalization: Ensure enm detected losers are also standardized to eng headers
                                if ($detected -eq "enm") { $detected = "eng" }

                                if ($detected -and $detected -ne "und" -and $lostTrack.properties.language -ne $detected) {
                                    $Params += @('--set', "language=$detected")
                                    $needsChange = $true
                                }
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
                        
                        # Resolve the root to its parent directory if the path is a direct file
                        $isFile = [System.IO.File]::Exists($anchorRoot)
                        $resolvedAnchor = if ($isFile) { Split-Path $anchorRoot -Parent } else { $anchorRoot }
                        
                        if ($isFile) {
                            $backupRootPath = Join-Path $resolvedAnchor "_updated"
                        } else {
                            $parentDir = Split-Path $resolvedAnchor -Parent
                            $rootName = Split-Path $resolvedAnchor -Leaf
                            $backupRootPath = Join-Path $parentDir "$($rootName)_updated"
                        }
                        
                        $relativeDir = ""
                        $fParent = Split-Path $fToFix.FullName -Parent
                        if ($fParent.Length -gt $resolvedAnchor.Length) {
                            $relativeDir = $fParent.Substring($resolvedAnchor.Length).TrimStart('\')
                        }
                        
                        $targetFile = Join-Path $backupRootPath $relativeDir (Split-Path $fToFix.FullName -Leaf)
                        
                    }

                    if ($targetFile -and (Test-Path -LiteralPath $targetFile)) {
                        if ($DevDebug) {
                            $fullCmd = "mkvpropedit `"$targetFile`" $($Params -join ' ')"
                            Write-Host "  [DevDebug-Fixer] $fullCmd" -ForegroundColor DarkYellow
                            [void]$fixDetails.Add("  DevDebug_CMD: $fullCmd")
                        }
                        & $mkvpropedit "$targetFile" @Params | Out-Null
                        $script:FilesModifiedInJob++
                        [void]$fixDetails.Add("  STATUS: Changes applied to -> $targetFile")
                    }
                }
                [void]$fixDetails.Add(""); $fixDetails | Out-File $fixerLog -Append -Encoding utf8
            } # <--- END SEQUENTIAL FILES LOOP
            Write-Host "" # Clear progress bar line
        } # <--- v2026.05.13_11.23.00 - END OF THE "ELSE" AUDITOR BYPASS # <--- v2026.05.13_11.23.00 - END OF THE "ELSE" AUDITOR BYPASS

    
    
    # --- STANDARD AUDITOR LOGGING ---
    # This only runs if $NoHwVideoSearch is FALSE because of the 'continue' above
    $spacer = "`r`n💜 • 💙 • 🦋 • ❤️ • 💛 • 🦋 • 💜 • 💙 • 🦋 • ❤️ • 💛 • 🦋 • 💜 • 💙 • 🦋 • ❤️ • 💛`r`n"
    $spacer | Out-File $detailLog -Append -Encoding utf8
    
    $compEntry = New-Object System.Collections.Generic.List[string]
    $compEntry.Add("Folder: $($folderPath.FullName)")
    $compEntry.Add($matchStatus)
    $compEntry.Add("Total: $($mkvFiles.Count) | Matches Primary: $($primaryGroup.Files.Count) | Mismatches: $mismatches`r`n")
    $compEntry | Out-File $compLog -Append -Encoding utf8
    
} # <--- END FOLDER LOOP

if ($CurrentJob.Mode -eq "Standard" -and -not $NoHwVideoSearch) {
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
    if ($CurrentJob.Mode -eq "Standard" -and $VerifyUpdates -and -not $NoHwVideoSearch) {
        $verifyPaths = New-Object System.Collections.Generic.List[string]
        
        if ($Fix -and -not $FixNoBackup) {
            foreach ($p in $CurrentJob.TargetPaths) {
                if ([System.IO.File]::Exists($p)) {
                    $parent = Split-Path $p -Parent
                    $targetUpdatePath = Join-Path $parent "_updated" (Split-Path $p -Leaf)
                } else {
                    $targetUpdatePath = $p.TrimEnd('\') + "_updated"
                }
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

# Final Session Report Generation (NoHW Mode)
if ($NoHwVideoSearch) {
    # 1. Grab any findings that haven't been flushed yet
    $remaining = @()
    if ($sessionNoHwList.Count -gt 0) { $remaining = $sessionNoHwList.ToArray() }

    # 2. Read existing discoveries from disk (skipping our placeholder lines)
    # Force Get-Content to return an array even for 1-line files to prevent String + Array concatenation
    $diskContent = if (Test-Path $noHwLog) { 
        @(Get-Content -LiteralPath $noHwLog) | Where-Object { $_ -notmatch "^--- SCAN IN PROGRESS ---$|^Results will be finalized" } 
    } else { @() }

    # Combine lists safely using .AddRange to maintain individual line integrity
    $combinedList = New-Object System.Collections.Generic.List[string]
    if ($diskContent) { $combinedList.AddRange([string[]]$diskContent) }
    if ($remaining)   { $combinedList.AddRange([string[]]$remaining) }
    
    $allResults = $combinedList | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
    # Apply Natural Sort (Windows Explorer Logic) to the file paths/errors
    if ($allResults.Count -gt 1) {
        $allResultsArray = [string[]]$allResults
        [System.Array]::Sort($allResultsArray, [System.Comparison[string]]{ 
            param($a, $b)
            # Strip prefixes/suffixes to get the raw path for sorting comparison only
            $cleanA = $a -replace '^💀 \[ERROR\] UNREADABLE: ', '' -replace ' - Reason: .*$', ''
            $cleanB = $b -replace '^💀 \[ERROR\] UNREADABLE: ', '' -replace ' - Reason: .*$', ''
            [NaturalSort]::StrCmpLogicalW($cleanA, $cleanB) 
        })
        $allResults = $allResultsArray
    }

    if ($allResults.Count -gt 0) {
        $finalOutput = New-Object System.Collections.Generic.List[string]
        $finalOutput.AddRange([string[]](Get-NoHwLogHeader -Fast:$fast -RootPath $inputPaths[0] -Flags @($sessionFlags)))
        $finalOutput.Add("") # Single gap after header
        $finalOutput.AddRange([string[]]$allResults)
        
        # 4. Perform the final surgical overwrite
        # Use .NET WriteAllLines to bypass PowerShell's formatting engine entirely
        [System.IO.File]::WriteAllLines($noHwLog, [string[]]$finalOutput, [System.Text.Encoding]::UTF8)
    }
}

# --- FINAL GLOBAL SUMMARY ---
if ($noHwCount -gt 0 -or $corruptCount -gt 0) {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor DarkYellow
    Write-Host " NoHW VIDEO SEARCH SUMMARY" -ForegroundColor DarkYellow
    Write-Host " Total NoHW Found: $noHwCount" -ForegroundColor Gray
    Write-Host " Total Corrupt Found: $corruptCount" -ForegroundColor $(if ($corruptCount -gt 0) { "Red" } else { "Gray" })
    Write-Host " Log: $noHwLog" -ForegroundColor Gray
    Write-Host "==================================================" -ForegroundColor DarkYellow
}


Write-Host "Complete." -ForegroundColor DarkCyan

# --- GLOBAL SESSION CLEANUP ---
if (Test-Path $script:GlobalTemp) {
if ($DevDebug -and $DeepSubtitleAudit) {
        Write-Host " [DevDebug-Main] Temp files preserved at: $script:GlobalTemp" -ForegroundColor DarkGray
    } else {
        # Standard Mode or DevDebug without DSA: Wipe the root temp folder on exit
        Remove-Item -LiteralPath $script:GlobalTemp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($DevDebug) { Stop-Transcript | Out-Null }

Pause