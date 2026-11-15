@echo off
setlocal
pushd "%~dp0"

echo Menjalankan aplikasi dengan konfigurasi publik Supabase bawaan.
echo Setelah server siap, buka http://127.0.0.1:7357
call flutter run -d web-server --no-pub --web-hostname=127.0.0.1 --web-port=7357
set "runExitCode=%ERRORLEVEL%"
popd
exit /b %runExitCode%
