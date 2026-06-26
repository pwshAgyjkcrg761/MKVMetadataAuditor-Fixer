# MKVMetadataAuditor+Fixer
**A high-fidelity media management and metadata enforcement suite for PowerShell 7.6.2 LTS.**

---

## Overview
MKVMetadataAuditor+Fixer is a high-performance automation suite built for media archivists who prioritize metadata integrity and container consistency. It operates by analyzing the underlying metadata headers of your files without remuxing or re-encoding the actual streams, ensuring 1:1 data integrity.

### The Scoring Engine
The script employs a sophisticated weighted scoring algorithm to determine which subtitle track should be the 'Default'. It automatically penalizes 'Signs & Songs' tracks (-200) while prioritizing full dialogue (+150). It further factors in Codec Priority (up to +100), Honorifics bonuses (+300), and even positional penalties (-40 per slot). This ensures that even in complex files with 10+ tracks, the most complete English dialogue track is selected for the viewer.

### Hardware Compatibility (NoHW Search)
Beyond standard metadata auditing, the suite includes a specialized compatibility engine targeting video profiles that lack Hardware Acceleration (NoHW) on consumer devices. It specifically isolates legacy 10-bit AVC encodes, Chroma 4:2:2, Chroma 4:4:4, and RGB color spaces which frequently cause stuttering or playback failure on Smart TVs and mobile devices.

## Usage Examples
```powershell
# Standard Audit (No Changes)
.\MKVMetadataAuditor+Fixer.ps1 -Path 'G:\Media\Anime'

# Automated Fix (JPN Audio / ENG Subs / Honorifics)
.\MKVMetadataAuditor+Fixer.ps1 -Fix -aud jpn -sub eng -Hon -ovrd -Path 'G:\Media\Anime'

# Update Video Language (Chinese) & Save to Config
.\MKVMetadataAuditor+Fixer.ps1 -Fix -vid chi -vidf -ovrd -Path 'G:\Media\Anime'

# Direct Fix (No Backup) with Codec Priority (Implicitly enables -Fix)
.\MKVMetadataAuditor+Fixer.ps1 -FixNoBackup -sc 'ass,srt' -ovrd -Path 'G:\Media\Anime'

# NoHW Hardware Compatibility Sweep (Fast Mode)
.\MKVMetadataAuditor+Fixer.ps1 -nohw -fast -Path 'G:\Media\Anime'
```
---

## Parameter Reference

### Core Flags
| Flag | Description |
| :--- | :--- |
| `-Path <string>` | Defines the target directory for recursive scanning. |
| `-Fix` | Enables **Write Mode**. Without this, the script runs in read-only audit mode. |
| `-FixNoBackup` | **Surgical Overwrite:** Disables the safety `_updated` folder and writes changes directly to source files. Implicitly enables `-Fix`. |
| `-overrideDefaults \| -ovrd` | **Configuration Safety Lock:** Mandatory when using automation flags to save session parameters as the new permanent JSON defaults. |

### Mode & Search Flags
| Flag | Description |
| :--- | :--- |
| `-Western \| -w \| -west \| -WesternMode` | Sets defaults for Western media (English audio/subs). |
| `-NoHwVideoSearch \| -NoHw` | **NoHW Search Mode:** Scans for hardware-incompatible profiles (AVC Hi10P, Chroma 4:2:2, Chroma 4:4:4, RGB). |
| `-fast` | Speeds up the NoHW search by skipping extended metadata checks (scans only the first file per folder). |
| `-LogFullPath \| -lfp` | Forces the log to write the full file path instead of just the folder path during a fast NoHW search. Requires `-fast`. |
| `-disableRecurse \| -nr` | **No-Recurse:** Disables subfolder scanning; only processes the root path. |

