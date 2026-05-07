# ==============================================================================
# SCRIPT: auditor+fixer.ps1
# VERSION: v2026.05.07_13.00.00
# TARGET: PowerShell 7.6.1 LTS
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
#	 - When printing the script only print snippets unless asked for entire script.
#	 - Always use a codebox with a copy button.
#	 - Show a clear beginning and end to the new code with and example of where to insert.
# ==============================================================================
# </PROTECTED>

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
    [Alias("sc")]  [string]$subtitleCodecPriority
)

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

# 2.5 VALIDATION: Require -ovrd for parameter usage
$usedFlags = @()
if ($PSBoundParameters.ContainsKey('videoLanguage')) { $usedFlags += "-vid" }
if ($PSBoundParameters.ContainsKey('audioLanguagePriority')) { $usedFlags += "-aud" }
if ($PSBoundParameters.ContainsKey('subtitleLanguagePriority')) { $usedFlags += "-sub" }
if ($PSBoundParameters.ContainsKey('subtitleCodecPriority')) { $usedFlags += "-sc" }

if ($usedFlags.Count -gt 0 -and -not $overrideDefaults) {
    Write-Host "==================================================" -ForegroundColor Red
    Write-Host "ERROR: Parameter Override Detected" -ForegroundColor Red
    Write-Host "The following flags were used: $($usedFlags -join ' ')" -ForegroundColor Yellow
    Write-Host "To use these, you MUST also include the -ovrd (or -overrideDefaults) switch." -ForegroundColor White
    Write-Host "This ensures your changes are saved to the config file." -ForegroundColor White
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
$version = "2026.05.07_13.00.00"
Write-Host "=================================================="
Write-Host "auditor+fixer.ps1 v$version" -ForegroundColor Cyan
Write-Host "=================================================="
Write-Host "Config Status: " -NoNewline; Write-Host $configSource -ForegroundColor Yellow
Write-Host "Config Path:   " -NoNewline; Write-Host $configFile -ForegroundColor DarkGray
Write-Host "--------------------------------------------------"
Write-Host "LOADED OPTIONS:" -ForegroundColor White
Write-Host "  Video Target: " -NoNewline; Write-Host "$($fixerConfig.Video.TargetLanguage)" -ForegroundColor Magenta
Write-Host "  Audio Target: " -NoNewline; Write-Host "$($fixerConfig.Audio.PreferredLanguage)" -ForegroundColor Magenta
Write-Host "  Sub Target:   " -NoNewline; Write-Host "$($fixerConfig.Subtitles.PreferredLanguage)" -ForegroundColor Magenta
Write-Host "  Sub Codecs:   " -NoNewline; Write-Host "$($fixerConfig.Subtitles.CodecPriority -join ', ')" -ForegroundColor Magenta
Write-Host "--------------------------------------------------"
#Write-Host "Script Location: " -NoNewline; Write-Host "$PSScriptRoot" -ForegroundColor Yellow
#Write-Host "--------------------------------------------------"
Write-Host "Target Folder(s):" -ForegroundColor White
foreach ($p in $inputPaths) { Write-Host "  -> $p" -ForegroundColor Magent }
Write-Host "--------------------------------------------------"

$choice = Read-Host "Begin processing? (Y/N)"
if ($choice -notmatch "^[yY]$") {
    Write-Host "Operation cancelled by user." -ForegroundColor Yellow
    Pause; exit
}
Write-Host "Starting..." -ForegroundColor Green
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

function Get-AuditFlags($tracks) {
    $reasons = ""; $jpnAud = $tracks | Where-Object { $_.type -eq "audio" -and $_.properties.language -eq "jpn" }
    $subs = $tracks | Where-Object { $_.type -eq "subtitles" }

    if ($tracks | Where-Object { $_.properties.forced_track }) { $reasons += "🚨[Forced Track] " }

    $trackTypes = $tracks | Select-Object -ExpandProperty type -Unique
    foreach ($type in $trackTypes) {
        $defaults = $tracks | Where-Object { $_.type -eq $type -and $_.properties.default_track }
        if ($defaults.Count -gt 1) { 
            $reasons += "⚔️[Conflict: Multiple $($type.ToUpper()) Defaults] " 
        }
    }

    if ($tracks | Where-Object { ($_.type -match "audio|subtitles") -and $_.properties.language -eq "und" }) { $reasons += "❔[Und Lang] " }
    if ($jpnAud -and -not ($jpnAud | Where-Object { $_.properties.default_track })) { $reasons += "🎙[JPN Audio Not Default] " }
    if ($jpnAud -and $subs.Count -eq 0) { $reasons += "⚠️[JPN Audio/No Subs] " }
    
    if ($subs.Count -gt 0) {
        $dSubs = $subs | Where-Object { $_.properties.default_track }
        if ($dSubs | Where-Object { $_.properties.track_name -match "Signs|Songs|Lyrics|Forced" -and $_.properties.track_name -notmatch "Dialogue" }) { $reasons += "🎵[Sub: Signs/Songs Default] " }
        if ($jpnAud -and -not ($subs | Where-Object { $_.properties.language -eq "eng" -and $_.properties.default_track })) { $reasons += "🔇[No ENG Sub Default] " }
        
        # --- PRIORITY ORDERED HI/CC CHECKS ---
        if ($subs | Where-Object { $_.properties.language -eq "eng" -and $_.properties.flag_hearing_impaired }) { $reasons += "👂[ENG Sub HI/CC] " }
        if ($subs | Where-Object { $_.properties.track_name -match "SDH" }) { $reasons += "🙉[SDH Name] " }
        if ($subs | Where-Object { $_.properties.flag_hearing_impaired }) { $reasons += "👀[Sub HI/CC] " }
    }
    
    if ($subs | Where-Object { $_.properties.language -eq "jpn" }) { $reasons += "⛩️[JPN Sub Present] " }
    
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
		$reasons = Get-AuditFlags $currentGroup.Json.tracks
        
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
                    # 1. Resolve the target language from your -vid chi command
                    $targetLangInput = if ($videoLanguage) { $videoLanguage } else { $fixerConfig.Video.TargetLanguage }
                    $target = if ($langMap.ContainsKey($targetLangInput.ToLower())) { $langMap[$targetLangInput.ToLower()] } else { $targetLangInput }

                    # 2. Check if the file is ACTUALLY different from your goal
                    $isIncorrect = ($t.properties.language -ne $target) -or ($t.properties.default_track -ne $true)
                    
                    if ($isIncorrect) {
                        # 3. Add the mkvpropedit command
                        $mkvID = $t.id + 1
						$Params += @('--edit', "track:$mkvID", '--set', "language=$target", '--set', "flag-default=1")
                        
                        # 4. LOGGING: Horizontal pipe-separated format
                        $logReason = if ($videoForceUpdate) { "Video Force (-vidf)" } else { "Passive Update (-vid)" }
                        [void]$fixDetails.Add("  ACTION: SET_LANG=$target | SET_DEFAULT=1 | TRACK: $sel | REASON: $logReason")

                        # 5. Only trigger the actual file write if -vidf was used
                        if ($videoForceUpdate) { $needsChange = $true }
                    }
                    continue 
                }

                # --- AUDIO/SUB TARGETING ---
                if ($t.type -eq "audio" -and -not $foundPrefAudio -and $t.properties.language -eq $fixerConfig.Audio.PreferredLanguage) {
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
                } # Closes Mechanical Trigger (if $winnerNeedsFix -or $losersNeedStrip)
            } # Closes Subtitle Logic Block


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