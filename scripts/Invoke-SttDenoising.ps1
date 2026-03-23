param(
    [Parameter(Mandatory = $true)]
    [string]$InputCsv,

    [string]$OutputCsv,

    [string]$TextColumn = "source_text",

    [string]$CleanedColumn = "source_text_cleaned",

    [string]$CleanupAppliedColumn = "stt_preprocess_cleanup_applied",

    [string]$UncertainSpansColumn = "stt_preprocess_uncertain_spans",

    [string]$NoisePatternsColumn = "stt_preprocess_noise_patterns",

    [string]$RetainedFactsColumn = "stt_preprocess_retained_key_facts",

    [ValidateSet("utf8", "unicode", "oem", "default")]
    [string]$InputEncoding = "utf8",

    [ValidateSet("utf8", "unicode")]
    [string]$OutputEncoding = "utf8"
)

$ErrorActionPreference = "Stop"

function ConvertTo-JsonArrayString {
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$Values
    )

    if ($null -eq $Values) {
        return '[]'
    }

    $normalized = @()
    foreach ($value in $Values) {
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $normalized += $value.Trim()
        }
    }

    return ($normalized | ConvertTo-Json -Compress)
}

function Get-UniqueOrdered {
    param(
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$Values
    )

    if ($null -eq $Values) {
        return @()
    }

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $result = [System.Collections.Generic.List[string]]::new()

    foreach ($value in $Values) {
        if ([string]::IsNullOrWhiteSpace($value)) {
            continue
        }

        $trimmed = $value.Trim()
        if ($seen.Add($trimmed)) {
            [void]$result.Add($trimmed)
        }
    }

    return $result.ToArray()
}

function Normalize-Whitespace {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text
    )

    $normalized = $Text -replace "`r`n", "`n"
    $normalized = $normalized -replace "[`t ]+", " "
    $normalized = $normalized -replace " ?`n ?", "`n"
    return $normalized.Trim()
}

function Remove-PatternWithAudit {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [regex]$Pattern,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Replacement,

        [Parameter(Mandatory = $true)]
        [string]$Label,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [System.Collections.Generic.List[string]]$Audit
    )

    $matches = $Pattern.Matches($Text)
    if ($matches.Count -gt 0) {
        [void]$Audit.Add($Label)
        return $Pattern.Replace($Text, $Replacement)
    }

    return $Text
}

