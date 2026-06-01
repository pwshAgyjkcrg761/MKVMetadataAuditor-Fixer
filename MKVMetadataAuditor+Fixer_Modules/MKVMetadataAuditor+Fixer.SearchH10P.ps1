# ==============================================================================
# MODULE: MKVMetadataAuditor+Fixer.SearchH10P.ps1
# VERSION: 2026.06.01__11.45.00
# ==============================================================================

function Test-IsHigh10 {
    param(
        [string]$FilePath,
        [string]$MediaInfoPath
    )
    if (-not (Test-Path -LiteralPath $MediaInfoPath)) { return $false }
    
    $profile = (& $MediaInfoPath --Inform="Video;%Format_Profile%" "$FilePath").ToString().Trim()
    return $profile -match "High.*10"
}

function Get-H10PLogHeader {
    param([switch]$Fast)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm"
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("----------------------------------------------")
    $lines.Add($ts)
    if ($Fast) { $lines.Add("Fast Scan - First File in Each Folder Only") }
    $lines.Add("AVC High 10 Profile Found")
    $lines.Add("Recommend convert to HEVC Main 10")
    $lines.Add("----------------------------------------------")
    $lines.Add("")
    return $lines
}