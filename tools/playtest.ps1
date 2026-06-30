[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateSet('doctor', 'test', 'build', 'audit', 'release')]
    [string]$Command,

    [string[]]$Targets = @('windows', 'web'),
    [string[]]$Profiles = @('participant', 'qa'),
    [string]$GodotPath = '',
    [string]$OutputRoot = '',
    [switch]$ContractOnly,
    [switch]$IncludeAudit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$ProjectScriptPath = 'res://Scripts/Tests/CiTestBootstrap.gd'
$ArtifactVerifierScriptPath = 'res://Scripts/Tools/VerifyExportArtifacts.gd'
$VisualAuditScriptPath = 'res://Scripts/Tools/RunVisualAuditBundle.gd'
$DefaultWindowsExecutableName = 'InABottle.exe'
$DefaultWebEntryName = 'index.html'
$PlatformIsWindows = [System.Environment]::OSVersion.Platform -eq 'Win32NT'

function Write-PlaytestLog {
    param([string]$Message)
    Write-Host "[playtest] $Message"
}

function ConvertTo-NormalizedList {
    param(
        [string[]]$Values,
        [string[]]$Fallback
    )

    $normalized = @()
    foreach ($value in ($Values | Where-Object { $_ -ne $null })) {
        foreach ($segment in ($value -split ',')) {
            $trimmed = $segment.Trim().ToLowerInvariant()
            if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
                $normalized += $trimmed
            }
        }
    }
    if ($normalized.Count -eq 0) {
        return $Fallback
    }
    return @($normalized | Select-Object -Unique)
}

function Resolve-AbsolutePath {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return ''
    }
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return [System.IO.Path]::GetFullPath($PathValue)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $PathValue))
}

function Get-RelativePathCore {
    param(
        [string]$BasePath,
        [string]$TargetPath
    )

    $baseSeparator = [System.IO.Path]::DirectorySeparatorChar
    $normalizedBase = $BasePath.TrimEnd('\', '/') + $baseSeparator
    $baseUri = New-Object System.Uri($normalizedBase)
    $targetUri = New-Object System.Uri($TargetPath)
    $relativeUri = $baseUri.MakeRelativeUri($targetUri)
    return [System.Uri]::UnescapeDataString($relativeUri.ToString()).Replace('\', '/')
}

function Get-RepoRelativePath {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return ''
    }
    $absolute = Resolve-AbsolutePath $PathValue
    return Get-RelativePathCore -BasePath $RepoRoot -TargetPath $absolute
}

function Remove-DirectoryIfPresent {
    param([string]$PathValue)

    if (Test-Path -LiteralPath $PathValue) {
        Remove-Item -LiteralPath $PathValue -Recurse -Force
    }
}

function Ensure-Directory {
    param([string]$PathValue)

    New-Item -ItemType Directory -Force -Path $PathValue | Out-Null
}

function Copy-DirectoryContents {
    param(
        [string]$Source,
        [string]$Destination
    )

    Ensure-Directory $Destination
    Get-ChildItem -LiteralPath $Source -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $Destination -Recurse -Force
    }
}

function Write-Utf8File {
    param(
        [string]$PathValue,
        [string]$Content
    )

    $parent = Split-Path -Parent $PathValue
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        Ensure-Directory $parent
    }
    Set-Content -LiteralPath $PathValue -Value $Content -Encoding utf8
}

function Write-JsonFile {
    param(
        [string]$PathValue,
        $Payload
    )

    Write-Utf8File -PathValue $PathValue -Content ($Payload | ConvertTo-Json -Depth 12)
}

function Resolve-GodotExecutable {
    param([string]$PreferredPath)

    if (-not [string]::IsNullOrWhiteSpace($PreferredPath)) {
        $resolvedPreferred = Resolve-AbsolutePath $PreferredPath
        if (-not (Test-Path -LiteralPath $resolvedPreferred)) {
            throw "Godot executable was not found at '$resolvedPreferred'."
        }
        return $resolvedPreferred
    }
    if (-not [string]::IsNullOrWhiteSpace($env:GODOT_BIN)) {
        $resolvedEnv = Resolve-AbsolutePath $env:GODOT_BIN
        if (Test-Path -LiteralPath $resolvedEnv) {
            return $resolvedEnv
        }
    }
    $godotCommand = Get-Command godot.exe -ErrorAction SilentlyContinue
    if ($godotCommand) {
        return $godotCommand.Source
    }
    $fallbackNames = @(
        'Godot_v4.6.1-stable_win64_console.exe',
        'Godot_v4.6.1-stable_win64.exe',
        'Godot_v4.6-stable_mono_win64_console.exe',
        'Godot_v4.6-stable_mono_win64.exe'
    )
    foreach ($candidate in $fallbackNames) {
        $match = Get-ChildItem -Path 'X:\Apps\Godot' -Recurse -Filter $candidate -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($match) {
            return $match.FullName
        }
    }
    throw 'Unable to locate a Godot executable. Pass -GodotPath or set GODOT_BIN.'
}

