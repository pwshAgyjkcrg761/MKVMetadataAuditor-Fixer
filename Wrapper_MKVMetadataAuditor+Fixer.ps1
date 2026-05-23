# ==============================================================================
# SCRIPT: Wrapper_MKVMetadataAuditor+Fixer.ps1
# VERSION: 2026.05.22__19.59.37
# TARGET: PowerShell 7.6.1 LTS
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
    [switch]$UsualFix,

    [Parameter(Mandatory = $false)]
    [switch]$DebugFix,

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
    #Audit+Fix Veify, fix, honorifics, audio language update, subtitles factor track order, verify, excluded paths
    $UsualFix { $profileFlags = "-Fix -hon -audf -SFTO -VerifyUpdates -ep"; break }
    #Debug Mode
    $DebugFix { $profileFlags = "-Fix -fixdebug -hon -audf -SFTO -VerifyUpdates -ep"; break }
    #Temp for whatever.
    $Temp { $profileFlags = "-Fix -fixdebug -hon -audf -SFTO -VerifyUpdates -ep"; break }
    #Chinese Donghua
    $ChiD { $profileFlags = "-Fix -ovrd -vid 'chi' -aud 'chi' -sub 'eng' -audf -SFTO -VerifyUpdates -ep"; break }
    #Korean Aeni
    $KorA { $profileFlags = "-Fix -ovrd -vid 'kor' -aud 'kor' -sub 'eng' -audf -SFTO -VerifyUpdates -ep"; break }
    
}

# Clean and sanitize all incoming folder paths into a comma-separated string block
$cleanedPaths = @()
foreach ($folder in $RemainingArgs) {
    $path = $folder.Trim().Trim('"')
    if ($path) {
        # Wrap each individual path in single quotes to protect spaces and brackets
        $cleanedPaths += "'$path'"
    }
}

# Join the paths with commas so PowerShell reads it natively as an array input: 'Path1','Path2','Path3'
$pathArrayString = $cleanedPaths -join ","

# Build the execution block for the single tab
$innerCmd = "& 'C:\scripts\MKVMetadataAuditor+Fixer.ps1'"
if ($profileFlags) {
    $innerCmd += " $profileFlags"
}
# Append the array of paths directly to the command call
$innerCmd += " $pathArrayString"

# Construct the single Windows Terminal execution argument string
$rawArguments = "-w 0 nt -- `"C:\Tools\ps-port\pwsh.exe`" -NoProfile -ExecutionPolicy Bypass -NoExit -Command `"$innerCmd`""

# Fire off Windows Terminal exactly once
$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = "C:\tools\win-term-port\WindowsTerminal.exe"
$startInfo.Arguments = $rawArguments
$startInfo.UseShellExecute = $true

[System.Diagnostics.Process]::Start($startInfo) | Out-Null