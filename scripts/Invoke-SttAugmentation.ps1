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

    [string]$AudioRunModeColumn = "audio_preprocess_run_mode",

    [string]$AudioStatusColumn = "audio_preprocess_status",

    [string]$AudioPipelineColumn = "audio_preprocess_pipeline",

    [string]$AudioPriorityColumn = "audio_preprocess_priority_steps",

    [string]$AudioTargetFormatColumn = "audio_preprocess_target_format",

    [string]$AudioNotesColumn = "audio_preprocess_notes",

    [ValidateSet("planned", "applied", "skipped")]
    [string]$AudioPreprocessStatus = "planned",

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

function Get-AudioPreprocessProfile {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Row,

        [Parameter(Mandatory = $true)]
        [string]$Status
    )

    $pipeline = @(
        "noise_reduction",
        "volume_normalization",
        "vad",
        "speaker_diarization",
        "overlap_handling",
        "segment_split",
        "format_normalization_16khz_mono"
    )

    $prioritySteps = @(
        "noise_reduction",
        "vad",
        "speaker_diarization"
    )

    $notes = [System.Collections.Generic.List[string]]::new()
    [void]$notes.Add("음원 전처리는 요약 프로세스와 분리된 STT 사전 단계로 운영")
    [void]$notes.Add("핵심 정보 추출에는 source_text_cleaned를 사용하고 최종 사실 확인은 source_text를 사용")

    $propertyNames = $Row.PSObject.Properties.Name
    $hasAudioReference = $propertyNames -contains "audio_path" -or $propertyNames -contains "audio_file"

    if (-not $hasAudioReference) {
        [void]$notes.Add("현재 CSV에는 음원 경로가 없어 실제 DSP 실행 여부 대신 권장 파이프라인 메타데이터만 기록")
    }

    return [pscustomobject]@{
        RunMode = "separate_pre_stt"
        Status = $Status
        Pipeline = $pipeline
        PrioritySteps = $prioritySteps
        TargetFormat = "16kHz mono"
        Notes = $notes.ToArray()
    }
}

if (-not (Test-Path -LiteralPath $InputCsv)) {
    throw "Input CSV not found: $InputCsv"
}

if (-not $OutputCsv) {
    $inputItem = Get-Item -LiteralPath $InputCsv
    $OutputCsv = Join-Path $inputItem.DirectoryName ($inputItem.BaseName + '.augmented.csv')
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
    $audioProfile = Get-AudioPreprocessProfile -Row $row -Status $AudioPreprocessStatus

    $row | Add-Member -NotePropertyName $CleanedColumn -NotePropertyValue $summary.CleanedText -Force
    $row | Add-Member -NotePropertyName $CleanupAppliedColumn -NotePropertyValue (ConvertTo-JsonArrayString $summary.CleanupApplied) -Force
    $row | Add-Member -NotePropertyName $UncertainSpansColumn -NotePropertyValue (ConvertTo-JsonArrayString $summary.UncertainSpans) -Force
    $row | Add-Member -NotePropertyName $NoisePatternsColumn -NotePropertyValue (ConvertTo-JsonArrayString $summary.NoisePatterns) -Force
    $row | Add-Member -NotePropertyName $RetainedFactsColumn -NotePropertyValue (ConvertTo-JsonArrayString $summary.RetainedKeyFacts) -Force

    $row | Add-Member -NotePropertyName $AudioRunModeColumn -NotePropertyValue $audioProfile.RunMode -Force
    $row | Add-Member -NotePropertyName $AudioStatusColumn -NotePropertyValue $audioProfile.Status -Force
    $row | Add-Member -NotePropertyName $AudioPipelineColumn -NotePropertyValue (ConvertTo-JsonArrayString $audioProfile.Pipeline) -Force
    $row | Add-Member -NotePropertyName $AudioPriorityColumn -NotePropertyValue (ConvertTo-JsonArrayString $audioProfile.PrioritySteps) -Force
    $row | Add-Member -NotePropertyName $AudioTargetFormatColumn -NotePropertyValue $audioProfile.TargetFormat -Force
    $row | Add-Member -NotePropertyName $AudioNotesColumn -NotePropertyValue (ConvertTo-JsonArrayString $audioProfile.Notes) -Force
}

$rows | Export-Csv -LiteralPath $OutputCsv -NoTypeInformation -Encoding $OutputEncoding

Write-Host "Created:" $OutputCsv
Write-Host "Rows:" $rows.Count
Write-Host "InputColumn:" $TextColumn
Write-Host "CleanedColumn:" $CleanedColumn
Write-Host "AudioRunMode:" "separate_pre_stt"
Write-Host "AudioStatus:" $AudioPreprocessStatus
