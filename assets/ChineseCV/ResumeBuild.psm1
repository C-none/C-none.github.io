#requires -Version 7.5

Set-StrictMode -Version Latest

$script:ResumeModuleRoot = $PSScriptRoot
$script:ResumeTemplatePath = Join-Path $script:ResumeModuleRoot 'resume.tex.template'
$script:ResumeLanguages = @('zh', 'en')
$script:ResumeUtf8NoBom = [System.Text.UTF8Encoding]::new($false)
$script:ResumeMonthNames = @('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec')
$script:ResumeSectionHeadings = @{
    zh = @{
        education = '教育背景'
        experience = '职业经历'
        publications = '发表论文'
        projects = '项目作品'
        awards = '奖项荣誉'
        skills = '技术能力'
    }
    en = @{
        education = 'Education'
        experience = 'Professional Experience'
        publications = 'Publications'
        projects = 'Projects'
        awards = 'Honors and Awards'
        skills = 'Technical Skills'
    }
}
$script:ResumeLatexEscapes = @{
    '\' = '\textbackslash{}'
    '{' = '\{'
    '}' = '\}'
    '$' = '\$'
    '&' = '\&'
    '#' = '\#'
    '_' = '\_'
    '%' = '\%'
    '~' = '\textasciitilde{}'
    '^' = '\textasciicircum{}'
}
$script:ResumeTemplateTokens = @(
    '{{LANGUAGE_PREAMBLE}}',
    '{{NAME_BLOCK}}',
    '{{CONTACT_BLOCK}}',
    '{{EDUCATION}}',
    '{{EXPERIENCE}}',
    '{{PUBLICATIONS}}',
    '{{PROJECTS}}',
    '{{AWARDS}}',
    '{{SKILLS}}'
)

function Throw-ResumeValidationError {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Message
    )

    throw ('{0}: {1}' -f $Path, $Message)
}

function Test-ResumeMapHasExactKey {
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]$Map,

        [Parameter(Mandatory)]
        [string]$Name
    )

    foreach ($key in $Map.Keys) {
        if ($key -is [string] -and [string]::Equals($key, $Name, [System.StringComparison]::Ordinal)) {
            return $true
        }
    }
    return $false
}

function Get-ResumeRequiredValue {
    param(
        [Parameter(Mandatory)]
        $Map,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Path
    )

    if ($Map -isnot [System.Collections.IDictionary]) {
        Throw-ResumeValidationError -Path $Path -Message 'must be an object'
    }
    if (-not (Test-ResumeMapHasExactKey -Map $Map -Name $Name)) {
        Throw-ResumeValidationError -Path ('{0}.{1}' -f $Path, $Name) -Message 'is required'
    }
    return $Map[$Name]
}

function Get-ResumeDictionary {
    param(
        [Parameter(Mandatory)]
        $Value,

        [Parameter(Mandatory)]
        [string]$Path
    )

    if ($null -eq $Value -or $Value -isnot [System.Collections.IDictionary]) {
        Throw-ResumeValidationError -Path $Path -Message 'must be an object'
    }
    return $Value
}

function Get-ResumeArray {
    param(
        [Parameter(Mandatory)]
        $Value,

        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$NonEmpty
    )

    if ($null -eq $Value -or $Value -isnot [System.Collections.IList]) {
        Throw-ResumeValidationError -Path $Path -Message 'must be an array'
    }
    if ($NonEmpty -and $Value.Count -eq 0) {
        Throw-ResumeValidationError -Path $Path -Message 'must not be empty'
    }
    return $Value
}

function Get-ResumeRequiredArray {
    param(
        [Parameter(Mandatory)]
        $Map,

        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$MapPath,

        [Parameter(Mandatory)]
        [string]$ArrayPath,

        [switch]$NonEmpty
    )

    if ($Map -isnot [System.Collections.IDictionary]) {
        Throw-ResumeValidationError -Path $MapPath -Message 'must be an object'
    }
    if (-not (Test-ResumeMapHasExactKey -Map $Map -Name $Name)) {
        Throw-ResumeValidationError -Path ('{0}.{1}' -f $MapPath, $Name) -Message 'is required'
    }
    return Get-ResumeArray -Value $Map[$Name] -Path $ArrayPath -NonEmpty:$NonEmpty
}

