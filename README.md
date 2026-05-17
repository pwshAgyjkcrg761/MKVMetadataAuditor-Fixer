# MKVMetadataAuditor+Fixer
**A high-fidelity media management and metadata enforcement suite for PowerShell 7.6.1 LTS.**

---


## Overview
MKVMetadataAuditor+Fixer is a high-performance automation suite built for media archivists who prioritize metadata integrity and container consistency. Designed to handle the complexities of large-scale libraries, the script acts as both a vigilant auditor and a precision repair tool. It eliminates the manual labor of checking track flags, language tags, and track titles by enforcing a standardized configuration across your collection. By identifying discrepancies in audio and subtitle tracks, it ensures that your media is always configured for your preferred playback experience.

## Technical Logic
The script employs a dual-engine approach to process files—handling Anime and Western media with specialized audit logic—and utilizes a customizable JSON-based defaults system to resolve metadata errors automatically. It features a robust gatekeeper engine that allows users to exclude specific directories via a switch-enabled (`-ep`) text-based bypass. With direct integration with `mkvpropedit`, the tool provides granular control over MKV headers, allowing for the batch correction of language codes and default/forced track flags without the need for full file remuxing.

## Usage Examples
```powershell
# Standard Audit (No Changes)
.\MKVMetadataAuditor+Fixer.ps1 -Path 'G:\Media\Anime'

# Automated Fix (JPN Audio / ENG Subs / Honorifics)
.\MKVMetadataAuditor+Fixer.ps1 -Fix -aud jpn -sub eng -Hon -ovrd -Path 'G:\Media\Anime'

# Update Video Language (Chinese) & Save to Config
.\MKVMetadataAuditor+Fixer.ps1 -Fix -vid chi -vidf -ovrd -Path 'G:\Media\Anime'

# Direct Fix (No Backup) with Codec Priority
.\MKVMetadataAuditor+Fixer.ps1 -Fix -FixNoBackup -sc 'ass,srt' -ovrd -Path 'G:\Media\Anime'

# AVC High 10 Deep Scan Library Sweep (Fast Mode)
.\MKVMetadataAuditor+Fixer.ps1 -h10p -fast -Path 'G:\Media\Anime'
```
---

## Parameter Reference

### Core Flags
| Flag | Description |
| :--- | :--- |
| `-Path <string>` | Defines the target directory for recursive scanning. |
| `-Fix` | Enables **Write Mode**. Without this, the script runs in read-only audit mode. |
| `-FixDebug` | Prints the exact `mkvpropedit` command strings before execution. |
| `-FixNoBackup` | Overwrites metadata directly on source files (disables `_updated` folder). |
| `-overrideDefaults \| -ovrd` | **Mandatory** when using automation flags to save parameters to the JSON config. |

### Mode & Search Flags
| Flag | Description |
| :--- | :--- |
| `-Western \| -w \| -west \| -WesternMode` | Sets defaults for Western media (English audio/subs). |
| `-AvcHigh10Search \| -h10p` | **Search Mode:** Scans specifically for AVC High 10 (10-bit) video streams. |
| `-AvcHigh10SearchDebug \| -h10pDebug` | Enables verbose terminal output during the High 10 search. |
| `-fast` | Speeds up the High 10 search by skipping extended metadata checks. |
| `-disableRecurse \| -nr` | **No-Recurse:** Disables subfolder scanning; only processes the root path. |

### Track Priorities & Automation
| Flag | Description |
| :--- | :--- |
| `-videoLanguage \| -vid <string>` | Targets the video track language (3-letter ISO code). |
| `-videoForceUpdate \| -vidf` | **Safety Toggle:** Confirms video language changes on files that otherwise pass audit. |
| `-audioLanguageUpdate \| -audf` | **Safety Toggle:** Confirms audio language changes on files that otherwise pass audit. |
| `-audioLanguagePriority \| -aud <string>` | Sets primary audio language (e.g., 'jpn') and sets it as 'Default'. |
| `-subtitleLanguagePriority \| -sub <string>` | Sets primary subtitle language. Uses weighted scoring for best dialogue track. |
| `-subtitleCodecPriority \| -sc <string>` | Comma-separated list (e.g., 'ass,srt') to dictate subtitle format preference. |
| `-Honorifics \| -Hon` | Injects a **+300 score bonus** to tracks labeled 'honorifics' or 'enm'. |
| `-FansubGroupPriority \| -fg <string>` | Sets preferred fansub groups for subtitle track prioritization (e.g., `-fg 'commie'`). Pass an empty string (`""`) to clear preferences via CLI. |
| `-SubtitlesHearingImpaired \| -sdh \| -hi \| -hicc \| -cc` | Prioritizes 'Hearing Impaired' or 'SDH' subtitle tracks (Western Mode). |
| `-OverrideWesternDefaults \| -ovrdw` | Allows the script to save custom Western mode parameters to the JSON configuration. |

### Advanced & Log Management Flags
| Flag | Description |
| :--- | :--- |
| `-VerifyUpdates \| -V \| -Verify` | Chains an automated second-pass verification audit immediately after fixing to confirm metadata integrity. Requires `-Fix`. |
| `-help \| -manual` | Displays the internal help manual. |
| `-DelLog` | Clears all historically accumulated files within the logs directory before starting operations. |
| `-ClearDefaults \| -clr` | Deletes the saved Anime configuration JSON template to reset rules back to factory conditions. |
| `-ClearWesternDefaults \| -clrw` | Deletes the custom Western configuration file to purge specialized rules. |
| `-ClearAllDefaults \| -cla` | Total system purge of both Anime and Western configuration JSON structures. |
| `-excludePaths \| -ep` | Enables the directory suppression exclusion engine (`MKVMetadataAuditor+Fixer__Excluded-Paths.txt`). |

---

## Dependencies
* **MKVToolNix:** Required for header probing (`mkvmerge`) and metadata editing (`mkvpropedit`).
* **MediaInfo:** Required for video profile verification during AVC High 10 searches.

## Support & Maintenance
**This repository is provided "as-is" for archival purposes.** I am not actively looking for feedback, feature requests, or bug reports. The issue tracker is disabled, and I will not be responding to inquiries regarding setup or usage.

## Disclaimer
*This script modifies MKV file headers and metadata. While designed for safety, always ensure you have backups of your media before running batch operations. The author is not responsible for any accidental data loss or corruption resulting from the use of this tool.*