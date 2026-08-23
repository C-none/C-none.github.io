#requires -Version 7.5

[CmdletBinding()]
param(
    [switch]$Integration
)

# This is a dependency-free test harness for the PowerShell resume build.
# Expected ResumeBuild.psm1 exports:
#   Read-ResumeJson -Path <path>
#   Test-ResumeData -Resume <hashtable>          # throws with a JSON path on invalid data
#   ConvertTo-LatexText -Text <string>
#   ConvertTo-ResumeTex -Resume <hashtable> -Language <zh|en>
# Expected build.ps1 parameters:
#   -Language <zh|en|all> -ValidateOnly -DataPath <path> -Clean

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$CvDirectory = $PSScriptRoot
$ModulePath = Join-Path $CvDirectory 'ResumeBuild.psm1'
$BuildScript = Join-Path $CvDirectory 'build.ps1'
$DataPath = Join-Path $CvDirectory 'resume.json'
$TestDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("resume-build-test-{0}" -f [guid]::NewGuid().ToString('N'))
$Failures = [System.Collections.Generic.List[string]]::new()
$Passed = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Equal {
    param($Actual, $Expected, [string]$Message)
    if ($Actual -cne $Expected) {
        throw "$Message`nExpected: $Expected`nActual:   $Actual"
    }
}

function Assert-Match {
    param([string]$Actual, [string]$Pattern, [string]$Message)
    if ($Actual -notmatch $Pattern) { throw "$Message`nPattern: $Pattern`nActual: $Actual" }
}

function Copy-Resume {
    param([hashtable]$Resume)
    return ($Resume | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable -DateKind String -Depth 20)
}

function Assert-InvalidResume {
    param([hashtable]$Resume, [string]$ExpectedPath)
    try {
        Test-ResumeData -Resume $Resume
        throw 'Validation unexpectedly succeeded.'
    } catch {
        Assert-Match $_.Exception.Message ("^{0}:" -f [regex]::Escape($ExpectedPath)) 'Validation error did not identify the field path.'
    }
}

function Add-ResumeTest {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        $script:Passed++
        Write-Host "PASS: ${Name}"
    } catch {
        $script:Failures.Add("${Name}: $($_.Exception.Message)")
        Write-Error "FAIL: ${Name}: $($_.Exception.Message)" -ErrorAction Continue
    }
}

function Invoke-BuildCli {
    param([string[]]$Arguments, [hashtable]$Environment = @{})
    $previous = @{}
    try {
        foreach ($entry in $Environment.GetEnumerator()) {
            $previous[$entry.Key] = [Environment]::GetEnvironmentVariable($entry.Key, 'Process')
            [Environment]::SetEnvironmentVariable($entry.Key, [string]$entry.Value, 'Process')
        }
        $output = @(& pwsh -NoLogo -NoProfile -File $BuildScript @Arguments 2>&1)
        $exitCode = [int]$LASTEXITCODE
        if ($exitCode -ne 0) {
            $output | ForEach-Object { Write-Host $_ }
        }
        return $exitCode
    } finally {
        foreach ($entry in $Environment.GetEnumerator()) {
            [Environment]::SetEnvironmentVariable($entry.Key, $previous[$entry.Key], 'Process')
        }
    }
}

