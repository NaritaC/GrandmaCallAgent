param(
    [string]$Serial = "",

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^V0TEST[A-Za-z0-9_-]{1,24}$')]
    [string]$ExpectedContactRemark,

    [Parameter(Mandatory = $true)]
    [ValidateSet("Voice", "Video")]
    [string]$CallType,

    [Parameter(Mandatory = $true)]
    [ValidateSet("Unlocked", "LockedScreenOn", "LockedScreenOff")]
    [string]$ScreenState,

    [string]$ExpectedWeChatVersion = "8.0.76",
    [string]$OutputRoot = "artifacts/v0-call-snapshots",
    [switch]$AcceptPrivateDataCapture,
    [switch]$ConfirmAutomationDisabled,
    [switch]$ConfirmTargetDeviceMatrix,
    [switch]$PlanOnly
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. (Join-Path $ScriptDir "v0_common.ps1")

Write-Host "V0 read-only WeChat incoming-call snapshot"
Write-Host "Target: HUAWEI Pura 70 Ultra / HarmonyOS 4.2.0 / WeChat $ExpectedWeChatVersion"
Write-Host "Case: $ScreenState / $CallType"
Write-Host "Safety: this script reads device state, captures a screenshot, and dumps the visible UI hierarchy."
Write-Host "Safety: it does not click, type, answer, reject, or dismiss any phone UI."
Write-Host "Privacy: use a test account and a synthetic unique remark such as V0TEST01."

if ($PlanOnly) {
    Write-Host "PlanOnly mode: no ADB command was run and no private data was captured."
    return
}

if (-not $AcceptPrivateDataCapture) {
    throw "Private-data capture was not accepted. Re-run with -AcceptPrivateDataCapture only on a controlled test call."
}
if (-not $ConfirmAutomationDisabled) {
    throw "Automation-disable confirmation is required. Disable GrandmaBridge and GKD Accessibility services, then re-run with -ConfirmAutomationDisabled."
}
if (-not $ConfirmTargetDeviceMatrix) {
    throw "Target-matrix confirmation is required. Verify HUAWEI Pura 70 Ultra / HarmonyOS 4.2.0 / WeChat 8.0.76, then re-run with -ConfirmTargetDeviceMatrix."
}

$target = Resolve-V0AdbTarget -Serial $Serial
$enabledAccessibility = (
    Invoke-V0Adb -Target $target -Arguments @("shell", "settings", "get", "secure", "enabled_accessibility_services")
) -join "`n"
$unsafeServices = @("com.grandmacallagent.bridge", "li.songe.gkd")
$enabledUnsafeServices = @($unsafeServices | Where-Object { $enabledAccessibility -like "*$_*" })
if ($enabledUnsafeServices.Count -gt 0) {
    throw "Automation Accessibility service is still enabled: $($enabledUnsafeServices -join ', '). Disable it before taking a read-only snapshot."
}

$wechatPackage = (
    Invoke-V0Adb -Target $target -Arguments @("shell", "dumpsys", "package", "com.tencent.mm")
) -join "`n"
$versionMatch = [regex]::Match($wechatPackage, '(?m)^\s*versionName=([^\s]+)')
if (-not $versionMatch.Success) {
    throw "Unable to read the installed WeChat version from com.tencent.mm."
}
$observedWeChatVersion = $versionMatch.Groups[1].Value
if ($observedWeChatVersion -ne $ExpectedWeChatVersion) {
    throw "WeChat version mismatch. Expected $ExpectedWeChatVersion, observed $observedWeChatVersion. Recalibrate before capture."
}

function Get-DeviceProperty {
    param([Parameter(Mandatory = $true)][string]$Name)

    return (((Invoke-V0Adb -Target $target -Arguments @("shell", "getprop", $Name)) -join "").Trim())
}

$observedManufacturer = Get-DeviceProperty -Name "ro.product.manufacturer"
if ($observedManufacturer -notmatch '(?i)huawei') {
    throw "Device manufacturer mismatch. Expected HUAWEI, observed '$observedManufacturer'."
}
$observedDeviceProperties = [ordered]@{
    manufacturer = $observedManufacturer
    model = Get-DeviceProperty -Name "ro.product.model"
    market_name = Get-DeviceProperty -Name "ro.product.marketname"
    marketing_name = Get-DeviceProperty -Name "ro.config.marketing_name"
    android_release = Get-DeviceProperty -Name "ro.build.version.release"
    android_sdk = Get-DeviceProperty -Name "ro.build.version.sdk"
    build_display_id = Get-DeviceProperty -Name "ro.build.display.id"
    harmony_platform_version = Get-DeviceProperty -Name "hw_sc.build.platform.version"
    emui_version = Get-DeviceProperty -Name "ro.build.version.emui"
    wechat_version = $observedWeChatVersion
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$caseName = "$($ScreenState.ToLowerInvariant())-$($CallType.ToLowerInvariant())"
$outputDir = Join-Path $OutputRoot "$timestamp-$caseName"
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

function Capture-Text {
    param(
        [Parameter(Mandatory = $true)][string]$FileName,
        [Parameter(Mandatory = $true)][scriptblock]$Command
    )

    $path = Join-Path $outputDir $FileName
    try {
        & $Command 2>&1 | Out-File -LiteralPath $path -Encoding utf8
    } catch {
        $_ | Out-File -LiteralPath $path -Encoding utf8
        throw
    }
}

Write-Host ""
Write-Host "Prepare the phone for $ScreenState. Do not start the call yet."
Read-Host "Press Enter on this computer after the requested pre-call screen state is ready" | Out-Null

Capture-Text -FileName "screen-state-before.txt" -Command {
    Invoke-V0Adb -Target $target -Arguments @("shell", "dumpsys", "power") |
        Select-String -Pattern "mWakefulness|Display Power"
    Invoke-V0Adb -Target $target -Arguments @("shell", "dumpsys", "window", "policy") |
        Select-String -Pattern "keyguard|lockscreen|showing="
}

Write-Host "Ask the synthetic test contact to start a WeChat $CallType call."
Write-Host "Leave the call ringing. Do not answer or reject it."
Read-Host "Press Enter on this computer only after the incoming-call UI is visible" | Out-Null

$remoteDump = "/sdcard/grandma_v0_call_snapshot.xml"
$remoteScreenshot = "/sdcard/grandma_v0_call_snapshot.png"
$localDump = Join-Path $outputDir "ui-dump.xml"
$screenshotPath = Join-Path $outputDir "screen.png"
try {
    Invoke-V0Adb -Target $target -Arguments @("shell", "uiautomator", "dump", $remoteDump) | Out-File `
        -LiteralPath (Join-Path $outputDir "ui-dump-command.txt") -Encoding utf8
    Invoke-V0Adb -Target $target -Arguments @("pull", $remoteDump, $localDump) | Out-File `
        -LiteralPath (Join-Path $outputDir "ui-dump-pull.txt") -Encoding utf8
    Invoke-V0Adb -Target $target -Arguments @("shell", "screencap", "-p", $remoteScreenshot) | Out-File `
        -LiteralPath (Join-Path $outputDir "screenshot-command.txt") -Encoding utf8
    Invoke-V0Adb -Target $target -Arguments @("pull", $remoteScreenshot, $screenshotPath) | Out-File `
        -LiteralPath (Join-Path $outputDir "screenshot-pull.txt") -Encoding utf8
} finally {
    try {
        Invoke-V0Adb -Target $target -Arguments @("shell", "rm", "-f", $remoteDump, $remoteScreenshot) | Out-Null
    } catch {
        Write-Warning "Unable to remove temporary snapshot files from the phone. Remove $remoteDump and $remoteScreenshot manually."
    }
}
if (-not (Test-Path -LiteralPath $localDump -PathType Leaf) -or (Get-Item -LiteralPath $localDump).Length -eq 0) {
    throw "The UI dump was not captured. Keep automation disabled and inspect the ADB command logs."
}
if (-not (Test-Path -LiteralPath $screenshotPath -PathType Leaf) -or (Get-Item -LiteralPath $screenshotPath).Length -eq 0) {
    throw "The screenshot was not captured. Keep automation disabled and inspect the ADB command logs."
}

Capture-Text -FileName "screen-state-during-call.txt" -Command {
    Invoke-V0Adb -Target $target -Arguments @("shell", "dumpsys", "power") |
        Select-String -Pattern "mWakefulness|Display Power"
    Invoke-V0Adb -Target $target -Arguments @("shell", "dumpsys", "window", "policy") |
        Select-String -Pattern "keyguard|lockscreen|showing="
}
Capture-Text -FileName "window-focus.txt" -Command {
    Invoke-V0Adb -Target $target -Arguments @("shell", "dumpsys", "window", "windows") |
        Select-String -Pattern "mCurrentFocus|mFocusedApp"
}
Capture-Text -FileName "device-info.txt" -Command {
    foreach ($entry in $observedDeviceProperties.GetEnumerator()) {
        "$($entry.Key)=$($entry.Value)"
    }
}

$analysisPath = Join-Path $outputDir "analysis.json"
& (Join-Path $ScriptDir "v0_analyze_call_snapshot.ps1") `
    -UiDumpPath $localDump `
    -ExpectedContactRemark $ExpectedContactRemark `
    -CallType $CallType `
    -ScreenState $ScreenState `
    -DeviceModel "HUAWEI Pura 70 Ultra" `
    -HarmonyOsVersion "4.2.0" `
    -WeChatVersion $observedWeChatVersion `
    -ConfirmTargetDeviceMatrix `
    -OutputPath $analysisPath

Set-Content -LiteralPath (Join-Path $outputDir "README.txt") -Encoding utf8 -Value @"
GrandmaCallAgent V0 read-only call snapshot

Generated: $(Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz")
Device: HUAWEI Pura 70 Ultra
HarmonyOS: 4.2.0
WeChat: $observedWeChatVersion
Screen state: $ScreenState
Call type: $CallType
Target matrix: operator-confirmed; inspect device-info.txt against Settings > About phone.

Privacy warning:
- screen.png and ui-dump.xml may contain the synthetic contact remark and other visible private text.
- Keep this directory local. Do not commit or upload it.
- analysis.json intentionally omits the expected contact value.
"@

Write-Host "Read-only snapshot captured: $outputDir"
Write-Host "End or reject the test call manually. Do not enable automation until all six snapshot cases pass."
