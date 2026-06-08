# ==============================================================================
# SCRIPT: MKVMetadataAuditor+Fixer.ps1
# VERSION: 2026.06.08__13.12.00
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
#    - VERSIONING: Update using CHICAGO TIME (Central Time), 24 hour clock. 
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
$scriptVersion = "2026.06.08__13.12.00"

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
    $tools = @{
        propedit  = Get-Command mkvpropedit.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
        merge     = Get-Command mkvmerge.exe    -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
        extract   = Get-Command mkvextract.exe  -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
        mediainfo = Get-Command MediaInfo.exe   -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    }

    # Fallbacks
    if (-not $tools.propedit) { $tools.propedit = "C:\Program Files\MKVToolNix\mkvpropedit.exe" }
    if (-not $tools.merge)    { $tools.merge    = "C:\Program Files\MKVToolNix\mkvmerge.exe" }
    if (-not $tools.extract)  { $tools.extract  = "C:\Program Files\MKVToolNix\mkvextract.exe" }
    if (-not $tools.mediainfo) { $tools.mediainfo = "C:\Program Files\MediaInfo\MediaInfo.exe" }

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
        [string]$MediaInfoPath
    )
    if (-not (Test-Path -LiteralPath $MediaInfoPath)) { return [PSCustomObject]@{ IsHigh10 = $false; IsReadable = $false; Error = "MediaInfo Missing" } }
    
    # 1. Validation: Check if the file is accessible and if MediaInfo can see its format
    if (-not (Test-Path -LiteralPath $FilePath)) {
        return [PSCustomObject]@{ IsNoHw = $false; IsReadable = $false; Error = "File Not Found" }
    }

    $genFormat = ""
    try {
        # Get multiple fields at once to minimize CLI overhead and verify file structure
        $raw = & $MediaInfoPath --Inform="General;%Format%|%VideoCount%|%FileExtension%" "$FilePath"
        if ($raw -is [array]) { $raw = $raw[0] }
        $parts = "$raw".Split('|')
        
        $genFormat = if ($parts.Count -gt 0) { $parts[0].Trim() } else { "" }
        $vCount    = if ($parts.Count -gt 1) { $parts[1].Trim() } else { "0" }
        $extension = if ($parts.Count -gt 2) { $parts[2].Trim() } else { "" }

        # If MediaInfo cannot determine the container format (genFormat), the file is invalid/corrupted
        # regardless of whether it has a file extension.
        if ([string]::IsNullOrWhiteSpace($genFormat)) {
             return [PSCustomObject]@{ IsHigh10 = $false; IsReadable = $false; Error = "Unreadable Header/Corrupted" }
        }

        # 2. Track Check: Skip profile checks if no video is present (e.g., audio-only files)
        if ($vCount -eq "0" -or [string]::IsNullOrWhiteSpace($vCount)) {
            return [PSCustomObject]@{ IsNoHw = $false; IsReadable = $false; Error = "Unreadable Header/Corrupted" }
        }

        # 3. Extraction: Get specific NoHW compatibility metrics
        $miRaw = & $MediaInfoPath --Inform="Video;%ChromaSubsampling%|%ColorSpace%|%Format_Profile%|%Format%" "$FilePath"
        if ($miRaw -is [array]) { $miRaw = $miRaw[0] }
        $m = "$miRaw".Split('|')
        
        $isHi10 = ($m[2] -match "High 10")
        $is422  = ($m[0] -eq "4:2:2")
        $is444  = ($m[0] -eq "4:4:4")
        $isRGB  = ($m[1] -eq "RGB")

        return [PSCustomObject]@{ 
            IsNoHw     = ($isHi10 -or $is444 -or $is422 -or $isRGB)
            IsReadable = $true
            Format     = $m[3]
            Profile    = $m[2]
            Chroma     = $m[0]
            Space      = $m[1]
            Flags      = @(
                if ($isHi10) { "AVC Hi10P" }
                if ($is422)  { "Chroma 4:2:2" }
                if ($is444)  { "Chroma 4:4:4" }
                if ($isRGB)  { "RGB" }
            ) -join ', '
        }
    } catch {
        return [PSCustomObject]@{ IsNoHw = $false; IsReadable = $false; Error = "CLI Execution Error" }
    }
}

