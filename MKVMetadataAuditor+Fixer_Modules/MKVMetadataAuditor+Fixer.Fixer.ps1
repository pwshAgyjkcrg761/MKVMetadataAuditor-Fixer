# ==============================================================================
# MODULE: MKVMetadataAuditor+Fixer.Fixer.ps1
# VERSION: 2026.06.01__13.06.00
# ==============================================================================

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
    
    # Standard Regex Patterns
    $RegexDiag = "Dialog|Full|Japanese Audio|Main"
    $RegexSign = "Sign|Song|Lyric|Opening|Ending|OP|ED|Partial|Forced|Translation|ASSR|S&S|S\s&\sS|Dubtitle"

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
        if (($trackName -match $honMatchRegex) -or ($trackLang -eq "enm")) { 
            $score += 300 
            [void]$ruleLog.Add("Honorifics(+300)")
        }
    }

    # 5. Language Scoring
    $isPrefLang = ($trackLang -eq $fixerConfig.Subtitles.PreferredLanguage)
    $honRegex = "(?<!no\s|non-|without\s|removed\s|no-)(honorific|honor)"
    $isHonorificsTrack = ($trackLang -eq "enm") -or ($trackName -match $honRegex)
    
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
        if ($trackLang -eq $fixerConfig.Subtitles.PreferredLanguage -and -not $t.properties.forced_track -and $trackName -notmatch "Sign|Song|Lyric") {
            $score += 200 
            [void]$ruleLog.Add("WesternFullSub(+200)")
        }
    }

    return [PSCustomObject]@{ Score = $score; Rules = ($ruleLog -join ' | ') }
}