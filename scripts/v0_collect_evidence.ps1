param(
    [string]$PackageName = "com.grandmacallagent.bridge",
    [string]$Serial = "",
    [string]$OutputRoot = "artifacts/v0-evidence",
    [switch]$IncludeUiDump
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. (Join-Path $ScriptDir "v0_common.ps1")

function Capture-Command {
    param(
        [string]$FileName,
        [scriptblock]$Command
    )

    $path = Join-Path $OutputDir $FileName
    try {
        & $Command 2>&1 | Out-File -FilePath $path -Encoding utf8
    } catch {
        $_ | Out-File -FilePath $path -Encoding utf8
    }
}

$target = Resolve-V0AdbTarget -Serial $Serial
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$OutputDir = Join-Path $OutputRoot $timestamp
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

Set-Content -Path (Join-Path $OutputDir "README.txt") -Encoding utf8 -Value @"
GrandmaCallAgent V0 evidence bundle

Generated: $(Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz")
Package: $PackageName
adb: $($target.AdbPath)
device_serial: $($target.Serial)

Privacy warning:
- v0-actions-log.txt may contain WeChat display names.
- ui-dump.xml, when requested, may contain visible screen text.
- Do not commit this evidence bundle.
"@

Capture-Command "adb-devices.txt" { $target.DeviceLines }
Capture-Command "device-info.txt" {
    $manufacturer = (Invoke-V0Adb -Target $target -Arguments @("shell", "getprop", "ro.product.manufacturer")) -join ""
    $model = (Invoke-V0Adb -Target $target -Arguments @("shell", "getprop", "ro.product.model")) -join ""
    $androidRelease = (Invoke-V0Adb -Target $target -Arguments @("shell", "getprop", "ro.build.version.release")) -join ""
    $androidSdk = (Invoke-V0Adb -Target $target -Arguments @("shell", "getprop", "ro.build.version.sdk")) -join ""

    "manufacturer=$manufacturer"
    "model=$model"
    "android_release=$androidRelease"
    "android_sdk=$androidSdk"
}
Capture-Command "preflight-summary.txt" {
    $packagePath = (Invoke-V0Adb -Target $target -Arguments @("shell", "pm", "path", $PackageName)) -join "`n"
    $accessibility = (
        Invoke-V0Adb -Target $target -Arguments @("shell", "settings", "get", "secure", "enabled_accessibility_services")
    ) -join "`n"
    $notifications = (
        Invoke-V0Adb -Target $target -Arguments @("shell", "settings", "get", "secure", "enabled_notification_listeners")
    ) -join "`n"
    $wechatPath = (Invoke-V0Adb -Target $target -Arguments @("shell", "pm", "path", "com.tencent.mm")) -join "`n"
    $accessibilityEnabled = $accessibility -like "*$PackageName*"
    $notificationListenerEnabled = $notifications -like "*$PackageName*"

    "package_name=$PackageName"
    "device_serial=$($target.Serial)"
    "package_installed=$([bool]$packagePath)"
    "package_path=$packagePath"
    "wechat_installed=$([bool]$wechatPath)"
    "accessibility_enabled=$accessibilityEnabled"
    "notification_listener_enabled=$notificationListenerEnabled"
}
Capture-Command "battery.txt" {
    Invoke-V0Adb -Target $target -Arguments @("shell", "dumpsys", "battery")
}
Capture-Command "package-path.txt" {
    Invoke-V0Adb -Target $target -Arguments @("shell", "pm", "path", $PackageName)
}
Capture-Command "app-package-summary.txt" {
    Invoke-V0Adb -Target $target -Arguments @("shell", "dumpsys", "package", $PackageName) |
        Select-String -Pattern "versionName|versionCode|granted=true|BIND_ACCESSIBILITY_SERVICE|BIND_NOTIFICATION_LISTENER_SERVICE"
}
Capture-Command "wechat-package-summary.txt" {
    Invoke-V0Adb -Target $target -Arguments @("shell", "dumpsys", "package", "com.tencent.mm") |
        Select-String -Pattern "versionName|versionCode|Package \[com.tencent.mm\]"
}
Capture-Command "accessibility-services.txt" {
    Invoke-V0Adb -Target $target -Arguments @("shell", "settings", "get", "secure", "enabled_accessibility_services")
}
Capture-Command "notification-listeners.txt" {
    Invoke-V0Adb -Target $target -Arguments @("shell", "settings", "get", "secure", "enabled_notification_listeners")
}
Capture-Command "v0-actions-log.txt" {
    Invoke-V0Adb -Target $target -Arguments @("shell", "run-as", $PackageName, "cat", "files/v0_actions.log")
}

if ($IncludeUiDump) {
    Capture-Command "ui-dump-command.txt" {
        Invoke-V0Adb -Target $target -Arguments @(
            "shell",
            "uiautomator",
            "dump",
            "/sdcard/grandma_v0_window_dump.xml"
        )
        try {
            Invoke-V0Adb -Target $target -Arguments @(
                "pull",
                "/sdcard/grandma_v0_window_dump.xml",
                (Join-Path $OutputDir "ui-dump.xml")
            )
        } finally {
            Invoke-V0Adb -Target $target -Arguments @(
                "shell",
                "rm",
                "/sdcard/grandma_v0_window_dump.xml"
            )
        }
    }
}

Write-Host "V0 evidence bundle written to: $OutputDir"
Write-Host "Review files locally. Do not commit bundles that contain real contact names or screen text."
