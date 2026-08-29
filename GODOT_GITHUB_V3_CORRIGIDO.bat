@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"

rem Mantem a janela aberta mesmo se alguma linha inesperada falhar.
if /I not "%~1"=="--interno" (
    start "Godot para GitHub" cmd /k call "%~f0" --interno
    exit /b
)

title Godot - GitHub (modo corrigido)

set "LOG=%CD%\github_setup_log.txt"
> "%LOG%" echo ==== Godot para GitHub ====
>>"%LOG%" echo Pasta: %CD%
>>"%LOG%" echo Data: %DATE% %TIME%

echo ============================================================
echo        GODOT ^> GITHUB - V3 CORRIGIDO
echo ============================================================
echo.
echo Esta janela NAO vai fechar sozinha.
echo Se houver erro, ele ficara visivel aqui.
echo.
echo Pasta:
echo %CD%
echo.

if not exist "project.godot" (
    echo [ERRO] project.godot nao encontrado.
    echo Coloque este BAT na raiz do projeto Godot.
    goto :FIM_ERRO
)

rem ------------------------------------------------------------
rem GIT
rem ------------------------------------------------------------
set "GITEXE="
where git >nul 2>nul
if not errorlevel 1 set "GITEXE=git"
if not defined GITEXE if exist "%ProgramFiles%\Git\cmd\git.exe" set "GITEXE=%ProgramFiles%\Git\cmd\git.exe"
if not defined GITEXE if exist "%ProgramFiles%\Git\bin\git.exe" set "GITEXE=%ProgramFiles%\Git\bin\git.exe"
if not defined GITEXE if exist "%LocalAppData%\Programs\Git\cmd\git.exe" set "GITEXE=%LocalAppData%\Programs\Git\cmd\git.exe"

if not defined GITEXE (
    echo [ERRO] Git nao encontrado.
    echo Instale Git for Windows e rode de novo:
    echo https://git-scm.com/download/win
    goto :FIM_ERRO
)

echo [OK] Git:
"%GITEXE%" --version
>>"%LOG%" echo Git OK

rem ------------------------------------------------------------
rem GH CLI - instalado ou portatil
rem ------------------------------------------------------------
set "GHEXE="
where gh >nul 2>nul
if not errorlevel 1 set "GHEXE=gh"
if not defined GHEXE if exist "%ProgramFiles%\GitHub CLI\gh.exe" set "GHEXE=%ProgramFiles%\GitHub CLI\gh.exe"
if not defined GHEXE if exist "%LocalAppData%\Programs\GitHub CLI\gh.exe" set "GHEXE=%LocalAppData%\Programs\GitHub CLI\gh.exe"

set "TOOLSDIR=%CD%\.github_tools"
set "GHROOT=%TOOLSDIR%\gh"
set "GHZIP=%TOOLSDIR%\gh.zip"

rem Procura copia portatil ja extraida.
if not defined GHEXE if exist "%GHROOT%" (
    for /f "delims=" %%G in ('dir /s /b "%GHROOT%\gh.exe" 2^>nul') do if not defined GHEXE set "GHEXE=%%G"
)

