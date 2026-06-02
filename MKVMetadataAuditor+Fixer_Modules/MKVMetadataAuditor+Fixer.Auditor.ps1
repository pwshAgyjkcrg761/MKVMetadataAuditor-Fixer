# ==============================================================================
# MODULE: MKVMetadataAuditor+Fixer.Auditor.ps1
# VERSION: 2026.06.02__11.53.00
# ==============================================================================

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
    param($tracks, $IsWestern, $fixerConfig, $Honorifics, $SubtitlesHearingImpaired)
    
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
    
    $vTrack = $tracks | Where-Object { $_.type -eq "video" } | Select-Object -First 1
    if ($null -ne $vTrack) {
        $privData = if ($null -ne $vTrack.properties.codec_private) { $vTrack.properties.codec_private } else { $vTrack.properties.codec_private_data }
        if ($null -ne $privData -and $privData.Length -ge 4) {
            if ($privData.Substring(2, 2) -eq "6e") { $reasons += "🔟[AVC High 10 Profile] " }
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

function Get-HeaderBlock {
    param($codecPadding, $propPadding, $namePadding)
    $h = "Codec".PadRight($codecPadding) + " | " + "   ID".PadRight(12) + " | " + "Sel.".PadRight(4) + " | " + "Type".PadRight(9) + " | " + "Lng" + " | " + "Flags".PadRight($propPadding) + " | " + "Name".PadRight($namePadding)
    $bar = "-" * $h.Length
    return $bar, $h
}