function Get-NoHwLogHeader {
    param([switch]$Fast)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm"
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("-" * 89)
    $lines.Add($ts)
    if ($Fast) { $lines.Add("Fast Scan - First File in Each Folder Only") }
    $lines.Add("NoHW Compatibility Issues Found (Hi10P/4:4:4/4:2:2/RGB)")
    $lines.Add("Recommend convert to HEVC Main 10, Chroma Subsampling: 4:2:0, Color Space: YUV")
    $lines.Add("-" * 89)
    $lines.Add("")
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
        return "und" 
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

    if ($korCount / $total -gt 0.15) { if ($DevDebug) { Write-Host "      -> MATCH: Korean (Hangul)" -ForegroundColor Green }; return "kor" }
    if ($jpnCount / $total -gt 0.05) { if ($DevDebug) { Write-Host "      -> MATCH: Japanese (Kana)" -ForegroundColor Green }; return "jpn" }
    if ($chiCount / $total -gt 0.15) { if ($DevDebug) { Write-Host "      -> MATCH: Chinese (Han)" -ForegroundColor Green }; return "chi" }

    
    # 2. Latin-Based Language Detection
    $latin = [regex]::Matches($text, "[\u0000-\u007F\u0080-\u00FF\u0100-\u017F\u1E00-\u1EFF]").Count
    if ($latin / $total -gt 0.5) {
        if ($DevDebug) { Write-Host "      -> Latin Script Density: $([Math]::Round(($latin / $total) * 100, 2))%" -ForegroundColor Gray }
        
        # English Verification Logic (Hardened Stopwords)
        $engStopwords = "\b(the|you|with|this|they|have|from|would|should|could|there|their)\b"
        $engMatches = [regex]::Matches($text, $engStopwords).Count
        $theCount = [regex]::Matches($text, "\bthe\b").Count
        $honMatches = if ($Honorifics) { [regex]::Matches($text, "-(?:san|kun|chan|sama|dono|senpai|kohai|sensei|niisan|niichan|neesan|neechan|jiisan|jiichan|baasan|baachan|shisou|heika|denka|kakka|tan|chama)\b").Count } else { 0 }

        if ($DevDebug) {
            Write-Host "      -> English Metrics: Stopwords: $engMatches (Min: 26) | 'The' Count: $theCount (Min: 6)" -ForegroundColor Gray
            if ($Honorifics) { Write-Host "      -> Honorifics Metrics: Suffixes found: $honMatches (Min: 1)" -ForegroundColor Gray }
        }
        
        # Validation: Must have a healthy count of English-specific words AND include 'the'.
        $isEnglish = ($engMatches -gt 25 -and $theCount -gt 5)

        if ($isEnglish) {
            if ($Honorifics -and $honMatches -ge 1) { 
                if ($DevDebug) { Write-Host "      -> MATCH: English (Japanese Honorifics) [enm] (Header: eng)" -ForegroundColor Green }
                return "enm" 
            }
            if ($DevDebug) { Write-Host "      -> MATCH: English [eng]" -ForegroundColor Green }
            return "eng" 
        }

        # Safety Fallback
        if ($DevDebug) { Write-Host "      -> NO MATCH: Fallback to header language ($CurrentLang)" -ForegroundColor DarkYellow }
        return $CurrentLang
    }
    return "und"
}

