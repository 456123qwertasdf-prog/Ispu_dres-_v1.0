@echo off
echo ========================================
echo LSPU DRES - Run on Android Device
echo ========================================
echo.

echo Checking Flutter setup...
flutter doctor

echo.
echo Checking connected devices...
flutter devices

echo.
echo Building and installing app on your Android device...
echo This may take a few minutes on first run...
echo.

flutter run -d YTLREE6DVWJVYS8L

pause

