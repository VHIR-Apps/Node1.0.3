Write-Host "Setting up Java..." -ForegroundColor Cyan
$env:JAVA_HOME="D:\an\jbr"
$env:Path="$env:JAVA_HOME\bin;$env:Path"

Write-Host "Cleaning..." -ForegroundColor Yellow
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs

Write-Host "Building Release AAB..." -ForegroundColor Green
Set-Location android
.\gradlew bundleRelease
Set-Location ..

Write-Host ""
Write-Host "====================================" -ForegroundColor Green
Write-Host "BUILD COMPLETE!" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Green
Write-Host ""

$aab = Get-ChildItem -Recurse . -Filter "*.aab" | Select-Object -Last 1
if ($aab) {
    Write-Host "AAB File: $($aab.FullName)" -ForegroundColor Cyan
    Write-Host "File Size: $([math]::Round($aab.Length / 1MB, 2)) MB" -ForegroundColor Cyan
} else {
    Write-Host "AAB not found!" -ForegroundColor Red
}

Write-Host ""
Write-Host "Building Debug APK..." -ForegroundColor Green
Set-Location android
.\gradlew assembleDebug
Set-Location ..

$apk = Get-ChildItem -Recurse . -Filter "*.apk" | Select-Object -Last 1
if ($apk) {
    Write-Host "APK File: $($apk.FullName)" -ForegroundColor Cyan
    Write-Host "File Size: $([math]::Round($apk.Length / 1MB, 2)) MB" -ForegroundColor Cyan
} else {
    Write-Host "APK not found!" -ForegroundColor Red
}

Write-Host ""
Write-Host "DONE!" -ForegroundColor Green