function Extract-DialogueText {
    param($Path, [string]$OutPath, [switch]$DevDebug)
    if ($Path -match "\.(sup|sub)$") { return "IMAGE_SUB_BYPASS" }

    $sb = New-Object System.Text.StringBuilder
    $content = Get-Content $Path -Raw -Encoding utf8 -ErrorAction SilentlyContinue
    if ($content -match "[\u0000]") { $content = Get-Content $Path -Raw -Encoding ansi }
    $lines = $content -split "`r?`n"
    
    $isASS = $Path -match "\.(ass|ssa)$"
    $history = New-Object System.Collections.Generic.List[string]

    foreach ($line in $lines) {
        $line = $line.Trim()
        if ($isASS) {
            if ($line -match "^Dialogue:") {
                if ($line -match "\\(?:p[1-9]|clip|iclip|move|org|t)\b") { continue }
                $parts = $line -split ",", 10
                if ($parts.Count -eq 10) {
                    if ($parts[8] -match "(?:sync|karaoke|fx|ktp|auto)") { continue }
                    $txt = $parts[9]
                    $techRegex = "(?i)(?:circle|square|box|rectangle|line|triangle|oval|star|polygon|cm|mm|width|height|depth|circ|vert|horiz)"
                    if ($txt -match "(?i)^[mb]\s-?\d+" -or $txt -match $techRegex) { continue }
                    $readable = $txt -replace '\{.*?\}', '' -replace '\\[Nnh]', ' '
                    $trimmed = $readable.Trim()
                    if ($history.Contains($trimmed) -or -not ($trimmed -match "\p{L}[,.?!]")) { continue }
                    [void]$sb.AppendLine($trimmed); $history.Add($trimmed)
                    if ($history.Count -gt 10) { $history.RemoveAt(0) }
                }
            }
        } else {
            if ($line -match "-->" -or $line -match "^\d+$" -or [string]::IsNullOrWhiteSpace($line)) { continue }
            $readable = $line -replace '<.*?>', '' -replace '\{.*?\}', ''
            $trimmed = $readable.Trim()
            if ($history.Contains($trimmed) -or -not ($trimmed -match "\p{L}[,.?!]")) { continue }
            [void]$sb.AppendLine($trimmed); $history.Add($trimmed)
            if ($history.Count -gt 10) { $history.RemoveAt(0) }
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
    $val = $global:trackCounters[$type]
    $letter = switch ($type) { "video" { "v" } "audio" { "a" } "subtitles" { "s" } }
    $global:trackCounters[$type]++
    return "$letter$val"
}

function Get-AuditFlags {
    param($tracks, $IsWestern, $fixerConfig, $Honorifics, $SubtitlesHearingImpaired, $FilePath, $MediaInfoPath)
    
    # Use Global Regex Patterns from Main Controller
    $RegexDiag = $script:RegexDiag
    $RegexSign = $script:RegexSign

    $reasons = ""; 
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
    
        # --- DEEP VIDEO INSPECTION (NoHW Flags) ---
    if (Test-Path -LiteralPath $MediaInfoPath) {
        $miRaw = & $MediaInfoPath --Inform="Video;%ChromaSubsampling%|%ColorSpace%|%Format_Profile%|%Format%" "$FilePath"
        if ($miRaw -is [array]) { $miRaw = $miRaw[0] }
        $m = "$miRaw".Split('|')
        
        if ($m.Count -ge 4 -and $m[3] -ne '') {
            if ($m[2] -match "High 10") { $reasons += "🔟 [NoHW: AVC Hi10P] " }
            if ($m[0] -eq "4:2:2")      { $reasons += "🎨 [NoHW: Chroma 4:2:2] " }
            if ($m[0] -eq "4:4:4")      { $reasons += "🎨 [NoHW: Chroma 4:4:4] " }
            if ($m[1] -eq "RGB")        { $reasons += "🌈 [NoHW: RGB] " }
        }
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
        $honMatchRegex = "(?<!no\s|non-|without\s|removed\s|no-)(honorific|honor)"
        $isHon = ($trackName -match $honMatchRegex) -or ($trackLang -eq "enm") -or ($t.DSA_DetectedLang -eq "enm")
        if ($isHon) { 
            $score += 300 
            [void]$ruleLog.Add("Honorifics(+300)")
        }
    }

    # 5. Language Scoring
    $isPrefLang = ($trackLang -eq $fixerConfig.Subtitles.PreferredLanguage)
    $honRegex = "(?<!no\s|non-|without\s|removed\s|no-)(honorific|honor)"
    $dsaDetected = $t.DSA_DetectedLang
    # [MOD] Prioritize Detection over Header: Since headers are normalized to 'eng', 
    # we rely on DSA's 'enm' detection or honorific name keywords to trigger the bonus.
    $isHonorificsTrack = ($trackLang -eq "enm") -or ($dsaDetected -eq "enm") -or ($trackName -match $honRegex)
    
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
    "  • MKVToolNix (mkvextract): Utilized by the Deep Subtitle Audit engine",
    "    to dump raw subtitle streams for size comparison analysis.",    
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

    &$PrintManualBlock "  -NoHwVideoSearch | -nohw | -h10p" @(
    "      Search Mode: Scans for NoHW compatibility issues (Hi10P, Chroma 4:2:2,",
    "      Chroma 4:4:4, or RGB). Use with -fast for quicker scanning.`n"
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

    &$PrintManualBlock "  -DeepSubtitleAudit | -DSA | -Deep | -DeepAudit" @(
    "      Triggers an advanced audit for files containing exactly two unnamed text",
    "      subtitle tracks with matching codecs. If track headers are ambiguous,",
    "      it extracts the streams to analyze file size deltas, automatically",
    "      classifying the smaller track as Signs & Songs and the larger track as",
    "      Full Dialogue. When executed with the -Fix switch, the script will",
    "      automatically apply the correct names to the tracks via mkvpropedit.",
    "      Includes built-in safety margins to skip processing if both tracks",
    "      are nearly identical in size (e.g., dual Full Dialogue tracks).`n"
)

    &$PrintManualBlock "  -DeepSubtitleAuditDebugExtraction | -DSADebugEx | -DeepDebugEx | -DeepAuditDbgEx | -DSADE" @(
    "      Forces the DSA engine to skip the 'Stage 1 Header Probe' and proceed",
    "      directly to 'Stage 2 Extraction'. Useful for testing the bitstream",
    "      size analysis on files with valid headers.`n"
)

    &$PrintManualBlock "  -DeepSubtitleAuditLanguageDetectionLimit2 | -DSALDL2 | -LDL2" @(
    "      Limits the DSA engine to files containing only 1 or 2 subtitle tracks.",
    "      When active, files with 3 or more subtitles will be skipped entirely",
    "      by the Deep Audit engine.`n"
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

    &$PrintManualBlock "  -DevDebug | -Dev | -DevD | -DBG | -DDBG" @(
    "      Global Debugging Switch. Clears standard UI reduction rules to expose",
    "      low-level automated processes. Specifically surfaces the active system",
    "      paths discovered for critical backend dependencies (mkvmerge, mkvextract,",
    "      mkvpropedit, and MediaInfo) during initial script verification. Additionally,",
    "      it preserves the low-level discovery telemetry on screen by disabling standard",
    "      console clearing rules when initiating an AVC High 10 Search, triggers real-time",
    "      terminal tracing for Deep Subtitle Audit (DSA) extraction thresholds, and details",
    "      the exact arithmetic scoring breakdown applied to every subtitle candidate.`n"
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
    $allowedNoHwFlags = @('NoHwVideoSearch', 'Fast', 'disableRecurse', 'Path', 'nohw', 'PathParts', 'ep', 'excludePaths', 'LogFullPath', 'lfp', 'DevDebug')

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
    Write-Host "`n [DevDebug-Main] Tool Discovery:" -ForegroundColor DarkYellow
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

# --- GLOBAL TEMP CONFIGURATION ---
$script:GlobalTemp = Join-Path $env:TEMP "MKVMetadataAuditor+Fixer"

# Startup Cleanup: Clear old artifacts from previous sessions
if (Test-Path $script:GlobalTemp) { 
    Remove-Item -LiteralPath $script:GlobalTemp -Recurse -Force -ErrorAction SilentlyContinue 
}
New-Item -Path $script:GlobalTemp -ItemType Directory | Out-Null

$noHwList = New-Object System.Collections.Generic.List[string]
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
    $dsaDisp = "Active"
    $dsaFlags = New-Object System.Collections.Generic.List[string]
    if ($PSBoundParameters.ContainsKey('DeepSubtitleAudit')) { [void]$dsaFlags.Add("Full Pass") }
    if ($DeepSubtitleAuditDebugExtraction) { [void]$dsaFlags.Add("Forced Extraction") }
    if ($DeepSubtitleAuditLanguageDetectionLimit2) { [void]$dsaFlags.Add("2-Track Limit") }
    if ($DeepSubtitleAuditNOLanguageDetection) { [void]$dsaFlags.Add("No Lng Detect") }
    
    if ($dsaFlags.Count -gt 0) { $dsaDisp += " ($($dsaFlags -join ' + '))" }
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
    "Begin NoHW Video Search Fast with Log Full File Path?" 
} elseif ($NoHwVideoSearch -and $Fast) { 
    "Begin NoHW Video Search Fast?"
} elseif ($NoHwVideoSearch) { 
    "Begin NoHW Video Search?"
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
    # Using ${Message} ensures the colon is treated as plain text
    # PadRight(100) ensures the entire line is cleared before writing the new one
    # [FIX] v2026.06.02_22.09.00 - Standardized flat line sequential padding for safe terminal streaming
    $progressLine = "[SHIELD] ${Message}: [$bar] $percent% ($Current/$Total)".PadRight(120)

    
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
    # [FIX] v2026.05.15_15.02.00 - Bypass probes if searching to match Finder speed
    if (-not $NoHwVideoSearch) {
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
    
    # NoHW Video SCAN (MediaInfo)
    # This runs BEFORE the auditor/grouping logic so it actually sees the files
    # --- SEARCH LOGIC (NoHW Compatibility Engine) ---

    
    # v2026.05.13_16.08.00 - Finalized Spacing & One-Time Fast Header
    if ($NoHwVideoSearch) {
        $scanFiles = if ($fast) { $mkvFiles | Select-Object -First 1 } else { $mkvFiles }
        $foundFlags = New-Object System.Collections.Generic.HashSet[string]
        
        foreach ($f in $scanFiles) {
            $sessionProgressIndex++
            if ($sessionProgressIndex % 10 -eq 0 -or $sessionProgressIndex -eq $totalSessionItems) {
                $statusMsg = if ($fast) { "Processing Folders" } else { "Processing Files" }
                Write-InlineProgress -Current $sessionProgressIndex -Total $totalSessionItems -Message $statusMsg
            }
            
            if ($DevDebug) { 
                Write-Host "`n [DevDebug-NoHW] File Path: $($f.FullName)" -ForegroundColor Gray
                Write-Host " [DevDebug-NoHW] File Name: $($f.Name)" -ForegroundColor DarkGray
            }

            $status = Test-IsNoHw -FilePath $f.FullName -MediaInfoPath $mediainfo
            
            if ($DevDebug) {
                if (-not $status.IsReadable) { 
                    Write-Host " [DevDebug-NoHW] Status: ERROR | $($status.Error)" -ForegroundColor Red 
                } else {
                    Write-Host " [DevDebug-NoHW] Status: $($status.Format) | $($status.Profile) | $($status.Chroma) | $($status.Space)" -ForegroundColor Gray
                }
            }

            if (-not $status.IsReadable) {
                $corruptCount++
                $noHwList.Add("[ERROR] UNREADABLE: $($f.FullName) - Reason: $($status.Error)")
                Write-Host "`n  [!] CORRUPT/UNREADABLE FILE FOUND: $($f.Name)" -ForegroundColor DarkRed
            }
            elseif ($status.IsNoHw) {
                $noHwCount++
                
                # Collect Detected Flags for the Folder Entry
                if ($status.Flags -match "Hi10P") { [void]$foundFlags.Add("🔟[NoHW: AVC Hi10P]") }
                if ($status.Flags -match "4:2:2") { [void]$foundFlags.Add("🎨[NoHW: Chroma 4:2:2]") }
                if ($status.Flags -match "4:4:4") { [void]$foundFlags.Add("🎨[NoHW: Chroma 4:4:4]") }
                if ($status.Flags -match "RGB")   { [void]$foundFlags.Add("🌈[NoHW: RGB]") }

                $entryToAdd = if ($fast -and -not $LogFullPath) { $folderPath.FullName.TrimEnd('\') } else { $f.FullName }
                $noHwList.Add($entryToAdd)
                
                Write-Host "`n  [!] Found NoHW ($($status.Flags)): $($f.Name)" -ForegroundColor DarkYellow
            }
        }
        # Sorts alphabetically by the text inside the brackets (ignoring the emoji)
        $sortedFlags = $foundFlags | Sort-Object { $_ -replace '^[^\[]+', '' }
        $folderFoundLabel = if ($foundFlags.Count -gt 0) { "Found: " + ($sortedFlags -join ' ') } else { "" }
        Write-Host "" # Clears the inline progress line
        
        # v2026.05.13_16.32.00 - Periodic 60-Second Flush
        if ($noHwList.Count -gt 0) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"

            
            # Detailed Block Construction
            $border = "-" * 89
            $leadingSpace = (Test-Path $noHwLog) -or ($logBuffer.Count -gt 0) ? "`r`n" : ""
            
            $logBuffer.Add("$leadingSpace$border")
            $logBuffer.Add($timestamp)
            if ($fast) { $logBuffer.Add("Fast Scan - First File in Each Folder Only") }
            $logBuffer.Add("Folder: $($folderPath.FullName)")
            if ($folderFoundLabel) { $logBuffer.Add($folderFoundLabel) }
            $logBuffer.Add("Recommend convert to HEVC Main 10, Chroma Subsampling: 4:2:0, Color Space: YUV")
            $logBuffer.Add($border)

            # In Standard mode, list the files below the border. In Fast mode, end the block at the border.
            if (-not $fast) {
                $logBuffer.Add("")
                foreach ($line in $noHwList) { $logBuffer.Add($line) }
            }
            
            $noHwList.Clear()
        }

        # CHECK TIMER: If 60 seconds passed, flush to disk
        if (([DateTime]::Now - $lastFlushTime).TotalSeconds -ge 60 -and $logBuffer.Count -gt 0) {
            Write-Host " [i] 60s Elapsed: Flushing log buffer to disk..." -ForegroundColor Cyan
            $logBuffer | Out-File -FilePath $noHwLog -Append -Encoding utf8
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
    if ($NoHwVideoSearch) {
        Write-Host " [✓] AVC High 10 Scan complete for this folder." -ForegroundColor DarkGreen
    } else {
        $mkvCount = $mkvFiles.Count
        $orderedGroups = New-Object System.Collections.Generic.List[PSObject]
        
        for ($i = 0; $i -lt $mkvCount; $i++) {
            $f = $mkvFiles[$i]
            # 1. Update the user with the progress bar immediately
            # [FIX] v2026.06.02_22.09.00 - Assign mode message string for analyzer
            $analyzerMsg = if ($CurrentJob.Mode -eq "Verification") { "Verifying Updates" } else { "Analyzing Files" }
            Write-InlineProgress -Current ($i + 1) -Total $mkvCount -Message $analyzerMsg
            
            if ($DevDebug) {
                Write-Host "`n`n`n [DevDebug-Main] File Path: $($f.FullName)" -ForegroundColor Gray
                Write-Host " [DevDebug-Main] File Name: $($f.Name)" -ForegroundColor DarkGray
            }
            
            # 2. Log path to file
            $f.FullName | Out-File $pathLog -Append -Encoding utf8
            
            # 3. Get JSON and build signature
            $json = & $mkvmerge -J $f.FullName | ConvertFrom-Json
            $f | Add-Member -NotePropertyName "PristineJson" -NotePropertyValue $json -Force
            # [CHANGE] v2026.05.29__15.48.15 - Add Selector (Sel) to Audit Signature
            Get-AuditSelector -Reset
            $sig = (($json.tracks | ForEach-Object { 
                $p = $_.properties
                $sel = Get-AuditSelector $_.type
                "$($_.id)|$sel|$($_.type)|$($_.codec)|$($p.language)|Def:$([bool]$p.default_track)|Frc:$([bool]$p.forced_track)|HI:$([bool]$p.flag_hearing_impaired)|$($p.track_name)" 
            }) -join "`n")
            
            # Signature Debugging
            if ($DevDebug) {
                Write-Host " [DevDebug-Main] Generating Track Signature..." -ForegroundColor DarkCyan
                $sig.Split("`n") | ForEach-Object { Write-Host "    $($_.Trim())" -ForegroundColor Gray }
            }
            
            # --- SEPARATE NOHW VIDEO SEARCH ---
            if ($NoHwVideoSearch -and (Test-Path -LiteralPath $mediainfo)) {
                $status = Test-IsNoHw -FilePath $f.FullName -MediaInfoPath $mediainfo
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
            $reasons = Get-AuditFlags -tracks $currentGroup.Json.tracks -IsWestern $Western -fixerConfig $fixerConfig -Honorifics $Honorifics -SubtitlesHearingImpaired $SubtitlesHearingImpaired -FilePath $repFile.FullName -MediaInfoPath $mediainfo

            
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

            foreach ($track in $fToFix.PristineJson.tracks) {
                # Clean up temporary DSA flags
                $track.PSObject.Properties.Remove("DSA_DetectedLang")
                    if ($track.properties.PSObject.Properties["DSA_Handled"]) { 
                        $track.properties.PSObject.Properties.Remove("DSA_Handled") 
                    }
                    
                    # Revert track name and language to original values from disk before evaluation
                    if ($null -ne $dsaCtx) {
                        if ($dsaCtx.OriginalNames.ContainsKey($track.id)) {
                            $orig = $dsaCtx.OriginalNames[$track.id]
                            $track.properties.track_name = if ($orig -eq "[None]") { "" } else { $orig }
                        }
                        if ($dsaCtx.OriginalLangs.ContainsKey($track.id)) {
                            $track.properties.language = $dsaCtx.OriginalLangs[$track.id]
                        }
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
                        if ($DeepSubtitleAudit -and -not $dsaFileProcessed) {
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
                                        continue 
                                    }
                                    if ($DevDebug) { Write-Host "  [DevDebug-DSA] Discovery: File accepted for Language Probe (Count: $($allSubs.Count))" -ForegroundColor Cyan }

                                    # [TRUTH CAPTURE] Take the snapshot BEFORE language detection runs
                                    $origNames = @{}; $origLangs = @{}
                                    foreach ($sub in $allSubs) {
                                        $origNames[$sub.id] = if ([string]::IsNullOrWhiteSpace($sub.properties.track_name)) { "[None]" } else { $sub.properties.track_name }
                                        $origLangs[$sub.id] = $sub.properties.language
                                    }

                                    $currentGroup | Add-Member -MemberType NoteProperty -Name $fileGuid -Value @{ "Tracks" = $allSubs; "Weights" = @{}; "OriginalNames" = $origNames; "OriginalLangs" = $origLangs } -Force
                                } else {
                                    if ($DevDebug -and $isLdl2Restricted) { Write-Host "  [DevDebug-DSA] Skipping: File has $($allSubs.Count) tracks (Limit2 is Active)" -ForegroundColor DarkGray }
                                    elseif ($DevDebug) { Write-Host "  [DevDebug-DSA] Skipping: File does not contain subtitle tracks." -ForegroundColor DarkGray }
                                    $currentGroup | Add-Member -MemberType NoteProperty -Name $fileGuid -Value $null -Force
                                }
                            }

                            $dsaCtx = $currentGroup.PSObject.Properties[$fileGuid].Value
                            if ($null -ne $dsaCtx) {
                                $ambiguousTracks = $dsaCtx.Tracks

                                # --- STAGE 2: PROBING PHASE (Weights and Language Detection) ---
                                if ($dsaCtx.Weights.Count -eq 0) {
                                    if ($DevDebug -and $DeepSubtitleAuditNOLanguageDetection) {
                                        Write-Host "  [DevDebug-DSA] Language Detection: DISABLED via flag (-NLD)" -ForegroundColor DarkGray
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
                                                    if ($DevDebug) { Write-Host "  [DevDebug-DSA] Header Probe Skip: Ratio too low ($($hRatio.ToString('F2')))." -ForegroundColor DarkYellow }
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
                                            
                                            # OPTIMIZATION: Skip extraction of picture subs if there are 3+ tracks.
                                            # Density/Ratio checks only apply to 1 or 2 track scenarios.
                                            if ($isImageSub -and $ambiguousTracks.Count -gt 2) {
                                                if ($DevDebug) { Write-Host "  [DevDebug-DSA] Skip Extraction: ID:$($sub.id) is Picture Sub and file has >2 tracks." -ForegroundColor DarkGray }
                                                continue
                                            }
                                            
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
                                                    $cleanText = Extract-DialogueText -Path $probeFile -OutPath (Join-Path $tempDir "track$($sub.id + 1)_cleaned.txt") -DevDebug:$DevDebug
                                                    
                                                    # Language Detection
                                                    if (-not $DeepSubtitleAuditNOLanguageDetection) {
                                                        # Resolve the 1-based selector (s1, s2, etc) for the display
                                                        $allSubs = @($fToFix.PristineJson.tracks | Where-Object { $_.type -eq "subtitles" })
                                                        $subIdx = [array]::IndexOf($allSubs, $sub) + 1
                                                        $tmpSel = "s$subIdx"

                                                        $detected = Detect-SubtitleLanguage -Text $cleanText `
                                                                                            -CurrentLang $sub.properties.language `
                                                                                            -Honorifics:$Honorifics `
                                                                                            -DevDebug:$DevDebug `
                                                                                            -TrackID $sub.id `
                                                                                            -Selector $tmpSel `
                                                                                            -TrackName $sub.properties.track_name

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
                                                            $needsChange = $true
                                                            $sub.properties.language = $detected
                                                        }
                                                    }
                                                    $dsaCtx.Weights[$sub.id] = $cleanText.Length
                                                } else {
                                                    # Image Sub Weights (Binary Size)
                                                    $dsaCtx.Weights[$sub.id] = (Get-Item -LiteralPath $probeFile).Length
                                                }
                                            }
                                        }

                                        # [Stage 2.3] RATIO CALCULATION: Exactly 2 tracks required for Sizing Decision
                                        if ($ambiguousTracks.Count -eq 2) {
                                            $id1 = $ambiguousTracks[0].id; $id2 = $ambiguousTracks[1].id
                                            $w1 = $dsaCtx.Weights[$id1]; $w2 = $dsaCtx.Weights[$id2]

                                            # Codec Family Check
                                            $textPattern = "s_text|utf8|srt|ass|ssa|substationalpha|subrip"
                                            $isText1 = $ambiguousTracks[0].codec -match $textPattern; $isText2 = $ambiguousTracks[1].codec -match $textPattern
                                            $isPGS1  = $ambiguousTracks[0].codec -match "pgs";        $isPGS2  = $ambiguousTracks[1].codec -match "pgs"
                                            $isVob1  = $ambiguousTracks[0].codec -match "vobsub";     $isVob2  = $ambiguousTracks[1].codec -match "vobsub"

                                            if (($isText1 -and $isText2) -or ($isPGS1 -and $isPGS2) -or ($isVob1 -and $isVob2)) {
                                                # [FIX] Gate changed to -or to allow ratios when one track is filtered to 0
                                                $bRatio = if ($w1 -gt 0 -or $w2 -gt 0) { [Math]::Max($w1, $w2) / [Math]::Max(1, [Math]::Min($w1, $w2)) } else { 0 }
                                                
                                                $minReq = if ($isText1) { 2.0 } else { 3.0 }

                                                if ($bRatio -ge $minReq) {
                                                    if ($DevDebug) { Write-Host "  [DevDebug-DSA] Bitstream/Text Probe SUCCESS (Ratio: $($bRatio.ToString('F2')))" -ForegroundColor Green }
                                                    $isResolved = $true
                                                    $currentGroup | Add-Member -MemberType NoteProperty -Name ($fileGuid + "_Ratio") -Value $minReq -Force
                                                } else {
                                                    if ($DevDebug) { Write-Host "  [DevDebug-DSA] Ratio too low ($($bRatio.ToString('F2'))). Skipping Naming logic." -ForegroundColor DarkGray }
                                                }
                                            } else {
                                                if ($DevDebug) { Write-Host "  [DevDebug-DSA] Analysis Skipped: Mixed Codec Families detected." -ForegroundColor DarkGray }
                                            }
                                        }

                                        # Cleanup artifacts
                                        if ($DevDebug) {
                                            $allSubs = @($fToFix.PristineJson.tracks | Where-Object { $_.type -eq "subtitles" })
                                            foreach ($sub in $ambiguousTracks) {
                                                $sIdx = [array]::IndexOf($allSubs, $sub) + 1
                                                $sSel = "s$sIdx"
                                                $kb = [Math]::Round($dsaCtx.Weights[$sub.id] / 1024, 3)
                                                Write-Host "    [DevDebug-DSA] Final Weight ID:$($sub.id) - Track $($sub.id + 1) - [$sSel]...($kb KB)" -ForegroundColor Gray
                                            }
                                            Write-Host "    [DevDebug-DSA] Preservation Active: Files kept at -> $tempDir" -ForegroundColor DarkCyan
                                        } else {
                                            if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
                                        }
                                    }
                                }
                                
                                # --- STAGE 3: DECISION LOGIC (SINGLE TRACK VALIDATION) ---
                                
                                # Aggressive Role Sanitization Filter
                                $roleFilter = "(?i)\b(full|dialogue|dialog|honorifics?|honor|signs|songs|english|eng|subs|subtitles|main|lyrics|translated|translation)\b"
                                $SanitizeName = { param($n) ($n -replace $roleFilter, ' ' -replace '[\(\)\[\]\{\}\-\.\:\&\+]', ' ').Trim() -replace '\s+', ' ' }

                                # Phase A: Universal Honorifics & Language Normalization (ALL tracks)
                                foreach ($tH in $ambiguousTracks) {
                                    $isHonDet = ($tH.DSA_DetectedLang -eq "enm" -or $tH.properties.language -eq "enm" -or $tH.properties.track_name -match "(?i)honorific|honor")
                                    if ($isHonDet) {
                                        $curName = if ($tH.properties.track_name) { $tH.properties.track_name } else { "" }
                                        
                                        # 1. Language Normalization: Force header to 'eng'
                                        if ($tH.properties.language -ne "eng") {
                                            $needsChange = $true
                                            if ($Fix) { $Params += @('--edit', "track:$($tH.id + 1)", '--set', "language=eng") }
                                        }

                                        # 2. Smart Naming: Standardize via Sanitization
                                        # First, extract group by stripping role keywords
                                        $cleanGroupName = &$SanitizeName $curName
                                        $newName = if ([string]::IsNullOrWhiteSpace($cleanGroupName)) { "Honorifics Full Dialogue" } else { "Honorifics Full Dialogue [$cleanGroupName]" }
                                        
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
                                if ($ambiguousTracks.Count -eq 2 -and $null -ne $currentGroup.PSObject.Properties[$fileGuid + "_Ratio"]) {
                                    $w1 = $dsaCtx.Weights[$ambiguousTracks[0].id]
                                    $w2 = $dsaCtx.Weights[$ambiguousTracks[1].id]
                                    
                                    # [FIX] Gate changed to -or to allow naming logic when one track is filtered to 0
                                    if ($w1 -gt 0 -or $w2 -gt 0) {
                                        # [FIX] Added Max(1, ...) safety wrapper to prevent DivideByZero when one weight is 0
                                        $ratio = [Math]::Max($w1, $w2) / [Math]::Max(1, [Math]::Min($w1, $w2))
                                        $dynRatio = $currentGroup.PSObject.Properties[$fileGuid + "_Ratio"].Value
                                        
                                        $largeTrack = if ($w1 -gt $w2) { $ambiguousTracks[0] } else { $ambiguousTracks[1] }
                                        $smallTrack = if ($w1 -gt $w2) { $ambiguousTracks[1] } else { $ambiguousTracks[0] }
                                        
                                        $nameL = if ($largeTrack.properties.track_name) { $largeTrack.properties.track_name } else { "" }
                                        $nameS = if ($smallTrack.properties.track_name) { $smallTrack.properties.track_name } else { "" }
                                        
                                        # [FIX] Determine EFFECTIVE language for truth check (Detected or Header)
                                        $effL0 = if ($ambiguousTracks[0].DSA_DetectedLang) { $ambiguousTracks[0].DSA_DetectedLang } else { $ambiguousTracks[0].properties.language }
                                        $effL1 = if ($ambiguousTracks[1].DSA_DetectedLang) { $ambiguousTracks[1].DSA_DetectedLang } else { $ambiguousTracks[1].properties.language }
                                        $isDualEng = ($effL0 -match "eng|enm" -and $effL1 -match "eng|enm")
                                        
                                        if ($ratio -ge $dynRatio -and $isDualEng) {
                                            # Aggressive Role Filtering
                                            $roleFilter = "(?i)\b(full|dialogue|dialog|honorifics|honor|signs|songs|english|eng|subs|subtitles|main|lyrics|translated|translation)\b"

                                            # Check handled status (Phase A)
                                            $handledL = $largeTrack.properties.DSA_Handled
                                            $handledS = $smallTrack.properties.DSA_Handled

                                            $hasDiagL = ($nameL -match $script:RegexDiag) -or $handledL
                                            $hasSignL = ($nameL -match $script:RegexSign)
                                            $hasDiagS = $nameS -match $script:RegexDiag
                                            $hasSignS = $nameS -match $script:RegexSign
                                            
                                            # Check if name is missing "Honorific" despite detection
                                            $isHonDet = ($largeTrack.DSA_DetectedLang -eq "enm" -or $largeTrack.properties.language -eq "enm")
                                            $isNameMissingHon = ($isHonDet -and $nameL -notmatch "(?i)honorific|honor")
                                            
                                            $actionMsg = ""

                                            # [Condition 3.1] SWAP REQUIRED
                                            if (($nameL -match $script:RegexSign) -and ($nameS -match $script:RegexDiag)) {
                                                $needsChange = $true
                                                $largeTrack.properties | Add-Member -NotePropertyName "DSA_Handled" -NotePropertyValue $true -Force
                                                $smallTrack.properties | Add-Member -NotePropertyName "DSA_Handled" -NotePropertyValue $true -Force

                                                # Standardize Names during swap
                                                $groupL = &$SanitizeName $nameS
                                                $groupS = &$SanitizeName $nameL
                                                
                                                $isHonL = ($largeTrack.DSA_DetectedLang -eq "enm" -or $largeTrack.properties.language -eq "enm" -or $nameS -match "Honorifics")
                                                $roleL = if ($isHonL) { "Honorifics Full Dialogue" } else { "Full Dialogue" }
                                                
                                                $nameS = if ([string]::IsNullOrWhiteSpace($roleL)) { "Full Dialogue" } else { if ([string]::IsNullOrWhiteSpace($groupL)) { $roleL } else { "$roleL [$groupL]" } }
                                                $nameL = if ([string]::IsNullOrWhiteSpace($groupS)) { "Signs & Songs" } else { "Signs & Songs [$groupS]" }
                                                if ($Fix) {
                                                    if ($nameS -ne $nameL) {
                                                        $Params += @('--edit', "track:$($largeTrack.id + 1)", '--set', "name=$nameS")
                                                        $Params += @('--edit', "track:$($smallTrack.id + 1)", '--set', "name=$nameL")
                                                    }
                                                }
                                                $largeTrack.properties | Add-Member -NotePropertyName "track_name" -NotePropertyValue $nameS -Force
                                                $smallTrack.properties | Add-Member -NotePropertyName "track_name" -NotePropertyValue $nameL -Force
                                                $actionMsg = "[DSA] SWAP: Swapping '$nameS' to Large and '$nameL' to Small"
                                            }
                                            # [Condition 3.2] FIX GARBAGE/MISSING/HONORIFICS
                                            elseif (-not $hasDiagL -or -not $hasSignS -or ($nameL -match "English Subtitles") -or $isNameMissingHon) {
                                                
                                                # Dialogue Track (Large)
                                                $isHonL = ($largeTrack.DSA_DetectedLang -eq "enm" -or $largeTrack.properties.language -eq "enm" -or $nameL -match "Honorifics")
                                                $isCorrectL = if ($isHonL) { $nameL -match "Honorifics" -and $nameL -match "Full Dialogue" }
                                                              else { $nameL -match "Full Dialogue" -and $nameL -notmatch "Honorifics" }

                                                if (-not $handledL -and -not $isCorrectL) {
                                                    $groupL = &$SanitizeName $nameL
                                                    $roleL = if ($isHonL) { "Honorifics Full Dialogue" } else { "Full Dialogue" }
                                                    $newNameL = if ([string]::IsNullOrWhiteSpace($groupL)) { $roleL } else { "$roleL [$groupL]" }
                                                    
                                                    if ($newNameL -ne $nameL) {
                                                        $needsChange = $true
                                                        if ($Fix) {
                                                            $largeTrack.properties | Add-Member -NotePropertyName "track_name" -NotePropertyValue $newNameL -Force
                                                        }
                                                    }
                                                } else { $newNameL = $nameL }

                                                # Signs Track (Small)
                                                if (-not $handledS -and $nameS -notmatch "Signs & Songs") {
                                                    $groupS = &$SanitizeName $nameS
                                                    $newNameS = if ([string]::IsNullOrWhiteSpace($groupS)) { "Signs & Songs" } else { "Signs & Songs [$groupS]" }

                                                    if ($newNameS -ne $nameS) {
                                                        $needsChange = $true
                                                        if ($Fix) {
                                                            $smallTrack.properties | Add-Member -NotePropertyName "track_name" -NotePropertyValue $newNameS -Force
                                                        }
                                                    }
                                                } else { $newNameS = $nameS }
                                                
                                                if ($newNameL -eq $newNameS) { $newNameL = "Full Dialogue"; $newNameS = "Signs & Songs" }

                                                if ($Fix) {
                                                    if ($newNameL -ne $nameL) { $Params += @('--edit', "track:$($largeTrack.id + 1)", '--set', "name=$newNameL") }
                                                    if ($newNameS -ne $nameS) { $Params += @('--edit', "track:$($smallTrack.id + 1)", '--set', "name=$newNameS") }
                                                }
                                                $largeTrack.properties | Add-Member -NotePropertyName "track_name" -NotePropertyValue $newNameL -Force
                                                $smallTrack.properties | Add-Member -NotePropertyName "track_name" -NotePropertyValue $newNameS -Force
                                                $largeTrack.properties | Add-Member -NotePropertyName "DSA_Handled" -NotePropertyValue $true -Force
                                                $smallTrack.properties | Add-Member -NotePropertyName "DSA_Handled" -NotePropertyValue $true -Force
                                                $actionMsg = "[DSA] FIX: Corrected Garbage/Missing names (Large: '$newNameL', Small: '$newNameS')"
                                            }
                                            else {
                                                $actionMsg = "[DSA] VERIFIED: Track names contain correct role keywords (Ratio: $($ratio.ToString('F2')))"
                                            }

                                            if ($t.id -eq $ambiguousTracks[0].id) {
                                                if ($DevDebug) { 
                                                    if ($actionMsg -match "SWAP|FIX") {
                                                        Write-Host "  [DevDebug-DSA] Found Track:$($ambiguousTracks[0].id + 1) Name: $($dsaCtx.OriginalNames[$ambiguousTracks[0].id])" -ForegroundColor Gray
                                                        Write-Host "  [DevDebug-DSA] Found Track:$($ambiguousTracks[1].id + 1) Name: $($dsaCtx.OriginalNames[$ambiguousTracks[1].id])" -ForegroundColor Gray
                                                    }
                                                    $consoleMsg = $actionMsg -replace '^\[DSA\]', '[DevDebug-DSA]'
                                                    $msgColor = if ($actionMsg -match "SWAP|FIX") { "DarkYellow" } else { "Green" }
                                                    Write-Host "  $consoleMsg" -ForegroundColor $msgColor 
                                                } # Closes: if ($Fix) [Inside Condition 3.2 Fix Garbage/Missing Names]
                                                [void]$fixDetails.Add("  $actionMsg")
                                            } # Closes: if ($t.id -eq $ambiguousTracks[0].id) [Reporting Guard]
                                        } # Closes: if ($ratio -ge $dynRatio -and $isDualEng) [Dual English Ratio Evaluation]
                                    } # Closes: if ($w1 -gt 0 -or $w2 -gt 0) [Zero Safety Gate]
                                } # Closes: if ($ambiguousTracks.Count -eq 2 -and ...) [Stage 3 Exact 2 Tracks Only]
                            } # Closes: if ($null -ne $dsaCtx) [Stage 2/3 Context Verification]
                        } # Closes: if ($DeepSubtitleAudit -and -not $dsaFileProcessed) [Main DSA Engine Open]
                        # --- END DSA ENGINE ---
                        
                        $trackLang = $t.properties.language.ToLower()
                        
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
                    Write-Host "" # Gap between DSA and Fixer
                    Write-Host "  [DevDebug-Fixer] Scoring file at path: $($fToFix.FullName)" -ForegroundColor Gray
                    Write-Host "  [DevDebug-Fixer] Subtitle Scoring Candidates:" -ForegroundColor Cyan
                    [void]$fixDetails.Add("  [DevDebug-Fixer] Subtitle Scoring Breakdown:")
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

# v2026.05.13_16.32.00 - Final Flush after loop ends
if ($logBuffer.Count -gt 0) {
    $logBuffer | Out-File -FilePath $noHwLog -Append -Encoding utf8
    $logBuffer.Clear()
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