param([string]$ServerName='.',[string]$DatabaseName='MARINE_SHIFT_RANGE_DW')
$ErrorActionPreference='Stop'
$taskRoot=Split-Path $PSScriptRoot -Parent
& sqlcmd -S $ServerName -E -d $DatabaseName -b -f 65001 -i "$taskRoot\sql\04_verify.sql"
if($LASTEXITCODE -ne 0){throw 'Initial SQL verification failed.'}
& "$taskRoot\scripts\export-evidence.ps1" -ServerName $ServerName -DatabaseName $DatabaseName
$taskBefore=Get-Content "$taskRoot\evidence\warehouse-validation.json" -Raw | ConvertFrom-Json
& "$taskRoot\scripts\run-etl.ps1" -ServerName $ServerName -DatabaseName $DatabaseName | Out-File "$taskRoot\evidence\rerun-test.log" -Encoding utf8
& "$taskRoot\scripts\export-evidence.ps1" -ServerName $ServerName -DatabaseName $DatabaseName
$taskAfter=Get-Content "$taskRoot\evidence\warehouse-validation.json" -Raw | ConvertFrom-Json
foreach($taskProperty in $taskBefore.digests.PSObject.Properties) {
    if($taskProperty.Value -ne $taskAfter.digests.($taskProperty.Name)){throw "Rerun changed $($taskProperty.Name)"}
}
# Supply a real malformed CSV to SSIS, exercising parsing, rejection and OnError.
$taskFixture=Join-Path $taskRoot 'evidence\invalid-fixture.csv'
$taskRows=Import-Csv -LiteralPath "$taskRoot\data\occurrence_clean.csv" | Select-Object -First 4
$taskRows[1].id=$taskRows[0].id
$taskRows[2].eventDate='31/02/2020'
$taskRows[3].sst='not-a-number'
$taskRows | Export-Csv -LiteralPath $taskFixture -NoTypeInformation -Encoding utf8BOM
$taskFailed=$false
try {& "$taskRoot\scripts\run-etl.ps1" -ServerName $ServerName -DatabaseName $DatabaseName -DataFile $taskFixture | Out-File "$taskRoot\evidence\reject-test.log" -Encoding utf8}
catch {$taskFailed=$true}
if(-not $taskFailed){throw 'Malformed CSV unexpectedly succeeded.'}
& "$taskRoot\scripts\export-evidence.ps1" -ServerName $ServerName -DatabaseName $DatabaseName
$taskRejected=Get-Content "$taskRoot\evidence\warehouse-validation.json" -Raw | ConvertFrom-Json
foreach($taskProperty in $taskAfter.digests.PSObject.Properties) {
    if($taskProperty.Value -ne $taskRejected.digests.($taskProperty.Name)){throw 'A rejected run modified the published warehouse.'}
}
& sqlcmd -S $ServerName -E -d $DatabaseName -b -Q "IF NOT EXISTS(SELECT 1 FROM etl.Batch WHERE batch_id=(SELECT MAX(batch_id) FROM etl.Batch) AND status='FAILED' AND source_rows=4 AND accepted_rows=1 AND rejected_rows=3) THROW 51200,'Reject audit mismatch.',1;"
if($LASTEXITCODE -ne 0){throw 'Reject audit did not match expected results.'}
# Restore working staging to the complete source and leave the final batch green.
& "$taskRoot\scripts\run-etl.ps1" -ServerName $ServerName -DatabaseName $DatabaseName | Out-File "$taskRoot\evidence\final-run.log" -Encoding utf8
& sqlcmd -S $ServerName -E -d $DatabaseName -b -f 65001 -i "$taskRoot\sql\04_verify.sql" | Tee-Object -FilePath "$taskRoot\evidence\sql-validation.txt"
if($LASTEXITCODE -ne 0){throw 'Final SQL verification failed.'}
& "$taskRoot\scripts\export-evidence.ps1" -ServerName $ServerName -DatabaseName $DatabaseName
[ordered]@{rerun_identical=$true;rejected_run_preserves_warehouse=$true;reject_rows=3;final_verification='PASS'} | ConvertTo-Json | Set-Content "$taskRoot\evidence\integration-tests.json" -Encoding utf8
Write-Host 'PASS: identical rerun, malformed CSV rejection, preserved snapshot, final reconciliation.'
