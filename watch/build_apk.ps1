# Release APK with a project-local Gradle home (avoids corrupted D:\GradleCache transforms).
# Run from repo root or this folder:  powershell -ExecutionPolicy Bypass -File build_apk.ps1
$ErrorActionPreference = 'Stop'
$watchRoot = $PSScriptRoot
$env:GRADLE_USER_HOME = Join-Path $watchRoot '.gradle_user_home'
New-Item -ItemType Directory -Force -Path $env:GRADLE_USER_HOME | Out-Null
Set-Location $watchRoot

if (-not $env:JAVA_HOME) {
    if (Test-Path 'D:\android studio\jbr\bin\java.exe') {
        $env:JAVA_HOME = 'D:\android studio\jbr'
        $env:Path = "$env:JAVA_HOME\bin;$env:Path"
    }
}

$flutter = 'flutter'
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    if (Test-Path 'D:\flutter\bin\flutter.bat') {
        $flutter = 'D:\flutter\bin\flutter.bat'
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
