# ==============================================================================
# SCRIPT: auditor+fixer.ps1
# VERSION: v2026.05.01_11.02.00
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
    [switch]$NoBackup    # Disables the automatic 1-by-1 backup
)

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
foreach ($dir in @($rootLog,$pLogDir,$dLogDir,$mLogDir,$cLogDir)) { if (-not (Test-Path $dir)) { New-Item $dir -ItemType Directory | Out-Null } }

$ts = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$pathLog = Join-Path $pLogDir "auditor+fixer_Paths_$($ts)-log.txt"
$detailLog = Join-Path $dLogDir "auditor+fixer_Details_$($ts)-log.txt"
$missLog = Join-Path $mLogDir "auditor+fixer_Mismatches_$($ts)-log.txt"
$compLog = Join-Path $cLogDir "auditor+fixer_Comparison_$($ts)-log.txt"

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

function Invoke-MkvBackup {
    param([string]$FilePath)
    $fileDir = Split-Path -LiteralPath $FilePath -Parent
    $backupDir = Join-Path $fileDir "Backups"
    if (-not (Test-Path -LiteralPath $backupDir)) { New-Item -Path $backupDir -ItemType Directory | Out-Null }
    $fileName = Split-Path -LiteralPath $FilePath -Leaf
    Write-Host "  [BACKUP] Copying: $fileName..." -ForegroundColor Gray
    Copy-Item -LiteralPath $FilePath -Destination (Join-Path $backupDir $fileName) -Force
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
    $orderedGroups = New-Object System.Collections.Generic.List[PSObject]
    foreach ($f in $mkvFiles) {
        $f.FullName | Out-File $pathLog -Append -Encoding utf8
		$json = & $mkvmerge -J $f.FullName | ConvertFrom-Json
        $sig = (($json.tracks | ForEach-Object { "$($_.id)|$($_.type)|$($_.codec)|$($_.properties.language)|$($_.properties.default_track)|$($_.properties.track_name)" }) -join "`n")
        $existingGroup = $orderedGroups | Where-Object { $_.Sig -eq $sig }
        if ($null -eq $existingGroup) {
            $orderedGroups.Add([PSCustomObject]@{ Sig = $sig; Files = New-Object System.Collections.Generic.List[PSObject]; Json = $json })
            $existingGroup = $orderedGroups[-1]
        }
        $existingGroup.Files.Add($f)
    }

    $primaryGroup = $orderedGroups[0]
    $mismatches = $mkvFiles.Count - $primaryGroup.Files.Count
	
	# If there are mismatches, print the Folder header to the mismatch log once
    if ($mismatches -gt 0) {
		# Check if file exists and has content to decide if we need a leading spacer
        $spacer = if (Test-Path $missLog) { "`r`n" } else { "" }
        $folderHeader = "${spacer}Folder: $($folder.FullName)"
        $folderHeader | Out-File $missLog -Append -Encoding utf8
    }

    # --- PROCESS GROUPS ---
    for ($g = 0; $g -lt $orderedGroups.Count; $g++) {
        $currentGroup = $orderedGroups[$g]
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
		$entry.Add("===Matches ${label} [$($repFile.Name)]: $($currentGroup.Files.Count.ToString('00'))===")
        for ($i = 0; $i -lt $currentGroup.Files.Count; $i++) {
            $entry.Add("  - $($currentGroup.Files[$i].Name)")
        }

        # --- FIX ACTIONS (EXACT LOGIC) ---
        if ($Fix -and -not $isPrimary) {
            $entry.Add(""); $entry.Add("FIX ACTIONS EXECUTED:")
            foreach ($fToFix in $currentGroup.Files) {
                if (-not $NoBackup) { Invoke-MkvBackup -FilePath $fToFix.FullName }
                $Params = @(); Get-Selector -Reset
                foreach ($t in $currentGroup.Json.tracks) {
                    $sel = Get-Selector $t.type
                    $Params += @('--edit', "track:$sel", '--set', 'flag-default=0')
                    if ($t.type -eq "audio" -and $t.properties.language -eq "jpn") {
                        $Params += @('--edit', "track:$sel", '--set', 'flag-default=1')
                        $entry.Add("  [$sel] SET JPN AUDIO DEFAULT -> $($fToFix.Name)")
                    }
                    if ($t.type -eq "subtitles" -and $t.properties.language -eq "eng" -and $t.properties.track_name -notmatch "Signs|Songs|SDH|HI/CC") {
                        $Params += @('--edit', "track:$sel", '--set', 'flag-default=1')
                        $entry.Add("  [$sel] SET ENG SUBS DEFAULT -> $($fToFix.Name)")
                    }
                }
                if ($Params.Count -gt 0) { & $mkvpropedit "$($fToFix.FullName)" @Params | Out-Null }
            }
        }

        # --- APPEND TO MASTER LOG ---
        $entry | Out-File $detailLog -Append -Encoding utf8
		
		# --- APPEND TO MISMATCH LOG (ONLY IF NOT PRIMARY) ---
        # If the folder has ANY mismatches, include EVERY group (Primary + Mismatches)
        if ($mismatches -gt 0) {
            $entry | Out-File $missLog -Append -Encoding utf8
        }
    }

    # --- HEART SPACER ---
    $spacer = "`r`n.• ♬ ͜͝ ̣̣♡.• ♬ ͜͝ ̣̣♡.• ♬ ͜͝ ̣̣♡..• ♬ ͜͝ ̣̣♡.• ♬ ͜͝ ̣̣♡.• ♬ ͜͝ ̣̣♡..• ♬ ͜͝ ̣̣♡.• ♬ ͜͝ ̣̣♡.• ♬ ͜͝ ̣̣♡.`r`n"
    $spacer | Out-File $detailLog -Append -Encoding utf8
	
	# --- COMPARISON LOG SUMMARY ---
    $matchStatus = if ($mismatches -eq 0) { 
        "✔+++All Files in Folder Match: YES ($($mkvFiles.Count))+++✔" 
    } else { 
        "❌+++All Files in Folder Match: NO (0)+++❌" 
    }

    $compEntry = New-Object System.Collections.Generic.List[string]
    $compEntry.Add("Folder: $($folder.FullName)")
    $compEntry.Add($matchStatus)
    $compEntry.Add("Total: $($mkvFiles.Count) | Matches Primary: $($primaryGroup.Files.Count) | Mismatches: $mismatches")
    $compEntry.Add("") 

    $compEntry | Out-File $compLog -Append -Encoding utf8
}
Write-Host "Complete." -ForegroundColor Cyan
Pause