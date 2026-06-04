param(
    [Parameter(Mandatory = $true)]
    [string] $SdkPath,

    [string] $FlutterPath = "C:\flutter"
)

$ErrorActionPreference = "Stop"

$resolvedSdk = Resolve-Path -LiteralPath $SdkPath
$sdkFullPath = $resolvedSdk.Path

$platformTools = Join-Path $sdkFullPath "platform-tools"
$cmdlineTools = Join-Path $sdkFullPath "cmdline-tools"

if (-not (Test-Path -LiteralPath $platformTools)) {
    throw "Android SDK platform-tools not found at $platformTools"
}

if (-not (Test-Path -LiteralPath $cmdlineTools)) {
    Write-Warning "cmdline-tools not found at $cmdlineTools. Flutter builds can work, but sdkmanager/licenses may be unavailable."
}

$androidDir = Join-Path (Get-Location) "android"
$localPropertiesPath = Join-Path $androidDir "local.properties"

if (-not (Test-Path -LiteralPath $androidDir)) {
    throw "Run this script from the HostConnect project root."
}

$escapedSdk = $sdkFullPath.Replace("\", "\\")
$escapedFlutter = $FlutterPath.Replace("\", "\\")

$content = @(
    "flutter.sdk=$escapedFlutter",
    "sdk.dir=$escapedSdk"
)

Set-Content -LiteralPath $localPropertiesPath -Value $content -Encoding ASCII

[Environment]::SetEnvironmentVariable("ANDROID_HOME", $sdkFullPath, "User")
[Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $sdkFullPath, "User")

$currentUserPath = [Environment]::GetEnvironmentVariable("Path", "User")
$pathEntries = @($currentUserPath -split ";") | Where-Object { $_ -ne "" }
$requiredEntries = @(
    $platformTools,
    (Join-Path $sdkFullPath "cmdline-tools\latest\bin")
)

foreach ($entry in $requiredEntries) {
    if ((Test-Path -LiteralPath $entry) -and ($pathEntries -notcontains $entry)) {
        $pathEntries += $entry
    }
}

[Environment]::SetEnvironmentVariable("Path", ($pathEntries -join ";"), "User")

Write-Host "Configured Android SDK for HostConnect:"
Write-Host "  sdk.dir=$sdkFullPath"
Write-Host "  ANDROID_HOME=$sdkFullPath"
Write-Host "Restart PowerShell, then run:"
Write-Host "  flutter doctor -v"
Write-Host "  flutter build apk --release"
