param([string]$ServerName='.',[string]$DatabaseName='MARINE_SHIFT_RANGE_DW',[string]$DataFile='',[int]$MaxRejects=0,[string]$Dtexec='')
$ErrorActionPreference='Stop'
$taskRoot=Split-Path $PSScriptRoot -Parent
if (-not $DataFile) {$DataFile=Join-Path $taskRoot 'data\occurrence_clean.csv'}
$DataFile=(Resolve-Path -LiteralPath $DataFile).Path
if (-not $Dtexec) {
    $taskCandidate=Join-Path ${env:ProgramFiles} 'Microsoft SQL Server\170\DTS\Binn\DTExec.exe'
    if(Test-Path -LiteralPath $taskCandidate){$Dtexec=$taskCandidate}else{$Dtexec=(Get-Command dtexec -ErrorAction Stop).Source}
}
New-Item -ItemType Directory -Force -Path "$taskRoot\evidence\runs" | Out-Null
$taskLog=Join-Path "$taskRoot\evidence\runs" (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
Push-Location $taskRoot
try {
    & $Dtexec /FILE "$taskRoot\ssis\Package.dtsx" /SET "\Package.Variables[User::ServerName].Properties[Value];$ServerName" /SET "\Package.Variables[User::DatabaseName].Properties[Value];$DatabaseName" /SET "\Package.Variables[User::DataFile].Properties[Value];$DataFile" /SET "\Package.Variables[User::MaxRejects].Properties[Value];$MaxRejects" /REPORTING EWI 2>&1 | Tee-Object -FilePath "$taskLog.log"
    $taskExit=$LASTEXITCODE
    if($taskExit -ne 0){throw "SSIS execution failed (exit $taskExit). See $taskLog.log and etl.Batch/etl.Reject."}
} finally {Pop-Location}
