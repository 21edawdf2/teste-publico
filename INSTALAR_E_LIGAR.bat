@echo off
setlocal EnableExtensions
chcp 65001 >nul
cd /d "%~dp0"

title Instalador - Godot OpenAI Assistant

echo ============================================================
echo              GODOT + OPENAI ASSISTANT
echo ============================================================
echo.
echo Este instalador deve estar na MESMA pasta do project.godot.
echo.

if not exist "project.godot" (
    echo [ERRO] Nao achei project.godot nesta pasta:
    echo %CD%
    echo.
    echo Extraia todo o ZIP dentro da pasta raiz do seu projeto Godot
    echo e execute este BAT novamente.
    pause
    exit /b 1
)

set "PYEXE="

where py >nul 2>nul
if not errorlevel 1 set "PYEXE=py"

if not defined PYEXE (
    where python >nul 2>nul
    if not errorlevel 1 set "PYEXE=python"
)

if not defined PYEXE (
    if exist "%LocalAppData%\Programs\Python\Python312\python.exe" (
        set "PYEXE=%LocalAppData%\Programs\Python\Python312\python.exe"
    )
)

if not defined PYEXE (
    echo [FALTA] Python 3 nao foi encontrado.
    echo.
    where winget >nul 2>nul
    if errorlevel 1 (
        echo O Windows Package Manager ^(winget^) tambem nao esta disponivel.
        echo Vou abrir a pagina oficial do Python.
        echo Na instalacao, marque "Add Python to PATH".
        start "" "https://www.python.org/downloads/windows/"
        echo.
        echo Depois de instalar, execute este BAT novamente.
        pause
        exit /b 1
    )

    choice /C SN /N /M "Deseja instalar o Python 3.12 automaticamente pelo winget? [S/N]: "
    if errorlevel 2 (
        echo Instalacao cancelada.
        pause
        exit /b 1
    )

    echo.
    echo Instalando Python...
    winget install -e --id Python.Python.3.12 --accept-package-agreements --accept-source-agreements

    if exist "%LocalAppData%\Programs\Python\Python312\python.exe" (
        set "PYEXE=%LocalAppData%\Programs\Python\Python312\python.exe"
    ) else (
        where py >nul 2>nul
        if not errorlevel 1 set "PYEXE=py"
    )

    if not defined PYEXE (
        echo.
        echo [ATENCAO] O Python foi instalado, mas este terminal ainda nao o encontrou.
        echo Feche esta janela e rode o BAT novamente.
        pause
        exit /b 1
    )
)

echo [OK] Python encontrado: %PYEXE%
echo.

if not exist ".godot_ai_venv\Scripts\python.exe" (
    echo Criando ambiente virtual...
    "%PYEXE%" -m venv ".godot_ai_venv"
    if errorlevel 1 (
        echo [ERRO] Nao consegui criar o ambiente virtual.
        pause
        exit /b 1
    )
)

set "VPY=%CD%\.godot_ai_venv\Scripts\python.exe"

echo Instalando/atualizando dependencias...
"%VPY%" -m pip install --disable-pip-version-check --upgrade pip >nul
"%VPY%" -m pip install --disable-pip-version-check -r "godot_ai\requirements.txt"
if errorlevel 1 (
    echo [ERRO] Falha ao instalar as dependencias Python.
    pause
    exit /b 1
)

set "NEEDKEY=1"
if exist ".env" (
    findstr /B /C:"OPENAI_API_KEY=sk-" ".env" >nul 2>nul
    if not errorlevel 1 set "NEEDKEY=0"
)

if "%NEEDKEY%"=="1" (
    echo.
    echo ============================================================
    echo FALTA A CHAVE DA OPENAI
    echo ============================================================
    echo Crie/copiei sua API key na plataforma da OpenAI.
    echo Ela sera salva SOMENTE no arquivo local .env deste projeto.
    echo O .env sera adicionado ao .gitignore.
    echo Nao envie sua chave para outras pessoas.
    echo.
    set /p "APIKEY=Cole sua OPENAI_API_KEY aqui e pressione ENTER: "

    if not defined APIKEY (
        echo [ERRO] Nenhuma chave foi informada.
        pause
        exit /b 1
    )

    >".env" echo OPENAI_API_KEY=%APIKEY%
    >>".env" echo OPENAI_MODEL=gpt-5.6-luna
    echo [OK] Chave salva no .env local.
) else (
    echo [OK] Chave da API ja configurada no .env.
)

echo.
echo Configurando o plugin no projeto Godot...
"%VPY%" "godot_ai\setup_project.py"
if errorlevel 1 (
    pause
    exit /b 1
)

echo.
echo Iniciando o servidor da IA...
start "Godot AI Server" "%ComSpec%" /k call "%CD%\godot_ai\run_server.bat"

echo Aguardando o servidor iniciar...
timeout /t 4 /nobreak >nul

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "try { $r=Invoke-RestMethod -Uri 'http://127.0.0.1:8765/health' -TimeoutSec 4; if($r.status -eq 'ok'){exit 0}else{exit 1} } catch { exit 1 }"

if errorlevel 1 (
    echo.
    echo [ATENCAO] O servidor ainda nao respondeu.
    echo Veja a janela "Godot AI Server" para conferir o erro.
) else (
    echo [OK] Servidor da IA esta online.
)

echo.
echo ============================================================
echo PRONTO
echo ============================================================
echo.
echo 1. Se a Godot ja estava aberta, FECHE e ABRA o projeto novamente.
echo 2. O painel "OpenAI Assistant" aparecera no lado direito do editor.
echo 3. Deixe a janela "Godot AI Server" aberta.
echo 4. Nas proximas vezes, basta executar LIGAR_IA.bat.
echo.
pause
