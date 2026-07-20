param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$UiDumpPath,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ExpectedContactRemark,

    [Parameter(Mandatory = $true)]
    [ValidateSet("Voice", "Video")]
    [string]$CallType,

    [Parameter(Mandatory = $true)]
    [ValidateSet("Unlocked", "LockedScreenOn", "LockedScreenOff")]
    [string]$ScreenState,

    [string]$DeviceModel = "HUAWEI Pura 70 Ultra",
    [string]$HarmonyOsVersion = "4.2.0",
    [string]$WeChatVersion = "8.0.76",
    [switch]$ConfirmTargetDeviceMatrix,
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. (Join-Path $ScriptDir "v0_common.ps1")

$resolvedDump = (Resolve-Path -LiteralPath $UiDumpPath).Path
try {
    [xml]$document = Get-Content -Raw -LiteralPath $resolvedDump
} catch {
    throw "Unable to parse UI dump as XML: $resolvedDump. $($_.Exception.Message)"
}

$core = Get-V0CallSnapshotAnalysis `
    -Document $document `
    -ExpectedContactRemark $ExpectedContactRemark `
    -CallType $CallType

$result = [pscustomobject][ordered]@{
    schema_version = 1
    analyzed_at = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
    pass = $core.pass
    screen_state = $ScreenState
    call_type = $CallType
    target = [pscustomobject][ordered]@{
        device_model = $DeviceModel
        harmonyos_version = $HarmonyOsVersion
        wechat_version = $WeChatVersion
        operator_confirmed = [bool]$ConfirmTargetDeviceMatrix
    }
    signals = $core
    source_ui_sha256 = (Get-FileHash -LiteralPath $resolvedDump -Algorithm SHA256).Hash.ToLowerInvariant()
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path (Split-Path -Parent $resolvedDump) "analysis.json"
}
$parent = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}
$result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $OutputPath -Encoding utf8

Write-Host "Snapshot analysis:"
Write-Host "- pass: $($result.pass)"
Write-Host "- screen_state: $ScreenState"
Write-Host "- call_type: $CallType"
Write-Host "- active_root_package: $($core.active_root_package)"
Write-Host "- expected_contact_visible: $($core.expected_contact_visible)"
Write-Host "- call_type_signal_visible: $($core.call_type_signal_visible)"
Write-Host "- clickable_accept_target_found: $($core.clickable_accept_target_found)"
Write-Host "- high_risk_keyword_visible: $($core.high_risk_keyword_visible)"
Write-Host "- result: $OutputPath"

if (-not $result.pass) {
    throw "Incoming-call snapshot is not compatible with the current GrandmaBridge safety contract: $($core.reasons -join ', '). No automation rule should be enabled."
}
