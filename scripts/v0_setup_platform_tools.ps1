param(
    [switch]$AcceptAndroidSdkLicense
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $ScriptDir "..")).Path

$platformToolsVersion = "37.0.0"
$archiveName = "platform-tools_r$platformToolsVersion-win.zip"
$downloadUrl = "https://dl.google.com/android/repository/$archiveName"
$expectedSha1 = "f29bfb58d0d6f9a57d7dbcba6cc259f9ca6f58f1"
$installRoot = Join-Path $RepoRoot ".tools\android-sdk"
$adbPath = Join-Path $installRoot "platform-tools\adb.exe"

if ($env:OS -ne "Windows_NT") {
    throw "This setup helper currently supports Windows only. Install Android SDK Platform-Tools for your OS manually."
}

if (Test-Path -LiteralPath $adbPath -PathType Leaf) {
    Write-Host "Platform-Tools is already installed: $adbPath"
    & $adbPath version
    if ($LASTEXITCODE -ne 0) {
        throw "Existing adb failed with exit code $LASTEXITCODE."
    }
    return
}

if (-not $AcceptAndroidSdkLicense) {
    Write-Host "Review the Android SDK License before installing:"
    Write-Host "https://developer.android.com/studio/terms"
    throw "License acceptance is required. Rerun with -AcceptAndroidSdkLicense after reviewing and accepting the terms."
}

if (Test-Path -LiteralPath $installRoot) {
    throw "Incomplete Platform-Tools directory already exists: $installRoot. Inspect it manually before retrying."
}

$archivePath = Join-Path $env:TEMP $archiveName
Write-Host "Downloading Google Platform-Tools $platformToolsVersion..."
Invoke-WebRequest -Uri $downloadUrl -OutFile $archivePath

$actualSha1 = (Get-FileHash -Algorithm SHA1 -LiteralPath $archivePath).Hash.ToLowerInvariant()
if ($actualSha1 -ne $expectedSha1) {
    throw "Platform-Tools checksum mismatch. Expected $expectedSha1, got $actualSha1."
}
Write-Host "Checksum verified: $actualSha1"

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $installRoot) | Out-Null
Expand-Archive -LiteralPath $archivePath -DestinationPath $installRoot
if (-not (Test-Path -LiteralPath $adbPath -PathType Leaf)) {
    throw "adb.exe was not found after extraction: $adbPath"
}

Write-Host "Platform-Tools installed: $adbPath"
& $adbPath version
if ($LASTEXITCODE -ne 0) {
    throw "Installed adb failed with exit code $LASTEXITCODE."
}
Write-Host "The V0 scripts will discover this repository-local ADB automatically."
