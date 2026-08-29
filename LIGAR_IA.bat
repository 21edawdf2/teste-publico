@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

if not exist "project.godot" (
    echo [ERRO] Este BAT precisa ficar na pasta do project.godot.
    pause
    exit /b 1
)

if not exist ".godot_ai_venv\Scripts\python.exe" (
    echo O assistente ainda nao foi instalado.
    echo Abrindo o instalador...
    call "INSTALAR_E_LIGAR.bat"
    exit /b
)

if not exist ".env" (
    echo A configuracao da API esta faltando.
    echo Abrindo o instalador...
    call "INSTALAR_E_LIGAR.bat"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "try { Invoke-RestMethod -Uri 'http://127.0.0.1:8765/health' -TimeoutSec 2 ^| Out-Null; exit 0 } catch { exit 1 }"

if not errorlevel 1 (
    echo A IA ja esta ligada em http://127.0.0.1:8765
    pause
    exit /b 0
)

start "Godot AI Server" "%ComSpec%" /k call "%CD%\godot_ai\run_server.bat"

echo Servidor iniciado.
echo Deixe a nova janela aberta enquanto usar a Godot.
timeout /t 2 /nobreak >nul
