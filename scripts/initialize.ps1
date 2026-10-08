param([string]$ServerName='.',[ValidatePattern('^[A-Za-z][A-Za-z0-9_]{0,127}$')][string]$DatabaseName='MARINE_SHIFT_RANGE_DW')
$ErrorActionPreference='Stop'
$taskRoot=Split-Path $PSScriptRoot -Parent
& sqlcmd -S $ServerName -E -d master -b -l 15 -Q "IF DB_ID(N'$DatabaseName') IS NULL CREATE DATABASE [$DatabaseName];"
if ($LASTEXITCODE -ne 0) {throw 'Cannot create or connect to target database.'}
foreach ($taskFile in @('01_schema.sql','02_views.sql','03_procedures.sql')) {
    & sqlcmd -S $ServerName -E -d $DatabaseName -b -f 65001 -i "$taskRoot\sql\$taskFile"
    if ($LASTEXITCODE -ne 0) {throw "Failed to initialize $taskFile"}
}
Write-Host "Ready: $ServerName / $DatabaseName"