function Assert-ResumeText {
    param(
        [Parameter(Mandatory)]
        $Value,

        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$DisallowRawLatex
    )

    if ($Value -isnot [string] -or [string]::IsNullOrWhiteSpace($Value)) {
        Throw-ResumeValidationError -Path $Path -Message 'must be a non-empty string'
    }
    if ($DisallowRawLatex -and $Value.Contains('\')) {
        Throw-ResumeValidationError -Path $Path -Message 'must not contain raw LaTeX commands'
    }
    return $Value
}

function Assert-LocalizedText {
    param(
        [Parameter(Mandatory)]
        $Value,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $localized = Get-ResumeDictionary -Value $Value -Path $Path
    if (
        $localized.Count -ne 2 -or
        -not (Test-ResumeMapHasExactKey -Map $localized -Name 'zh') -or
        -not (Test-ResumeMapHasExactKey -Map $localized -Name 'en')
    ) {
        Throw-ResumeValidationError -Path $Path -Message 'must contain exactly zh and en'
    }
    foreach ($language in $script:ResumeLanguages) {
        [void](Assert-ResumeText -Value $localized[$language] -Path ('{0}.{1}' -f $Path, $language) -DisallowRawLatex)
    }
    return $localized
}

function Assert-ResumeDate {
    param(
        [Parameter(Mandatory)]
        $Value,

        [Parameter(Mandatory)]
        [string]$Path,

        [switch]$MonthRequired
    )

    $date = Assert-ResumeText -Value $Value -Path $Path
    if ($date -notmatch '^\d{4}(?:-(?:0[1-9]|1[0-2]))?$') {
        Throw-ResumeValidationError -Path $Path -Message 'must be a quoted YYYY or YYYY-MM string'
    }
    if ($MonthRequired -and $date.Length -ne 7) {
        Throw-ResumeValidationError -Path $Path -Message 'must include a month'
    }
    return $date
}

function Assert-ResumeIdentifier {
    param(
        [Parameter(Mandatory)]
        $Entry,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [System.Collections.Generic.Dictionary[string, string]]$SeenIdentifiers
    )

    $idPath = '{0}.id' -f $Path
    $identifier = Assert-ResumeText -Value (Get-ResumeRequiredValue -Map $Entry -Name 'id' -Path $Path) -Path $idPath
    if ($SeenIdentifiers.ContainsKey($identifier)) {
        Throw-ResumeValidationError -Path $idPath -Message ('duplicates {0}' -f $SeenIdentifiers[$identifier])
    }
    $SeenIdentifiers[$identifier] = $idPath
}

function Assert-ResumeBullets {
    param(
        [Parameter(Mandatory)]
        $Entry,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $bullets = @(Get-ResumeRequiredArray -Map $Entry -Name 'bullets' -MapPath $Path -ArrayPath ('{0}.bullets' -f $Path) -NonEmpty)
    for ($index = 0; $index -lt $bullets.Count; $index++) {
        [void](Assert-LocalizedText -Value $bullets[$index] -Path ('{0}.bullets[{1}]' -f $Path, $index))
    }
}

function Read-ResumeJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    try {
        $resolvedPath = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
        $bytes = [System.IO.File]::ReadAllBytes($resolvedPath)
        $strictUtf8 = [System.Text.UTF8Encoding]::new($false, $true)
        $json = $strictUtf8.GetString($bytes)
        if ($json.Length -gt 0 -and $json[0] -eq [char]0xFEFF) {
            throw 'UTF-8 BOM is not allowed'
        }

        $documentOptions = [System.Text.Json.JsonDocumentOptions]::new()
        $documentOptions.CommentHandling = [System.Text.Json.JsonCommentHandling]::Disallow
        $documentOptions.AllowTrailingCommas = $false
        $document = [System.Text.Json.JsonDocument]::Parse($json, $documentOptions)
        $document.Dispose()

        return ConvertFrom-Json -InputObject $json -AsHashtable -Depth 100 -DateKind String
    } catch {
        throw ('JSON {0}: {1}' -f $Path, $_.Exception.Message)
    }
}

function Test-ResumeData {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        $Resume
    )

    $root = Get-ResumeDictionary -Value $Resume -Path 'resume'
    $version = Get-ResumeRequiredValue -Map $root -Name 'version' -Path 'resume'
    if ($version -isnot [long] -or $version -ne [long]1) {
        Throw-ResumeValidationError -Path 'version' -Message 'must be the JSON integer 1'
    }

    $seenIdentifiers = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::Ordinal)
    $profile = Get-ResumeDictionary -Value (Get-ResumeRequiredValue -Map $root -Name 'profile' -Path 'resume') -Path 'profile'
    [void](Assert-LocalizedText -Value (Get-ResumeRequiredValue -Map $profile -Name 'name' -Path 'profile') -Path 'profile.name')
    $email = Assert-ResumeText -Value (Get-ResumeRequiredValue -Map $profile -Name 'email' -Path 'profile') -Path 'profile.email'
    $website = Assert-ResumeText -Value (Get-ResumeRequiredValue -Map $profile -Name 'website' -Path 'profile') -Path 'profile.website'
    [void](Assert-ResumeText -Value (Get-ResumeRequiredValue -Map $profile -Name 'wechat_id' -Path 'profile') -Path 'profile.wechat_id' -DisallowRawLatex)
    if ($email -notmatch '^[^@\s{}\\]+@[^@\s{}\\]+\.[^@\s{}\\]+$') {
        Throw-ResumeValidationError -Path 'profile.email' -Message 'must be a valid email address'
    }
    $websiteUri = $null
    if (
        $website -notmatch '^https?://\S+$' -or
        -not [System.Uri]::TryCreate($website, [System.UriKind]::Absolute, [ref]$websiteUri) -or
        $websiteUri.Scheme -notin @('http', 'https') -or
        [string]::IsNullOrWhiteSpace($websiteUri.Host)
    ) {
        Throw-ResumeValidationError -Path 'profile.website' -Message 'must be an http(s) URL'
    }

    $education = @(Get-ResumeRequiredArray -Map $root -Name 'education' -MapPath 'resume' -ArrayPath 'education' -NonEmpty)
    for ($index = 0; $index -lt $education.Count; $index++) {
        $path = 'education[{0}]' -f $index
        $entry = Get-ResumeDictionary -Value $education[$index] -Path $path
        Assert-ResumeIdentifier -Entry $entry -Path $path -SeenIdentifiers $seenIdentifiers
        foreach ($field in @('institution', 'field', 'degree')) {
            [void](Assert-LocalizedText -Value (Get-ResumeRequiredValue -Map $entry -Name $field -Path $path) -Path ('{0}.{1}' -f $path, $field))
        }
        $start = Assert-ResumeDate -Value (Get-ResumeRequiredValue -Map $entry -Name 'start' -Path $path) -Path ('{0}.start' -f $path) -MonthRequired
        $end = Assert-ResumeDate -Value (Get-ResumeRequiredValue -Map $entry -Name 'end' -Path $path) -Path ('{0}.end' -f $path) -MonthRequired
    }

    $experience = @(Get-ResumeRequiredArray -Map $root -Name 'experience' -MapPath 'resume' -ArrayPath 'experience' -NonEmpty)
    for ($index = 0; $index -lt $experience.Count; $index++) {
        $path = 'experience[{0}]' -f $index
        $entry = Get-ResumeDictionary -Value $experience[$index] -Path $path
        Assert-ResumeIdentifier -Entry $entry -Path $path -SeenIdentifiers $seenIdentifiers
        [void](Assert-LocalizedText -Value (Get-ResumeRequiredValue -Map $entry -Name 'company' -Path $path) -Path ('{0}.company' -f $path))
        [void](Assert-LocalizedText -Value (Get-ResumeRequiredValue -Map $entry -Name 'position' -Path $path) -Path ('{0}.position' -f $path))
        $start = Assert-ResumeDate -Value (Get-ResumeRequiredValue -Map $entry -Name 'start' -Path $path) -Path ('{0}.start' -f $path) -MonthRequired
        $end = Assert-ResumeDate -Value (Get-ResumeRequiredValue -Map $entry -Name 'end' -Path $path) -Path ('{0}.end' -f $path) -MonthRequired
        Assert-ResumeBullets -Entry $entry -Path $path
    }

    $publications = @(Get-ResumeRequiredArray -Map $root -Name 'publications' -MapPath 'resume' -ArrayPath 'publications' -NonEmpty)
    for ($index = 0; $index -lt $publications.Count; $index++) {
        $path = 'publications[{0}]' -f $index
        $entry = Get-ResumeDictionary -Value $publications[$index] -Path $path
        Assert-ResumeIdentifier -Entry $entry -Path $path -SeenIdentifiers $seenIdentifiers
        [void](Assert-LocalizedText -Value (Get-ResumeRequiredValue -Map $entry -Name 'title' -Path $path) -Path ('{0}.title' -f $path))
        [void](Assert-LocalizedText -Value (Get-ResumeRequiredValue -Map $entry -Name 'venue' -Path $path) -Path ('{0}.venue' -f $path))
        [void](Assert-ResumeDate -Value (Get-ResumeRequiredValue -Map $entry -Name 'date' -Path $path) -Path ('{0}.date' -f $path) -MonthRequired)
        Assert-ResumeBullets -Entry $entry -Path $path

        $authors = @(Get-ResumeRequiredArray -Map $entry -Name 'authors' -MapPath $path -ArrayPath ('{0}.authors' -f $path) -NonEmpty)
        $selfCount = 0
        for ($authorIndex = 0; $authorIndex -lt $authors.Count; $authorIndex++) {
            $authorPath = '{0}.authors[{1}]' -f $path, $authorIndex
            $author = Get-ResumeDictionary -Value $authors[$authorIndex] -Path $authorPath
            [void](Assert-ResumeText -Value (Get-ResumeRequiredValue -Map $author -Name 'name' -Path $authorPath) -Path ('{0}.name' -f $authorPath) -DisallowRawLatex)
            $isSelf = Get-ResumeRequiredValue -Map $author -Name 'is_self' -Path $authorPath
            if ($isSelf -isnot [bool]) {
                Throw-ResumeValidationError -Path ('{0}.is_self' -f $authorPath) -Message 'must be true or false'
            }
            if ($isSelf) {
                $selfCount++
            }
        }
        if ($selfCount -ne 1) {
            Throw-ResumeValidationError -Path ('{0}.authors' -f $path) -Message 'must mark exactly one author as self'
        }
    }

    $projects = @(Get-ResumeRequiredArray -Map $root -Name 'projects' -MapPath 'resume' -ArrayPath 'projects' -NonEmpty)
    for ($index = 0; $index -lt $projects.Count; $index++) {
        $path = 'projects[{0}]' -f $index
        $entry = Get-ResumeDictionary -Value $projects[$index] -Path $path
        Assert-ResumeIdentifier -Entry $entry -Path $path -SeenIdentifiers $seenIdentifiers
        [void](Assert-LocalizedText -Value (Get-ResumeRequiredValue -Map $entry -Name 'title' -Path $path) -Path ('{0}.title' -f $path))
        Assert-ResumeBullets -Entry $entry -Path $path
    }

    $awards = @(Get-ResumeRequiredArray -Map $root -Name 'awards' -MapPath 'resume' -ArrayPath 'awards' -NonEmpty)
    for ($index = 0; $index -lt $awards.Count; $index++) {
        $path = 'awards[{0}]' -f $index
        $entry = Get-ResumeDictionary -Value $awards[$index] -Path $path
        Assert-ResumeIdentifier -Entry $entry -Path $path -SeenIdentifiers $seenIdentifiers
        [void](Assert-LocalizedText -Value (Get-ResumeRequiredValue -Map $entry -Name 'title' -Path $path) -Path ('{0}.title' -f $path))
        $dates = @(Get-ResumeRequiredArray -Map $entry -Name 'dates' -MapPath $path -ArrayPath ('{0}.dates' -f $path) -NonEmpty)
        for ($dateIndex = 0; $dateIndex -lt $dates.Count; $dateIndex++) {
            [void](Assert-ResumeDate -Value $dates[$dateIndex] -Path ('{0}.dates[{1}]' -f $path, $dateIndex))
        }
    }

    $skills = @(Get-ResumeRequiredArray -Map $root -Name 'skills' -MapPath 'resume' -ArrayPath 'skills' -NonEmpty)
    for ($index = 0; $index -lt $skills.Count; $index++) {
        $path = 'skills[{0}]' -f $index
        $entry = Get-ResumeDictionary -Value $skills[$index] -Path $path
        Assert-ResumeIdentifier -Entry $entry -Path $path -SeenIdentifiers $seenIdentifiers
        [void](Assert-LocalizedText -Value (Get-ResumeRequiredValue -Map $entry -Name 'label' -Path $path) -Path ('{0}.label' -f $path))
        $values = @(Get-ResumeRequiredArray -Map $entry -Name 'values' -MapPath $path -ArrayPath ('{0}.values' -f $path) -NonEmpty)
        for ($valueIndex = 0; $valueIndex -lt $values.Count; $valueIndex++) {
            $valuePath = '{0}.values[{1}]' -f $path, $valueIndex
            if ($values[$valueIndex] -is [System.Collections.IDictionary]) {
                [void](Assert-LocalizedText -Value $values[$valueIndex] -Path $valuePath)
            } else {
                [void](Assert-ResumeText -Value $values[$valueIndex] -Path $valuePath -DisallowRawLatex)
            }
        }
    }

    return $true
}

