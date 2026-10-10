param(
    [string]$Compiler = '',
    [string]$Python = 'py'
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $taskRoot
try {
    if (-not $Compiler) {
        $taskOmc = Get-Command omc -ErrorAction SilentlyContinue
        if ($taskOmc) { $Compiler = $taskOmc.Source }
        else {
            $taskInstall = Get-ChildItem -LiteralPath $env:ProgramFiles -Directory -Filter 'OpenModelica*' |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if ($taskInstall) { $Compiler = Join-Path $taskInstall.FullName 'bin\omc.exe' }
        }
    }
    if (-not $Compiler -or -not (Test-Path -LiteralPath $Compiler)) {
        throw 'OpenModelica no encontrado. Indica -Compiler con la ruta a omc.exe.'
    }
    New-Item -ItemType Directory -Path 'verification/current' -Force | Out-Null
    $taskResult = 'verification/current/CurrentCycle_res.csv'
    $taskPrevious = if (Test-Path -LiteralPath $taskResult) { (Get-Item -LiteralPath $taskResult).LastWriteTimeUtc } else { [datetime]::MinValue }
    $taskOutput = & $Compiler 'verification/current_memory.mos' 2>&1
    $taskExit = $LASTEXITCODE
    $taskOutput | Set-Content -LiteralPath 'verification/current/simulation.log' -Encoding UTF8
    $taskOutput | Write-Output
    if ($taskExit -ne 0 -or ($taskOutput -match 'Failed to build model|LOG_ERROR|resultFile = ""|Error:')) {
        throw 'La simulacion fallo. Revisa verification/current/simulation.log.'
    }
    if (-not (Test-Path -LiteralPath $taskResult) -or (Get-Item -LiteralPath $taskResult).LastWriteTimeUtc -le $taskPrevious) {
        throw 'No se genero un resultado nuevo.'
    }
    $taskPythonArgs = @()
    if ([IO.Path]::GetFileNameWithoutExtension($Python) -eq 'py') { $taskPythonArgs = @('-3') }
    & $Python @taskPythonArgs 'verification/validate_current.py'
    if ($LASTEXITCODE -ne 0) { throw 'Fallo la validacion del ciclo actual.' }
    & $Python @taskPythonArgs 'verification/report_current.py'
    if ($LASTEXITCODE -ne 0) { throw 'Fallo la generacion del Excel.' }
    & $Python @taskPythonArgs 'verification/plot_current.py'
    if ($LASTEXITCODE -ne 0) { throw 'Fallo la generacion de las graficas.' }
} finally {
    Pop-Location
}
