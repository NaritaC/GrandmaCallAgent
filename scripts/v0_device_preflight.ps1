param(
    [string]$PackageName = "com.grandmacallagent.bridge"
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
& adb shell pm path $PackageName

Write-Host "`nAccessibility services:"
& adb shell settings get secure enabled_accessibility_services

Write-Host "`nNotification listeners:"
& adb shell settings get secure enabled_notification_listeners

Write-Host "`nBattery:"
& adb shell dumpsys battery | Select-String -Pattern "level|status|AC powered|USB powered|Wireless powered"

Write-Host "`nIf package path is empty, install GrandmaBridge first."
Write-Host "If service/listener output does not contain $PackageName, enable permissions in Android Settings."
