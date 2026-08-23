#requires -Version 7.5
[CmdletBinding(DefaultParameterSetName = 'Build')]
param(
    [Parameter(ParameterSetName = 'Build')]
    [ValidateSet('zh', 'en', 'all')]
    [string]$Language = 'all',

    [Parameter(ParameterSetName = 'Validate', Mandatory)]
    [switch]$ValidateOnly,

    [Parameter(ParameterSetName = 'Clean', Mandatory)]
    [switch]$Clean,

    [Parameter(ParameterSetName = 'Build', DontShow)]
    [Parameter(ParameterSetName = 'Validate', DontShow)]
    [ValidateNotNullOrEmpty()]
    [string]$DataPath = (Join-Path $PSScriptRoot 'resume.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    if ($PSVersionTable.PSEdition -ne 'Core' -or -not $IsWindows) {
        throw 'PowerShell Core 7.5+ on Windows is required'
    }

    Import-Module (Join-Path $PSScriptRoot 'ResumeBuild.psm1') -Force

    if ($Clean) {
        Clear-ResumeBuildArtifacts -CvDirectory $PSScriptRoot
        Write-Host 'Removed assets/ChineseCV/.build only.'
        exit 0
    }

    $resume = Read-ResumeJson -Path $DataPath
    Test-ResumeData -Resume $resume | Out-Null
    if ($ValidateOnly) {
        Write-Host ('Validated {0}' -f $DataPath)
        exit 0
    }

    $normalizedLanguage = $Language.ToLowerInvariant()
    $languages = if ($normalizedLanguage -eq 'all') { @('zh', 'en') } else { @($normalizedLanguage) }
    Invoke-ResumeBuild -Resume $resume -Language $languages -CvDirectory $PSScriptRoot
    Write-Host ('Built {0}' -f (($languages | ForEach-Object { 'lhzy_resume_{0}.pdf' -f $_ }) -join ' and '))
    exit 0
} catch {
    [System.Console]::Error.WriteLine(('resume build failed: {0}' -f $_.Exception.Message))
    exit 1
}