function ConvertTo-LatexText {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Text
    )

    $builder = [System.Text.StringBuilder]::new()
    foreach ($character in $Text.ToCharArray()) {
        $key = [string]$character
        if ($script:ResumeLatexEscapes.ContainsKey($key)) {
            [void]$builder.Append($script:ResumeLatexEscapes[$key])
        } else {
            [void]$builder.Append($character)
        }
    }
    return $builder.ToString()
}

function Get-LocalizedLatexText {
    param(
        [Parameter(Mandatory)]
        $Value,

        [Parameter(Mandatory)]
        [ValidateSet('zh', 'en')]
        [string]$Language
    )

    return ConvertTo-LatexText -Text ([string]$Value[$Language])
}

function ConvertTo-ResumeDate {
    param(
        [Parameter(Mandatory)]
        [string]$Date,

        [Parameter(Mandatory)]
        [ValidateSet('zh', 'en')]
        [string]$Language
    )

    $parts = $Date.Split('-')
    if ($parts.Count -eq 1) {
        return $parts[0]
    }

    $month = [int]$parts[1]
    if ($Language -eq 'zh') {
        return ('{0}.{1}' -f $parts[0], $month)
    }
    return ('{0} {1}' -f $script:ResumeMonthNames[$month - 1], $parts[0])
}

