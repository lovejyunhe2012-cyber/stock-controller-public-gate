

# EO-03 E4B research diagnostics only. NOT A TRUSTED LAUNCHER.
# Read only: no extraction, no network, no policy changes, no script invocation.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ZipPath = ''
)


Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'


$results = New-Object 'System.Collections.Generic.List[object]'
function Add-Finding {
    param([string]$Code, [string]$Status, [string]$Detail)
    $results.Add([pscustomobject]@{code=$Code;status=$Status;detail=$Detail})
}


$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptHash = 'UNAVAILABLE'
try {
    $scriptHash = (Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash.ToLowerInvariant()
    Add-Finding 'D01_SCRIPT_IDENTITY' 'OBSERVED' 'Local script SHA256 measured; no independent trust assertion'
} catch {
    Add-Finding 'D01_SCRIPT_IDENTITY' 'UNKNOWN' 'Local SHA256 cannot be read'
}


$isWindows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
$isPS51 = ($PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -eq 1 -and $PSVersionTable.PSEdition -eq 'Desktop')
if ($isWindows -and $isPS51) {
    Add-Finding 'D02_WINDOWS_PS51' 'OBSERVED' 'Windows PowerShell 5.1 Desktop host detected'
} else {
    Add-Finding 'D02_WINDOWS_PS51' 'BLOCK_FOR_E4B_RUNTIME' 'This is not Windows PowerShell 5.1 Desktop'
}


try {
    $policy = (Get-ExecutionPolicy -List | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($policy)) { throw 'empty policy result' }
    Add-Finding 'D03_EXECUTION_POLICY' 'OBSERVED' 'Execution policy is read only; policy is not a security boundary'
} catch {
    Add-Finding 'D03_EXECUTION_POLICY' 'UNKNOWN' 'Policy cannot be queried'
}


$testCases = @(
    [pscustomobject]@{name='valid_ascii.ps1';expected='ZERO'},
    [pscustomobject]@{name='valid_utf8_bom.ps1';expected='ZERO'},
    [pscustomobject]@{name='invalid_syntax.ps1';expected='NONZERO'}
)
foreach ($case in $testCases) {
    $fixture = Join-Path (Join-Path $root 'fixtures') $case.name
    try {
        if (-not (Test-Path -LiteralPath $fixture -PathType Leaf)) { throw 'fixture missing' }
        $tokens = $null
        $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($fixture, [ref]$tokens, [ref]$parseErrors)
        $count = 0
        if ($null -ne $parseErrors) { $count = @($parseErrors).Count }
        $matched = (($case.expected -eq 'ZERO' -and $count -eq 0) -or ($case.expected -eq 'NONZERO' -and $count -gt 0))
        if ($matched) {
            Add-Finding ('D04_PARSE_' + $case.name) 'OBSERVED_EXPECTED' ('Parse errors=' + $count)
        } else {
            Add-Finding ('D04_PARSE_' + $case.name) 'BLOCK_FOR_E4B_RUNTIME' ('Parse errors=' + $count + '; expected=' + $case.expected)
        }
    } catch {
        Add-Finding ('D04_PARSE_' + $case.name) 'UNKNOWN' 'Fixture absent or ParseFile failed'
    }
}


try {
    $json = @{analysis_date='2026-10-13';flags=@($true,$false);names=@('A','B')} | ConvertTo-Json -Depth 4 -Compress
    $obj = $json | ConvertFrom-Json
    if ($obj.flags.Count -eq 2 -and $obj.flags[0] -eq $true -and $obj.names[1] -eq 'B') {
        Add-Finding 'D05_IN_MEMORY_JSON_BINDING' 'OBSERVED_EXPECTED' 'Boolean/array round trip succeeds in current host'
    } else {
        Add-Finding 'D05_IN_MEMORY_JSON_BINDING' 'BLOCK_FOR_E4B_RUNTIME' 'Round trip deviates from expected shape'
    }
} catch {
    Add-Finding 'D05_IN_MEMORY_JSON_BINDING' 'UNKNOWN' 'JSON round trip failed'
}


try {
    $null = Get-Acl -LiteralPath $root
    Add-Finding 'D06_PACKAGE_FOLDER_ACL' 'OBSERVED_NOT_PROTECTED' 'ACL could be read; this is not evidence of protected installation or write denial'
} catch {
    Add-Finding 'D06_PACKAGE_FOLDER_ACL' 'UNKNOWN' 'ACL cannot be queried'
}


if ([string]::IsNullOrWhiteSpace($ZipPath)) {
    Add-Finding 'D07_ZIP_METADATA' 'NOT_TESTED' 'No ZIP path supplied'
} else {
    $archive = $null
    $stream = $null
    try {
        if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) { throw 'ZIP does not exist' }
        Add-Type -AssemblyName 'System.IO.Compression' -ErrorAction Stop
        $stream = [System.IO.File]::Open($ZipPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        $archive = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Read, $false)
        $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        $unsafe = New-Object 'System.Collections.Generic.List[string]'
        if ($archive.Entries.Count -gt 128) { $unsafe.Add('Too many members') }
        foreach ($e in $archive.Entries) {
            $name = [string]$e.FullName
            if ($name.Length -gt 240 -or $name -match '[\\:]' -or $name.StartsWith('/') -or $name -match '[\x00-\x1f]' -or $name -match '(^|/)\.\.?(?:/|$)') {
                $unsafe.Add('Unsafe member name')
            }
            if ($e.Length -gt 4194304 -or $e.CompressedLength -gt 4194304) {
                $unsafe.Add('Member exceeds research size limit')
            }
            $mode = ($e.ExternalAttributes -shr 16) -band 61440
            if ($mode -eq 40960) { $unsafe.Add('Symbolic link member') }
            if (-not $seen.Add($name.TrimEnd('/'))) { $unsafe.Add('Duplicate case-insensitive path') }
        }
        if ($unsafe.Count -gt 0) {
            Add-Finding 'D07_ZIP_METADATA' 'BLOCK_FOR_E4B_RUNTIME' 'Unsafe or ambiguous ZIP metadata detected'
        } else {
            Add-Finding 'D07_ZIP_METADATA' 'OBSERVED_METADATA_ONLY' 'ZIP central directory enumerated without extracting or executing; NOT a release approval'
        }
    } catch {
        Add-Finding 'D07_ZIP_METADATA' 'UNKNOWN' 'ZIP cannot be read; no extraction or execution attempted'
    } finally {
        if ($null -ne $archive) { $archive.Dispose() }
        if ($null -ne $stream) { $stream.Dispose() }
    }
}


$report = [ordered]@{
    role = 'EO03_E4B_READ_ONLY_DIAGNOSTICS_ONLY'
    execution_authorized = $false
    release_approved = $false
    true_independent_approver_verified = $false
    fixed_trust_root_verified = $false
    windows_ps51_real_execution_test = 'NOT_PERFORMED'
    script_sha256_observed = $scriptHash
    findings = @($results.ToArray())
    notes = 'Does not execute PS1, does not extract ZIP, never enables a production gate. Output remains on console only.'
}
$report | ConvertTo-Json -Depth 8
