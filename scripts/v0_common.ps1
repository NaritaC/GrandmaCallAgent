function ConvertFrom-V0AdbDevices {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$Lines
    )

    $devices = @()
    foreach ($line in $Lines) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            continue
        }
        if ($trimmed -like "List of devices attached*") {
            continue
        }
        if ($trimmed.StartsWith("*")) {
            continue
        }
        if ($trimmed -match '^(\S+)\s+(\S+)') {
            $devices += [pscustomobject]@{
                Serial = $Matches[1]
                State = $Matches[2]
            }
        }
    }

    return $devices
}

function Select-V0AdbSerial {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$Devices,
        [string]$Serial = ""
    )

    $allDevices = @($Devices)
    $summary = ($allDevices | ForEach-Object { "$($_.Serial)=$($_.State)" }) -join ", "
    if ([string]::IsNullOrWhiteSpace($summary)) {
        $summary = "none"
    }

    if (-not [string]::IsNullOrWhiteSpace($Serial)) {
        $selected = @($allDevices | Where-Object { $_.Serial -eq $Serial })
        if ($selected.Count -eq 0) {
            throw "ADB device '$Serial' was not found. Available devices: $summary"
        }
        if ($selected[0].State -ne "device") {
            throw "ADB device '$Serial' is '$($selected[0].State)', not ready. Unlock the phone, authorize USB debugging, and reconnect it."
        }
        return [string]$selected[0].Serial
    }

    $ready = @($allDevices | Where-Object { $_.State -eq "device" })
    if ($ready.Count -eq 1) {
        return [string]$ready[0].Serial
    }
    if ($ready.Count -eq 0) {
        throw "No authorized Android device is ready. Detected devices: $summary. Unlock the phone and authorize USB debugging."
    }

    $readySerials = ($ready | ForEach-Object { $_.Serial }) -join ", "
    throw "Multiple authorized Android devices are connected: $readySerials. Pass -Serial <deviceSerial>."
}

function ConvertFrom-V0JavaMajorVersion {
    param([string]$VersionText)

    if ($VersionText -match '(?i)version\s+"?1\.(\d+)') {
        return [int]$Matches[1]
    }
    if ($VersionText -match '(?i)version\s+"?(\d+)') {
        return [int]$Matches[1]
    }
    if ($VersionText -match '(?im)^(?:openjdk|java)\s+(\d+)') {
        return [int]$Matches[1]
    }
    return $null
}

function Resolve-V0ApkPath {
    param([Parameter(Mandatory = $true)][string]$ApkPath)

    if (-not (Test-Path -LiteralPath $ApkPath -PathType Leaf)) {
        throw "Prebuilt APK was not found: $ApkPath"
    }
    $resolved = (Resolve-Path -LiteralPath $ApkPath).Path
    if ([System.IO.Path]::GetExtension($resolved) -ine ".apk") {
        throw "Prebuilt package must be an .apk file: $resolved"
    }
    return $resolved
}

function Resolve-V0AdbPath {
    param([string[]]$AdditionalCandidates = @())

    foreach ($candidate in $AdditionalCandidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    $command = Get-Command adb -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $adbFileName = if ($env:OS -eq "Windows_NT") { "adb.exe" } else { "adb" }
    $sdkRoots = @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME)
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $sdkRoots += (Join-Path $repoRoot ".tools\android-sdk")
    }
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        $sdkRoots += (Join-Path $env:LOCALAPPDATA "Android\Sdk")
    }

    foreach ($sdkRoot in ($sdkRoots | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)) {
        $platformTools = Join-Path $sdkRoot "platform-tools"
        $candidate = Join-Path $platformTools $adbFileName
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    return $null
}

function Resolve-V0AdbTarget {
    param([string]$Serial = "")

    $adbPath = Resolve-V0AdbPath
    if (-not $adbPath) {
        throw "adb not found. Run scripts/v0_setup_platform_tools.ps1 or install Android Studio Platform-Tools."
    }

    $deviceLines = @(& $adbPath devices 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "adb devices failed with exit code $LASTEXITCODE."
    }
    $textLines = @($deviceLines | ForEach-Object { $_.ToString() })
    $devices = @(ConvertFrom-V0AdbDevices -Lines $textLines)
    $selectedSerial = Select-V0AdbSerial -Devices $devices -Serial $Serial

    return [pscustomobject]@{
        AdbPath = $adbPath
        Serial = $selectedSerial
        Devices = $devices
        DeviceLines = $textLines
    }
}

function Invoke-V0Adb {
    param(
        [Parameter(Mandatory = $true)]
        [object]$Target,
        [string[]]$Arguments = @()
    )

    $output = @(& $Target.AdbPath -s $Target.Serial @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        $command = ($Arguments -join " ")
        throw "adb -s $($Target.Serial) $command failed with exit code $exitCode."
    }
    return $output
}