function Get-ResumeDateRange {
    param(
        [Parameter(Mandatory)]
        $Entry,

        [Parameter(Mandatory)]
        [ValidateSet('zh', 'en')]
        [string]$Language
    )

    return ('{0}--{1}' -f (ConvertTo-ResumeDate -Date $Entry['start'] -Language $Language), (ConvertTo-ResumeDate -Date $Entry['end'] -Language $Language))
}

function Get-ResumeEducationTitle {
    param(
        [Parameter(Mandatory)]
        $Entry,

        [Parameter(Mandatory)]
        [ValidateSet('zh', 'en')]
        [string]$Language
    )

    $institution = Get-LocalizedLatexText -Value $Entry['institution'] -Language $Language
    $field = Get-LocalizedLatexText -Value $Entry['field'] -Language $Language
    $degree = Get-LocalizedLatexText -Value $Entry['degree'] -Language $Language
    if ($Language -eq 'zh') {
        return ('\textbf{{{0}}}，{1}，\textit{{{2}}}' -f $institution, $field, $degree)
    }
    return ('\textbf{{{0}}}, \textit{{{1}}} in {2}' -f $institution, $degree, $field)
}

function Get-ResumeExperienceTitle {
    param(
        [Parameter(Mandatory)]
        $Entry,

        [Parameter(Mandatory)]
        [ValidateSet('zh', 'en')]
        [string]$Language
    )

    $separator = if ($Language -eq 'zh') { '，' } else { ', ' }
    return ('{0}{1}{2}' -f (Get-LocalizedLatexText -Value $Entry['company'] -Language $Language), $separator, (Get-LocalizedLatexText -Value $Entry['position'] -Language $Language))
}

function Get-ResumePublicationAuthors {
    param(
        [Parameter(Mandatory)]
        $Authors
    )

    $renderedAuthors = foreach ($author in $Authors) {
        $name = ConvertTo-LatexText -Text ([string]$author['name'])
        if ($author['is_self']) {
            '\textbf{{{0}}}' -f $name
        } else {
            $name
        }
    }
    return ($renderedAuthors -join ', ')
}

function Get-ResumeSkillValues {
    param(
        [Parameter(Mandatory)]
        $Values,

        [Parameter(Mandatory)]
        [ValidateSet('zh', 'en')]
        [string]$Language
    )

    $renderedValues = foreach ($value in $Values) {
        if ($value -is [System.Collections.IDictionary]) {
            Get-LocalizedLatexText -Value $value -Language $Language
        } else {
            ConvertTo-LatexText -Text ([string]$value)
        }
    }
    return ($renderedValues -join ', ')
}

function New-ResumeItemizeBlock {
    param(
        [Parameter(Mandatory)]
        $Bullets,

        [Parameter(Mandatory)]
        [ValidateSet('zh', 'en')]
        [string]$Language
    )

    $builder = [System.Text.StringBuilder]::new()
    $itemizeOptions = if ($Language -eq 'en') { 'parsep=0.15ex,leftmargin=1.35pc' } else { 'parsep=0.15ex' }
    [void]$builder.AppendLine(('\begin{{itemize}}[{0}]' -f $itemizeOptions))
    foreach ($bullet in $Bullets) {
        $text = Get-LocalizedLatexText -Value $bullet -Language $Language
        if ($Language -eq 'en') {
            # Keep a short sentence tail together so one or two words are not
            # stranded on the final line. Ragged-right text avoids the large
            # spaces that these nonbreaking spaces could otherwise introduce.
            $words = @([System.Text.RegularExpressions.Regex]::Split($text.Trim(), '\s+'))
            if ($words.Count -ge 4) {
                $prefixCount = $words.Count - 4
                $tail = ($words[$prefixCount..($words.Count - 1)] -join '~')
                $text = if ($prefixCount -gt 0) {
                    (($words[0..($prefixCount - 1)] -join ' ') + ' ' + $tail)
                } else {
                    $tail
                }
            }
            $text = '\raggedright\hyphenpenalty=10000\exhyphenpenalty=10000 {0}' -f $text
        }
        [void]$builder.AppendLine(('  \item {0}' -f $text))
    }
    [void]$builder.AppendLine('\end{itemize}')
    return $builder.ToString().TrimEnd()
}

function New-ResumeEducationBlock {
    param(
        [Parameter(Mandatory)]
        $Resume,

        [Parameter(Mandatory)]
        [ValidateSet('zh', 'en')]
        [string]$Language
    )

    $builder = [System.Text.StringBuilder]::new()
    [void]$builder.AppendLine(('\section{{{0}}}' -f $script:ResumeSectionHeadings[$Language]['education']))
    foreach ($entry in $Resume['education']) {
        [void]$builder.AppendLine(('\datedsubsection{{{0}}}{{{1}}}' -f (Get-ResumeEducationTitle -Entry $entry -Language $Language), (Get-ResumeDateRange -Entry $entry -Language $Language)))
    }
    return $builder.ToString().TrimEnd()
}

function New-ResumeExperienceBlock {
    param(
        [Parameter(Mandatory)]
        $Resume,

        [Parameter(Mandatory)]
        [ValidateSet('zh', 'en')]
        [string]$Language
    )

    $builder = [System.Text.StringBuilder]::new()
    [void]$builder.AppendLine(('\section{{{0}}}' -f $script:ResumeSectionHeadings[$Language]['experience']))
    foreach ($entry in $Resume['experience']) {
        [void]$builder.AppendLine(('\datedsubsection{{\textbf{{{0}}}}}{{{1}}}' -f (Get-ResumeExperienceTitle -Entry $entry -Language $Language), (Get-ResumeDateRange -Entry $entry -Language $Language)))
        [void]$builder.AppendLine((New-ResumeItemizeBlock -Bullets $entry['bullets'] -Language $Language))
    }
    return $builder.ToString().TrimEnd()
}

