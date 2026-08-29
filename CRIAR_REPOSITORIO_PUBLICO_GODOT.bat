@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"

if /I not "%~1"=="--interno" (
    start "Godot para GitHub Publico" cmd /k call "%~f0" --interno
    exit /b
)

title Godot - Criar repositorio PUBLICO

echo ============================================================
echo       GODOT ^> NOVO REPOSITORIO PUBLICO NO GITHUB
echo ============================================================
echo.
echo Este BAT cria um NOVO repositorio PUBLICO sem apagar o
echo repositorio privado que voce ja tem.
echo.
echo A chave .env e arquivos temporarios serao ignorados.
echo.

if not exist "project.godot" (
    echo [ERRO] Nao encontrei project.godot.
    echo Coloque este BAT na raiz do projeto Godot.
    goto :FIM
)

rem ------------------------------------------------------------
rem LOCALIZAR GIT
rem ------------------------------------------------------------
set "GITEXE="
where git >nul 2>nul
if not errorlevel 1 set "GITEXE=git"
if not defined GITEXE if exist "%ProgramFiles%\Git\cmd\git.exe" set "GITEXE=%ProgramFiles%\Git\cmd\git.exe"
if not defined GITEXE if exist "%ProgramFiles%\Git\bin\git.exe" set "GITEXE=%ProgramFiles%\Git\bin\git.exe"
if not defined GITEXE if exist "%LocalAppData%\Programs\Git\cmd\git.exe" set "GITEXE=%LocalAppData%\Programs\Git\cmd\git.exe"

if not defined GITEXE (
    echo [ERRO] Git nao encontrado.
    goto :FIM
)

echo [OK] Git:
"%GITEXE%" --version
echo.

rem ------------------------------------------------------------
rem LOCALIZAR GITHUB CLI
rem ------------------------------------------------------------
set "GHEXE="
where gh >nul 2>nul
if not errorlevel 1 set "GHEXE=gh"
if not defined GHEXE if exist "%ProgramFiles%\GitHub CLI\gh.exe" set "GHEXE=%ProgramFiles%\GitHub CLI\gh.exe"
if not defined GHEXE if exist "%LocalAppData%\Programs\GitHub CLI\gh.exe" set "GHEXE=%LocalAppData%\Programs\GitHub CLI\gh.exe"

set "TOOLSDIR=%CD%\.github_tools"
set "GHROOT=%TOOLSDIR%\gh"
set "GHZIP=%TOOLSDIR%\gh.zip"

if not defined GHEXE if exist "%GHROOT%\bin\gh.exe" set "GHEXE=%GHROOT%\bin\gh.exe"

if not defined GHEXE if exist "%GHROOT%" (
    for /f "delims=" %%G in ('dir /s /b "%GHROOT%\gh.exe" 2^>nul') do (
        if not defined GHEXE set "GHEXE=%%G"
    )
)

if not defined GHEXE (
    echo GitHub CLI nao encontrado. Baixando copia portatil oficial...
    if not exist "%TOOLSDIR%" mkdir "%TOOLSDIR%"
    if exist "%GHROOT%" rmdir /s /q "%GHROOT%"
    mkdir "%GHROOT%"

    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "$ErrorActionPreference='Stop';" ^
      "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
      "$r=Invoke-RestMethod -Headers @{'User-Agent'='Godot-GitHub-Public'} -Uri 'https://api.github.com/repos/cli/cli/releases/latest';" ^
      "$a=$r.assets | Where-Object { $_.name -match '^gh_.*_windows_amd64\.zip$' } | Select-Object -First 1;" ^
      "if(-not $a){throw 'Nao achei o ZIP windows_amd64.'};" ^
      "Write-Host ('Baixando ' + $a.name + ' ...');" ^
      "Invoke-WebRequest -UseBasicParsing -Headers @{'User-Agent'='Godot-GitHub-Public'} -Uri $a.browser_download_url -OutFile '%GHZIP%';"

    if errorlevel 1 (
        echo [ERRO] Falha ao baixar o GitHub CLI.
        goto :FIM
    )

    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "$ErrorActionPreference='Stop'; Expand-Archive -LiteralPath '%GHZIP%' -DestinationPath '%GHROOT%' -Force"
    if errorlevel 1 (
        echo [ERRO] Falha ao extrair o GitHub CLI.
        goto :FIM
    )

    del /q "%GHZIP%" >nul 2>nul

    if exist "%GHROOT%\bin\gh.exe" set "GHEXE=%GHROOT%\bin\gh.exe"
    if not defined GHEXE (
        for /f "delims=" %%G in ('dir /s /b "%GHROOT%\gh.exe" 2^>nul') do (
            if not defined GHEXE set "GHEXE=%%G"
        )
    )
)

