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

function ConvertTo-V0NormalizedUiText {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return ""
    }
    return ($Value -replace '\s', '').ToLowerInvariant()
}

function Get-V0UiNodeValues {
    param([Parameter(Mandatory = $true)][System.Xml.XmlElement]$Node)

    return @(
        $Node.GetAttribute("text"),
        $Node.GetAttribute("content-desc"),
        $Node.GetAttribute("hint")
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
}

function Get-V0CallSnapshotAnalysis {
    param(
        [Parameter(Mandatory = $true)][xml]$Document,
        [Parameter(Mandatory = $true)]
        [ValidateScript({ -not [string]::IsNullOrWhiteSpace($_) })]
        [string]$ExpectedContactRemark,
        [Parameter(Mandatory = $true)][ValidateSet("Voice", "Video")][string]$CallType
    )

    $nodes = @($Document.SelectNodes("//node"))
    if ($nodes.Count -eq 0) {
        throw "UI dump does not contain any <node> elements."
    }

    $rootNode = [System.Xml.XmlElement]$nodes[0]
    $activeRootPackage = $rootNode.GetAttribute("package")
    $wechatPackage = "com.tencent.mm"
    $allValues = @()
    foreach ($node in $nodes) {
        $allValues += @(Get-V0UiNodeValues -Node ([System.Xml.XmlElement]$node))
    }

    $normalizedContact = ConvertTo-V0NormalizedUiText -Value $ExpectedContactRemark
    $contactMarkers = @("邀请你", "正在邀请", "来电", "calling", "invites you")
    $contactPrefixes = @("", "来自", "from")
    $contactVisible = $false
    foreach ($value in $allValues) {
        $normalizedValue = ConvertTo-V0NormalizedUiText -Value $value
        if ($normalizedValue -eq $normalizedContact) {
            $contactVisible = $true
            break
        }
        foreach ($prefix in $contactPrefixes) {
            foreach ($marker in $contactMarkers) {
                $expectedPrefix = (ConvertTo-V0NormalizedUiText -Value $prefix) +
                    $normalizedContact +
                    (ConvertTo-V0NormalizedUiText -Value $marker)
                if ($normalizedValue.StartsWith($expectedPrefix)) {
                    $contactVisible = $true
                    break
                }
            }
            if ($contactVisible) { break }
        }
        if ($contactVisible) { break }
    }

    $callLabels = if ($CallType -eq "Video") {
        @("视频通话", "video call")
    } else {
        @("语音通话", "voice call")
    }
    $joinedValues = $allValues -join " "
    $callTypeVisible = @($callLabels | Where-Object {
        $joinedValues.IndexOf($_, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
    }).Count -gt 0

    $acceptLabels = @("接听", "接受", "接通", "answer", "accept")
    $normalizedAcceptLabels = @($acceptLabels | ForEach-Object { ConvertTo-V0NormalizedUiText -Value $_ })
    $acceptLabelNodes = @($nodes | Where-Object {
        $nodeValues = @(Get-V0UiNodeValues -Node ([System.Xml.XmlElement]$_))
        @($nodeValues | Where-Object {
            (ConvertTo-V0NormalizedUiText -Value $_) -in $normalizedAcceptLabels
        }).Count -gt 0
    })

    $acceptTarget = $null
    foreach ($labelNode in $acceptLabelNodes) {
        $candidate = [System.Xml.XmlNode]$labelNode
        for ($depth = 0; $depth -lt 6 -and $null -ne $candidate; $depth += 1) {
            if ($candidate -is [System.Xml.XmlElement] -and $candidate.Name -eq "node") {
                $element = [System.Xml.XmlElement]$candidate
                $isClickable = $element.GetAttribute("clickable") -eq "true"
                $isEnabled = $element.GetAttribute("enabled") -ne "false"
                if ($isClickable -and $isEnabled) {
                    $acceptTarget = $element
                    break
                }
            }
            $candidate = $candidate.ParentNode
        }
        if ($null -ne $acceptTarget) { break }
    }

    $blockedKeywords = @(
        "支付", "付款", "转账", "收款", "红包", "银行卡", "验证码", "删除", "清空聊天记录", "撤回",
        "payment", "transfer", "delete"
    )
    $blockedKeyword = @($blockedKeywords | Where-Object {
        $joinedValues.IndexOf($_, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
    } | Select-Object -First 1)

    $wechatPackageVisible = @($nodes | Where-Object {
        ([System.Xml.XmlElement]$_).GetAttribute("package") -eq $wechatPackage
    }).Count -gt 0
    $activeRootIsWeChat = $activeRootPackage -eq $wechatPackage
    $acceptTargetIsWeChat = $null -ne $acceptTarget -and $acceptTarget.GetAttribute("package") -eq $wechatPackage

    $reasons = @()
    if (-not $activeRootIsWeChat) { $reasons += "active_root_is_not_wechat" }
    if (-not $wechatPackageVisible) { $reasons += "wechat_nodes_not_visible" }
    if (-not $contactVisible) { $reasons += "expected_contact_not_visible" }
    if (-not $callTypeVisible) { $reasons += "call_type_signal_not_visible" }
    if ($acceptLabelNodes.Count -eq 0) { $reasons += "accept_label_not_visible" }
    if ($null -eq $acceptTarget) { $reasons += "clickable_accept_target_not_found" }
    if ($null -ne $acceptTarget -and -not $acceptTargetIsWeChat) { $reasons += "accept_target_is_not_wechat" }
    if ($blockedKeyword.Count -gt 0) { $reasons += "high_risk_keyword_visible" }

    return [pscustomobject][ordered]@{
        pass = $reasons.Count -eq 0
        active_root_package = $activeRootPackage
        active_root_is_wechat = $activeRootIsWeChat
        wechat_package_visible = $wechatPackageVisible
        expected_contact_visible = $contactVisible
        call_type_signal_visible = $callTypeVisible
        accept_label_visible = $acceptLabelNodes.Count -gt 0
        clickable_accept_target_found = $null -ne $acceptTarget
        accept_target_is_wechat = $acceptTargetIsWeChat
        accept_target_resource_id = if ($null -ne $acceptTarget) { $acceptTarget.GetAttribute("resource-id") } else { "" }
        accept_target_class = if ($null -ne $acceptTarget) { $acceptTarget.GetAttribute("class") } else { "" }
        high_risk_keyword_visible = $blockedKeyword.Count -gt 0
        visible_node_count = $nodes.Count
        reasons = @($reasons)
    }
}

function Get-V0SnapshotGateSummary {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Analyses,
        [string]$ExpectedDeviceModel = "HUAWEI Pura 70 Ultra",
        [string]$ExpectedHarmonyOsVersion = "4.2.0",
        [string]$ExpectedWeChatVersion = "8.0.76"
    )

    $requiredStates = @("Unlocked", "LockedScreenOn", "LockedScreenOff")
    $requiredCallTypes = @("Voice", "Video")
    $missing = @()
    $valid = @()

    foreach ($screenState in $requiredStates) {
        foreach ($callType in $requiredCallTypes) {
            $matches = @($Analyses | Where-Object {
                $_.pass -eq $true -and
                $_.screen_state -eq $screenState -and
                $_.call_type -eq $callType -and
                $_.target.device_model -eq $ExpectedDeviceModel -and
                $_.target.harmonyos_version -eq $ExpectedHarmonyOsVersion -and
                $_.target.wechat_version -eq $ExpectedWeChatVersion -and
                $_.target.operator_confirmed -eq $true
            })
            $key = "$screenState/$callType"
            if ($matches.Count -gt 0) {
                $valid += $key
            } else {
                $missing += $key
            }
        }
    }

    return [pscustomobject][ordered]@{
        schema_version = 1
        complete = $missing.Count -eq 0
        target = [pscustomobject][ordered]@{
            device_model = $ExpectedDeviceModel
            harmonyos_version = $ExpectedHarmonyOsVersion
            wechat_version = $ExpectedWeChatVersion
            operator_confirmed = $true
        }
        required_count = $requiredStates.Count * $requiredCallTypes.Count
        valid_count = $valid.Count
        valid = @($valid)
        missing = @($missing)
    }
}

function Get-V0SnapshotGateValidation {
    param(
        [Parameter(Mandatory = $true)][object]$Gate,
        [string]$ExpectedDeviceModel = "HUAWEI Pura 70 Ultra",
        [string]$ExpectedHarmonyOsVersion = "4.2.0",
        [string]$ExpectedWeChatVersion = "8.0.76"
    )

    $requiredCases = @(
        "Unlocked/Voice",
        "Unlocked/Video",
        "LockedScreenOn/Voice",
        "LockedScreenOn/Video",
        "LockedScreenOff/Voice",
        "LockedScreenOff/Video"
    )
    $reasons = @()
    $validCases = @($Gate.valid | ForEach-Object { $_.ToString() } | Select-Object -Unique)

    if ($Gate.schema_version -ne 1) { $reasons += "unsupported_schema_version" }
    if ($Gate.complete -ne $true) { $reasons += "gate_not_complete" }
    if ($Gate.target.device_model -ne $ExpectedDeviceModel) { $reasons += "device_model_mismatch" }
    if ($Gate.target.harmonyos_version -ne $ExpectedHarmonyOsVersion) { $reasons += "harmonyos_version_mismatch" }
    if ($Gate.target.wechat_version -ne $ExpectedWeChatVersion) { $reasons += "wechat_version_mismatch" }
    if ($Gate.target.operator_confirmed -ne $true) { $reasons += "target_matrix_not_operator_confirmed" }
    if ($Gate.snapshots_reviewed -ne $true) { $reasons += "snapshots_not_reviewed" }
    if ($Gate.required_count -ne $requiredCases.Count) { $reasons += "required_count_mismatch" }
    if ($Gate.valid_count -ne $requiredCases.Count) { $reasons += "valid_count_mismatch" }
    if ($validCases.Count -ne $requiredCases.Count) { $reasons += "valid_case_count_mismatch" }
    foreach ($requiredCase in $requiredCases) {
        if ($requiredCase -notin $validCases) {
            $reasons += "missing_case:$requiredCase"
        }
    }
    if (@($Gate.missing).Count -gt 0) { $reasons += "gate_reports_missing_cases" }

    return [pscustomobject][ordered]@{
        pass = $reasons.Count -eq 0
        reasons = @($reasons)
        required_cases = $requiredCases
    }
}
