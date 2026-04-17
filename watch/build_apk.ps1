# Release APK with a project-local Gradle home (avoids corrupted Gradle transforms in a global cache).
# Run from repo root or this folder:  powershell -ExecutionPolicy Bypass -File build_apk.ps1
#
# Optional env: ELDERLINK_TOOLS_ROOT (default D:) — base for android studio\jbr and flutter
#              ELDERLINK_FLUTTER_BIN — full path to flutter.bat if not on PATH

$ErrorActionPreference = 'Stop'
$watchRoot = $PSScriptRoot
$env:GRADLE_USER_HOME = Join-Path $watchRoot '.gradle_user_home'
New-Item -ItemType Directory -Force -Path $env:GRADLE_USER_HOME | Out-Null
Set-Location $watchRoot

$toolsRoot = if ($env:ELDERLINK_TOOLS_ROOT) { $env:ELDERLINK_TOOLS_ROOT.TrimEnd('\', '/') } else { 'D:' }

if (-not $env:JAVA_HOME) {
    $jbr = Join-Path $toolsRoot 'android studio\jbr'
    if (Test-Path (Join-Path $jbr 'bin\java.exe')) {
        $env:JAVA_HOME = $jbr
        $env:Path = "$env:JAVA_HOME\bin;$env:Path"
    }
}

$flutterBat = if ($env:ELDERLINK_FLUTTER_BIN) { $env:ELDERLINK_FLUTTER_BIN } else { Join-Path $toolsRoot 'flutter\bin\flutter.bat' }
$flutter = 'flutter'
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    if (Test-Path $flutterBat) {
        $flutter = $flutterBat
    }
}

& $flutter build apk --release
Write-Host ""
$apk = Join-Path $watchRoot 'build\app\outputs\flutter-apk\app-release.apk'
if (Test-Path $apk) {
    $i = Get-Item $apk
    Write-Host "APK: $($i.FullName)  ($([math]::Round($i.Length/1MB, 2)) MB)"
} else {
    Write-Host "Build finished but app-release.apk not found under build\app\outputs\flutter-apk\"
}
