@echo off
setlocal EnableDelayedExpansion

echo [1/9] Cleaning project...
call flutter clean
if ERRORLEVEL 1 (
  echo Clean failed - folder may be locked. Continuing...
)

echo [2/9] Getting dependencies...
call flutter pub get
if ERRORLEVEL 1 (
  echo Failed to get dependencies. Check your connection or run 'flutter pub get' manually.
  exit /b %ERRORLEVEL%
)

echo [3/9] Formatting code...
set "FORMAT_TARGETS="
for %%d in (lib test android\app\src\main\kotlin android\app\src\main\java) do (
  if exist "%%d" (
    set "FORMAT_TARGETS=!FORMAT_TARGETS! "%%d""
  )
)
if defined FORMAT_TARGETS (
  call set "FORMAT_CMD=dart format%%FORMAT_TARGETS%%"
  call %%FORMAT_CMD%%
) else (
  echo No Dart formatting targets found, skipping.
)

echo [4/9] Analyzing code...
call flutter analyze

echo [5/9] Running tests...
if exist test (
  call flutter test
) else (
  echo No test directory found, skipping tests.
)

echo [6/9] Checking ProGuard/R8 release protection...
set "ANDROID_APP_GRADLE=android\app\build.gradle.kts"
set "PROGUARD_RULES=android\app\proguard-rules.pro"

if not exist "%ANDROID_APP_GRADLE%" (
  echo Android app Gradle config not found: %ANDROID_APP_GRADLE%
  exit /b 1
)

if not exist "%PROGUARD_RULES%" (
  echo ProGuard rules file not found: %PROGUARD_RULES%
  exit /b 1
)

findstr /C:"isMinifyEnabled = true" "%ANDROID_APP_GRADLE%" >nul
if ERRORLEVEL 1 (
  echo ProGuard/R8 is not enabled for release. Expected: isMinifyEnabled = true
  exit /b 1
)

findstr /C:"isShrinkResources = true" "%ANDROID_APP_GRADLE%" >nul
if ERRORLEVEL 1 (
  echo Resource shrinking is not enabled for release. Expected: isShrinkResources = true
  exit /b 1
)

findstr /C:"proguardFiles(" "%ANDROID_APP_GRADLE%" >nul
if ERRORLEVEL 1 (
  echo ProGuard files are not configured for release.
  exit /b 1
)

findstr /C:"proguard-rules.pro" "%ANDROID_APP_GRADLE%" >nul
if ERRORLEVEL 1 (
  echo Custom ProGuard rules are not included in release build.
  exit /b 1
)

echo [7/9] Building protected APK...
if not exist build\debug-info (
  mkdir build\debug-info
)
call flutter build apk --release --obfuscate --split-debug-info=build/debug-info
if ERRORLEVEL 1 (
  echo APK build failed. Fix issues above and retry.
  exit /b %ERRORLEVEL%
)

echo [8/9] Building release app bundle (AAB)...
set "KEY_PROPERTIES=android\key.properties"
if not exist "%KEY_PROPERTIES%" (
  echo Release signing is not configured: %KEY_PROPERTIES% is missing.
  echo Create it from android\key.properties.example and point it to your .jks keystore.
  exit /b 1
)

set "AAB_PATH=build\app\outputs\bundle\release\app-release.aab"

call flutter build appbundle --release --obfuscate --split-debug-info=build/debug-info
if ERRORLEVEL 1 (
  echo.
  echo AAB build reported a failure.
  if exist "%AAB_PATH%" (
    echo NOTE: the bundle file was still produced at %AAB_PATH%.
    echo If the error above is "failed to strip debug symbols", flutter could not
    echo VERIFY the bundle because apkanalyzer is missing, not because stripping
    echo failed. Install the Android SDK "Command-line Tools" component
    echo ^(Android Studio - SDK Manager - SDK Tools^) and re-run.
    echo Verify with: flutter doctor
  )
  exit /b %ERRORLEVEL%
)

if not exist "%AAB_PATH%" (
  echo AAB was not produced at expected path: %AAB_PATH%
  exit /b 1
)

echo AAB ready: %AAB_PATH%
for %%f in ("%AAB_PATH%") do echo Size: %%~zf bytes

echo [9/9] Done!
endlocal
