# ==============================================================================
# MODULE: MKVMetadataAuditor+Fixer.Scanner.ps1
# VERSION: 2026.06.01__08.58.00
# ==============================================================================

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
        [switch]$DisableRecurse
    )
    
    $folders = if ($DisableRecurse) {
        $InputPaths | ForEach-Object { Get-Item -LiteralPath $_ }
    } else {
        Get-ChildItem -LiteralPath $InputPaths -Directory -Recurse
    }

    # Combine input roots with discovered subfolders and sort naturally
    return (@($InputPaths | ForEach-Object { Get-Item -LiteralPath $_ }) + $folders | Select-Object -Unique) | Sort-Natural
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