function New-ResumePublicationsBlock {
    param(
        [Parameter(Mandatory)]
        $Resume,

        [Parameter(Mandatory)]
        [ValidateSet('zh', 'en')]
        [string]$Language
    )

    $builder = [System.Text.StringBuilder]::new()
    [void]$builder.AppendLine(('\section{{{0}}}' -f $script:ResumeSectionHeadings[$Language]['publications']))
    foreach ($entry in $Resume['publications']) {
        $title = Get-LocalizedLatexText -Value $entry['title'] -Language $Language
        $authors = Get-ResumePublicationAuthors -Authors $entry['authors']
        $venue = Get-LocalizedLatexText -Value $entry['venue'] -Language $Language
        $date = ConvertTo-ResumeDate -Date $entry['date'] -Language $Language
        [void]$builder.AppendLine(('\datedsubsection{{\textbf{{{0}}}. \newline' -f $title))
        [void]$builder.AppendLine(('{0}. \textit{{{1}}}.}}{{{2}}}' -f $authors, $venue, $date))
        [void]$builder.AppendLine((New-ResumeItemizeBlock -Bullets $entry['bullets'] -Language $Language))
    }
    return $builder.ToString().TrimEnd()
}

function New-ResumeProjectsBlock {
    param(
        [Parameter(Mandatory)]
        $Resume,

        [Parameter(Mandatory)]
        [ValidateSet('zh', 'en')]
        [string]$Language
    )

    $builder = [System.Text.StringBuilder]::new()
    [void]$builder.AppendLine(('\section{{{0}}}' -f $script:ResumeSectionHeadings[$Language]['projects']))
    foreach ($entry in $Resume['projects']) {
        [void]$builder.AppendLine(('\textbf{{{0}}}' -f (Get-LocalizedLatexText -Value $entry['title'] -Language $Language)))
        [void]$builder.AppendLine((New-ResumeItemizeBlock -Bullets $entry['bullets'] -Language $Language))
    }
    return $builder.ToString().TrimEnd()
}

function New-ResumeAwardsBlock {
    param(
        [Parameter(Mandatory)]
        $Resume,

        [Parameter(Mandatory)]
        [ValidateSet('zh', 'en')]
        [string]$Language
    )

    $builder = [System.Text.StringBuilder]::new()
    [void]$builder.AppendLine(('\section{{{0}}}' -f $script:ResumeSectionHeadings[$Language]['awards']))
    if ($Language -eq 'en') {
        [void]$builder.AppendLine('\titleformat{\subsection}{\fontsize{10.5pt}{12.6pt}\selectfont\raggedright}{}{0em}{}')
    }
    foreach ($entry in $Resume['awards']) {
        $dates = (($entry['dates'] | ForEach-Object { ConvertTo-ResumeDate -Date $_ -Language $Language }) -join ', ')
        [void]$builder.AppendLine(('\datedsubsection{{\textbf{{{0}}}}}{{{1}}}' -f (Get-LocalizedLatexText -Value $entry['title'] -Language $Language), $dates))
    }
    if ($Language -eq 'en') {
        [void]$builder.AppendLine('\titleformat{\subsection}{\large\raggedright}{}{0em}{}')
    }
    return $builder.ToString().TrimEnd()
}

function New-ResumeSkillsBlock {
    param(
        [Parameter(Mandatory)]
        $Resume,

        [Parameter(Mandatory)]
        [ValidateSet('zh', 'en')]
        [string]$Language
    )

    $builder = [System.Text.StringBuilder]::new()
    [void]$builder.AppendLine(('\section{{{0}}}' -f $script:ResumeSectionHeadings[$Language]['skills']))
    $itemizeOptions = if ($Language -eq 'en') { 'parsep=0.15ex,leftmargin=1.35pc' } else { 'parsep=0.15ex' }
    [void]$builder.AppendLine(('\begin{{itemize}}[{0}]' -f $itemizeOptions))
    foreach ($entry in $Resume['skills']) {
        [void]$builder.AppendLine(('  \item \textbf{{{0}}}: {1}' -f (Get-LocalizedLatexText -Value $entry['label'] -Language $Language), (Get-ResumeSkillValues -Values $entry['values'] -Language $Language)))
    }
    [void]$builder.AppendLine('\end{itemize}')
    return $builder.ToString().TrimEnd()
}

function Get-ResumeTemplate {
    param(
        [Parameter(Mandatory)]
        [string]$TemplatePath
    )

    if (-not (Test-Path -LiteralPath $TemplatePath -PathType Leaf)) {
        throw ('Missing LaTeX template: {0}' -f $TemplatePath)
    }
    $template = [System.IO.File]::ReadAllText($TemplatePath, $script:ResumeUtf8NoBom)
    foreach ($token in $script:ResumeTemplateTokens) {
        $count = [System.Text.RegularExpressions.Regex]::Matches($template, [System.Text.RegularExpressions.Regex]::Escape($token)).Count
        if ($count -ne 1) {
            throw ('resume.tex.template must contain {0} exactly once' -f $token)
        }
    }
    $tokensInTemplate = [System.Text.RegularExpressions.Regex]::Matches($template, '\{\{[^{}]*\}\}') | ForEach-Object { $_.Value }
    foreach ($token in $tokensInTemplate) {
        if ($token -notin $script:ResumeTemplateTokens) {
            throw ('resume.tex.template contains an unknown placeholder: {0}' -f $token)
        }
    }
    return $template
}

