# MKVMetadataAuditor+Fixer
**A high-fidelity media management and metadata enforcement suite for PowerShell 7.6.x.**

---

## Overview
MKVMetadataAuditor+Fixer is a high-performance automation suite built for media archivists who prioritize metadata integrity and container consistency. It operates by analyzing the underlying metadata headers of your files without remuxing or re-encoding the actual streams, ensuring 1:1 data integrity.

The script logic is divided into three specialized operational phases:
1. **AUDIT:** Scans files to identify 'Mismatch Groups' and track errors.
2. **FIX:** Uses Mkvpropedit to align tracks with your preferred defaults.
3. **SEARCH:** Locates hardware-incompatible profiles like AVC High 10.

### The Scoring Engine
The script employs a sophisticated weighted scoring algorithm to determine which subtitle track should be the 'Default'. The engine prioritizes your Preferred Language above all else (+5000), then evaluates content: prioritizing Full Dialogue (+150) while heavily penalizing 'Signs & Songs' (-200) or 'Dubtitles' (-100). 

It further factors in Codec Priority (up to +100), Fansub Group preferences (up to +10000), Honorifics (up to +350), and physical Track Order penalties (-40 per slot). This ensures that even in complex files with 10+ tracks, the most complete dialogue track is selected.

### Deep Subtitle Audit (DSA)
When track names are missing or generic (e.g., 'English'), the DSA engine performs a bitstream analysis. It extracts dialogue samples to calculate character density and file size ratios. By identifying the larger 'Full Dialogue' stream vs. the smaller 'Signs & Songs' stream, it can automatically rename tracks and fix language tags with near-perfect accuracy.

### Hardware Compatibility (NoHW Search)
Beyond standard metadata auditing, the suite includes a specialized compatibility engine targeting video profiles that lack Hardware Acceleration (NoHW) on consumer devices. It specifically isolates legacy AVC High 10 (10-bit) encodes, Chroma 4:2:2, Chroma 4:4:4, and RGB color spaces. These profiles frequently cause stuttering or playback failure on Smart TVs, mobile phones, and older streaming boxes.

## Usage Examples
```powershell
# Standard Audit (No Changes)
.\MKVMetadataAuditor+Fixer.ps1 -Path 'G:\Media\Anime'

# Automated Fix (JPN Audio / ENG Subs / Honorifics)
.\MKVMetadataAuditor+Fixer.ps1 -Fix -aud jpn -sub eng -Hon -ovrd -Path 'G:\Media\Anime'

# Update Video Language (Chinese) & Save to Config
.\MKVMetadataAuditor+Fixer.ps1 -Fix -vid chi -vidf -ovrd -Path 'G:\Media\Anime'

# Direct Fix (No Backup) with Codec Priority
.\MKVMetadataAuditor+Fixer.ps1 -FixNoBackup -sc 'ass,srt' -ovrd -Path 'G:\Media\Anime'

# Hardware Compatibility Deep Scan (NoHW Search)
.\MKVMetadataAuditor+Fixer.ps1 -nohw -fast -Path 'G:\Media\Anime'
```

---

## Parameter Reference

### Core Flags
| Flag | Description |
| :--- | :--- |
| `-Path <string[]>` | Defines the target directory or directories. Supports multiple paths and recursively scans all subfolders for MKV files. Supports folder drag-and-drop. |
| `-Fix` | Enables **Write Mode**. Without this, the script runs in read-only audit mode, generating logs without modifying files. |
| `-FixNoBackup` | **Surgical Overwrite:** Disables the safety-net creation of the `_updated` mirror folder. Forces modifications directly on source media. Faster and saves disk space, but changes are irreversible. |
| `-overrideDefaults \| -ovrd` | **Configuration Safety Lock:** Commits current session parameters (e.g., `-aud`, `-sub`) to the JSON config file as permanent defaults. Mandatory to prevent command-line parameters from being ignored. |

### Mode & Search Flags
| Flag | Description |
| :--- | :--- |
| `-Western \| -w \| -west \| -WesternMode` | Sets defaults for Western media (English audio/subs). |
| `-NoHwVideoSearch \| -nohw` | **NoHW Search Mode:** Initiates a specialized compatibility audit targeting video profiles lacking hardware acceleration (AVC High 10, Chroma 4:2:2, Chroma 4:4:4, RGB color spaces). |
| `-fast` | Speeds up the NoHW Search by skipping extended metadata checks. Progress tracks folders processed instead of individual files. |
| `-LogFullPath \| -lfp` | Forces the log to write the full file path instead of just the folder path during a fast NoHW search. Requires `-fast`. |
| `-disableRecurse \| -nr` | **No-Recurse:** Disables subfolder scanning. Only the root of the provided path is processed. |

