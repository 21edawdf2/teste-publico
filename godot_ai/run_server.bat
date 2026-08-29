@echo off
chcp 65001 >nul
cd /d "%~dp0.."

if not exist ".godot_ai_venv\Scripts\python.exe" (
    echo [ERRO] Ambiente Python nao encontrado.
    echo Rode INSTALAR_E_LIGAR.bat primeiro.
    pause
    exit /b 1
)

echo ==========================================
echo   GODOT OPENAI ASSISTANT - SERVIDOR
echo ==========================================
echo.
echo Deixe esta janela aberta enquanto usar a IA na Godot.
echo Endereco local: http://127.0.0.1:8765
echo.

".godot_ai_venv\Scripts\python.exe" "godot_ai\server.py"

echo.
echo O servidor foi encerrado.
pause
