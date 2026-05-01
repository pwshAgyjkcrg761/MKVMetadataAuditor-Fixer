# ==============================================================================
# SCRIPT: auditor+fixer.ps1
# VERSION: v2026.05.01_05.14.00
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
    $inputPaths.Add('\\SIDES-CLOUD\blakes-videos\anime アニメ japanese 日本語')
} else {
    foreach ($part in ($PathParts | Sort-Object)) { 
        $cleaned = $part.Trim('"')
        if (Test-Path -LiteralPath $cleaned) { $inputPaths.Add($cleaned) }
    }
}

$rootLog = Join-Path $PSScriptRoot "MKV-Metadata-Auditor_Logs"
$pLogDir = Join-Path $rootLog "Path_Logs"; $dLogDir = Join-Path $rootLog "Detail_Logs"
$mLogDir = Join-Path $rootLog "Mismatch_Logs"; $cLogDir = Join-Path $rootLog "Comparison_Logs"
foreach ($dir in @($rootLog,$pLogDir,$dLogDir,$mLogDir,$cLogDir)) { if (-not (Test-Path $dir)) { New-Item $dir -ItemType Directory | Out-Null } }

$ts = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$pathLog = Join-Path $pLogDir "Metadata-Auditor_Paths_$($ts)-log.txt"
$detailLog = Join-Path $dLogDir "Metadata-Auditor_Details_$($ts)-log.txt"
$missLog = Join-Path $mLogDir "Metadata-Auditor_Mismatches_$($ts)-log.txt"

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
    foreach ($type in ($tracks | Select-Object -ExpandProperty type -Unique)) {
        if (($tracks | Where-Object { $_.type -eq $type -and $_.properties.default_track }).Count -gt 1) { $reasons += "⚔️[Conflict: Multiple $($type.ToUpper()) Defaults] " }
    }
    if ($tracks | Where-Object { ($_.type -match "audio|subtitles") -and $_.properties.language -eq "und" }) { $reasons += "❔[Und Lang] " }
    if ($jpnAud -and -not ($jpnAud | Where-Object { $_.properties.default_track })) { $reasons += "🎙[JPN Audio Not Default] " }
    if ($subs.Count -gt 0) {
        if ($subs | Where-Object { $_.properties.language -eq "eng" -and $_.properties.flag_hearing_impaired }) { $reasons += "👂[ENG Sub HI/CC] " }
    }
    return $reasons.Trim()
}

# 3. Main Processing Loop
$targetFolders = Get-ChildItem -LiteralPath $inputPaths -Directory -Recurse | Sort-Object FullName
foreach ($folderPath in $targetFolders) {
    $mkvFiles = Get-ChildItem -LiteralPath $folderPath.FullName -Filter "*.mkv" | Sort-Object Name
    if ($mkvFiles.Count -eq 0) { continue }

    $orderedGroups = New-Object System.Collections.Generic.List[PSObject]
    foreach ($f in $mkvFiles) {
        $json = & $mkvmerge -J $f.FullName | ConvertFrom-Json
        $sig = ($json.tracks | ForEach-Object { "$($_.id)|$($_.type)|$($_.properties.language)|$($_.properties.default_track)|$($_.properties.track_name)" } | Out-String)
        $existingGroup = $orderedGroups | Where-Object { $_.Sig -eq $sig }
        if ($null -eq $existingGroup) {
            $orderedGroups.Add([PSCustomObject]@{ Sig = $sig; Files = New-Object System.Collections.Generic.List[PSObject]; Json = $json })
            $existingGroup = $orderedGroups[-1]
        }
        $existingGroup.Files.Add($f)
    }

    foreach ($group in $orderedGroups) {
        $reason = Get-AuditFlags $group.Json.tracks
        if (-not $reason) { continue }

        foreach ($f in $group.Files) {
            Write-Host "Flagged: $($f.Name) -> $reason" -ForegroundColor Yellow
            
            if ($Fix) {
                if (-not $NoBackup) { Invoke-MkvBackup -FilePath $f.FullName }
                
                $Params = @()
                Get-Selector -Reset
                foreach ($t in $group.Json.tracks) {
                    $sel = Get-Selector $t.type
                    if ($t.properties.language -eq "und") { $Params += @('--edit', "track:$sel", '--set', 'language=eng') }
                    if ($t.type -eq "audio" -and $t.properties.language -eq "jpn" -and -not $t.properties.default_track) { 
                        $Params += @('--edit', "track:$sel", '--set', 'flag-default=1') 
                    }
                }

                if ($Params.Count -gt 0) {
                    & $mkvpropedit "$($f.FullName)" @Params | Out-Null
                    Write-Host "  > Fixed: Metadata updated." -ForegroundColor Green
                }
            }
        }
    }
}
Write-Host "Complete." -ForegroundColor Cyan