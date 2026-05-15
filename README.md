# MKVMetadataAuditor+Fixer
**A high-fidelity media management and metadata enforcement suite for PowerShell 7.6.1 LTS.**

---

## Overview
MKVMetadataAuditor+Fixer is a high-performance automation suite built for media archivists who prioritize metadata integrity and container consistency. Designed to handle the complexities of large-scale libraries, the script acts as both a vigilant auditor and a precision repair tool. It eliminates the manual labor of checking track flags, language tags, and track titles by enforcing a standardized configuration across your collection. By identifying discrepancies in audio and subtitle tracks, it ensures that your media is always configured for your preferred playback experience.

## Technical Logic
The script employs a dual-engine approach to process files—handling Anime and Western media with specialized audit logic—and utilizes a customizable JSON-based defaults system to resolve metadata errors automatically. It features a robust gatekeeper engine that allows users to exclude specific directories via a switch-enabled (`-ep`) text-based bypass. With direct integration with `mkvpropedit`, the tool provides granular control over MKV headers, allowing for the batch correction of language codes and default/forced track flags without the need for full file remuxing.

## Usage & Parameters
The script is designed for PowerShell 7.6.1+ and requires **MKVToolNix** to be installed on your system.

```powershell
# Standard Audit (No Changes)
.\MKVMetadataAuditor+Fixer.ps1 -Path 'G:\Media\Anime'

# Automated Fix (JPN Audio / ENG Subs / Honorifics)
.\MKVMetadataAuditor+Fixer.ps1 -Fix -aud jpn -sub eng -Hon -ovrd -Path 'G:\Media\Anime'

# Update Video Language (Chinese) & Save to Config
.\MKVMetadataAuditor+Fixer.ps1 -Fix -vid chi -vidf -ovrd -Path 'G:\Media\Anime'

# Direct Fix (No Backup) with Codec Priority
.\MKVMetadataAuditor+Fixer.ps1 -Fix -FixNoBackup -sc 'ass,srt' -ovrd -Path 'G:\Media\Anime'

# AVC High 10 Search Mode (Fast & No-Recurse)
.\MKVMetadataAuditor+Fixer.ps1 -h10p -fast -nr -Path 'G:\Media\Anime'
```

## Support & Maintenance
This repository is provided "as-is" for archival and sharing purposes. I am not actively looking for feedback, feature requests, or bug reports. The issue tracker is disabled, and I will not be responding to inquiries regarding setup, troubleshooting, or usage.

## Disclaimer
This script modifies MKV file headers and metadata. While designed for safety, always ensure you have backups of your media before running batch operations. The author is not responsible for any accidental data loss or corruption resulting from the use of this tool.