if not defined GHEXE (
    echo [ERRO] gh.exe nao encontrado.
    goto :FIM
)

echo [OK] GitHub CLI:
"%GHEXE%" --version
echo.

rem ------------------------------------------------------------
rem LOGIN
rem ------------------------------------------------------------
"%GHEXE%" auth status --hostname github.com >nul 2>nul
if errorlevel 1 (
    echo Fazendo login no GitHub...
    "%GHEXE%" auth login --hostname github.com --git-protocol https --web
    if errorlevel 1 (
        echo [ERRO] Login nao concluido.
        goto :FIM
    )
)

set "TMPUSER=%TEMP%\godot_gh_user_%RANDOM%.txt"
"%GHEXE%" api user --jq .login > "%TMPUSER%" 2>nul
set "GHUSER="
if exist "%TMPUSER%" set /p GHUSER=<"%TMPUSER%"
del /q "%TMPUSER%" >nul 2>nul

if not defined GHUSER (
    echo [ERRO] Nao consegui identificar sua conta do GitHub.
    goto :FIM
)

echo [OK] Conta: !GHUSER!
echo.

rem ------------------------------------------------------------
rem PROTEGER ARQUIVOS PRIVADOS/TEMPORARIOS
rem ------------------------------------------------------------
call :IGNORE ".env"
call :IGNORE ".godot/"
call :IGNORE ".godot_ai_venv/"
call :IGNORE ".github_tools/"
call :IGNORE "__pycache__/"
call :IGNORE "*.pyc"
call :IGNORE "*.bak_openai_assistant"
call :IGNORE "Godot_OpenAI_Assistant.zip"
call :IGNORE "Godot_OpenAI_Assistant/"
call :IGNORE "github_setup_log.txt"
call :IGNORE ".gitignoregit"

if not exist ".git" (
    "%GITEXE%" init
    if errorlevel 1 goto :GIT_ERRO
)

"%GITEXE%" branch -M main >nul 2>nul
"%GITEXE%" rm -r --cached --ignore-unmatch ".env" ".godot" ".godot_ai_venv" ".github_tools" "__pycache__" "Godot_OpenAI_Assistant.zip" "Godot_OpenAI_Assistant" "github_setup_log.txt" ".gitignoregit" >nul 2>nul

rem ------------------------------------------------------------
rem CHECAGEM SIMPLES DE SEGREDOS
rem ------------------------------------------------------------
echo Verificando se existe chave/token aparente nos arquivos rastreados...
set "SECRETS_FOUND=0"

"%GITEXE%" grep -n -E "sk-(proj-)?[A-Za-z0-9_-]{20,}" -- . > "%TEMP%\godot_secret_scan.txt" 2>nul
if not errorlevel 1 set "SECRETS_FOUND=1"

"%GITEXE%" grep -n -E "ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}" -- . >> "%TEMP%\godot_secret_scan.txt" 2>nul
if not errorlevel 1 set "SECRETS_FOUND=1"