function ConvertTo-ResumeTex {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        $Resume,

        [Parameter(Mandatory)]
        [ValidateSet('zh', 'en')]
        [string]$Language,

        [string]$TemplatePath = $script:ResumeTemplatePath
    )

    Test-ResumeData -Resume $Resume | Out-Null
    $template = Get-ResumeTemplate -TemplatePath $TemplatePath
    $profile = $Resume['profile']
    $name = Get-LocalizedLatexText -Value $profile['name'] -Language $Language
    $nameBlock = if ($Language -eq 'zh') {
        ('\centerline{{\Huge{{{0}}}}}{1}\vspace{{1.2ex}}' -f $name, [System.Environment]::NewLine)
    } else {
        '\name{{{0}}}' -f $name
    }

    $email = [string]$profile['email']
    $website = [string]$profile['website']
    $websiteLabel = $website -replace '^https?://', '' -replace '/$', ''
    $wechatLabel = if ($Language -eq 'zh') { '微信' } else { 'WeChat' }
    $contactLines = @(
        '\begin{center}',
        '  \sffamily\large',
        ('  \href{{mailto:{0}}}{{{1}}}' -f (ConvertTo-LatexText -Text $email), (ConvertTo-LatexText -Text $email)),
        ('  \textperiodcentered\ \href{{{0}}}{{{1}}}' -f (ConvertTo-LatexText -Text $website), (ConvertTo-LatexText -Text $websiteLabel)),
        ('  \textperiodcentered\ {0}: {1}' -f $wechatLabel, (ConvertTo-LatexText -Text ([string]$profile['wechat_id']))),
        '\end{center}'
    )
    $contactBlock = $contactLines -join [System.Environment]::NewLine
    $languagePreamble = if ($Language -eq 'zh') {
        @(
            '\usepackage[UTF8,fontset=fandol]{ctex}',
            '\titleformat{\section}{\Large\raggedright}{}{0em}{}[\titlerule]'
        ) -join [System.Environment]::NewLine
    } else {
        @(
            '\geometry{left=0.6in,right=0.6in}',
            '\renewcommand{\datedsubsection}[2]{\subsection[#1]{#1 \hfill \mbox{#2}}}',
            '% English uses TeX Gyre Termes configured by resume.cls.'
        ) -join [System.Environment]::NewLine
    }

    $replacements = [ordered]@{
        '{{LANGUAGE_PREAMBLE}}' = $languagePreamble
        '{{NAME_BLOCK}}' = $nameBlock
        '{{CONTACT_BLOCK}}' = $contactBlock
        '{{EDUCATION}}' = New-ResumeEducationBlock -Resume $Resume -Language $Language
        '{{EXPERIENCE}}' = New-ResumeExperienceBlock -Resume $Resume -Language $Language
        '{{PUBLICATIONS}}' = New-ResumePublicationsBlock -Resume $Resume -Language $Language
        '{{PROJECTS}}' = New-ResumeProjectsBlock -Resume $Resume -Language $Language
        '{{AWARDS}}' = New-ResumeAwardsBlock -Resume $Resume -Language $Language
        '{{SKILLS}}' = New-ResumeSkillsBlock -Resume $Resume -Language $Language
    }
    $rendered = $template
    foreach ($token in $script:ResumeTemplateTokens) {
        $rendered = $rendered.Replace($token, [string]$replacements[$token])
    }
    if ([System.Text.RegularExpressions.Regex]::IsMatch($rendered, '\{\{[^{}]*\}\}')) {
        throw 'resume.tex.template has an unreplaced placeholder'
    }

    return $rendered
}

function Get-ResumeToolPath {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('xelatex', 'pdfinfo', 'pdftotext')]
        [string]$Name
    )

    $override = [System.Environment]::GetEnvironmentVariable($Name.ToUpperInvariant(), 'Process')
    if (-not [string]::IsNullOrWhiteSpace($override)) {
        return $override
    }

    if ($Name -in @('pdfinfo', 'pdftotext')) {
        $scoopRoot = [System.Environment]::GetEnvironmentVariable('SCOOP', 'Process')
        if ([string]::IsNullOrWhiteSpace($scoopRoot)) {
            $scoopRoot = Join-Path ([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)) 'scoop'
        }
        $scoopCandidate = Join-Path $scoopRoot ('apps\poppler\current\bin\{0}.exe' -f $Name)
        if (Test-Path -LiteralPath $scoopCandidate -PathType Leaf) {
            return $scoopCandidate
        }
    }

    $command = Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $command) {
        throw ('Required executable not found: {0}' -f $Name)
    }
    return $command.Source
}

function Invoke-ResumeNativeProcess {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$ArgumentList,

        [Parameter(Mandatory)]
        [string]$WorkingDirectory
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    $startInfo.WorkingDirectory = $WorkingDirectory
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.StandardOutputEncoding = $script:ResumeUtf8NoBom
    $startInfo.StandardErrorEncoding = $script:ResumeUtf8NoBom
    foreach ($argument in $ArgumentList) {
        [void]$startInfo.ArgumentList.Add([string]$argument)
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        [void]$process.Start()
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.WaitForExit()
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            StdOut = $stdoutTask.GetAwaiter().GetResult()
            StdErr = $stderrTask.GetAwaiter().GetResult()
        }
    } finally {
        $process.Dispose()
    }
}

function Write-ResumeUtf8File {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Content
    )

    $directory = [System.IO.Path]::GetDirectoryName($Path)
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    [System.IO.File]::WriteAllText($Path, $Content, $script:ResumeUtf8NoBom)
}

