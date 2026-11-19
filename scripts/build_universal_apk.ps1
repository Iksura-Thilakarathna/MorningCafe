# Morning Cafe - Universal All-Device Compatible APK Build Script (PowerShell)
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "Building Morning Cafe Universal APK (All-Device Support)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$rootDir = Split-Path -Parent $PSScriptRoot
Set-Location $rootDir

Write-Host "`n[1/3] Getting Flutter dependencies..." -ForegroundColor Yellow
flutter pub get

Write-Host "`n[2/3] Building Release APK for all physical Android phones (armeabi-v7a + arm64-v8a)..." -ForegroundColor Yellow
flutter build apk --release --target-platform android-arm,android-arm64

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n[ERROR] Universal APK build failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "`n[3/3] Deploying Universal APK to project root..." -ForegroundColor Yellow
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "MorningCafe_Universal.apk" -Force
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "MorningCafe.apk" -Force

$apkItem = Get-Item "MorningCafe_Universal.apk"
$sizeMb = [math]::Round($apkItem.Length / 1MB, 2)

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "SUCCESS! Universal All-Device Compatible APK ready: ($sizeMb MB)" -ForegroundColor Green
Write-Host " - MorningCafe_Universal.apk" -ForegroundColor Green
Write-Host " - MorningCafe.apk" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