function Get-NoiseSummary {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Text
    )

    $cleanupApplied = [System.Collections.Generic.List[string]]::new()
    $noisePatterns = [System.Collections.Generic.List[string]]::new()
    $uncertainSpans = [System.Collections.Generic.List[string]]::new()
    $retainedFacts = [System.Collections.Generic.List[string]]::new()

    $working = Normalize-Whitespace -Text $Text
    if ([string]::IsNullOrWhiteSpace($working)) {
        return [pscustomobject]@{
            CleanedText = ""
            CleanupApplied = @()
            NoisePatterns = @()
            UncertainSpans = @()
            RetainedKeyFacts = @()
        }
    }

    $working = Remove-PatternWithAudit -Text $working -Pattern ([regex]'(?im)\b(네|예|음|아|어|저기요|잠시만요|여보세요)([\s,./-]+\1){1,}\b') -Replacement '$1' -Label '반복 채움 발화 축약' -Audit $cleanupApplied
    $working = Remove-PatternWithAudit -Text $working -Pattern ([regex]'(?im)(생년월일|주민등록번호|휴대폰번호|전화번호|연락처|주소|계좌번호|카드번호|증권번호)\s*[:은는이가]?[\s0-9\-]{4,}') -Replacement '' -Label '본인확인용 개인정보 제거' -Audit $cleanupApplied
    $working = Remove-PatternWithAudit -Text $working -Pattern ([regex]'(?im)\b(감사합니다|수고하세요|좋은 하루 보내세요|도와드리겠습니다|확인해 드리겠습니다|안녕하세요)\b') -Replacement '' -Label '반복 인사말 제거' -Audit $cleanupApplied
    $working = Remove-PatternWithAudit -Text $working -Pattern ([regex]'(?im)\b(네네네|예예예|아아아|음음음)\b') -Replacement '' -Label '반복 채움 발화 제거' -Audit $cleanupApplied

    $lines = $working -split "`n"
    $cleanLines = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $lines) {
        $candidate = ($line -replace '\s+', ' ').Trim(' ', ',', '.', ';', ':')
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }

        if ($candidate -match '^(네|예|음|아|어|잠시만요|잠깐만요|여보세요)$') {
            [void]$noisePatterns.Add('의미 없는 단독 채움 발화')
            continue
        }

        if ($candidate -match '(?i)생년월일|주민등록번호|휴대폰번호|전화번호|연락처|주소|계좌번호|카드번호|증권번호') {
            [void]$noisePatterns.Add('본인확인용 개인정보 문장')
            continue
        }

        if ($candidate -match '(?i)(수강 이력|드론 수입|대통령 손편지)') {
            [void]$uncertainSpans.Add($candidate)
            continue
        }

        if ($candidate -match '[0-9]{6,}' -and $candidate -notmatch '(보험금|청구|접수|처리|유지|해지|부활|재가입|문자|콜백|서류|보장|계약)') {
            [void]$uncertainSpans.Add($candidate)
            continue
        }

        [void]$cleanLines.Add($candidate)
    }

    $cleanedText = Normalize-Whitespace -Text (($cleanLines.ToArray() -join " `n"))

    if ($cleanedText -match '요청|문의|확인|알려') {
        [void]$retainedFacts.Add('고객 요청')
    }
    if ($cleanedText -match '접수|진행|완료|유지|해지|반송|철회|부활|재가입') {
        [void]$retainedFacts.Add('처리 상태')
    }
    if ($cleanedText -match '문자|콜백|안내|발송|연락|서류') {
        [void]$retainedFacts.Add('상담사 후속조치')
    }
    if ($cleanedText -match '불만|민원|불편|항의') {
        [void]$retainedFacts.Add('민원/불만')
    }

    return [pscustomobject]@{
        CleanedText = $cleanedText
        CleanupApplied = (Get-UniqueOrdered $cleanupApplied.ToArray())
        NoisePatterns = (Get-UniqueOrdered $noisePatterns.ToArray())
        UncertainSpans = (Get-UniqueOrdered $uncertainSpans.ToArray())
        RetainedKeyFacts = (Get-UniqueOrdered $retainedFacts.ToArray())
    }
}

if (-not (Test-Path -LiteralPath $InputCsv)) {
    throw "Input CSV not found: $InputCsv"
}

if (-not $OutputCsv) {
    $inputItem = Get-Item -LiteralPath $InputCsv
    $OutputCsv = Join-Path $inputItem.DirectoryName ($inputItem.BaseName + '.denoised.csv')
}

$rows = Import-Csv -LiteralPath $InputCsv -Encoding $InputEncoding
if ($rows.Count -eq 0) {
    throw "Input CSV has no data rows: $InputCsv"
}

if (-not ($rows[0].PSObject.Properties.Name -contains $TextColumn)) {
    throw "Text column not found: $TextColumn"
}

foreach ($row in $rows) {
    $text = [string]$row.$TextColumn
    $summary = Get-NoiseSummary -Text $text

    $row | Add-Member -NotePropertyName $CleanedColumn -NotePropertyValue $summary.CleanedText -Force
    $row | Add-Member -NotePropertyName $CleanupAppliedColumn -NotePropertyValue (ConvertTo-JsonArrayString $summary.CleanupApplied) -Force
    $row | Add-Member -NotePropertyName $UncertainSpansColumn -NotePropertyValue (ConvertTo-JsonArrayString $summary.UncertainSpans) -Force
    $row | Add-Member -NotePropertyName $NoisePatternsColumn -NotePropertyValue (ConvertTo-JsonArrayString $summary.NoisePatterns) -Force
    $row | Add-Member -NotePropertyName $RetainedFactsColumn -NotePropertyValue (ConvertTo-JsonArrayString $summary.RetainedKeyFacts) -Force
}

$rows | Export-Csv -LiteralPath $OutputCsv -NoTypeInformation -Encoding $OutputEncoding

Write-Host "Created:" $OutputCsv
Write-Host "Rows:" $rows.Count
Write-Host "InputColumn:" $TextColumn
Write-Host "CleanedColumn:" $CleanedColumn
