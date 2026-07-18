$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. (Join-Path $ScriptDir "v0_common.ps1")

function Assert-Equal {
    param(
        [Parameter(Mandatory = $true)]$Expected,
        [Parameter(Mandatory = $true)]$Actual,
        [Parameter(Mandatory = $true)][string]$Name
    )
    if ($Expected -ne $Actual) {
        throw "$Name failed. Expected '$Expected', got '$Actual'."
    }
    Write-Host "PASS: $Name"
}

function Assert-Throws {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [Parameter(Mandatory = $true)][string]$ExpectedMessage,
        [Parameter(Mandatory = $true)][string]$Name
    )

    try {
        & $Action | Out-Null
    } catch {
        if ($_.Exception.Message -notlike "*$ExpectedMessage*") {
            throw "$Name threw an unexpected error: $($_.Exception.Message)"
        }
        Write-Host "PASS: $Name"
        return
    }
    throw "$Name failed. Expected an exception containing '$ExpectedMessage'."
}

Write-Host "Parsing V0 PowerShell scripts..."
$scriptFiles = Get-ChildItem -LiteralPath $ScriptDir -Filter "v0*.ps1" -File
foreach ($file in $scriptFiles) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName,
        [ref]$tokens,
        [ref]$parseErrors
    )
    if ($parseErrors.Count -gt 0) {
        $messages = ($parseErrors | ForEach-Object { $_.Message }) -join "; "
        throw "PowerShell parse failed for $($file.Name): $messages"
    }
}
Write-Host "PASS: parsed $($scriptFiles.Count) V0 PowerShell scripts"

$singleDeviceLines = @(
    "List of devices attached",
    "phone-001`tdevice product:test model:Test transport_id:1"
)
$singleDevice = @(ConvertFrom-V0AdbDevices -Lines $singleDeviceLines)
Assert-Equal -Expected 1 -Actual $singleDevice.Count -Name "parse one ADB device"
Assert-Equal -Expected "phone-001" -Actual (Select-V0AdbSerial -Devices $singleDevice) -Name "select sole ready device"

$mixedDeviceLines = @(
    "List of devices attached",
    "phone-001`tdevice product:test model:Test transport_id:1",
    "phone-002`tunauthorized usb:1-1 transport_id:2"
)
$mixedDevices = @(ConvertFrom-V0AdbDevices -Lines $mixedDeviceLines)
Assert-Equal -Expected "phone-001" -Actual (Select-V0AdbSerial -Devices $mixedDevices) -Name "ignore unauthorized device when one ready device exists"
Assert-Throws -Action {
    Select-V0AdbSerial -Devices $mixedDevices -Serial "phone-002"
} -ExpectedMessage "not ready" -Name "reject explicitly selected unauthorized device"

$multipleReady = @(
    [pscustomobject]@{ Serial = "phone-001"; State = "device" },
    [pscustomobject]@{ Serial = "emulator-5554"; State = "device" }
)
Assert-Throws -Action {
    Select-V0AdbSerial -Devices $multipleReady
} -ExpectedMessage "Multiple authorized" -Name "require serial when multiple devices are ready"
Assert-Equal -Expected "emulator-5554" -Actual (
    Select-V0AdbSerial -Devices $multipleReady -Serial "emulator-5554"
) -Name "select requested ready device"
Assert-Throws -Action {
    Select-V0AdbSerial -Devices @()
} -ExpectedMessage "No authorized Android device" -Name "reject missing device"

$scenarios = @(
    "AutoAnswerOff",
    "WhitelistVoice",
    "WhitelistVideo",
    "NonWhitelist",
    "HighRiskPage",
    "NonCallAccept",
    "OutboundVoice",
    "OutboundVideo",
    "OutboundWrongPage",
    "OutboundCancel"
)
foreach ($scenario in $scenarios) {
    & (Join-Path $ScriptDir "v0_run_scenario.ps1") -Scenario $scenario -PlanOnly *> $null
}
Write-Host "PASS: planned $($scenarios.Count) V0 validation scenarios without ADB"
Write-Host "V0 script self-test passed."