if "!SECRETS_FOUND!"=="1" (
    echo.
    echo [BLOQUEADO] Encontrei algo parecido com chave/token:
    type "%TEMP%\godot_secret_scan.txt"
    del /q "%TEMP%\godot_secret_scan.txt" >nul 2>nul
    echo.
    echo Por seguranca, o repositorio PUBLICO NAO foi criado.
    echo Remova a chave/token do arquivo e rode novamente.
    goto :FIM
)
del /q "%TEMP%\godot_secret_scan.txt" >nul 2>nul
echo [OK] Nenhuma chave/token obvia encontrada.
echo.

rem ------------------------------------------------------------
rem COMMIT ATUAL
rem ------------------------------------------------------------
"%GITEXE%" add .
if errorlevel 1 goto :GIT_ERRO

"%GITEXE%" reset -- ".env" >nul 2>nul
"%GITEXE%" reset -- ".github_tools" >nul 2>nul
"%GITEXE%" reset -- "github_setup_log.txt" >nul 2>nul
"%GITEXE%" reset -- ".gitignoregit" >nul 2>nul

"%GITEXE%" diff --cached --quiet
if errorlevel 1 (
    echo Criando commit com as alteracoes atuais...
    "%GITEXE%" commit -m "Atualizacao antes de publicar projeto"
    if errorlevel 1 goto :GIT_ERRO
)

rem ------------------------------------------------------------
rem NOME DO NOVO REPOSITORIO PUBLICO
rem ------------------------------------------------------------
for %%I in ("%CD%") do set "DEFAULT_REPO=%%~nxI-publico"

echo ============================================================
echo              NOVO REPOSITORIO PUBLICO
echo ============================================================
echo.
set "REPONAME="
set /p "REPONAME=Nome do repositorio publico [!DEFAULT_REPO!]: "
if not defined REPONAME set "REPONAME=!DEFAULT_REPO!"

echo.
echo O repositorio sera PUBLICO:
echo https://github.com/!GHUSER!/!REPONAME!
echo.
choice /C SN /N /M "Continuar e deixar o projeto visivel para qualquer pessoa? [S/N]: "
if errorlevel 2 (
    echo Cancelado. Nada foi publicado.
    goto :FIM
)

rem ------------------------------------------------------------
rem CHECAR / CRIAR REPO
rem ------------------------------------------------------------
"%GHEXE%" repo view "!GHUSER!/!REPONAME!" >nul 2>nul
if not errorlevel 1 (
    echo.
    echo [ERRO] Ja existe um repositorio chamado !REPONAME!.
    echo Rode de novo e escolha outro nome.
    goto :FIM
)

echo.
echo Criando repositorio PUBLICO...
"%GHEXE%" repo create "!REPONAME!" --public --description "Projeto Godot" --confirm
if errorlevel 1 (
    echo [ERRO] Nao consegui criar o repositorio.
    goto :FIM
)

rem Preserva o origin privado. Usa um remote separado chamado "publico".
"%GITEXE%" remote remove publico >nul 2>nul
"%GITEXE%" remote add publico "https://github.com/!GHUSER!/!REPONAME!.git"
if errorlevel 1 goto :GIT_ERRO

echo.
echo Enviando branch main para o repositorio PUBLICO...
"%GITEXE%" push -u publico main
if errorlevel 1 goto :GIT_ERRO

echo.
echo ============================================================
echo                         PRONTO!
echo ============================================================
echo.
echo Repositorio PUBLICO criado:
echo https://github.com/!GHUSER!/!REPONAME!
echo.
echo O repositorio privado original foi mantido.
echo O novo remote se chama: publico
echo.
start "" "https://github.com/!GHUSER!/!REPONAME!"
goto :FIM

:IGNORE
if not exist ".gitignore" type nul > ".gitignore"
findstr /X /C:"%~1" ".gitignore" >nul 2>nul
if errorlevel 1 >>".gitignore" echo %~1
exit /b

:GIT_ERRO
echo.
echo [ERRO] O Git encontrou um problema.
echo Nada foi apagado do seu computador.
echo.

:FIM
echo.
echo Pode fechar esta janela quando quiser.
echo.
goto :EOF