function Get-ResumeBuildDirectory {
    param(
        [Parameter(Mandatory)]
        [string]$CvDirectory
    )

    $trimCharacters = [char[]]@('\', '/')
    $root = [System.IO.Path]::GetFullPath($CvDirectory).TrimEnd($trimCharacters)
    $buildDirectory = [System.IO.Path]::GetFullPath((Join-Path $root '.build')).TrimEnd($trimCharacters)
    $expectedDirectory = (Join-Path $root '.build').TrimEnd($trimCharacters)
    if (-not [string]::Equals($buildDirectory, $expectedDirectory, [System.StringComparison]::OrdinalIgnoreCase) -or $buildDirectory -eq $root) {
        throw 'Refusing to use an unsafe build directory'
    }
    return $buildDirectory
}

function Remove-ResumeLanguageBuildDirectory {
    param(
        [Parameter(Mandatory)]
        [string]$CvDirectory,

        [Parameter(Mandatory)]
        [ValidateSet('zh', 'en')]
        [string]$Language
    )

    $buildDirectory = Get-ResumeBuildDirectory -CvDirectory $CvDirectory
    if (Test-Path -LiteralPath $buildDirectory) {
        $buildItem = Get-Item -LiteralPath $buildDirectory -Force
        if (($buildItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw 'Refusing to build through a reparse-point .build directory'
        }
    }
    $languageDirectory = [System.IO.Path]::GetFullPath((Join-Path $buildDirectory $Language))
    $expectedDirectory = Join-Path $buildDirectory $Language
    if (-not [string]::Equals($languageDirectory, $expectedDirectory, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Refusing to clean an unsafe language build directory'
    }
    if (Test-Path -LiteralPath $languageDirectory) {
        $languageItem = Get-Item -LiteralPath $languageDirectory -Force
        if (($languageItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            Remove-Item -LiteralPath $languageDirectory -Force
        } else {
            Remove-Item -LiteralPath $languageDirectory -Recurse -Force
        }
    }
    [System.IO.Directory]::CreateDirectory($languageDirectory) | Out-Null
    return $languageDirectory
}

function Test-ResumeTexLog {
    param(
        [Parameter(Mandatory)]
        [string]$LogPath,

        [Parameter(Mandatory)]
        [ValidateSet('zh', 'en')]
        [string]$Language
    )

    if (-not (Test-Path -LiteralPath $LogPath -PathType Leaf)) {
        throw ('{0}: XeLaTeX did not create a log file' -f $Language)
    }
    $log = [System.IO.File]::ReadAllText($LogPath, $script:ResumeUtf8NoBom)
    foreach ($pattern in @('Missing character:', 'Package fontspec Error', '(?i)font .* not found', 'Overfull \\[hv]box')) {
        if ($log -match $pattern) {
            throw ('{0}: XeLaTeX log failed validation ({1})' -f $Language, $pattern)
        }
    }
}

function Get-ResumePdfAnchors {
    param(
        [Parameter(Mandatory)]
        $Resume,

        [Parameter(Mandatory)]
        [ValidateSet('zh', 'en')]
        [string]$Language
    )

    $websiteLabel = ([string]$Resume['profile']['website']) -replace '^https?://', '' -replace '/$', ''
    $languageAnchors = if ($Language -eq 'zh') {
        @('网易互娱', '腾讯')
    } else {
        @('NetEase Games', 'LIGHTSPEED STUDIOS')
    }
    return @(
        [string]$Resume['profile']['name'][$Language]
        [string]$Resume['education'][0]['institution'][$Language]
        $languageAnchors
        (([string]$Resume['publications'][0]['title'][$Language] -split ':')[0]).Trim()
        [string]$Resume['profile']['email']
        $websiteLabel
        'ReSTIR'
    )
}

function Test-ResumePdfCandidate {
    param(
        [Parameter(Mandatory)]
        [string]$PdfPath,

        [Parameter(Mandatory)]
        [string]$LanguageDirectory,

        [Parameter(Mandatory)]
        $Resume,

        [Parameter(Mandatory)]
        [ValidateSet('zh', 'en')]
        [string]$Language,

        [Parameter(Mandatory)]
        [string]$CvDirectory
    )

    if (-not (Test-Path -LiteralPath $PdfPath -PathType Leaf) -or (Get-Item -LiteralPath $PdfPath).Length -eq 0) {
        throw ('{0}: XeLaTeX did not create a non-empty PDF' -f $Language)
    }

    $pdfInfo = Invoke-ResumeNativeProcess -FilePath (Get-ResumeToolPath -Name 'pdfinfo') -ArgumentList @($PdfPath) -WorkingDirectory $CvDirectory
    Write-ResumeUtf8File -Path (Join-Path $LanguageDirectory 'pdfinfo.stdout.log') -Content $pdfInfo.StdOut
    Write-ResumeUtf8File -Path (Join-Path $LanguageDirectory 'pdfinfo.stderr.log') -Content $pdfInfo.StdErr
    if ($pdfInfo.ExitCode -ne 0) {
        throw ('{0}: pdfinfo failed: {1}' -f $Language, $pdfInfo.StdErr.Trim())
    }
    if ($pdfInfo.StdOut -notmatch '(?m)^Pages:\s+1\s*$') {
        throw ('{0}: PDF must contain exactly one page' -f $Language)
    }
    $pageSize = [System.Text.RegularExpressions.Regex]::Match($pdfInfo.StdOut, '(?m)^Page size:\s+([0-9.]+) x ([0-9.]+) pts')
    if (-not $pageSize.Success -or [Math]::Abs([double]$pageSize.Groups[1].Value - 595.28) -ge 1 -or [Math]::Abs([double]$pageSize.Groups[2].Value - 841.89) -ge 1) {
        throw ('{0}: PDF must use A4 page size' -f $Language)
    }

    $textPath = Join-Path $LanguageDirectory 'pdf.text.txt'
    $pdfText = Invoke-ResumeNativeProcess -FilePath (Get-ResumeToolPath -Name 'pdftotext') -ArgumentList @('-enc', 'UTF-8', '-layout', $PdfPath, $textPath) -WorkingDirectory $CvDirectory
    Write-ResumeUtf8File -Path (Join-Path $LanguageDirectory 'pdftotext.stdout.log') -Content $pdfText.StdOut
    Write-ResumeUtf8File -Path (Join-Path $LanguageDirectory 'pdftotext.stderr.log') -Content $pdfText.StdErr
    if ($pdfText.ExitCode -ne 0 -or -not (Test-Path -LiteralPath $textPath -PathType Leaf)) {
        throw ('{0}: pdftotext failed: {1}' -f $Language, $pdfText.StdErr.Trim())
    }

    try {
        $text = [System.Text.UTF8Encoding]::new($false, $true).GetString([System.IO.File]::ReadAllBytes($textPath))
    } catch {
        throw ('{0}: extracted PDF text is not valid UTF-8' -f $Language)
    }
    foreach ($anchor in Get-ResumePdfAnchors -Resume $Resume -Language $Language) {
        if (-not $text.Contains($anchor, [System.StringComparison]::Ordinal)) {
            throw ('{0}: PDF text is missing anchor {1}' -f $Language, $anchor)
        }
    }

    $previousIndex = -1
    foreach ($section in @('education', 'experience', 'publications', 'projects', 'awards', 'skills')) {
        $heading = $script:ResumeSectionHeadings[$Language][$section]
        $index = $text.IndexOf($heading, [System.StringComparison]::Ordinal)
        if ($index -lt 0 -or $index -le $previousIndex) {
            throw ('{0}: extracted PDF text has an invalid section order' -f $Language)
        }
        $previousIndex = $index
    }
}

function New-ResumePdfCandidate {
    param(
        [Parameter(Mandatory)]
        $Resume,

        [Parameter(Mandatory)]
        [ValidateSet('zh', 'en')]
        [string]$Language,

        [Parameter(Mandatory)]
        [string]$CvDirectory
    )

    $languageDirectory = Remove-ResumeLanguageBuildDirectory -CvDirectory $CvDirectory -Language $Language
    $jobName = 'lhzy_resume_{0}' -f $Language
    $texPath = Join-Path $languageDirectory ('{0}.tex' -f $jobName)
    Write-ResumeUtf8File -Path $texPath -Content (ConvertTo-ResumeTex -Resume $Resume -Language $Language)

    $xelatex = Get-ResumeToolPath -Name 'xelatex'
    $arguments = @(
        '-interaction=nonstopmode',
        '-halt-on-error',
        '-file-line-error',
        ('-output-directory={0}' -f $languageDirectory),
        ('-jobname={0}' -f $jobName),
        $texPath
    )
    for ($pass = 1; $pass -le 2; $pass++) {
        $result = Invoke-ResumeNativeProcess -FilePath $xelatex -ArgumentList $arguments -WorkingDirectory $CvDirectory
        Write-ResumeUtf8File -Path (Join-Path $languageDirectory ('xelatex.pass{0}.stdout.log' -f $pass)) -Content $result.StdOut
        Write-ResumeUtf8File -Path (Join-Path $languageDirectory ('xelatex.pass{0}.stderr.log' -f $pass)) -Content $result.StdErr
        if ($result.ExitCode -ne 0) {
            throw ('{0}: XeLaTeX pass {1} failed; inspect {2}' -f $Language, $pass, $languageDirectory)
        }
    }

    $logPath = Join-Path $languageDirectory ('{0}.log' -f $jobName)
    Test-ResumeTexLog -LogPath $logPath -Language $Language
    $pdfPath = Join-Path $languageDirectory ('{0}.pdf' -f $jobName)
    Test-ResumePdfCandidate -PdfPath $pdfPath -LanguageDirectory $languageDirectory -Resume $Resume -Language $Language -CvDirectory $CvDirectory
    return $pdfPath
}

function Initialize-ResumeMoveFileApi {
    if (-not ('ResumeBuild.NativeMethods' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace ResumeBuild
{
    public static class NativeMethods
    {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool MoveFileEx(string existingFileName, string newFileName, int flags);
    }
}
'@
    }
}

function Publish-ResumePdf {
    param(
        [Parameter(Mandatory)]
        [string]$CandidatePath,

        [Parameter(Mandatory)]
        [string]$TargetPath
    )

    $CandidatePath = [System.IO.Path]::GetFullPath($CandidatePath)
    $TargetPath = [System.IO.Path]::GetFullPath($TargetPath)
    if (-not (Test-Path -LiteralPath $CandidatePath -PathType Leaf)) {
        throw ('Cannot publish missing candidate: {0}' -f $CandidatePath)
    }

    $targetDirectory = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($TargetPath))
    $targetName = [System.IO.Path]::GetFileName($TargetPath)
    $stagedPath = Join-Path $targetDirectory ('.{0}.{1}.tmp' -f $targetName, [guid]::NewGuid().ToString('N'))
    try {
        [System.IO.File]::Copy($CandidatePath, $stagedPath, $false)
        Initialize-ResumeMoveFileApi
        $moveFlags = 0x00000001 -bor 0x00000008
        if (-not [ResumeBuild.NativeMethods]::MoveFileEx($stagedPath, $TargetPath, $moveFlags)) {
            $errorCode = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
            throw ([System.ComponentModel.Win32Exception]::new($errorCode, ('Could not atomically publish {0}' -f $TargetPath)))
        }
    } finally {
        if (Test-Path -LiteralPath $stagedPath -PathType Leaf) {
            Remove-Item -LiteralPath $stagedPath -Force
        }
    }
}

function Invoke-ResumeBuild {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $Resume,

        [Parameter(Mandatory)]
        [ValidateSet('zh', 'en')]
        [string[]]$Language,

        [Parameter(Mandatory)]
        [string]$CvDirectory
    )

    Test-ResumeData -Resume $Resume | Out-Null
    $candidates = [ordered]@{}
    foreach ($currentLanguage in $Language) {
        $candidates[$currentLanguage] = New-ResumePdfCandidate -Resume $Resume -Language $currentLanguage -CvDirectory $CvDirectory
    }
    foreach ($currentLanguage in $Language) {
        Publish-ResumePdf -CandidatePath $candidates[$currentLanguage] -TargetPath (Join-Path $CvDirectory ('lhzy_resume_{0}.pdf' -f $currentLanguage))
    }
}

function Clear-ResumeBuildArtifacts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$CvDirectory
    )

    $trimCharacters = [char[]]@('\', '/')
    $requestedRoot = [System.IO.Path]::GetFullPath($CvDirectory).TrimEnd($trimCharacters)
    $expectedRoot = [System.IO.Path]::GetFullPath($script:ResumeModuleRoot).TrimEnd($trimCharacters)
    if (-not [string]::Equals($requestedRoot, $expectedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Refusing to clean anything except assets/ChineseCV/.build'
    }

    $buildDirectory = Get-ResumeBuildDirectory -CvDirectory $requestedRoot
    if (-not (Test-Path -LiteralPath $buildDirectory)) {
        return
    }

    $item = Get-Item -LiteralPath $buildDirectory -Force
    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        Remove-Item -LiteralPath $buildDirectory -Force
    } else {
        Remove-Item -LiteralPath $buildDirectory -Recurse -Force
    }
}

Export-ModuleMember -Function @(
    'Read-ResumeJson',
    'Test-ResumeData',
    'ConvertTo-LatexText',
    'ConvertTo-ResumeTex',
    'Invoke-ResumeBuild',
    'Clear-ResumeBuildArtifacts'
)
