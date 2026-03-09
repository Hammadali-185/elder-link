# Remove corrupted NDK folder so Gradle can re-download it.
# Run from project root: .\fix-ndk.ps1

$ndkPath = "$env:LOCALAPPDATA\Android\sdk\ndk\27.0.12077973"
if (Test-Path $ndkPath) {
    Write-Host "Removing corrupted NDK at: $ndkPath" -ForegroundColor Yellow
    Remove-Item -Recurse -Force $ndkPath
    Write-Host "Done. Run .\build-and-copy-apk.ps1 again so Gradle can re-download the NDK." -ForegroundColor Green
} else {
    Write-Host "NDK folder not found at: $ndkPath" -ForegroundColor Cyan
    Write-Host "If your SDK is on D: or elsewhere, delete the folder manually:"
    Write-Host "  <SDK path>\ndk\27.0.12077973" -ForegroundColor Cyan
    Write-Host "Then run .\build-and-copy-apk.ps1 again." -ForegroundColor Green
}
