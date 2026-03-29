# Release APK with project-local Gradle home (avoids corrupted global Gradle caches).
# Run: powershell -ExecutionPolicy Bypass -File build_apk.ps1
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$env:GRADLE_USER_HOME = Join-Path $root '.gradle_user_home'
New-Item -ItemType Directory -Force -Path $env:GRADLE_USER_HOME | Out-Null
Set-Location $root

if (-not $env:JAVA_HOME) {
    if (Test-Path 'D:\android studio\jbr\bin\java.exe') {
        $env:JAVA_HOME = 'D:\android studio\jbr'
        $env:Path = "$env:JAVA_HOME\bin;$env:Path"
    }
}

$flutter = if (Get-Command flutter -ErrorAction SilentlyContinue) { 'flutter' }
elseif (Test-Path 'D:\flutter\bin\flutter.bat') { 'D:\flutter\bin\flutter.bat' }
else { throw 'Flutter not found. Add flutter to PATH or install to D:\flutter' }

& $flutter build apk --release
$apk = Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'
if (Test-Path $apk) {
    $i = Get-Item $apk
    Write-Host "APK: $($i.FullName)  ($([math]::Round($i.Length/1MB, 2)) MB)"
}
