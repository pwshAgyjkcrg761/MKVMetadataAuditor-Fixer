# ==============================================================================
# MODULE: MKVMetadataAuditor+Fixer.UI.ps1
# VERSION: 2026.06.01__12.58.00
# ==============================================================================

function Get-ProjectTable {
    param(
        [scriptblock]$Selector,
        $groupJson, 
        $title, 
        $compareJson, 
        $codecPadding, 
        $propPadding, 
        $namePadding,
        [System.Collections.Generic.List[string]]$entry
    )
    
    if ($title -ne "") { $entry.Add(""); $entry.Add("$title") }
    
    $line = "-" * ("Codec".PadRight($codecPadding) + " | " + "   ID".PadRight(12) + " | " + "Sel.".PadRight(4) + " | " + "Type".PadRight(9) + " | " + "Lng" + " | " + "Flags".PadRight($propPadding) + " | " + "Name".PadRight($namePadding)).Length
    $header = "$("Codec".PadRight($codecPadding)) | $("   ID".PadRight(12)) | $("Sel.".PadRight(4)) | $("Type".PadRight(9)) | Lng | $("Flags".PadRight($propPadding)) | $("Name".PadRight($namePadding))"
    $sep = "$("-" * $codecPadding)-|-$("-" * 12)-|-$("-" * 4)-|-$("-" * 9)-|-----|-$("-" * $propPadding)-|-$("-" * $namePadding)"
    
    $entry.Add($line)
    $entry.Add($header)
    $entry.Add($sep)
    
    # Reset the selector at the start of each table
    $Selector.Invoke($null, $true)

    foreach ($t in $groupJson.tracks) {
        $sel = $Selector.Invoke($t.type)
        $isDiff = $false
        if ($null -ne $compareJson) {
            $pTrack = $compareJson.tracks | Where-Object { $_.id -eq $t.id }
            if ($null -ne $pTrack) {
                $pSig = "$($pTrack.id)|$($pTrack.type)|$($pTrack.codec)|$($pTrack.properties.language)|$($pTrack.properties.default_track)|$($pTrack.properties.track_name)"
                $cSig = "$($t.id)|$($t.type)|$($t.codec)|$($t.properties.language)|$($t.properties.default_track)|$($t.properties.track_name)"
                if ($pSig -ne $cSig) { $isDiff = $true }
            }
        }

        $idStr = if ($isDiff) { ">>>ID:$($t.id)<<<" } else { "   ID:$($t.id)" }
        $codec = "$($t.codec.PadRight($codecPadding))"
        $tName = if ($t.properties.track_name) { $t.properties.track_name } else { "" }

        $flags = @(Get-TrackProps $t)
        $firstFlag = if ($flags.Count -gt 0) { [string]$flags[0] } else { "" }
        
        $entry.Add("$codec | $($idStr.PadRight(12)) | $($sel.PadRight(4)) | $($t.type.PadRight(9)) | $($t.properties.language) | $(($firstFlag).PadRight($propPadding)) | $($tName.PadRight($namePadding))")

        if ($flags.Count -gt 1) {
            for ($i = 1; $i -lt $flags.Count; $i++) {
                $entry.Add("$(" ".PadRight($codecPadding)) | $(" ".PadRight(12)) | $(" ".PadRight(4)) | $(" ".PadRight(9)) |     | $([string]($flags[$i]).PadRight($propPadding)) | $(" ".PadRight($namePadding))")
            }
        }
    }
    $entry.Add($line)
}

