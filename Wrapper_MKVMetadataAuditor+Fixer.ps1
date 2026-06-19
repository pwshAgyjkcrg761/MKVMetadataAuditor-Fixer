# ==============================================================================
# SCRIPT: Wrapper_MKVMetadataAuditor+Fixer.ps1
# VERSION: 2026.06.19__07.06.04
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
#    - VERSIONING: Update using CHICAGO TIME (Central Time). 
#    - CRITICAL: Do not use AI system time. Use the time provided in the most 
#      recent user prompt or link (Ref: https://www.timeanddate.com/worldclock/usa/chicago).
#    - STAMP ACCURACY: Ensure the minutes match the current Chicago clock exactly.
# 2. DO NOT modify or refactor any code inside <PROTECTED> tags.
# 3. SCRIPT OUTPUT:
#    - When printing the script only print snippets unless asked for entire script.
#    - Always use a codebox with a copy button.
# 4. VERBATIM ANCHOR PROTOCOL:
#    - To facilitate "Find" in Notepad++, always provide "Verbatim Anchors."
#    - "Verbatim Anchors" are the exact lines of existing code immediately BEFORE and AFTER the insertion point.
#    - Do not summarize, truncate, or refactor the existing code used as an anchor.
#    - Copy the existing spaces, comments, and symbols exactly as they appear in the file.
# ==============================================================================
# </PROTECTED>

param(
    [Parameter(Mandatory = $false)]
    [switch]$Audit,
    
    [Parameter(Mandatory = $false)]
    [switch]$AuditDebug,

    [Parameter(Mandatory = $false)]
    [switch]$UsualFix,

    [Parameter(Mandatory = $false)]
    [switch]$FixDebug,
    
    [Parameter(Mandatory = $false)]
    [switch]$FixSFTO,
    
    [Parameter(Mandatory = $false)]
    [switch]$FixNoBackup,

    [Parameter(Mandatory = $false)]
    [switch]$Temp,

    [Parameter(Mandatory = $false)]
    [switch]$ChiD,

    [Parameter(Mandatory = $false)]
    [switch]$KorA,

    # Automatically captures all right-clicked folder paths dropped by SendTo
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

if ($RemainingArgs.Count -eq 0) { Exit }

# Identify profile switches
$profileFlags = ""
switch ($true) {
    #Audit with Excluded Paths
    $Audit { $profileFlags = "-ep"; break }
    #Audit Debug with Excluded Paths
    $AuditDebug { $profileFlags = "-DBG -ep"; break }
    #Audit+Fix Veify, fix, honorifics, audio language update, subtitles factor track order, verify, excluded paths
    $UsualFix { $profileFlags = "-Fix -DSA -hon -audf -VerifyUpdates -ep"; break }
    #Fix Debug
    $FixDebug { $profileFlags = "-Fix -DSA -DBG -hon -audf -VerifyUpdates -ep"; break }
    #Fix Subtitle Factor Track Order
    $FixSFTO { $profileFlags = "-Fix -DSA -hon -SFTO -VerifyUpdates -ep"; break }
    #Fix No Backup
    # $FixNoBackup { $profileFlags = "-FixNoBackup -DSA -DBG -hon -VerifyUpdates -ep"; break }
    #Temp for whatever.
    $Temp { $profileFlags = "-Fix -DSA -DBG -hon -VerifyUpdates -ep"; break }
    #Chinese Donghua
    $ChiD { $profileFlags = "-Fix -ovrd -vid 'chi' -aud 'chi' -sub 'eng' -audf -SFTO -DSA -DBG -VerifyUpdates -ep"; break }
    #Korean Aeni
    $KorA { $profileFlags = "-Fix -ovrd -vid 'kor' -aud 'kor' -sub 'eng' -audf -SFTO -DSA -DBG -VerifyUpdates -ep"; break }
    
}

# Clean and sanitize all incoming folder paths into a comma-separated string block
$cleanedPaths = @()
foreach ($item in $RemainingArgs) {
    $path = $item.Trim().Trim('"')
    if ($path) {
        # Escape single quotes (apostrophes) by doubling them up, then wrap in single quotes
        # This prevents paths like "90's Hits" from breaking the PowerShell command string
        $escapedPath = $path.Replace("'", "''")
        $cleanedPaths += "'$escapedPath'"
    }
}

# Join the paths with commas so PowerShell reads it natively as an array input: 'Path1','Path2','Path3'
$pathArrayString = $cleanedPaths -join ","

# Build the execution block for the single tab
$innerCmd = "& 'C:\scripts\MKVMetadataAuditor+Fixer.ps1'"

if ($pathArrayString) {
    # If the sub-script uses a specific parameter for input, use it here (e.g., -Path $pathArrayString)
    # Otherwise, passing it immediately after the script call ensures it is the first positional argument.
    $innerCmd += " $pathArrayString"
}

if ($profileFlags) {
    $innerCmd += " $profileFlags"
}

# Construct the single Windows Terminal execution argument string
$rawArguments = "-w 0 nt -- `"C:\Tools\ps-port\pwsh.exe`" -NoProfile -ExecutionPolicy Bypass -NoExit -Command `"$innerCmd`""

# Fire off Windows Terminal exactly once
$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = "C:\tools\win-term-port\WindowsTerminal.exe"
$startInfo.Arguments = $rawArguments
$startInfo.UseShellExecute = $true

[System.Diagnostics.Process]::Start($startInfo) | Out-Null