# ============================================================
# PARCHE DEFINITIVO: ENTER PARA CHAT (UIManager C++)
# ============================================================

$ErrorActionPreference = "Stop"
$baseDir = "C:\solaris\Source Client"
$luaFile = "C:\solaris\OTCV8\modules\game_chat\chat.lua"

function Write-Step($msg) { Write-Host "`n[>>>] $msg" -ForegroundColor Cyan }
function Write-OK($msg) { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Err($msg) { Write-Host "[X] $msg" -ForegroundColor Red }

# 1. INYECTAR FUNCION EN LUA (Para asegurar que exista)
Write-Step "1. Modificando chat.lua..."
if (Test-Path $luaFile) {
    $luaContent = Get-Content $luaFile -Raw
    if ($luaContent -notmatch "handleEnterKey") {
        $luaAdd = @"

-- PARCHE DEEPSEEK: MANEJADOR DE ENTER
function handleEnterKey()
    if not isActive() then
        toggleChat()
        textEdit:focus()
    end
    return true
end
"@
        Add-Content -Path $luaFile -Value $luaAdd
        Write-OK "Funcion handleEnterKey agregada a chat.lua."
    } else {
        Write-OK "La funcion handleEnterKey ya existe."
    }
}

# 2. INYECTAR CODIGO EN C++ (uimanager.cpp)
Write-Step "2. Modificando UIManager en C++..."
$fileToPatch = "$baseDir\src\framework\ui\uimanager.cpp"

if (Test-Path $fileToPatch) {
    $content = Get-Content $fileToPatch -Raw
    
    if ($content -match "PARCHE DEEPSEEK") {
        Write-OK "El parche ya estaba aplicado en uimanager.cpp."
    } else {
        # Buscamos exactamente el case de KeyDownInputEvent
        $originalCode = @"
        case Fw::KeyDownInputEvent:
            g_lua.callGlobalField("g_ui", "onKeyDown", event.keyCode, event.keyboardModifiers);
            m_keyboardReceiver->propagateOnKeyDown(event.keyCode, event.keyboardModifiers);
            break;
"@

        $patchedCode = @"
        case Fw::KeyDownInputEvent:
            // PARCHE DEEPSEEK: ENTER CHAT
            // Si es Enter, y el foco NO es una caja de texto (ej. el mapa), abrimos el chat
            if (event.keyCode == Fw::KeyEnter && m_keyboardReceiver && m_keyboardReceiver->getClassName() != "UITextEdit") {
                g_lua.callGlobalField("modules.game_chat", "handleEnterKey");
                break; // Consumimos la tecla para que no siga al mapa
            }
            g_lua.callGlobalField("g_ui", "onKeyDown", event.keyCode, event.keyboardModifiers);
            m_keyboardReceiver->propagateOnKeyDown(event.keyCode, event.keyboardModifiers);
            break;
"@

        if ($content -match [regex]::Escape($originalCode)) {
            Write-Host "Inyectando en $fileToPatch..." -ForegroundColor Yellow
            Copy-Item $fileToPatch "$fileToPatch.bak" -Force
            $content = $content -replace [regex]::Escape($originalCode), $patchedCode
            Set-Content -Path $fileToPatch -Value $content -NoNewline
            Write-OK "Parche C++ aplicado en uimanager.cpp."
        } else {
            Write-Err "No se encontro el bloque KeyDownInputEvent exacto. Revisa si el codigo tiene espacios diferentes."
            exit 1
        }
    }
} else {
    Write-Err "No se encontro uimanager.cpp."
    exit 1
}

# 3. COMPILAR
Write-Step "3. Compilando el cliente..."
$buildDir = "$baseDir\build"
if (-not (Test-Path $buildDir)) { New-Item -ItemType Directory -Path $buildDir | Out-Null }

Push-Location $buildDir
$vsCMake = "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
if (-not (Test-Path $vsCMake)) {
    $vsCMake = "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
}

& $vsCMake .. -DCMAKE_BUILD_TYPE=Release
& $vsCMake --build . --config Release
Pop-Location

Write-OK "¡PROCESO COMPLETADO!"
Write-Host "Busca el nuevo .exe en: $buildDir\Release\" -ForegroundColor Yellow