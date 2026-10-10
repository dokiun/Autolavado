param([string]$Workbook = 'Memoria_Calculo_Hidraulica_Completa.xlsx')
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskFile = [IO.Path]::GetFullPath((Join-Path $taskRoot $Workbook))
if (-not $taskFile.StartsWith($taskRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Workbook outside project' }
$taskExcel = $null
$taskBook = $null
try {
    $taskExcel = New-Object -ComObject Excel.Application
    $taskExcel.Visible = $false
    $taskExcel.DisplayAlerts = $false
    $taskExcel.AskToUpdateLinks = $false
    $taskExcel.AutomationSecurity = 3
    $taskBook = $taskExcel.Workbooks.Open($taskFile, 0, $false)
    $taskBook.ForceFullCalculation = $false
    $taskExcel.Calculation = -4105
    $taskExcel.CalculateFullRebuild()
    $taskDeadline = [DateTime]::UtcNow.AddSeconds(50)
    while ([int]$taskExcel.CalculationState -eq 1 -and [DateTime]::UtcNow -lt $taskDeadline) {
        Start-Sleep -Milliseconds 200
    }
    if ([int]$taskExcel.CalculationState -eq 1) { throw 'Excel still calculating' }
    $taskBook.Save()
    # Excel may report xlPending (2) even after synchronous full rebuild.
    # The validator checks every stored formula cache and error after Save.
    Write-Output ('Excel CalculationState after Save: ' + [int]$taskExcel.CalculationState)
    Write-Output 'Workbook recalculated and saved with Microsoft Excel.'
} finally {
    if ($taskBook) { $taskBook.Close($false); [void][Runtime.InteropServices.Marshal]::ReleaseComObject($taskBook) }
    if ($taskExcel) { $taskExcel.Quit(); [void][Runtime.InteropServices.Marshal]::ReleaseComObject($taskExcel) }
}
