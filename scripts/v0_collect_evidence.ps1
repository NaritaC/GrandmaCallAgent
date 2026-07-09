param(
    [string]$PackageName = "com.grandmacallagent.bridge",
    [string]$OutputRoot = "artifacts/v0-evidence",
    [switch]$IncludeUiDump
)

$ErrorActionPreference = "Stop"

function Require-Adb {
    $adb = Get-Command adb -ErrorAction SilentlyContinue
    if (-not $adb) {
        throw "adb not found. Install Android Studio Platform Tools and add adb to PATH."
    }
    return $adb.Source
}

function Capture-Command {
    param(
        [string]$FileName,
        [scriptblock]$Command
    )

    $path = Join-Path $OutputDir $FileName
    try {
        & $Command 2>&1 | Out-File -FilePath $path -Encoding utf8
        if ($LASTEXITCODE -ne 0) {
            "LASTEXITCODE=$LASTEXITCODE" | Out-File -FilePath $path -Encoding utf8 -Append
        }
    } catch {
        $_ | Out-File -FilePath $path -Encoding utf8
    }
}

$adb = Require-Adb
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$OutputDir = Join-Path $OutputRoot $timestamp
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

Set-Content -Path (Join-Path $OutputDir "README.txt") -Encoding utf8 -Value @"
GrandmaCallAgent V0 evidence bundle

Generated: $(Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz")
Package: $PackageName
adb: $adb

Privacy warning:
- v0-actions-log.txt may contain WeChat display names.
- ui-dump.xml, when requested, may contain visible screen text.
- Do not commit this evidence bundle.
"@

Capture-Command "adb-devices.txt" { adb devices }
Capture-Command "device-info.txt" {
    "manufacturer=$(adb shell getprop ro.product.manufacturer)"
    "model=$(adb shell getprop ro.product.model)"
    "android_release=$(adb shell getprop ro.build.version.release)"
    "android_sdk=$(adb shell getprop ro.build.version.sdk)"
}
Capture-Command "preflight-summary.txt" {
    $packagePath = adb shell pm path $PackageName
    $accessibility = adb shell settings get secure enabled_accessibility_services
    $notifications = adb shell settings get secure enabled_notification_listeners
    $wechatPath = adb shell pm path com.tencent.mm

    "package_name=$PackageName"
    "package_installed=$([bool]$packagePath)"
    "package_path=$packagePath"
    "wechat_installed=$([bool]$wechatPath)"
    "accessibility_enabled=$($accessibility -like ""*$PackageName*"")"
    "notification_listener_enabled=$($notifications -like ""*$PackageName*"")"
}
Capture-Command "battery.txt" { adb shell dumpsys battery }
Capture-Command "package-path.txt" { adb shell pm path $PackageName }
Capture-Command "app-package-summary.txt" {
    adb shell dumpsys package $PackageName | Select-String -Pattern "versionName|versionCode|granted=true|BIND_ACCESSIBILITY_SERVICE|BIND_NOTIFICATION_LISTENER_SERVICE"
}
Capture-Command "wechat-package-summary.txt" {
    adb shell dumpsys package com.tencent.mm | Select-String -Pattern "versionName|versionCode|Package \[com.tencent.mm\]"
}
Capture-Command "accessibility-services.txt" { adb shell settings get secure enabled_accessibility_services }
Capture-Command "notification-listeners.txt" { adb shell settings get secure enabled_notification_listeners }
Capture-Command "v0-actions-log.txt" { adb shell run-as $PackageName cat files/v0_actions.log }

if ($IncludeUiDump) {
    Capture-Command "ui-dump-command.txt" {
        adb shell uiautomator dump /sdcard/grandma_v0_window_dump.xml
        adb pull /sdcard/grandma_v0_window_dump.xml (Join-Path $OutputDir "ui-dump.xml")
        adb shell rm /sdcard/grandma_v0_window_dump.xml
    }
}

Write-Host "V0 evidence bundle written to: $OutputDir"
Write-Host "Review files locally. Do not commit bundles that contain real contact names or screen text."