if not defined GHEXE (
    echo.
    echo GitHub CLI nao encontrado.
    echo Baixando a versao portatil oficial...
    echo.

    if not exist "%TOOLSDIR%" mkdir "%TOOLSDIR%"
    if exist "%GHROOT%" rmdir /s /q "%GHROOT%"
    mkdir "%GHROOT%"

    echo [1/3] Consultando versao mais recente...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "$ErrorActionPreference='Stop';" ^
      "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;" ^
      "$r=Invoke-RestMethod -Headers @{'User-Agent'='Godot-GitHub-Setup'} -Uri 'https://api.github.com/repos/cli/cli/releases/latest';" ^
      "$a=$r.assets | Where-Object { $_.name -match '^gh_.*_windows_amd64\.zip$' } | Select-Object -First 1;" ^
      "if(-not $a){throw 'Nao achei o ZIP windows_amd64.'};" ^
      "Write-Host ('Baixando ' + $a.name + ' ...');" ^
      "Invoke-WebRequest -UseBasicParsing -Headers @{'User-Agent'='Godot-GitHub-Setup'} -Uri $a.browser_download_url -OutFile '%GHZIP%';"
    if errorlevel 1 (
        echo [ERRO] Falha no download do GitHub CLI.
        >>"%LOG%" echo ERRO download GH CLI
        goto :FIM_ERRO
    )

    echo [2/3] Extraindo...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "$ErrorActionPreference='Stop';" ^
      "Expand-Archive -LiteralPath '%GHZIP%' -DestinationPath '%GHROOT%' -Force"
    if errorlevel 1 (
        echo [ERRO] Falha ao extrair o GitHub CLI.
        >>"%LOG%" echo ERRO extracao GH CLI
        goto :FIM_ERRO
    )

    echo [3/3] Procurando gh.exe...
    for /f "delims=" %%G in ('dir /s /b "%GHROOT%\gh.exe" 2^>nul') do if not defined GHEXE set "GHEXE=%%G"

    if not defined GHEXE (
        echo [ERRO] A extracao terminou, mas gh.exe nao foi encontrado.
        echo Conteudo da pasta:
        dir /s /b "%GHROOT%"
        >>"%LOG%" echo ERRO gh.exe nao encontrado
        goto :FIM_ERRO
    )

    del /q "%GHZIP%" >nul 2>nul
)

echo.
echo [OK] GitHub CLI encontrado em:
echo %GHEXE%
"%GHEXE%" --version
if errorlevel 1 (
    echo [ERRO] O gh.exe foi encontrado mas nao conseguiu iniciar.
    goto :FIM_ERRO
)
>>"%LOG%" echo GH CLI OK: %GHEXE%

rem ------------------------------------------------------------
rem LOGIN
rem ------------------------------------------------------------
echo.
echo Verificando login...
"%GHEXE%" auth status --hostname github.com >nul 2>nul
if errorlevel 1 (
    echo.
    echo ============================================================
    echo                    LOGIN NO GITHUB
    echo ============================================================
    echo.
    echo Agora o GitHub CLI vai mostrar um codigo e abrir o navegador.
    echo Autorize sua conta do GitHub.
    echo.
    "%GHEXE%" auth login --hostname github.com --git-protocol https --web
    if errorlevel 1 (
        echo [ERRO] Login nao concluido.
        >>"%LOG%" echo ERRO login
        goto :FIM_ERRO
    )
)

echo [OK] Login confirmado.

set "GHUSER="
set "GHID="
for /f "delims=" %%A in ('"%GHEXE%" api user --jq ".login" 2^>nul') do set "GHUSER=%%A"
for /f "delims=" %%A in ('"%GHEXE%" api user --jq ".id" 2^>nul') do set "GHID=%%A"

if not defined GHUSER (
    echo [ERRO] Nao consegui ler seu usuario do GitHub.
    goto :FIM_ERRO
)

echo Conta GitHub: !GHUSER!
>>"%LOG%" echo Usuario: !GHUSER!

rem ------------------------------------------------------------
rem GITIGNORE
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

rem ------------------------------------------------------------
rem REPOSITORIO LOCAL
rem ------------------------------------------------------------
if not exist ".git" (
    "%GITEXE%" init
    if errorlevel 1 goto :GIT_ERRO
)

"%GITEXE%" branch -M main >nul 2>nul

rem Remove segredos/temporarios caso tenham sido staged anteriormente.
"%GITEXE%" rm -r --cached --ignore-unmatch ".env" ".godot" ".godot_ai_venv" ".github_tools" "__pycache__" "Godot_OpenAI_Assistant.zip" "Godot_OpenAI_Assistant" >nul 2>nul

set "GITNAME="
set "GITEMAIL="
for /f "delims=" %%A in ('"%GITEXE%" config user.name 2^>nul') do set "GITNAME=%%A"
for /f "delims=" %%A in ('"%GITEXE%" config user.email 2^>nul') do set "GITEMAIL=%%A"

