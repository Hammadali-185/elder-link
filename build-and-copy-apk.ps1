# Build ElderLink APK and copy to release folder
# Run from project root: .\build-and-copy-apk.ps1
#
# Optional env: ELDERLINK_TOOLS_ROOT (default D:) — base for android, android studio, flutter, GradleCache, release
#              ELDERLINK_ANDROID_SDK — override Android SDK path
#              ELDERLINK_RELEASE_DIR — override APK copy destination

$root = $PSScriptRoot
Set-Location $root

$toolsRoot = if ($env:ELDERLINK_TOOLS_ROOT) { $env:ELDERLINK_TOOLS_ROOT.TrimEnd('\', '/') } else { 'D:' }
$env:ANDROID_HOME = if ($env:ELDERLINK_ANDROID_SDK) { $env:ELDERLINK_ANDROID_SDK } else { Join-Path $toolsRoot 'android' }
Write-Host "Using ANDROID_HOME = $env:ANDROID_HOME (tools root: $toolsRoot)" -ForegroundColor Cyan

# Ensure Java is available for Gradle (flutter build uses it too) — prefer JBR under tools root (no C: drive)
if (-not $env:JAVA_HOME) {
    $jbr = Join-Path $toolsRoot 'android studio\jbr'
    if (Test-Path (Join-Path $jbr 'bin\java.exe')) {
        $env:JAVA_HOME = $jbr
        $env:Path = "$env:JAVA_HOME\bin;$env:Path"
        Write-Host "Using JAVA_HOME = $env:JAVA_HOME" -ForegroundColor Cyan
    }
}
if (-not $env:JAVA_HOME) {
    Write-Host "JAVA_HOME not set. Set it to your JDK (e.g. Android Studio\jbr) if Gradle fails." -ForegroundColor Yellow
}

Set-Location mobile
# Clean build to avoid Kotlin cache "different roots" (mixed drives) and "Storage already registered" errors
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
$gradleCacheRoot = Join-Path $toolsRoot 'GradleCache'
# Clear corrupted Gradle transforms cache (fixes "Could not read workspace metadata")
foreach ($base in @(
        (Join-Path $gradleCacheRoot '.gradle'),
        $gradleCacheRoot,
        $env:GRADLE_USER_HOME,
        (Join-Path $env:USERPROFILE ".gradle")
    )) {
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
$releaseDir = if ($env:ELDERLINK_RELEASE_DIR) { $env:ELDERLINK_RELEASE_DIR } else { Join-Path $toolsRoot 'release' }
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
