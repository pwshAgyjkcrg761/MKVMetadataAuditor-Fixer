# ==============================================================================
# MODULE: MKVMetadataAuditor+Fixer.Core.ps1
# VERSION: 2026.06.01__08.33.00
# ==============================================================================

function Initialize-NaturalSort {
    $NaturalSortDefinition = @'
    using System;
    using System.Runtime.InteropServices;
    using System.Collections.Generic;

    public class NaturalSort {
        [DllImport("shlwapi.dll", CharSet = CharSet.Unicode)]
        public static extern int StrCmpLogicalW(string psz1, string psz2);
    }
'@
    if (-not ([System.Management.Automation.PSTypeName]"NaturalSort").Type) {
        Add-Type -TypeDefinition $NaturalSortDefinition
    }
}

function Sort-Natural {
    param([Parameter(ValueFromPipeline=$true)]$InputObject)
    begin { $all = [System.Collections.Generic.List[PSObject]]::new() }
    process { if ($null -ne $_) { $all.Add($_) } }
    end {
        if ($all.Count -gt 1) {
            $all.Sort({ param($a,$b) [NaturalSort]::StrCmpLogicalW($a.FullName, $b.FullName) })
        }
        return $all
    }
}

function Sort-NaturalFiles {
    param([Parameter(ValueFromPipeline=$true)]$InputObject)
    begin { $all = [System.Collections.Generic.List[PSObject]]::new() }
    process { if ($null -ne $_) { $all.Add($_) } }
    end {
        if ($all.Count -gt 1) {
            $all.Sort({ param($a,$b) [NaturalSort]::StrCmpLogicalW($a.Name, $b.Name) })
        }
        return $all
    }
}

function Get-MKVToolPaths {
    $tools = @{
        propedit  = Get-Command mkvpropedit.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
        merge     = Get-Command mkvmerge.exe    -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
        extract   = Get-Command mkvextract.exe  -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
        mediainfo = Get-Command MediaInfo.exe   -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    }

    # Fallbacks
    if (-not $tools.propedit) { $tools.propedit = "C:\Program Files\MKVToolNix\mkvpropedit.exe" }
    if (-not $tools.merge)    { $tools.merge    = "C:\Program Files\MKVToolNix\mkvmerge.exe" }
    if (-not $tools.extract)  { $tools.extract  = "C:\Program Files\MKVToolNix\mkvextract.exe" }
    if (-not $tools.mediainfo) { $tools.mediainfo = "C:\Program Files\MediaInfo\MediaInfo.exe" }

    return $tools
}