### Track Priorities & Automation
| Flag | Description |
| :--- | :--- |
| `-videoLanguage \| -vid <string>` | Targets the video track language (3-letter ISO code). |
| `-videoForceUpdate \| -vidf` | **Safety Toggle:** Confirms video language changes on files that otherwise pass audit. |
| `-audioLanguageUpdate \| -audf` | **Safety Toggle:** Confirms audio language changes on files that otherwise pass audit. |
| `-audioLanguagePriority \| -aud <string>` | Sets primary audio language (e.g., `jpn`) and sets it as 'Default'. |
| `-subtitleLanguagePriority \| -sub <string>` | Sets primary subtitle language. Uses weighted scoring for best dialogue track. |
| `-subtitleCodecPriority \| -sc <string>` | Comma-separated list (e.g., `ass,srt`) to dictate subtitle format preference. |
| `-Honorifics \| -Hon` | Injects a **+300 score bonus** to tracks labeled 'honorifics' or `enm`. |
| `-SubtitleFactorTrackOrder \| -SFTO \| -TrackOrder` | **Positional Penalty:** Subtracts 40 points per track position, prioritizing tracks located closer to the top of the container. |
| `-FansubGroupPriority \| -fg <string>` | Sets preferred fansub groups for subtitle track prioritization (e.g., `-fg 'commie'`). |
| `-DeepSubtitleAudit \| -DSA \| -Deep` | **Intelligence Tier:** Uses a 3-stage process (Header Probe, Extraction, Bitstream Analysis) to resolve ambiguous track names. Automatically identifies 'Full Dialogue' vs 'Signs & Songs' via file size ratios (2.0x for text / 3.0x for image). |
| `-DeepSubtitleAuditDebugExtraction \| -DSADE` | Forces the DSA engine to skip the 'Header Probe' and proceed directly to physical bitstream extraction. Required for forcing size checks on image-based tracks. |
| `-DeepSubtitleAuditLanguageDetectionLimit2 \| -DSALDL2 \| -LDL2` | **Complexity Gate:** Limits the DSA engine to processing files with exactly 1 or 2 subtitle tracks. Files with 3 or more tracks are skipped entirely to prevent incorrect role assignment in complex containers. |
| `-DeepSubtitleAuditNOLanguageDetection \| -DSANLD \| -NLD` | **Manual Bitstream Analysis:** Disables linguistic probing. Bypasses language detection (Japanese/English Honorifics) and relies exclusively on file size ratios to resolve track roles. |
| `-SubtitlesHearingImpaired \| -sdh \| -hi \| -hicc \| -cc` | Prioritizes 'Hearing Impaired' or 'SDH' subtitle tracks (Western Mode). |
| `-OverrideWesternDefaults \| -ovrdw` | Allows the script to save custom Western mode parameters to the JSON configuration. |

### Advanced & Log Management Flags
| Flag | Description |
| :--- | :--- |
| `-VerifyUpdates \| -V \| -Verify` | **Closed-Loop Verification:** Launches a second-pass audit immediately after fixing to confirm all discrepancies were resolved. |
| `-Sequential \| -seq` | Disables parallel processing and forces the script to analyze one file at a time. This is useful for troubleshooting performance issues, identifying specific file locks, or reducing system resource competition on legacy hardware. |
| `-DevDebug \| -Dev \| -DevD \| -DBG` | **Exposing the Black Box:** Disables UI suppression to reveal tool system paths, exact scoring arithmetic, and real-time DSA tracing. |
| `-help \| -manual` | Displays the internal help manual. |
| `-DelLog` | **Fresh Start:** Clears all files within the logs directory before starting the operation. |
| `-ClearDefaults \| -clr` | Deletes the saved Anime configuration JSON template to reset rules back to factory conditions. |
| `-ClearWesternDefaults \| -clrw` | Deletes the custom Western configuration file to purge specialized rules. |
| `-ClearAllDefaults \| -cla` | Total system purge of both Anime and Western configuration JSON structures. |
| `-excludePaths \| -ep` | Enables the suppression engine (`MKVMetadataAuditor+Fixer__Excluded-Paths.txt`). |
| `-Version \| -Ver` | Displays the script's current version number and exits immediately. |

---

## Dependencies
* **PowerShell:** Built with PowerShell 7.6.x.
* **<a href="https://mkvtoolnix.download/" target="_blank" rel="noopener noreferrer">MKVToolNix:</a>** Required for header probing (`mkvmerge`), raw subtitle extraction (`mkvextract`), and metadata editing (`mkvpropedit`).
* **<a href="https://mediaarea.net/en/MediaInfo" target="_blank" rel="noopener noreferrer">MediaInfo DLL & CLI:</a>** Required for video profile verification during NoHW searches.

## Support & Maintenance
**This repository is provided "as-is" for archival purposes.** The author is not actively looking for feedback, feature requests, or bug reports. The issue tracker is disabled, and the author will not be responding to inquiries regarding setup or usage.

## Disclaimer
*This script modifies MKV file headers and metadata. While designed for safety, always ensure you have backups of your media before running batch operations. The author is not responsible for any accidental data loss or corruption resulting from the use of this tool.*

---
> **Document Control**  
> *This document is up-to-date with the following version of MKVMetadataAuditor+Fixer.*  
> *2026.06.13__15.00.00*