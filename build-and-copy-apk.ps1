# Build ElderLink APK and copy to release folder
# Run from project root: .\build-and-copy-apk.ps1

$root = $PSScriptRoot
Set-Location $root

# Use only D: for Android SDK (no C:)
$env:ANDROID_HOME = "D:\android"
Write-Host "Using ANDROID_HOME = $env:ANDROID_HOME (D: only)" -ForegroundColor Cyan

# Ensure Java is available for Gradle (flutter build uses it too)
if (-not $env:JAVA_HOME) {
    $jbr = "C:\Program Files\Android\Android Studio\jbr"
    if (Test-Path (Join-Path $jbr "bin\java.exe")) {
        $env:JAVA_HOME = $jbr
        Write-Host "Using JAVA_HOME = $env:JAVA_HOME" -ForegroundColor Cyan
    }
}
if (-not $env:JAVA_HOME) {
    Write-Host "JAVA_HOME not set. Set it to your JDK (e.g. Android Studio\jbr) if Gradle fails." -ForegroundColor Yellow
}

Set-Location mobile
# Clean build to avoid Kotlin cache "different roots" (C: vs D:) and "Storage already registered" errors
Write-Host "Cleaning previous build..." -ForegroundColor Cyan
flutter clean
# Remove Android Kotlin/Gradle caches that cause "Could not close incremental caches" / "already registered"
$androidDir = Join-Path $root "mobile\android"
foreach ($dir in @(".gradle", ".kotlin", "build")) {
    $path = Join-Path $androidDir $dir
    if (Test-Path $path) {
        Remove-Item -Recurse -Force $path -ErrorAction SilentlyContinue
        Write-Host "Removed $dir" -ForegroundColor Gray
    }
}
# Stop Gradle daemons so they don't hold stale Kotlin cache handles (best-effort; needs JAVA_HOME)
if ($env:JAVA_HOME -and (Test-Path (Join-Path $androidDir "gradlew.bat"))) {
    Set-Location $androidDir
    & .\gradlew.bat --stop 2>$null
    Set-Location (Join-Path $root "mobile")
}
# Clear corrupted Gradle transforms cache (fixes "Could not read workspace metadata")
foreach ($base in @("D:\GradleCache\.gradle", "D:\GradleCache", $env:GRADLE_USER_HOME, (Join-Path $env:USERPROFILE ".gradle"))) {
    if (-not $base) { continue }
    $transforms = Join-Path $base "caches\8.14\transforms"
    if (Test-Path $transforms) {
        Remove-Item -Recurse -Force $transforms -ErrorAction SilentlyContinue
        Write-Host "Cleared Gradle transforms cache: $transforms" -ForegroundColor Gray
        break
    }
}
flutter pub get
Write-Host "Building APK (mobile app, split-per-abi)..." -ForegroundColor Cyan
flutter build apk --release --split-per-abi
$buildOk = ($LASTEXITCODE -eq 0)
Set-Location $root

if (-not $buildOk) {
    Write-Host "Build failed. Check that Android SDK is installed and ANDROID_HOME is set." -ForegroundColor Red
    exit 1
}

$apkDir = Join-Path $root "mobile\build\app\outputs\flutter-apk"
$releaseDir = "D:\release"
if (-not (Test-Path $releaseDir)) {
    New-Item -ItemType Directory -Path $releaseDir | Out-Null
}

$apks = Get-ChildItem -Path $apkDir -Filter "app-*-release.apk" -ErrorAction SilentlyContinue
if (-not $apks) {
    $single = Join-Path $apkDir "app-release.apk"
    if (Test-Path $single) {
        $apks = @(Get-Item $single)
    }
}
if (-not $apks) {
    Write-Host "APK(s) not found in $apkDir" -ForegroundColor Red
    exit 1
}
foreach ($apk in $apks) {
    $dest = Join-Path $releaseDir $apk.Name
    Copy-Item -Path $apk.FullName -Destination $dest -Force
    Write-Host "Copied: $($apk.Name) -> $dest" -ForegroundColor Green
}
Write-Host "Output folder: $releaseDir" -ForegroundColor Cyan