if not defined GITNAME "%GITEXE%" config user.name "!GHUSER!"
if not defined GITEMAIL (
    if defined GHID (
        "%GITEXE%" config user.email "!GHID!+!GHUSER!@users.noreply.github.com"
    ) else (
        "%GITEXE%" config user.email "!GHUSER!@users.noreply.github.com"
    )
)

echo.
echo Adicionando arquivos...
"%GITEXE%" add .
if errorlevel 1 goto :GIT_ERRO
"%GITEXE%" reset -- ".env" >nul 2>nul

"%GITEXE%" diff --cached --quiet
if errorlevel 1 (
    set "MSG="
    set /p "MSG=Mensagem do commit [Atualizacao do projeto Godot]: "
    if not defined MSG set "MSG=Atualizacao do projeto Godot"
    "%GITEXE%" commit -m "!MSG!"
    if errorlevel 1 goto :GIT_ERRO
) else (
    echo Nenhuma alteracao nova para commit.
)

rem ------------------------------------------------------------
rem REMOTE / CRIAR REPO
rem ------------------------------------------------------------
set "ORIGIN="
for /f "delims=" %%A in ('"%GITEXE%" remote get-url origin 2^>nul') do set "ORIGIN=%%A"

if not defined ORIGIN (
    for %%I in ("%CD%") do set "DEFAULT_REPO=%%~nxI"

    echo.
    echo ============================================================
    echo                  CRIAR REPOSITORIO
    echo ============================================================
    set "REPONAME="
    set /p "REPONAME=Nome do repositorio [!DEFAULT_REPO!]: "
    if not defined REPONAME set "REPONAME=!DEFAULT_REPO!"

    echo.
    echo [1] Privado ^(recomendado^)
    echo [2] Publico
    choice /C 12 /N /M "Escolha 1 ou 2: "
    if errorlevel 2 (set "VISIBILITY=public") else (set "VISIBILITY=private")

    "%GHEXE%" repo view "!GHUSER!/!REPONAME!" >nul 2>nul
    if not errorlevel 1 (
        echo Repositorio ja existe. Ligando...
        "%GITEXE%" remote add origin "https://github.com/!GHUSER!/!REPONAME!.git"
        if errorlevel 1 goto :GIT_ERRO
    ) else (
        echo Criando repositorio !VISIBILITY!...
        "%GHEXE%" repo create "!REPONAME!" --!VISIBILITY! --source "." --remote origin
        if errorlevel 1 goto :FIM_ERRO
    )
)

echo.
echo Enviando para o GitHub...
"%GITEXE%" push -u origin main
if errorlevel 1 goto :GIT_ERRO

set "FINALREMOTE="
for /f "delims=" %%A in ('"%GITEXE%" remote get-url origin') do set "FINALREMOTE=%%A"
set "WEBURL=!FINALREMOTE:.git=!"

echo.
echo ============================================================
echo                         PRONTO!
echo ============================================================
echo.
echo Seu projeto foi enviado para:
echo !WEBURL!
echo.
echo O arquivo .env NAO foi enviado.
echo A pasta .github_tools NAO foi enviada.
echo.
start "" "!WEBURL!"
>>"%LOG%" echo SUCESSO: !WEBURL!

goto :FIM_OK

:IGNORE
if not exist ".gitignore" type nul > ".gitignore"
findstr /X /C:"%~1" ".gitignore" >nul 2>nul
if errorlevel 1 >>".gitignore" echo %~1
exit /b

:GIT_ERRO
echo.
echo [ERRO] O Git encontrou um problema.
>>"%LOG%" echo ERRO Git
goto :FIM_ERRO

:FIM_ERRO
echo.
echo ============================================================
echo O processo parou por causa do erro mostrado acima.
echo Esta janela continuara aberta.
echo Log salvo em:
echo %LOG%
echo ============================================================
echo.
goto :EOF

:FIM_OK
echo.
echo Pode fechar esta janela quando quiser.
echo Nas proximas vezes execute este mesmo BAT para atualizar.
echo.
goto :EOF