### Track Priorities & Automation
| Flag | Description |
| :--- | :--- |
| `-videoLanguage \| -vid <string>` | Targets the video track language. Applied automatically if other fixes are needed. |
| `-videoForceUpdate \| -vidf` | **Safety Toggle:** Confirms changes to video track language on files that otherwise pass the audit. |
| `-audioLanguageUpdate \| -audf` | **Safety Toggle:** Confirms changes to audio track language on files that otherwise pass the audit. |
| `-audioLanguagePriority \| -aud <string>` | Sets the 3-letter ISO code (e.g., `jpn`) for primary audio and marks it as the 'Default' track. |
| `-subtitleLanguagePriority \| -sub <string>` | Sets primary subtitle language. Uses weighted scoring to find the best dialogue track. |
| `-subtitleCodecPriority \| -sc <string>` | Comma-separated list (e.g., `ass,srt`) to dictate subtitle format preference when multiple tracks are available. |
| `-Honorifics \| -Hon` | Injects a **+300 score bonus** to tracks labeled with 'honorifics' or `enm` to prioritize them over standard dialogue. |
| `-SubtitleFactorTrackOrder \| -SFTO \| -SubTrackOrder \| -TrackOrder` | **Positional Penalty:** Activates a -40 point penalty per slot away from the top track. Prevents high-scoring specialty tracks appearing later from overriding primary dialogue. |
| `-subtitleFansubGroupPriority \| -fg <string>` | Sets preferred fansub groups for subtitle track prioritization (e.g., `-fg 'commie'`). Pass an empty string (`""`) to clear preferences via command line. |
| `-DeepSubtitleAudit \| -DSA \| -Deep \| -DeepAudit` | **Intelligence Tier:** Resolves missing or ambiguous track names via four stages: Header Probe, Extraction, Analysis, and Detection (probing for Japanese Kana, Hangul, or English honorifics). Automatically renames and corrects language tags based on size ratios (2.0x for text / 3.0x for image). |
| `-DeepSubtitleAuditDebugExtraction \| -DSADE \| -DSADebugEx \| -DeepDebugEx \| -DeepAuditDbgEx` | Forces a physical bitstream extraction even when statistical headers are present. Essential for size checks on image tracks (PGS/VobSub) or when language detection is turned off. |
| `-DeepSubtitleAuditLanguageDetectionLimit2 \| -DSALDL2 \| -LDL2 \| -DeepSALDL2 \| -LngDL2 \| -LanguageDetectionL2` | Limits the DSA engine to processing files containing only 1 or 2 subtitle tracks; files with 3 or more subtitles are skipped. |
| `-DeepSubtitleAuditNOLanguageDetection \| -DSANLD \| -NLD \| -DeepSANLD \| -NoLngD \| -LanguageDetectionOff \| -LDO` | Disables the linguistic probe (Kana, Hangul, honorifics), relying solely on bitstream size ratios to identify dialogue tracks to speed up audits. |

### Western Specific
| Flag | Description |
| :--- | :--- |
| `-SubtitlesHearingImpaired \| -sdh \| -hi \| -hicc \| -cc` | Forces the script to prioritize 'Hearing Impaired' or 'SDH' subtitle tracks for Western media. |
| `-OverrideWesternDefaults \| -ovrdw` | Allows the script to save custom Western mode parameters to the JSON configuration. |

### Advanced & Log Management Flags
| Flag | Description |
| :--- | :--- |
| `-VerifyUpdates \| -V \| -Verify` | **Closed-Loop Verification:** Automatically launches a new audit session targeting updated files immediately after fixing to confirm all Mismatch Groups are resolved. |
| `-Sequential \| -seq` | Disables parallel processing and forces single-file analysis for troubleshooting performance issues, file locks, or resource competition. |
| `-DevDebug \| -Dev \| -DevD \| -DBG \| -DDBG` | **Exposing the Black Box:** Disables UI suppression and surfaces telemetry regarding tool system paths, exact scoring arithmetic, DSA sizing ratios, and raw backend tool CLI errors. |
| `-help \| -manual` | Displays the internal manual and usage guide. |
| `-DelLog` | **Fresh Start:** Purges the log directory before the scan begins to prevent session clutter. |
| `-ClearDefaults \| -clr` | Deletes the saved Anime configuration JSON template to reset rules back to factory conditions. |
| `-ClearWesternDefaults \| -clrw` | Deletes the custom Western configuration file. |
| `-ClearAllDefaults \| -cla` | Total system purge of both Anime and Western configuration JSON structures. |
| `-excludePaths \| -ep` | Enables the exclusion engine, skipping folders listed in `MKVMetadataAuditor+Fixer__Excluded-Paths.txt`. |
| `-Version \| -Ver` | Displays the script's current version number and exits immediately. |

---

## Dependencies
* **PowerShell:** Built with PowerShell 7.6.x.
* **<a href="https://mkvtoolnix.download/" target="_blank" rel="noopener noreferrer">MKVToolNix:</a>** Deep-probes file headers (`mkvmerge`), dumps raw subtitle streams for size checks (`mkvextract`), and performs instant metadata updates without remuxing (`mkvpropedit`).
* **<a href="https://mediaarea.net/en/MediaInfo" target="_blank" rel="noopener noreferrer">MediaInfo DLL & CLI:</a>** Globally handles video profile analysis (bit-depth, chroma subsampling, color spaces), with CLI integration ensuring extended path support for tracks exceeding 250 characters.

## Support & Maintenance
**This repository is provided "as-is" for archival purposes.** The author is not actively looking for feedback, feature requests, or bug reports. The issue tracker is disabled, and the author will not be responding to inquiries regarding setup or usage.

## Disclaimer
*This script modifies MKV file headers and metadata. While designed for safety, always ensure you have backups of your media before running batch operations. The author is not responsible for any accidental data loss or corruption resulting from the use of this tool.*

---
> **Document Control** > *This document is up-to-date with the following version of MKVMetadataAuditor+Fixer.* > *2026.06.27__09.35.00*