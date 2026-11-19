@echo off
REM Morning Cafe - Universal All-Device Compatible APK Build Script
echo ========================================================
echo Building Morning Cafe Universal APK (All-Device Support)
echo ========================================================

cd /d "%~dp0\.."

echo.
echo [1/3] Running Flutter clean and getting dependencies...
call flutter pub get

echo.
echo [2/3] Building Release APK for all Android architectures (armeabi-v7a, arm64-v8a, x86_64)...
call flutter build apk --release

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Universal APK build failed!
    exit /b %ERRORLEVEL%
)

echo.
echo [3/3] Deploying Universal APK to project root...
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "MorningCafe_Universal.apk"
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "MorningCafe.apk"

echo.
echo ========================================================
echo SUCCESS! Universal All-Device Compatible APK ready:
echo  - MorningCafe_Universal.apk
echo  - MorningCafe.apk
echo ========================================================
