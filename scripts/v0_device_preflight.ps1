param(
    [string]$PackageName = "com.grandmacallagent.bridge",
    [string]$Serial = "",
    [switch]$AssertReady
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. (Join-Path $ScriptDir "v0_common.ps1")

$target = Resolve-V0AdbTarget -Serial $Serial
Write-Host "adb: $($target.AdbPath)"
Write-Host "selected device: $($target.Serial)"

Write-Host "`nConnected devices:"
foreach ($device in $target.Devices) {
    Write-Host "- $($device.Serial) [$($device.State)]"
}

Write-Host "`nPackage install path:"
$packagePath = (Invoke-V0Adb -Target $target -Arguments @("shell", "pm", "path", $PackageName)) -join "`n"
$packagePath

Write-Host "`nWeChat package install path:"
$wechatPath = (Invoke-V0Adb -Target $target -Arguments @("shell", "pm", "path", "com.tencent.mm")) -join "`n"
$wechatPath

Write-Host "`nAccessibility services:"
$accessibilityServices = (
    Invoke-V0Adb -Target $target -Arguments @("shell", "settings", "get", "secure", "enabled_accessibility_services")
) -join "`n"
$accessibilityServices

Write-Host "`nNotification listeners:"
$notificationListeners = (
    Invoke-V0Adb -Target $target -Arguments @("shell", "settings", "get", "secure", "enabled_notification_listeners")
) -join "`n"
$notificationListeners

Write-Host "`nBattery:"
Invoke-V0Adb -Target $target -Arguments @("shell", "dumpsys", "battery") |
    Select-String -Pattern "level|status|AC powered|USB powered|Wireless powered"

Write-Host "`nIf package path is empty, install GrandmaBridge first."
Write-Host "If service/listener output does not contain $PackageName, enable permissions in Android Settings."

if ($AssertReady) {
    $failures = @()
    if (-not $packagePath) {
        $failures += "GrandmaBridge package is not installed."
    }
    if (-not $wechatPath) {
        $failures += "WeChat package com.tencent.mm is not installed."
    }
    if ($accessibilityServices -notlike "*$PackageName*") {
        $failures += "GrandmaBridge AccessibilityService is not enabled."
    }
    if ($notificationListeners -notlike "*$PackageName*") {
        $failures += "GrandmaBridge NotificationListenerService is not enabled."
    }

    if ($failures.Count -gt 0) {
        Write-Host ""
        Write-Host "V0 device preflight failed:"
        foreach ($failure in $failures) {
            Write-Host "- $failure"
        }
        throw "V0 device is not ready for scenario validation."
    }

    Write-Host "`nV0 device preflight passed."
}
