# Release APK with project-local Gradle home (avoids corrupted global Gradle caches).
# Run: powershell -ExecutionPolicy Bypass -File build_apk.ps1
#
# Optional env: ELDERLINK_TOOLS_ROOT (default D:) — base for android studio\jbr and flutter
#              ELDERLINK_FLUTTER_BIN — full path to flutter.bat if not on PATH

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$env:GRADLE_USER_HOME = Join-Path $root '.gradle_user_home'
New-Item -ItemType Directory -Force -Path $env:GRADLE_USER_HOME | Out-Null
Set-Location $root

$toolsRoot = if ($env:ELDERLINK_TOOLS_ROOT) { $env:ELDERLINK_TOOLS_ROOT.TrimEnd('\', '/') } else { 'D:' }

if (-not $env:JAVA_HOME) {
    $jbr = Join-Path $toolsRoot 'android studio\jbr'
    if (Test-Path (Join-Path $jbr 'bin\java.exe')) {
        $env:JAVA_HOME = $jbr
        $env:Path = "$env:JAVA_HOME\bin;$env:Path"
    }
}

$flutterBat = if ($env:ELDERLINK_FLUTTER_BIN) { $env:ELDERLINK_FLUTTER_BIN } else { Join-Path $toolsRoot 'flutter\bin\flutter.bat' }
$flutter = if (Get-Command flutter -ErrorAction SilentlyContinue) { 'flutter' }
elseif (Test-Path $flutterBat) { $flutterBat }
else { throw "Flutter not found. Add flutter to PATH, set ELDERLINK_FLUTTER_BIN, or install under $toolsRoot\flutter" }

& $flutter build apk --release
$apk = Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'
if (Test-Path $apk) {
    $i = Get-Item $apk
    Write-Host "APK: $($i.FullName)  ($([math]::Round($i.Length/1MB, 2)) MB)"
}