function Show-ProjectManual {
    param($scriptVersion)

    # $True means DarkCyan, $False means DarkMagenta
    $global:altColorToggle = $true  

    $PrintManualBlock = {
        param(
            [string]$FlagLine,
            [string[]]$DescLines,
            [string]$ForceDescColor = $null
        )
        
        # 1. Print the Flag in DarkGreen
        Write-Host $FlagLine -ForegroundColor DarkGreen
        
        # 2. Determine description color
        $currentColor = if ($ForceDescColor) { $ForceDescColor } else { 
            if ($global:altColorToggle) { "DarkCyan" } else { "DarkMagenta" } 
        }
        
        # 3. Print the description lines
        foreach ($line in $DescLines) {
            Write-Host $line -ForegroundColor $currentColor
        }
        
        if (-not $ForceDescColor) {
            $global:altColorToggle = -not $global:altColorToggle
        }
    }

    Clear-Host
    Write-Host "============================================================" -ForegroundColor Cyan
               " MKVMetadataAuditor+Fixer.ps1 v$scriptVersion  ",
               " MANUAL & USAGE GUIDE" | ForEach-Object { Write-Host $_ -ForegroundColor DarkMagenta }
    Write-Host " Copyright (C) 2026 pwsh.Agyjkcrg761`n" -ForegroundColor DarkCyan
    
     " This program is free software: you can redistribute it and/or",
     " modify it under the terms of the GNU General Public License as",
     " published by the Free Software Foundation, either version 3 of",
     " the License, or (at your option) any later version."  | ForEach-Object { Write-Host $_ -ForegroundColor DarkMagenta }
    Write-Host "============================================================" -ForegroundColor Cyan
    
    Write-Host "`n OVERVIEW:" -ForegroundColor DarkYellow
     "  This utility is a high-fidelity media management tool designed to ensure",
     "  structural consistency across MKV libraries. It operates in two stages:",
     "  1. AUDIT: Scans files to identify 'Mismatch Groups' and track errors.",
     "  2. FIX:  Uses Mkvpropedit to align tracks with your preferred defaults.",
     "  3. SEARCH: Locates specific video profiles like AVC High 10 (10-bit).`n",

    "`n  This script intelligently handles track scoring, automatically penalizing",
    "  'Signs & Songs' tracks while prioritizing full dialogue and honorifics.",
    
    "  The AVC High 10 Search (-h10p) bypasses standard auditing to quickly",
    "  isolate legacy 10-bit encodes that may cause hardware compatibility",
    "  issues, supporting both deep-dive and fast-scan logic.`n"   | ForEach-Object { Write-Host $_ -ForegroundColor DarkCyan }
    
    Write-Host " DEPENDENCIES:" -ForegroundColor DarkYellow
    "  • MKVToolNix (mkvmerge): Used for deep-probing file headers and", 
    "    extracting detailed track metadata for the audit.",
    "  • MKVToolNix (mkvextract): Utilized by the Deep Subtitle Audit engine",
    "    to dump raw subtitle streams for size comparison analysis.",    
    "  • MKVToolNix (mkvpropedit): The primary tool for the 'Fix' engine,", 
    "    allowing instant metadata edits without remuxing the file.", 
    "  • MediaInfo: Utilized specifically during AVC High 10 searches", 
    "    to verify video profiles and bit-depth accuracy.`n" | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }
    
    Write-Host "`n USAGE:" -ForegroundColor DarkYellow
    Write-Host "  .\MKVMetadataAuditor+Fixer.ps1 [Flags] -Path 'G:\Media'" -ForegroundColor DarkGreen
    
    Write-Host "`n USAGE EXAMPLES:`n" -ForegroundColor DarkYellow
    
    Write-Host "  Standard Audit (No Changes):`n" -ForegroundColor DarkGray
    Write-Host "    .\MKVMetadataAuditor+Fixer.ps1 -Path 'G:\Media\Anime'`n" -ForegroundColor DarkMagenta
    
    Write-Host "  Automated Fix (JPN Audio / ENG Subs / Honorifics):`n" -ForegroundColor DarkGray
    Write-Host "    .\MKVMetadataAuditor+Fixer.ps1 -Fix -aud jpn -sub eng -Hon -ovrd -Path 'G:\Media\Anime'`n" -ForegroundColor DarkCyan
    
    Write-Host "  Update Video Language (Chinese) & Save to Config:`n" -ForegroundColor DarkGray
    Write-Host "    .\MKVMetadataAuditor+Fixer.ps1 -Fix -vid chi -vidf -ovrd -Path 'G:\Media\Anime'`n" -ForegroundColor DarkMagenta

    Write-Host "  Direct Fix (No Backup) with Codec Priority:`n" -ForegroundColor DarkGray
    Write-Host "    .\MKVMetadataAuditor+Fixer.ps1 -Fix -FixNoBackup -sc 'ass,srt' -ovrd -Path 'G:\Media\Anime'`n" -ForegroundColor DarkCyan
    
    Write-Host "  AVC High 10 Deep Scan Library Sweep (Fast Mode):`n" -ForegroundColor DarkGray
    Write-Host "    .\MKVMetadataAuditor+Fixer.ps1 -h10p -fast -Path 'G:\Media\Anime'`n" -ForegroundColor DarkMagenta
    
    Write-Host "`n CORE FLAGS:`n" -ForegroundColor DarkYellow

    &$PrintManualBlock "  -Path <string>" @(
    "      Defines the target directory. The script will recursively scan all",
    "      subfolders for MKV files to perform bulk auditing.`n"
)

    &$PrintManualBlock "  -Fix" @(
    "      Enables 'Write Mode'. Without this, the script runs in read-only",
    "      audit mode, generating logs without modifying any files.`n"
)    
                        
    &$PrintManualBlock "  -FixNoBackup" @(
    "      Disables the '_updated' sibling folder creation. Use with caution,",
    "      as this overwrites metadata directly on the source files.`n"
) -ForceDescColor "DarkRed"
    
    &$PrintManualBlock "  -overrideDefaults | -ovrd" @(
    "      Mandatory when using automation flags. It allows the script to",
    "      write your current session parameters into the JSON config file.`n"
)
    
    Write-Host "`n MODE FLAGS:`n" -ForegroundColor DarkYellow

    &$PrintManualBlock "  -Western | -w | -west | -WesternMode" @(
    "      Sets defaults for Western media (English audio/subs).`n"
)

    &$PrintManualBlock "  -AvcHigh10Search | -h10p" @(
    "      Search Mode: Scans for AVC High 10 (10-bit) video streams. Use",
    "      with -fast for quicker scanning.`n"
)    
    
    &$PrintManualBlock "  -fast" @(
    "      Speeds up the AVC High 10 Search by skipping extended metadata",
    "      checks. In this mode, progress tracks Folders processed.`n"
)
    
    &$PrintManualBlock "  -LogFullPath | -lfp" @(
    "      Forces the log to write the full file path instead of just the folder",
    "      path during a fast AVC High 10 search. Requires -fast.`n"
)

    &$PrintManualBlock "  -disableRecurse | -nr" @(
    "      Disables subfolder scanning. Only the root of the provided -Path", 
    "      will be processed.`n"
)
    
    Write-Host "`n TRACK PRIORITIES & AUTOMATION:`n" -ForegroundColor DarkYellow
    
    &$PrintManualBlock "  -videoLanguage | -vid <string>" @(
    "      Targets the video track language. Note: This is applied",
    "      automatically if the file requires other fixes. -vidf is",
    "      only required if the file is already 'perfect'.`n"
)

    &$PrintManualBlock "  -videoForceUpdate | -vidf" @(
    "      The safety toggle for video metadata. This must be present",
    "      to confirm you want to change the video track language on",
    "      files that otherwise pass the audit.`n"
)
    
    &$PrintManualBlock "  -audioLanguageUpdate | -audf" @(
    "      The safety toggle for audio metadata. This must be present",
    "      to confirm you want to change the audio track language on",
    "      files that otherwise pass the audit.`n"
)
    
    &$PrintManualBlock "  -audioLanguagePriority | -aud <string>" @(
    "      Sets the 3-letter ISO code (e.g., 'jpn') for your primary audio.",
    "      It will automatically set this track as the 'Default' choice.`n"
)
    
    &$PrintManualBlock "  -subtitleLanguagePriority | -sub <string>" @(
    "      Sets the primary subtitle language. The script uses weighted",
    "      scoring to find the best dialogue track in this language.`n"
)
    
    &$PrintManualBlock "  -subtitleCodecPriority | -sc <string>" @(
    "      A comma-separated list (e.g., 'ass,srt') that dictates which",
    "      subtitle formats to prefer when multiple tracks are available.`n"
)
    
    &$PrintManualBlock "  -Honorifics | -Hon" @(
    "      Injects a +300 score bonus to tracks labeled with 'honorifics'",
    "      or 'enm', ensuring they are selected over standard dialogue.`n"
)

    &$PrintManualBlock "  -SubtitleFactorTrackOrder | -SFTO | -SubTrackOrder | -TrackOrder" @(
    "      Instructs the weighted scoring algorithm to factor in the physical",
    "      track placement when determining priorities for subtitle selection.`n"
)
    
    &$PrintManualBlock "  -FansubGroupPriority | -fg <string>" @(
    "      Sets preferred fansub groups for subtitle track prioritization",
    "      (e.g., -fg 'commie'). Pass an empty string (`"`") to clear the",
    "      list and reset preferences via command line.`n"
)

    &$PrintManualBlock "  -DeepSubtitleAudit | -DSA | -Deep | -DeepAudit" @(
    "      Triggers an advanced audit for files containing exactly two unnamed text",
    "      subtitle tracks with matching codecs. If track headers are ambiguous,",
    "      it extracts the streams to analyze file size deltas, automatically",
    "      classifying the smaller track as Signs & Songs and the larger track as",
    "      Full Dialogue. When executed with the -Fix switch, the script will",
    "      automatically apply the correct names to the tracks via mkvpropedit.",
    "      Includes built-in safety margins to skip processing if both tracks",
    "      are nearly identical in size (e.g., dual Full Dialogue tracks).`n"
)

    &$PrintManualBlock "  -DeepSubtitleAuditDebugExtraction | -DSADebugEx | -DeepDebugEx | -DeepAuditDbgEx | -DSADE" @(
    "      Forces the DSA engine to skip the 'Stage 1 Header Probe' and proceed",
    "      directly to 'Stage 2 Extraction'. Useful for testing the bitstream",
    "      size analysis on files with valid headers.`n"
)
    
    Write-Host "`n WESTERN SPECIFIC:`n" -ForegroundColor DarkYellow

    &$PrintManualBlock "  -SubtitlesHearingImpaired | -sdh | -hi | -hicc | -cc" @(
    "      Forces the script to prioritize 'Hearing Impaired' or 'SDH'",
    "      subtitle tracks for Western media.`n"
)
    
    &$PrintManualBlock "  -OverrideWesternDefaults | -ovrdw" @(
    "      Allows the script to save custom Western mode parameters to",
    "      the JSON configuration.`n"
)

    Write-Host "`n ADVANCED & LOG MANAGEMENT FLAGS:`n" -ForegroundColor DarkYellow

    &$PrintManualBlock "  -VerifyUpdates | -V | -Verify" @(
    "      Chains an automated second-pass verification audit immediately after",
    "      fixing, confirming header adjustments match intent perfectly. Requires -Fix.`n"
)

    &$PrintManualBlock "  -DevDebug | -Dev | -DevD | -DBG | -DDBG" @(
    "      Global Debugging Switch. Clears standard UI reduction rules to expose",
    "      low-level automated processes. Specifically surfaces the active system",
    "      paths discovered for critical backend dependencies (mkvmerge, mkvextract,",
    "      mkvpropedit, and MediaInfo) during initial script verification. Additionally,",
    "      it preserves the low-level discovery telemetry on screen by disabling standard",
    "      console clearing rules when initiating an AVC High 10 Search, triggers real-time",
    "      terminal tracing for Deep Subtitle Audit (DSA) extraction thresholds, and details",
    "      the exact arithmetic scoring breakdown applied to every subtitle candidate.`n"
)
    
    &$PrintManualBlock "  -help | -manual" @(
    "      Displays this manual for MKVMetadataAuditor+Fixer.ps1. The one you are",
    "      reading right now.`n"
)
    
    &$PrintManualBlock "  -DelLog" @(
    "      Clears all files within the logs directory (MKVMetadataAuditor+Fixer_logs) before",
    "      starting the operation.`n"
) -ForceDescColor "DarkRed"
    
    &$PrintManualBlock "  -ClearDefaults | -clr" @(
    "      Deletes the saved Anime configuration JSON template to reset rules back",
    "      to factory script conditions.`n"
)

    &$PrintManualBlock "  -ClearWesternDefaults | -clrw" @(
    "      Deletes the custom Western configuration file to purge specialized rules.`n"
)

    &$PrintManualBlock "  -ClearAllDefaults | -cla" @(
    "      Total system purge of both Anime and Western configuration JSON structures.`n"
)
    
    &$PrintManualBlock "  -excludePaths | -ep" @(
    "      Enables the exclusion engine. When active, the script will skip folders",
    "      listed in 'MKVMetadataAuditor+Fixer__Excluded-Paths.txt'.`n"
)
    
    &$PrintManualBlock "  -Version | -Ver" @(
    "      Displays the script's current version number and exits immediately.`n"
)    

    Write-Host "`n NOTES:" -ForegroundColor DarkYellow
    "  * SCORING: Automatically penalizes 'Signs/Songs' tracks.",
    "  * CONFIG: -ovrd is REQUIRED when using automation flags to save to JSON.",
    "  * LOGS: Detailed reports are saved to: MKVMetadataAuditor+Fixer_logs\Detail_Logs"  | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }
    
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host " Press any key to exit..." -ForegroundColor DarkYellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}