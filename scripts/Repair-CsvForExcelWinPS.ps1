param(
    [Parameter(Mandatory = $true)]
    [string]$InputCsv,

    [string]$OutputCsv,

    [ValidateSet("utf8", "unicode", "oem", "default")]
    [string]$InputEncoding = "utf8",

    [ValidateSet("utf8", "unicode")]
    [string]$OutputEncoding = "utf8",

    [switch]$AsTsv
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $InputCsv)) {
    throw "Input CSV not found: $InputCsv"
}

if (-not $OutputCsv) {
    $inputItem = Get-Item -LiteralPath $InputCsv
    $suffix = if ($AsTsv) { ".excel.tsv" } else { ".excel.csv" }
    $OutputCsv = Join-Path $inputItem.DirectoryName ($inputItem.BaseName + $suffix)
}

$rows = Import-Csv -LiteralPath $InputCsv -Encoding $InputEncoding

if ($rows.Count -eq 0) {
    throw "Input CSV has no data rows: $InputCsv"
}

$delimiter = if ($AsTsv) { "`t" } else { "," }

# Windows PowerShell 5.1 uses UTF8 with BOM, which Excel handles better for Korean text.
$rows | Export-Csv `
    -LiteralPath $OutputCsv `
    -NoTypeInformation `
    -Encoding $OutputEncoding `
    -Delimiter $delimiter

Write-Host "Created:" $OutputCsv
Write-Host "Rows:" $rows.Count
Write-Host "Format:" $(if ($AsTsv) { "TSV" } else { "CSV" })
Write-Host "Encoding:" $OutputEncoding