try {
    Assert-True (Test-Path -LiteralPath $ModulePath -PathType Leaf) "Missing module: $ModulePath"
    Assert-True (Test-Path -LiteralPath $BuildScript -PathType Leaf) "Missing build script: $BuildScript"
    Assert-True (Test-Path -LiteralPath $DataPath -PathType Leaf) "Missing JSON data: $DataPath"
    Import-Module $ModulePath -Force
    New-Item -ItemType Directory -Path $TestDirectory | Out-Null

    $Resume = Read-ResumeJson -Path $DataPath

    Add-ResumeTest 'current JSON is valid' {
        Assert-True (Test-ResumeData -Resume (Copy-Resume $Resume)) 'Validator did not return true.'
    }

    Add-ResumeTest 'version must be the JSON integer 1' {
        $data = Copy-Resume $Resume
        $data.version = '1'
        Assert-InvalidResume $data 'version'
    }

    Add-ResumeTest 'malformed JSON fails with a clear error' {
        $invalidPath = Join-Path $TestDirectory 'malformed.json'
        [System.IO.File]::WriteAllText($invalidPath, '{ "version": ', [System.Text.UTF8Encoding]::new($false))
        $errorMessage = $null
        try {
            Read-ResumeJson -Path $invalidPath | Out-Null
        } catch {
            $errorMessage = $_.Exception.Message
        }
        Assert-True ($null -ne $errorMessage) 'Malformed JSON unexpectedly loaded.'
        Assert-Match $errorMessage 'JSON|json|Unexpected|invalid' 'Malformed JSON error is not recognizable.'
    }

    Add-ResumeTest 'JSON comments and trailing commas are rejected' {
        foreach ($case in @(
            @{ Name = 'comment'; Text = "{`n// not strict JSON`n`"version`": 1`n}" },
            @{ Name = 'trailing-comma'; Text = '{ "version": 1, }' }
        )) {
            $invalidPath = Join-Path $TestDirectory ("{0}.json" -f $case.Name)
            [System.IO.File]::WriteAllText($invalidPath, $case.Text, [System.Text.UTF8Encoding]::new($false))
            $errorMessage = $null
            try {
                Read-ResumeJson -Path $invalidPath | Out-Null
            } catch {
                $errorMessage = $_.Exception.Message
            }
            Assert-True ($null -ne $errorMessage) "$($case.Name) JSON unexpectedly loaded."
            Assert-Match $errorMessage 'JSON|json|comment|trailing|invalid|expected' "The $($case.Name) error is not recognizable."
        }
    }

    Add-ResumeTest 'JSON must be UTF-8 without a BOM' {
        $bomPath = Join-Path $TestDirectory 'bom.json'
        $validBytes = [System.Text.UTF8Encoding]::new($false).GetBytes('{"version":1}')
        [System.IO.File]::WriteAllBytes($bomPath, [byte[]](@(0xEF, 0xBB, 0xBF) + $validBytes))
        $invalidUtf8Path = Join-Path $TestDirectory 'invalid-utf8.json'
        [System.IO.File]::WriteAllBytes($invalidUtf8Path, [byte[]]@(0x7B, 0xFF, 0x7D))
        foreach ($path in @($bomPath, $invalidUtf8Path)) {
            $errorMessage = $null
            try {
                Read-ResumeJson -Path $path | Out-Null
            } catch {
                $errorMessage = $_.Exception.Message
            }
            Assert-True ($null -ne $errorMessage) "Invalid UTF-8 input unexpectedly loaded: $path"
            Assert-Match $errorMessage 'JSON|UTF-8|Unicode|byte' 'UTF-8 error is not recognizable.'
        }
    }

    Add-ResumeTest 'missing translation reports its path' {
        $data = Copy-Resume $Resume
        $data.education[0].degree.Remove('en')
        Assert-InvalidResume $data 'education[0].degree'
    }

    Add-ResumeTest 'translation keys are exactly lowercase zh and en' {
        $data = Copy-Resume $Resume
        $localized = $data.education[0].degree
        $english = $localized.en
        $localized.Remove('en')
        $localized['EN'] = $english
        Assert-InvalidResume $data 'education[0].degree'
    }

    Add-ResumeTest 'duplicate ID reports its path' {
        $data = Copy-Resume $Resume
        $data.education[1].id = $data.education[0].id
        Assert-InvalidResume $data 'education[1].id'
    }

    Add-ResumeTest 'invalid date reports its path' {
        $data = Copy-Resume $Resume
        $data.education[0].start = '2025-13'
        Assert-InvalidResume $data 'education[0].start'
    }

    Add-ResumeTest 'empty bullet reports its path' {
        $data = Copy-Resume $Resume
        $data.experience[0].bullets[0].zh = ''
        Assert-InvalidResume $data 'experience[0].bullets[0].zh'
    }

    Add-ResumeTest 'raw LaTeX reports its path' {
        $data = Copy-Resume $Resume
        $data.experience[0].bullets[0].en = '\textbf{not allowed}'
        Assert-InvalidResume $data 'experience[0].bullets[0].en'
    }

    Add-ResumeTest 'Unicode JSON survives rendering' {
        $tex = ConvertTo-ResumeTex -Resume $Resume -Language zh
        Assert-Match $tex '龙胡志远' 'Chinese name was lost during rendering.'
        Assert-Match $tex '网易互娱' 'Chinese experience was lost during rendering.'
        Assert-Match $tex '×2' 'Unicode multiplication sign was lost during rendering.'
    }

    Add-ResumeTest 'LaTeX special characters are escaped without corrupting Unicode' {
        $escaped = ConvertTo-LatexText -Text '龙 & C++ #1_50% ~ ^ {x} \\'
        Assert-Equal $escaped '龙 \& C++ \#1\_50\% \textasciitilde{} \textasciicircum{} \{x\} \textbackslash{}\textbackslash{}' 'LaTeX escaping differs from the required mapping.'
    }

    Add-ResumeTest 'English education uses degree-in-field wording' {
        $tex = ConvertTo-ResumeTex -Resume $Resume -Language en
        Assert-Match $tex ([regex]::Escape('\textbf{Tongji University}, \textit{B.Eng.} in Software Engineering')) 'English degree wording is wrong.'
    }

    Add-ResumeTest 'English experience keeps the company-position comma' {
        $tex = ConvertTo-ResumeTex -Resume $Resume -Language en
        $expected = '\textbf{NetEase Games — Knives Out Business Unit, Graphics Development Intern}'
        Assert-Match $tex ([regex]::Escape($expected)) 'English experience title punctuation is wrong.'
    }

    Add-ResumeTest 'English layout widens the text area and protects short bullet tails' {
        $enTex = ConvertTo-ResumeTex -Resume $Resume -Language en
        $zhTex = ConvertTo-ResumeTex -Resume $Resume -Language zh
        Assert-Match $enTex ([regex]::Escape('\geometry{left=0.6in,right=0.6in}')) 'English horizontal margins were not widened.'
        Assert-Match $enTex ([regex]::Escape('\renewcommand{\datedsubsection}[2]{\subsection[#1]{#1 \hfill \mbox{#2}}}')) 'English dates are not protected from line breaks.'
        Assert-Match $enTex ([regex]::Escape('\begin{itemize}[parsep=0.15ex,leftmargin=1.35pc]')) 'English list indentation was not tightened.'
        Assert-Match $enTex ([regex]::Escape('\raggedright\hyphenpenalty=10000\exhyphenpenalty=10000')) 'English bullets do not suppress awkward word splitting.'
        Assert-Match $enTex ([regex]::Escape('guide~radiance~cache~optimization.')) 'English bullet tail was not kept together.'
        Assert-Match $enTex ([regex]::Escape('\fontsize{10.5pt}{12.6pt}\selectfont')) 'English awards did not receive the compact local font size.'
        Assert-True (-not $zhTex.Contains('\geometry{left=0.6in,right=0.6in}', [System.StringComparison]::Ordinal)) 'English margin override leaked into the Chinese resume.'
        Assert-True (-not $zhTex.Contains('\raggedright\hyphenpenalty=10000', [System.StringComparison]::Ordinal)) 'English bullet layout leaked into the Chinese resume.'
    }

    Add-ResumeTest 'localized date ranges use compact en dashes' {
        $zhTex = ConvertTo-ResumeTex -Resume $Resume -Language zh
        $enTex = ConvertTo-ResumeTex -Resume $Resume -Language en
        Assert-Match $zhTex '2025\.5--2025\.8' 'Chinese date range is wrong.'
        Assert-Match $enTex 'May 2025--Aug 2025' 'English date range is wrong.'
    }

    Add-ResumeTest 'template placeholders must be unique, known, and complete' {
        $template = [System.IO.File]::ReadAllText((Join-Path $CvDirectory 'resume.tex.template'), [System.Text.Encoding]::UTF8)
        $cases = @(
            @{ Name = 'missing'; Text = $template.Replace('{{SKILLS}}', '') },
            @{ Name = 'duplicate'; Text = $template + "`n{{SKILLS}}" },
            @{ Name = 'unknown'; Text = $template + "`n{{UNKNOWN_PLACEHOLDER}}" }
        )
        foreach ($case in $cases) {
            $path = Join-Path $TestDirectory ("template-{0}.tex" -f $case.Name)
            [System.IO.File]::WriteAllText($path, $case.Text, [System.Text.UTF8Encoding]::new($false))
            $errorMessage = $null
            try {
                ConvertTo-ResumeTex -Resume $Resume -Language en -TemplatePath $path | Out-Null
            } catch {
                $errorMessage = $_.Exception.Message
            }
            Assert-True ($null -ne $errorMessage) "$($case.Name) placeholder template unexpectedly rendered."
            Assert-Match $errorMessage 'placeholder|exactly once|unknown' "The $($case.Name) placeholder error is not recognizable."
        }
    }

    Add-ResumeTest 'CLI ValidateOnly reports a JSON field path and returns nonzero' {
        $data = Copy-Resume $Resume
        $data.projects[0].title.Remove('en')
        $invalidPath = Join-Path $TestDirectory 'invalid.json'
        [System.IO.File]::WriteAllText($invalidPath, ($data | ConvertTo-Json -Depth 20), [System.Text.UTF8Encoding]::new($false))
        $output = & pwsh -NoLogo -NoProfile -File $BuildScript -ValidateOnly -DataPath $invalidPath 2>&1
        Assert-True ($LASTEXITCODE -eq 1) "ValidateOnly returned $LASTEXITCODE instead of 1."
        Assert-Match ($output -join "`n") 'resume build failed:' 'CLI error omitted the required prefix.'
        Assert-Match ($output -join "`n") 'projects\[0\]\.title' 'CLI error omitted the invalid JSON path.'
    }

    if ($Integration) {
        Add-ResumeTest 'integration builds all languages with two XeLaTeX passes and validates PDFs' {
            $exitCode = Invoke-BuildCli @('-Language', 'all')
            Assert-True ($exitCode -eq 0) "all build returned $exitCode."
            foreach ($language in 'zh', 'en') {
                $pdf = Join-Path $CvDirectory "lhzy_resume_$language.pdf"
                $pass1 = Join-Path $CvDirectory ".build/$language/xelatex.pass1.stdout.log"
                $pass2 = Join-Path $CvDirectory ".build/$language/xelatex.pass2.stdout.log"
                $pdfInfoLog = Join-Path $CvDirectory ".build/$language/pdfinfo.stdout.log"
                $textPath = Join-Path $CvDirectory ".build/$language/pdf.text.txt"
                Assert-True (Test-Path -LiteralPath $pdf -PathType Leaf) "Missing published $language PDF."
                Assert-True (Test-Path -LiteralPath $pass1 -PathType Leaf) "Missing $language XeLaTeX pass 1 log."
                Assert-True (Test-Path -LiteralPath $pass2 -PathType Leaf) "Missing $language XeLaTeX pass 2 log."
                $pdfInfo = [System.IO.File]::ReadAllText($pdfInfoLog, [System.Text.Encoding]::UTF8)
                Assert-Match $pdfInfo '(?m)^Pages:\s+1\s*$' "$language PDF is not exactly one page."
                Assert-Match $pdfInfo '(?m)^Page size:\s+595\.28 x 841\.89 pts' "$language PDF is not A4."
                $text = [System.Text.UTF8Encoding]::new($false, $true).GetString([System.IO.File]::ReadAllBytes($textPath))
                $anchors = if ($language -eq 'zh') {
                    @('龙胡志远', '香港大学', '网易互娱', '腾讯', 'SRSSIS', 'huzhiyuan.long@outlook.com', 'c-none.github.io', 'ReSTIR')
                } else {
                    @('Huzhiyuan Long', 'The University of Hong Kong', 'NetEase Games', 'LIGHTSPEED STUDIOS', 'SRSSIS', 'huzhiyuan.long@outlook.com', 'c-none.github.io', 'ReSTIR')
                }
                foreach ($anchor in $anchors) {
                    Assert-True ($text.Contains($anchor, [System.StringComparison]::Ordinal)) "$language PDF text is missing $anchor."
                }
            }
            $staged = @(Get-ChildItem -LiteralPath $CvDirectory -Force -Filter '.lhzy_resume_*.tmp')
            Assert-True ($staged.Count -eq 0) 'Successful atomic publish left a temporary file behind.'
        }

        Add-ResumeTest 'integration builds each language independently' {
            foreach ($language in 'zh', 'en') {
                $exitCode = Invoke-BuildCli @('-Language', $language)
                Assert-True ($exitCode -eq 0) "$language build returned $exitCode."
            }
        }

        Add-ResumeTest 'failed XeLaTeX does not overwrite published PDFs or leave atomic staging files' {
            $published = @('zh', 'en') | ForEach-Object { Join-Path $CvDirectory "lhzy_resume_$_.pdf" }
            $before = @{}
            foreach ($path in $published) { $before[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
            $exitCode = Invoke-BuildCli @('-Language', 'all') @{ XELATEX = (Join-Path $PSHOME 'pwsh.exe') }
            Assert-True ($exitCode -ne 0) 'Invalid XeLaTeX command unexpectedly succeeded.'
            foreach ($path in $published) {
                Assert-Equal (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash $before[$path] "Failed build overwrote $path."
            }
            $staged = @(Get-ChildItem -LiteralPath $CvDirectory -Force -Filter '.lhzy_resume_*.tmp')
            Assert-True ($staged.Count -eq 0) 'Atomic publish left a temporary file behind.'
        }

        Add-ResumeTest 'Clean preserves published PDFs' {
            $published = @('zh', 'en') | ForEach-Object { Join-Path $CvDirectory "lhzy_resume_$_.pdf" }
            $preservedInputs = @(
                $DataPath,
                (Join-Path $CvDirectory 'resume.tex.template'),
                (Join-Path $CvDirectory 'fonts')
            )
            $before = @{}
            foreach ($path in $published) { $before[$path] = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
            $exitCode = Invoke-BuildCli @('-Clean')
            Assert-True ($exitCode -eq 0) "Clean returned $exitCode."
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $CvDirectory '.build'))) 'Clean did not remove .build.'
            foreach ($path in $published) {
                Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "Clean deleted $path."
                Assert-Equal (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash $before[$path] "Clean changed $path."
            }
            foreach ($path in $preservedInputs) {
                Assert-True (Test-Path -LiteralPath $path) "Clean deleted required input or font asset: $path"
            }
        }
    }
} finally {
    if (Test-Path -LiteralPath $TestDirectory) { Remove-Item -LiteralPath $TestDirectory -Recurse -Force }
}

if ($Failures.Count -gt 0) {
    Write-Error ("{0} of {1} tests failed:`n- {2}" -f $Failures.Count, ($Failures.Count + $Passed), ($Failures -join "`n- ")) -ErrorAction Continue
    exit 1
}

Write-Host "$Passed tests passed"
