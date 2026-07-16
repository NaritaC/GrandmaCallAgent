param(
    [string]$PackageName = "com.grandmacallagent.bridge",
    [switch]$AssertReady
)

$ErrorActionPreference = "Stop"

function Require-Adb {
    $adb = Get-Command adb -ErrorAction SilentlyContinue
    if (-not $adb) {
        throw "adb not found. Install Android Studio Platform Tools and add adb to PATH."
    }
    return $adb.Source
}

$adb = Require-Adb
Write-Host "adb: $adb"

Write-Host "`nConnected devices:"
& adb devices

Write-Host "`nPackage install path:"
$packagePath = adb shell pm path $PackageName
$packagePath

Write-Host "`nWeChat package install path:"
$wechatPath = adb shell pm path com.tencent.mm
$wechatPath

Write-Host "`nAccessibility services:"
$accessibilityServices = adb shell settings get secure enabled_accessibility_services
$accessibilityServices

Write-Host "`nNotification listeners:"
$notificationListeners = adb shell settings get secure enabled_notification_listeners
$notificationListeners

Write-Host "`nBattery:"
& adb shell dumpsys battery | Select-String -Pattern "level|status|AC powered|USB powered|Wireless powered"

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
