# ==============================================================================
# MODULE: MKVMetadataAuditor+Fixer.DeepSubtitleAudit.ps1
# VERSION: 2026.06.01__09.35.00
# ==============================================================================

function Get-SubtitleExtension {
    param([string]$Codec)
    if ($Codec -match "PGS") { return "sup" }
    if ($Codec -match "VobSub") { return "sub" }
    if ($Codec -match "UTF8|SRT") { return "srt" }
    return "ass"
}

function Detect-SubtitleLanguage {
    param([string]$Text, [switch]$Honorifics)
    if ([string]::IsNullOrWhiteSpace($text)) { return "und" }
    $total = $text.Length
    
    # 1. Non-Latin Script Detection
    $arabic   = [regex]::Matches($text, "[\u0600-\u06FF]").Count
    $cyrillic = [regex]::Matches($text, "[\u0400-\u04FF]").Count
    $hangul   = [regex]::Matches($text, "[\uAC00-\uD7AF]").Count
    $kana     = [regex]::Matches($text, "[\u3040-\u309F\u30A0-\u30FF]").Count
    $han      = [regex]::Matches($text, "[\u4E00-\u9FFF]").Count
    $thai     = [regex]::Matches($text, "[\u0E00-\u0E7F]").Count
    
    if ($arabic / $total -gt 0.15)   { return "ara" }
    if ($cyrillic / $total -gt 0.15) { return "rus" }
    if ($hangul / $total -gt 0.15)   { return "kor" }
    if ($kana / $total -gt 0.05)     { return "jpn" }
    if ($han / $total -gt 0.15)      { return "chi" }
    if ($thai / $total -gt 0.15)     { return "tha" }
    
    # 2. Latin-Based Language Detection
    $latin = [regex]::Matches($text, "[\u0000-\u007F\u0080-\u00FF\u0100-\u017F\u1E00-\u1EFF]").Count
    if ($latin / $total -gt 0.5) {
        if ($text -match "[đĐ]|[ấầẩẫậếềểễệốồổỗộắằẳẵặ]") { return "vie" }
        if ($text -match "[ßäöüÄÖÜ]") { return "ger" }
        if ($text -match "[ñÑ¿¡]") { return "spa" }
        if ($text -match "[ãÃõÕ]") { return "por" }
        if ($text -match "[çÇœŒêëâîû]") { return "fre" }
        if ($text -match "[ìÌòÒùÙ]") { return "ita" }
        # Honorifics (ONLY return enm if the flag is active)
        if ($Honorifics -and ($text -match "-(?:san|kun|chan|sama|dono|senpai|kohai|sensei)\b")) { return "enm" }
        return "eng"
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