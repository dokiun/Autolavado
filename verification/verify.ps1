param(
    [ValidateSet('verification/injection.mos','verification/haceb.mos')]
    [string]$Script = 'verification/injection.mos',
    [string]$Compiler = 'C:\Program Files\OpenModelica1.27.1-64bit\bin\omc.exe',
    [string]$Python = 'C:\Users\Mateo\AppData\Local\Programs\Python\Python313\python.exe'
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $taskRoot
$taskBuild = Join-Path $PSScriptRoot 'build'
New-Item -ItemType Directory -Path $taskBuild, (Join-Path $PSScriptRoot 'results') -Force | Out-Null
& $Compiler $Script 2>&1 | Tee-Object -FilePath (Join-Path $taskBuild 'verification.log') | Tee-Object -Variable taskOutput
$taskExit = $LASTEXITCODE
if ($taskExit -ne 0 -or ($taskOutput -match 'Error:|Failed to build model|LOG_ERROR|resultFile = ""')) { exit 1 }
$taskValidator = if ($Script -eq 'verification/haceb.mos') { 'validate_haceb.py' } else { 'validate_injection.py' }
& $Python (Join-Path $PSScriptRoot $taskValidator)
if ($LASTEXITCODE -ne 0) { exit 1 }
if ($Script -eq 'verification/injection.mos') {
    & $Python (Join-Path $PSScriptRoot 'plot_injection.py')
    if ($LASTEXITCODE -ne 0) { exit 1 }
}
Write-Output 'Verificacion completa. Informes y grafica en verification/results; compilacion temporal en verification/build.'
exit 0