function ConvertTo-ProcessArgumentString {
    param([string[]]$Arguments)

    if ($null -eq $Arguments -or $Arguments.Count -eq 0) {
        return ''
    }

    $quotedArguments = @()
    foreach ($argument in $Arguments) {
        if ($null -eq $argument -or $argument.Length -eq 0) {
            $quotedArguments += '""'
            continue
        }
        if ($argument -notmatch '[\s"]') {
            $quotedArguments += $argument
            continue
        }

        $builder = New-Object System.Text.StringBuilder
        [void]$builder.Append('"')
        $backslashCount = 0
        foreach ($character in $argument.ToCharArray()) {
            if ($character -eq '\') {
                $backslashCount += 1
                continue
            }
            if ($character -eq '"') {
                [void]$builder.Append('\', ($backslashCount * 2) + 1)
                [void]$builder.Append('"')
                $backslashCount = 0
                continue
            }
            if ($backslashCount -gt 0) {
                [void]$builder.Append('\', $backslashCount)
                $backslashCount = 0
            }
            [void]$builder.Append($character)
        }
        if ($backslashCount -gt 0) {
            [void]$builder.Append('\', $backslashCount * 2)
        }
        [void]$builder.Append('"')
        $quotedArguments += $builder.ToString()
    }
    return [string]::Join(' ', $quotedArguments)
}

function Get-LastNativeExitCodeOrSuccess {
    $lastExitCodeVariable = Get-Variable -Name 'LASTEXITCODE' -ErrorAction SilentlyContinue
    if (-not $lastExitCodeVariable -or $null -eq $lastExitCodeVariable.Value) {
        return 0
    }
    return [int]$lastExitCodeVariable.Value
}

function Invoke-ExternalCommand {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [switch]$CaptureOutput,
        [switch]$AllowFailure
    )

    if (-not $CaptureOutput) {
        $previousErrorActionPreference = $ErrorActionPreference
        $nativeErrorPreferenceAvailable = $false
        $nativeErrorPreferenceOriginal = $null
        try {
            if (Get-Variable -Name 'PSNativeCommandUseErrorActionPreference' -ErrorAction SilentlyContinue) {
                $nativeErrorPreferenceAvailable = $true
                $nativeErrorPreferenceOriginal = Get-Variable -Name 'PSNativeCommandUseErrorActionPreference' -ValueOnly
                Set-Variable -Name 'PSNativeCommandUseErrorActionPreference' -Value $false
            }
            $ErrorActionPreference = 'SilentlyContinue'

            Push-Location $RepoRoot
            try {
                Set-Variable -Name 'LASTEXITCODE' -Value 0 -Scope Global
                & $FilePath @Arguments
                $exitCode = Get-LastNativeExitCodeOrSuccess
            } finally {
                Pop-Location
            }

            if (-not $AllowFailure -and $exitCode -ne 0) {
                throw "Command failed ($exitCode): $FilePath $($Arguments -join ' ')"
            }
            return @{
                ExitCode = $exitCode
                Output   = @()
            }
        } finally {
            $ErrorActionPreference = $previousErrorActionPreference
            if ($nativeErrorPreferenceAvailable) {
                Set-Variable -Name 'PSNativeCommandUseErrorActionPreference' -Value $nativeErrorPreferenceOriginal
            }
        }
    }

    $combinedOutputPath = [System.IO.Path]::GetTempFileName()
    $previousErrorActionPreference = $ErrorActionPreference
    $nativeErrorPreferenceAvailable = $false
    $nativeErrorPreferenceOriginal = $null

    try {
        if (Get-Variable -Name 'PSNativeCommandUseErrorActionPreference' -ErrorAction SilentlyContinue) {
            $nativeErrorPreferenceAvailable = $true
            $nativeErrorPreferenceOriginal = Get-Variable -Name 'PSNativeCommandUseErrorActionPreference' -ValueOnly
            Set-Variable -Name 'PSNativeCommandUseErrorActionPreference' -Value $false
        }
        $ErrorActionPreference = 'SilentlyContinue'

        Push-Location $RepoRoot
        try {
            Set-Variable -Name 'LASTEXITCODE' -Value 0 -Scope Global
            & $FilePath @Arguments *> $combinedOutputPath
            $exitCode = Get-LastNativeExitCodeOrSuccess
        } finally {
            Pop-Location
        }

        $lines = @()
        if (Test-Path $combinedOutputPath) {
            $lines = @(Get-Content -LiteralPath $combinedOutputPath -ErrorAction SilentlyContinue)
            $lines = @($lines | Where-Object { $_ -ne $null -and $_ -ne '' })
        }

        if (-not $AllowFailure -and $exitCode -ne 0) {
            throw "Command failed ($exitCode): $FilePath $($Arguments -join ' ')`n$($lines -join [Environment]::NewLine)"
        }
        if (-not $CaptureOutput) {
            foreach ($line in $lines) {
                Write-Host $line
            }
        }
        return @{
            ExitCode = $exitCode
            Output   = $lines
        }
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
        if ($nativeErrorPreferenceAvailable) {
            Set-Variable -Name 'PSNativeCommandUseErrorActionPreference' -Value $nativeErrorPreferenceOriginal
        }
        if (Test-Path $combinedOutputPath) {
            Remove-Item -LiteralPath $combinedOutputPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Join-CommandArgumentsForDisplay {
    param(
        [string]$FilePath,
        [string[]]$Arguments
    )

    $parts = @($FilePath)
    if ($Arguments) {
        $parts += $Arguments
    }
    return ($parts -join ' ').Trim()
}

function Invoke-LoggedExternalCommand {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    Write-PlaytestLog ("Running: " + (Join-CommandArgumentsForDisplay -FilePath $FilePath -Arguments $Arguments))
    $result = Invoke-ExternalCommand -FilePath $FilePath -Arguments $Arguments -AllowFailure:$AllowFailure
    if ($result.Output.Count -gt 0) {
        foreach ($line in $result.Output) {
            Write-Host $line
        }
    }
    return $result
}

function Get-GodotMetadata {
    param([string]$ExecutablePath)

    $versionResult = Invoke-ExternalCommand -FilePath $ExecutablePath -Arguments @('--version') -CaptureOutput
    $version = if ($versionResult.Output.Count -gt 0) { $versionResult.Output[-1].Trim() } else { 'unknown' }
    $templateDir = $version
    if ($version -match '^(?<template>.+?)\.official(?:\..+)?$') {
        $templateDir = $Matches['template']
    }
    $isMono = $ExecutablePath.ToLowerInvariant().Contains('mono') -or $version.ToLowerInvariant().Contains('.mono.')
    return @{
        Path        = $ExecutablePath
        Version     = $version
        TemplateDir = $templateDir
        IsMono      = $isMono
    }
}

function Get-ExportTemplatesPath {
    param([hashtable]$GodotMetadata)

    if ($PlatformIsWindows) {
        return Join-Path $env:APPDATA ('Godot\export_templates\' + $GodotMetadata.TemplateDir)
    }
    return Join-Path $HOME ('.local/share/godot/export_templates/' + $GodotMetadata.TemplateDir)
}

function Test-WebExportBlockedLocally {
    param([hashtable]$GodotMetadata)

    return [bool]$GodotMetadata.IsMono
}

function Get-GitMetadata {
    $branch = (& git -C $RepoRoot rev-parse --abbrev-ref HEAD).Trim()
    $commit = (& git -C $RepoRoot rev-parse HEAD).Trim()
    $statusLines = @((& git -C $RepoRoot status --short) | ForEach-Object { $_.ToString() })
    return @{
        Branch         = $branch
        Commit         = $commit
        Dirty          = ($statusLines.Count -gt 0)
        DirtyShortStat = $statusLines
    }
}

function New-DoctorReport {
    param(
        [hashtable]$GodotMetadata,
        [string]$ResolvedOutputRoot
    )

    $templatesPath = Get-ExportTemplatesPath $GodotMetadata
    $templatesReady = Test-Path -LiteralPath $templatesPath
    $gitMetadata = Get-GitMetadata
    return @{
        godot = @{
            path          = $GodotMetadata.Path
            version       = $GodotMetadata.Version
            is_mono       = $GodotMetadata.IsMono
            template_path = $templatesPath
        }
        local_web_export = @{
            blocked = (Test-WebExportBlockedLocally $GodotMetadata)
            reason  = if (Test-WebExportBlockedLocally $GodotMetadata) { 'Web exports must use a non-Mono Godot build.' } else { '' }
        }
        export_templates_ready = $templatesReady
        output_root            = $ResolvedOutputRoot
        git                    = @{
            branch = $gitMetadata.Branch
            commit = $gitMetadata.Commit
            dirty  = $gitMetadata.Dirty
            dirty_paths = $gitMetadata.DirtyShortStat
        }
    }
}

function Show-DoctorReport {
    param([hashtable]$Report)

    Write-PlaytestLog "Godot path: $($Report.godot.path)"
    Write-PlaytestLog "Godot version: $($Report.godot.version)"
    Write-PlaytestLog "Mono build: $($Report.godot.is_mono)"
    Write-PlaytestLog "Local web export blocked: $($Report.local_web_export.blocked)"
    if (-not [string]::IsNullOrWhiteSpace($Report.local_web_export.reason)) {
        Write-PlaytestLog "Web export note: $($Report.local_web_export.reason)"
    }
    Write-PlaytestLog "Export templates ready: $($Report.export_templates_ready)"
    Write-PlaytestLog "Output root: $($Report.output_root)"
    Write-PlaytestLog "Git branch: $($Report.git.branch)"
    Write-PlaytestLog "Git commit: $($Report.git.commit)"
    Write-PlaytestLog "Dirty worktree: $($Report.git.dirty)"
    if ($Report.git.dirty) {
        Write-PlaytestLog 'Dirty worktree warning: local changes are present and were not treated as a build blocker.'
    }
}

function Assert-ExportTemplatesReady {
    param([hashtable]$DoctorReport)

    if (-not [bool]$DoctorReport.export_templates_ready) {
        throw "Export templates were not found at '$($DoctorReport.godot.template_path)'."
    }
}

function Get-PlaytestOutputRoot {
    param([string]$RequestedRoot)

    if (-not [string]::IsNullOrWhiteSpace($RequestedRoot)) {
        return Resolve-AbsolutePath $RequestedRoot
    }
    $stamp = [DateTimeOffset]::Now.ToString('yyyyMMdd-HHmmss')
    return Resolve-AbsolutePath (Join-Path 'build/playtest' $stamp)
}

function Get-GodotValidationAppDataRoot {
    return Resolve-AbsolutePath '.godot_appdata/playtest'
}

function Invoke-WithGodotValidationAppData {
    param([scriptblock]$ScriptBlock)

    $appDataRoot = Get-GodotValidationAppDataRoot
    Ensure-Directory $appDataRoot
    $previousAppData = [System.Environment]::GetEnvironmentVariable('APPDATA', 'Process')
    Write-PlaytestLog "Using isolated Godot app data: $(Get-RepoRelativePath $appDataRoot)."
    try {
        [System.Environment]::SetEnvironmentVariable('APPDATA', $appDataRoot, 'Process')
        return & $ScriptBlock
    } finally {
        [System.Environment]::SetEnvironmentVariable('APPDATA', $previousAppData, 'Process')
    }
}

function New-GodotLogArguments {
    param([string]$Label)

    $safeLabel = if ([string]::IsNullOrWhiteSpace($Label)) { 'godot' } else { $Label -replace '[^A-Za-z0-9_-]', '-' }
    $logRoot = Join-Path $RepoRoot 'build/playtest/_logs'
    Ensure-Directory $logRoot
    $stamp = [DateTimeOffset]::Now.ToString('yyyyMMdd-HHmmss-ffff')
    $logPath = Join-Path $logRoot ("$safeLabel-$stamp-$PID.log")
    return @('--log-file', $logPath)
}

function New-GodotArguments {
    param(
        [string]$Label,
        [string[]]$Arguments
    )

    $withLog = @()
    $withLog += New-GodotLogArguments -Label $Label
    $withLog += $Arguments
    return $withLog
}

function Invoke-GodotProjectBootstrap {
    param([string]$ExecutablePath)
    Write-PlaytestLog 'Importing project metadata.'
    Invoke-ExternalCommand -FilePath $ExecutablePath -Arguments (New-GodotArguments -Label 'bootstrap' -Arguments @('--headless', '--path', $RepoRoot, '--import')) | Out-Null
}

function Invoke-GodotCheckOnly {
    param([string]$ExecutablePath)
    Write-PlaytestLog 'Running --check-only validation.'
    Invoke-ExternalCommand -FilePath $ExecutablePath -Arguments (New-GodotArguments -Label 'check-only' -Arguments @('--headless', '--path', $RepoRoot, '--check-only', '--quit-after', '1')) | Out-Null
}

function Invoke-GodotCiTests {
    param([string]$ExecutablePath)
    Write-PlaytestLog 'Running CiTestBootstrap.'
    Invoke-ExternalCommand -FilePath $ExecutablePath -Arguments (New-GodotArguments -Label 'ci-tests' -Arguments @('--headless', '--path', $RepoRoot, '--script', $ProjectScriptPath)) | Out-Null
}

function Invoke-RepoValidation {
    param([string]$ExecutablePath)
    Invoke-WithGodotValidationAppData -ScriptBlock {
        Invoke-GodotProjectBootstrap -ExecutablePath $ExecutablePath
        Invoke-GodotCheckOnly -ExecutablePath $ExecutablePath
        Invoke-GodotCiTests -ExecutablePath $ExecutablePath
    }
}

function Invoke-ExportArtifactVerification {
    param(
        [string]$ExecutablePath,
        [string]$PresetName,
        [string]$TargetPath
    )

    Write-PlaytestLog "Verifying artifacts for $PresetName at $(Get-RepoRelativePath $TargetPath)."
    Invoke-ExternalCommand -FilePath $ExecutablePath -Arguments (New-GodotArguments -Label 'artifact-verify' -Arguments @('--headless', '--path', $RepoRoot, '--script', $ArtifactVerifierScriptPath, '--', $PresetName, $TargetPath)) | Out-Null
}

function Export-GodotRelease {
    param(
        [string]$ExecutablePath,
        [string]$PresetName,
        [string]$TargetPath
    )

    Ensure-Directory (Split-Path -Parent $TargetPath)
    Write-PlaytestLog "Exporting $PresetName to $(Get-RepoRelativePath $TargetPath)."
    Invoke-ExternalCommand -FilePath $ExecutablePath -Arguments (New-GodotArguments -Label 'export-release' -Arguments @('--headless', '--path', $RepoRoot, '--export-release', $PresetName, $TargetPath)) | Out-Null
    Invoke-ExportArtifactVerification -ExecutablePath $ExecutablePath -PresetName $PresetName -TargetPath $TargetPath
}

function Assert-FileExists {
    param([string]$PathValue)

    if (-not (Test-Path -LiteralPath $PathValue)) {
        throw "Expected artifact was missing: $PathValue"
    }
}

function New-ProfileInjection {
    param([string]$Profile)

@"
<script>
(function () {
  const desiredProfile = '$Profile';
  window.__IN_A_BOTTLE_BUILD_PROFILE = desiredProfile;
})();
</script>
"@
}

function Add-ProfileInjectionToHtml {
    param(
        [string]$HtmlContent,
        [string]$Profile
    )

    $injection = New-ProfileInjection $Profile
    if ($HtmlContent -match '</head>') {
        return ($HtmlContent -replace '</head>', ($injection + [Environment]::NewLine + '</head>'))
    }
    if ($HtmlContent -match '<body[^>]*>') {
        return ($HtmlContent -replace '(<body[^>]*>)', ('$1' + [Environment]::NewLine + $injection))
    }
    return $injection + [Environment]::NewLine + $HtmlContent
}

function Write-WebEntryPage {
    param(
        [string]$SourceHtmlPath,
        [string]$TargetHtmlPath,
        [string]$Profile
    )

    $baseHtml = Get-Content -LiteralPath $SourceHtmlPath -Raw
    $patchedHtml = Add-ProfileInjectionToHtml -HtmlContent $baseHtml -Profile $Profile
    Write-Utf8File -PathValue $TargetHtmlPath -Content $patchedHtml
}

function New-WindowsStartHereNote {
    param([string]$Profile)

    $launcher = if ($Profile -eq 'qa') { 'Launch QA.cmd' } else { 'Launch Participant.cmd' }
    $profileLabel = if ($Profile -eq 'qa') { 'QA' } else { 'Participant' }
@"
In a Bottle $profileLabel Build

1. Double-click $launcher.
2. The app will start in the intended runtime profile for this folder.
3. Desktop exports and ZIP handoff save into the app's local export folder.

This folder contains:
- InABottle.exe and its .pck
- A profile-specific launcher
- manifest.json with build details
"@
}

function New-WebStartHereNote {
    param([string]$Profile)

    if ($Profile -eq 'qa') {
@"
In a Bottle QA Web Bundle

Open index.html from a hosted copy or local web server to launch the QA profile.
Use participant.html if you want to compare the clean participant landing from the same asset set.

This folder contains:
- Shared exported Godot web assets
- Profile-specific entry HTML files
- manifest.json with build details
"@
    }
    else {
@"
In a Bottle Participant Web Bundle

Open index.html from a hosted copy or local web server to launch the participant profile.
This folder intentionally does not include a QA entry page; use the separate QA bundle for internal verification.

This folder contains:
- Shared exported Godot web assets
- The participant entry HTML file
- manifest.json with build details
"@
    }
}

function New-FolderManifest {
    param(
        [string]$Target,
        [string]$Profile,
        [string]$FolderPath,
        [string]$EntryPoint,
        [string]$GodotVersion,
        [string]$Commit,
        [string]$Branch,
        [string]$GeneratedAt
    )

    return @{
        format       = 'in_a_bottle_playtest_folder_v1'
        generated_at = $GeneratedAt
        target       = $Target
        profile      = $Profile
        folder       = (Get-RepoRelativePath $FolderPath)
        entry_point  = $EntryPoint
        git          = @{
            branch = $Branch
            commit = $Commit
        }
        godot        = @{
            version = $GodotVersion
        }
    }
}

function Package-WindowsTarget {
    param(
        [string]$ExecutablePath,
        [hashtable]$GodotMetadata,
        [string[]]$RequestedProfiles,
        [string]$TargetRoot,
        [string]$Commit,
        [string]$Branch,
        [string]$GeneratedAt
    )

    $sharedRoot = Join-Path $TargetRoot '_shared_export'
    $sharedTarget = Join-Path $sharedRoot $DefaultWindowsExecutableName
    Remove-DirectoryIfPresent $TargetRoot
    Ensure-Directory $sharedRoot
    Export-GodotRelease -ExecutablePath $ExecutablePath -PresetName 'Windows Desktop' -TargetPath $sharedTarget

    $packaged = @()
    foreach ($profile in $RequestedProfiles) {
        $profileRoot = Join-Path $TargetRoot $profile
        Copy-DirectoryContents -Source $sharedRoot -Destination $profileRoot
        $launcherName = if ($profile -eq 'qa') { 'Launch QA.cmd' } else { 'Launch Participant.cmd' }
        $launcherPath = Join-Path $profileRoot $launcherName
        $launcherContent = @"
@echo off
setlocal
cd /d "%~dp0"
start "" "%~dp0$DefaultWindowsExecutableName" -- --build-profile $profile
"@
        Write-Utf8File -PathValue $launcherPath -Content $launcherContent
        Write-Utf8File -PathValue (Join-Path $profileRoot 'START-HERE.txt') -Content (New-WindowsStartHereNote -Profile $profile)
        $folderManifest = New-FolderManifest -Target 'windows' -Profile $profile -FolderPath $profileRoot -EntryPoint $launcherName -GodotVersion $GodotMetadata.Version -Commit $Commit -Branch $Branch -GeneratedAt $GeneratedAt
        Write-JsonFile -PathValue (Join-Path $profileRoot 'manifest.json') -Payload $folderManifest
        Invoke-ExportArtifactVerification -ExecutablePath $ExecutablePath -PresetName 'Windows Desktop' -TargetPath (Join-Path $profileRoot $DefaultWindowsExecutableName)
        Assert-FileExists (Join-Path $profileRoot $launcherName)
        Assert-FileExists (Join-Path $profileRoot 'START-HERE.txt')
        Assert-FileExists (Join-Path $profileRoot 'manifest.json')
        $packaged += @{
            target            = 'windows'
            profile           = $profile
            folder            = (Get-RepoRelativePath $profileRoot)
            entry             = $launcherName
            manifest_path     = (Get-RepoRelativePath (Join-Path $profileRoot 'manifest.json'))
            exported_artifacts = @(
                (Get-RepoRelativePath (Join-Path $profileRoot $DefaultWindowsExecutableName)),
                (Get-RepoRelativePath (Join-Path $profileRoot 'InABottle.pck'))
            )
        }
    }
    Remove-DirectoryIfPresent $sharedRoot
    return $packaged
}

function Package-WebTarget {
    param(
        [string]$ExecutablePath,
        [hashtable]$GodotMetadata,
        [string[]]$RequestedProfiles,
        [string]$TargetRoot,
        [string]$Commit,
        [string]$Branch,
        [string]$GeneratedAt
    )

    $sharedRoot = Join-Path $TargetRoot '_shared_export'
    $sharedTarget = Join-Path $sharedRoot $DefaultWebEntryName
    Remove-DirectoryIfPresent $TargetRoot
    Ensure-Directory $sharedRoot
    Export-GodotRelease -ExecutablePath $ExecutablePath -PresetName 'Web' -TargetPath $sharedTarget

    $sharedHtmlPath = Join-Path $sharedRoot $DefaultWebEntryName
    $packaged = @()
    foreach ($profile in $RequestedProfiles) {
        $profileRoot = Join-Path $TargetRoot $profile
        Copy-DirectoryContents -Source $sharedRoot -Destination $profileRoot
        if ($profile -eq 'qa') {
            Write-WebEntryPage -SourceHtmlPath $sharedHtmlPath -TargetHtmlPath (Join-Path $profileRoot 'index.html') -Profile 'qa'
            Write-WebEntryPage -SourceHtmlPath $sharedHtmlPath -TargetHtmlPath (Join-Path $profileRoot 'participant.html') -Profile 'participant'
            $entryPoint = 'index.html'
        }
        else {
            Write-WebEntryPage -SourceHtmlPath $sharedHtmlPath -TargetHtmlPath (Join-Path $profileRoot 'index.html') -Profile 'participant'
            $entryPoint = 'index.html'
        }
        Write-Utf8File -PathValue (Join-Path $profileRoot 'START-HERE.txt') -Content (New-WebStartHereNote -Profile $profile)
        $folderManifest = New-FolderManifest -Target 'web' -Profile $profile -FolderPath $profileRoot -EntryPoint $entryPoint -GodotVersion $GodotMetadata.Version -Commit $Commit -Branch $Branch -GeneratedAt $GeneratedAt
        Write-JsonFile -PathValue (Join-Path $profileRoot 'manifest.json') -Payload $folderManifest
        Invoke-ExportArtifactVerification -ExecutablePath $ExecutablePath -PresetName 'Web' -TargetPath (Join-Path $profileRoot 'index.html')
        Assert-FileExists (Join-Path $profileRoot 'manifest.json')
        Assert-FileExists (Join-Path $profileRoot 'START-HERE.txt')
        if ($profile -eq 'qa') {
            Assert-FileExists (Join-Path $profileRoot 'participant.html')
        }
        $packaged += @{
            target            = 'web'
            profile           = $profile
            folder            = (Get-RepoRelativePath $profileRoot)
            entry             = $entryPoint
            manifest_path     = (Get-RepoRelativePath (Join-Path $profileRoot 'manifest.json'))
            exported_artifacts = @(
                (Get-RepoRelativePath (Join-Path $profileRoot 'index.html')),
                (Get-RepoRelativePath (Join-Path $profileRoot 'index.js')),
                (Get-RepoRelativePath (Join-Path $profileRoot 'index.pck')),
                (Get-RepoRelativePath (Join-Path $profileRoot 'index.wasm'))
            )
        }
    }
    Remove-DirectoryIfPresent $sharedRoot
    return $packaged
}

function Invoke-PlaytestBuild {
    param(
        [string]$ExecutablePath,
        [hashtable]$GodotMetadata,
        [string[]]$RequestedTargets,
        [string[]]$RequestedProfiles,
        [string]$ResolvedOutputRoot
    )

    $doctorReport = New-DoctorReport -GodotMetadata $GodotMetadata -ResolvedOutputRoot $ResolvedOutputRoot
    Assert-ExportTemplatesReady -DoctorReport $doctorReport

    $gitMetadata = Get-GitMetadata
    $generatedAt = [DateTimeOffset]::Now.ToString('o')
    Ensure-Directory $ResolvedOutputRoot
    $entries = @()

    if ($RequestedTargets -contains 'windows') {
        $entries += Package-WindowsTarget -ExecutablePath $ExecutablePath -GodotMetadata $GodotMetadata -RequestedProfiles $RequestedProfiles -TargetRoot (Join-Path $ResolvedOutputRoot 'windows') -Commit $gitMetadata.Commit -Branch $gitMetadata.Branch -GeneratedAt $generatedAt
    }

    if ($RequestedTargets -contains 'web') {
        if (Test-WebExportBlockedLocally $GodotMetadata) {
            throw 'Web export is blocked for the selected Godot build. Use a non-Mono Godot executable.'
        }
        $entries += Package-WebTarget -ExecutablePath $ExecutablePath -GodotMetadata $GodotMetadata -RequestedProfiles $RequestedProfiles -TargetRoot (Join-Path $ResolvedOutputRoot 'web') -Commit $gitMetadata.Commit -Branch $gitMetadata.Branch -GeneratedAt $generatedAt
    }

    $manifest = @{
        format            = 'in_a_bottle_playtest_release_v1'
        generated_at      = $generatedAt
        output_root       = (Get-RepoRelativePath $ResolvedOutputRoot)
        requested_targets = $RequestedTargets
        requested_profiles = $RequestedProfiles
        git               = @{
            branch = $gitMetadata.Branch
            commit = $gitMetadata.Commit
            dirty  = $gitMetadata.Dirty
        }
        godot             = @{
            path    = $GodotMetadata.Path
            version = $GodotMetadata.Version
            is_mono = $GodotMetadata.IsMono
        }
        packages          = $entries
    }
    $manifestPath = Join-Path $ResolvedOutputRoot 'release_manifest.json'
    Write-JsonFile -PathValue $manifestPath -Payload $manifest
    Write-PlaytestLog "Release manifest written to $(Get-RepoRelativePath $manifestPath)."
    return @{
        OutputRoot    = $ResolvedOutputRoot
        ManifestPath  = $manifestPath
        PackageEntries = $entries
    }
}

function Invoke-PlaytestAudit {
    param(
        [string]$ExecutablePath,
        [string]$ResolvedOutputRoot,
        [switch]$ContractMode
    )

    Ensure-Directory $ResolvedOutputRoot
    Ensure-Directory (Join-Path $ResolvedOutputRoot 'audit')
    $arguments = @('--path', $RepoRoot)
    if ($ContractMode) {
        $arguments += '--headless'
    }
    $arguments += @('--script', $VisualAuditScriptPath)
    if ($ContractMode) {
        $arguments += @('--', '--contract-only')
    }
    $arguments = New-GodotArguments -Label 'visual-audit' -Arguments $arguments

    Write-PlaytestLog ('Running visual audit in ' + ($(if ($ContractMode) { 'contract-only' } else { 'renderer-backed' })) + ' mode.')
    $result = Invoke-WithGodotValidationAppData -ScriptBlock {
        Invoke-ExternalCommand -FilePath $ExecutablePath -Arguments $arguments -CaptureOutput
    }
    foreach ($line in $result.Output) {
        Write-Host $line
    }
    $payloadLine = $result.Output | Where-Object { $_ -like 'PLAYTEST_AUDIT_RESULT=*' } | Select-Object -Last 1
    if (-not $payloadLine) {
        throw 'The visual audit runner did not emit a PLAYTEST_AUDIT_RESULT payload.'
    }
    $jsonText = $payloadLine.Substring('PLAYTEST_AUDIT_RESULT='.Length)
    $auditPayload = $jsonText | ConvertFrom-Json
    if (-not [bool]$auditPayload.ok) {
        $failureMessage = if ($auditPayload.PSObject.Properties.Name -contains 'message') { [string]$auditPayload.message } else { 'Visual audit export failed.' }
        throw $failureMessage
    }
    $zipSource = Resolve-AbsolutePath ([string]$auditPayload.zip_absolute_path)
    Assert-FileExists $zipSource
    $zipDestination = Join-Path (Join-Path $ResolvedOutputRoot 'audit') ([System.IO.Path]::GetFileName($zipSource))
    Copy-Item -LiteralPath $zipSource -Destination $zipDestination -Force
    $auditManifestPath = Join-Path (Join-Path $ResolvedOutputRoot 'audit') 'manifest.json'
    $auditManifest = @{
        format                    = 'in_a_bottle_visual_audit_v1'
        contract_only             = [bool]$ContractMode
        zip_path                  = (Get-RepoRelativePath $zipDestination)
        source_zip_path           = [string]$auditPayload.zip_path
        capture_count             = [int]$auditPayload.capture_count
        placeholder_capture_count = [int]$auditPayload.placeholder_capture_count
        flow_chart_path           = [string]$auditPayload.flow_chart_path
    }
    Write-JsonFile -PathValue $auditManifestPath -Payload $auditManifest
    if (-not $ContractMode -and [int]$auditPayload.placeholder_capture_count -gt 0) {
        throw "Renderer-backed audit completed with $($auditPayload.placeholder_capture_count) placeholder captures."
    }
    Write-PlaytestLog "Visual audit ZIP copied to $(Get-RepoRelativePath $zipDestination)."
    return @{
        OutputRoot = $ResolvedOutputRoot
        ZipPath    = $zipDestination
    }
}

$requestedTargets = ConvertTo-NormalizedList -Values $Targets -Fallback @('windows', 'web')
$requestedProfiles = ConvertTo-NormalizedList -Values $Profiles -Fallback @('participant', 'qa')
foreach ($target in $requestedTargets) {
    if ($target -notin @('windows', 'web')) {
        throw "Unsupported target '$target'. Use windows or web."
    }
}
foreach ($profile in $requestedProfiles) {
    if ($profile -notin @('participant', 'qa')) {
        throw "Unsupported profile '$profile'. Use participant or qa."
    }
}

$godotExe = Resolve-GodotExecutable -PreferredPath $GodotPath
$godotMetadata = Get-GodotMetadata -ExecutablePath $godotExe
$resolvedOutputRoot = Get-PlaytestOutputRoot -RequestedRoot $OutputRoot

switch ($Command) {
    'doctor' {
        $doctorReport = New-DoctorReport -GodotMetadata $godotMetadata -ResolvedOutputRoot $resolvedOutputRoot
        Show-DoctorReport -Report $doctorReport
    }
    'test' {
        Invoke-RepoValidation -ExecutablePath $godotExe
        Write-PlaytestLog 'Validation stack completed successfully.'
    }
    'build' {
        $buildResult = Invoke-PlaytestBuild -ExecutablePath $godotExe -GodotMetadata $godotMetadata -RequestedTargets $requestedTargets -RequestedProfiles $requestedProfiles -ResolvedOutputRoot $resolvedOutputRoot
        Write-PlaytestLog "Playtest build output: $(Get-RepoRelativePath $buildResult.OutputRoot)"
    }
    'audit' {
        Invoke-PlaytestAudit -ExecutablePath $godotExe -ResolvedOutputRoot $resolvedOutputRoot -ContractMode:$ContractOnly | Out-Null
    }
    'release' {
        $doctorReport = New-DoctorReport -GodotMetadata $godotMetadata -ResolvedOutputRoot $resolvedOutputRoot
        Show-DoctorReport -Report $doctorReport
        Invoke-RepoValidation -ExecutablePath $godotExe
        $buildResult = Invoke-PlaytestBuild -ExecutablePath $godotExe -GodotMetadata $godotMetadata -RequestedTargets $requestedTargets -RequestedProfiles $requestedProfiles -ResolvedOutputRoot $resolvedOutputRoot
        if ($IncludeAudit) {
            Invoke-PlaytestAudit -ExecutablePath $godotExe -ResolvedOutputRoot $resolvedOutputRoot -ContractMode:$ContractOnly | Out-Null
        }
        Write-PlaytestLog "Playtest release output: $(Get-RepoRelativePath $buildResult.OutputRoot)"
    }
}
