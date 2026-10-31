param([string]$ServerName='.',[string]$DatabaseName='MARINE_SHIFT_RANGE_DW')
$ErrorActionPreference='Stop'
$taskRoot=Split-Path $PSScriptRoot -Parent
$taskConnection=New-Object System.Data.SqlClient.SqlConnection("Server=$ServerName;Database=$DatabaseName;Integrated Security=True;TrustServerCertificate=True")
$taskConnection.Open()
function Read-Rows([string]$Query) {
    $taskCommand=$taskConnection.CreateCommand();$taskCommand.CommandText=$Query;$taskCommand.CommandTimeout=120
    $taskReader=$taskCommand.ExecuteReader();$taskRows=[Collections.Generic.List[object]]::new()
    try {while($taskReader.Read()) {
        $taskRow=[ordered]@{}
        for($taskIndex=0;$taskIndex -lt $taskReader.FieldCount;$taskIndex++) {
            $taskValue=$taskReader.GetValue($taskIndex)
            if($taskValue -is [DBNull]){$taskValue=$null}
            elseif($taskValue -is [byte[]]){$taskValue=[BitConverter]::ToString($taskValue).Replace('-','')}
            elseif($taskValue -is [datetime]){$taskValue=$taskValue.ToString('yyyy-MM-ddTHH:mm:ss.fffffff')}
            $taskRow[$taskReader.GetName($taskIndex)]=$taskValue
        }
        $taskRows.Add([pscustomobject]$taskRow)
    }} finally {$taskReader.Close();$taskCommand.Dispose()}
    return ,$taskRows.ToArray()
}
try {
    $taskTables=@('Dim_Date','Dim_Taxon','Dim_Location','Dim_Depth_Band','Dim_Quality','Fact_Occurrence')
    $taskEvidence=[ordered]@{captured_at_utc=[datetime]::UtcNow.ToString('o');database=$DatabaseName}
    $taskEvidence.counts=@{};$taskEvidence.digests=@{};$taskEvidence.samples=@{}
    foreach($taskTable in $taskTables) {
        $taskEvidence.counts[$taskTable]=(Read-Rows "SELECT COUNT_BIG(*) AS n FROM dbo.[$taskTable]")[0].n
        $taskEvidence.digests[$taskTable]=(Read-Rows "SELECT HASHBYTES('SHA2_256',(SELECT * FROM dbo.[$taskTable] ORDER BY id FOR JSON PATH,INCLUDE_NULL_VALUES)) AS digest")[0].digest
        $taskEvidence.samples[$taskTable]=Read-Rows "SELECT TOP(5) * FROM dbo.[$taskTable] ORDER BY id"
    }
    $taskEvidence.batches=Read-Rows 'SELECT batch_id,started_at,completed_at,status,source_rows,accepted_rows,rejected_rows,fact_rows,error_message FROM etl.Batch ORDER BY batch_id'
    $taskEvidence.taxonomy_conflicts=Read-Rows 'SELECT scientificName,variant_count,variants_json FROM etl.TaxonConflict WHERE batch_id=(SELECT batch_id FROM etl.SnapshotState WHERE singleton=1) ORDER BY scientificName'
    $taskEvidence.metrics=Read-Rows 'SELECT SUM(occurrence_count) AS occurrence_sum,SUM(individualCount) AS individual_sum,SUM(CASE WHEN depth IS NULL THEN 1 ELSE 0 END) AS missing_depth,SUM(CASE WHEN individualCount IS NULL THEN 1 ELSE 0 END) AS missing_individual_count FROM dbo.Fact_Occurrence'
    $taskEvidence.dates=Read-Rows 'SELECT MIN(event_date) AS first_date,MAX(event_date) AS last_date FROM dbo.Dim_Date'
    $taskEvidence | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath "$taskRoot\evidence\warehouse-validation.json" -Encoding utf8
    Write-Host 'Exported evidence/warehouse-validation.json'
} finally {$taskConnection.Close();$taskConnection.Dispose()}
