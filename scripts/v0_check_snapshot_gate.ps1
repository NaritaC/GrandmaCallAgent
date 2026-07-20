param(
    [string]$AnalysisRoot = "artifacts/v0-call-snapshots",
    [string]$DeviceModel = "HUAWEI Pura 70 Ultra",
    [string]$HarmonyOsVersion = "4.2.0",
    [string]$WeChatVersion = "8.0.76",
    [switch]$ConfirmScreenshotsReviewed,
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. (Join-Path $ScriptDir "v0_common.ps1")

if (-not (Test-Path -LiteralPath $AnalysisRoot -PathType Container)) {
    throw "Snapshot analysis root was not found: $AnalysisRoot"
}
if (-not $ConfirmScreenshotsReviewed) {
    throw "Screenshot review is required. Inspect all six screen.png files, then re-run with -ConfirmScreenshotsReviewed."
}

$analysisFiles = @(Get-ChildItem -LiteralPath $AnalysisRoot -Recurse -Filter "analysis.json" -File)
if ($analysisFiles.Count -eq 0) {
    throw "No analysis.json files were found under $AnalysisRoot."
}

$analyses = @()
foreach ($file in $analysisFiles) {
    try {
        $analyses += Get-Content -Raw -LiteralPath $file.FullName | ConvertFrom-Json
    } catch {
        throw "Unable to parse snapshot analysis file: $($file.FullName). $($_.Exception.Message)"
    }
}

$summary = Get-V0SnapshotGateSummary `
    -Analyses $analyses `
    -ExpectedDeviceModel $DeviceModel `
    -ExpectedHarmonyOsVersion $HarmonyOsVersion `
    -ExpectedWeChatVersion $WeChatVersion
$result = [pscustomobject][ordered]@{
    schema_version = 1
    checked_at = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
    complete = $summary.complete
    target = $summary.target
    required_count = $summary.required_count
    valid_count = $summary.valid_count
    valid = $summary.valid
    missing = $summary.missing
    source_analysis_count = $analysisFiles.Count
    snapshots_reviewed = $true
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $OutputPath = Join-Path $AnalysisRoot "snapshot-gate-$timestamp.json"
}
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding utf8

if ($result.complete) {
    $gateValidation = Get-V0SnapshotGateValidation -Gate $result
    if (-not $gateValidation.pass) {
        throw "Generated snapshot gate failed structural validation: $($gateValidation.reasons -join ', ')."
    }
}

Write-Host "V0 snapshot gate:"
Write-Host "- complete: $($result.complete)"
Write-Host "- valid: $($result.valid_count)/$($result.required_count)"
Write-Host "- missing: $($result.missing -join ', ')"
Write-Host "- result: $OutputPath"

if (-not $result.complete) {
    throw "Snapshot gate is incomplete. Keep all automation Accessibility services disabled."
}
