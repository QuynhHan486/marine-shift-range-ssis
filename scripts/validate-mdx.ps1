param(
 [string]$ServerName='localhost',
 [string]$DatabaseName='MARINE_SHIFT_RANGE_SSAS',
 [int[]]$QueryNumbers=@(),
 [string]$OutputDirectory='',
 [string]$ClientDirectory='C:\Program Files\Microsoft SQL Server Management Studio 22\Release\Common7\IDE',
 [int]$TimeoutSeconds=180
)
$ErrorActionPreference='Stop'
$taskRepo=Split-Path $PSScriptRoot -Parent
if(-not $OutputDirectory){$OutputDirectory=Join-Path $taskRepo ('evidence\runs\mdx-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
[void][System.Reflection.Assembly]::LoadFrom((Join-Path $ClientDirectory 'Microsoft.AnalysisServices.AdomdClient.dll'))
$taskConnection=New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection("Data Source=$ServerName;Initial Catalog=$DatabaseName")
$taskSummary=@()
try{
 $taskFiles=Get-ChildItem -LiteralPath (Join-Path $taskRepo 'mdx') -File -Filter '*.mdx' | Where-Object {$_.Name -match '^(0[1-9]|1[0-5])_'} | Sort-Object Name
 if($taskFiles.Count -ne 15){throw ('Expected 15 numbered MDX files; found '+$taskFiles.Count)}
 $taskNumbers=@($taskFiles | ForEach-Object {[int]$_.Name.Substring(0,2)} | Sort-Object -Unique)
 if($taskNumbers.Count -ne 15){throw 'MDX query numbers must be unique from 01 to 15'}
 if(@($QueryNumbers | Where-Object {$_ -notin $taskNumbers}).Count){throw 'QueryNumbers must be between 1 and 15'}
 $taskConnection.Open()
 foreach($taskFile in $taskFiles){
  $taskNumber=[int]$taskFile.Name.Substring(0,2)
  if($QueryNumbers.Count -gt 0 -and $taskNumber -notin $QueryNumbers){continue}
  Write-Output ('RUN '+$taskFile.Name)
  $taskWatch=[System.Diagnostics.Stopwatch]::StartNew()
  try{
   $taskCmd=$taskConnection.CreateCommand();$taskCmd.CommandText=Get-Content -LiteralPath $taskFile.FullName -Raw -Encoding UTF8;$taskCmd.CommandTimeout=$TimeoutSeconds
   $taskCells=$taskCmd.ExecuteCellSet()
   $taskColumns=@($taskCells.Axes[0].Positions | ForEach-Object {$_.Members[0].Caption})
   $taskRows=[System.Collections.Generic.List[object]]::new()
   for($taskR=0;$taskR -lt $taskCells.Axes[1].Positions.Count;$taskR++){
    $taskMembers=@($taskCells.Axes[1].Positions[$taskR].Members | ForEach-Object {@{unique_name=$_.UniqueName;caption=$_.Caption}})
    $taskValues=@();$taskFormatted=@()
    for($taskC=0;$taskC -lt $taskColumns.Count;$taskC++){
     $taskCell=$taskCells.Cells[$taskC,$taskR]
     if($taskCell.FormattedValue -eq '#Error'){throw ('Cell error at row '+$taskR+' column '+$taskC)}
     $taskValue=$taskCell.Value
     if($taskValue -is [System.DBNull]){$taskValue=$null}
     $taskValues+=,$taskValue;$taskFormatted+=,$taskCell.FormattedValue
    }
    $taskRows.Add(@{members=$taskMembers;values=$taskValues;formatted=$taskFormatted})
   }
   $taskWatch.Stop()
   $taskReport=@{query=$taskFile.Name;status='PASS';row_count=$taskRows.Count;column_count=$taskColumns.Count;columns=$taskColumns;elapsed_ms=$taskWatch.ElapsedMilliseconds;rows=$taskRows.ToArray()}
   $taskReport | ConvertTo-Json -Depth 12 -Compress | Set-Content -LiteralPath (Join-Path $OutputDirectory ($taskFile.BaseName+'.json')) -Encoding utf8
   $taskSummary+=@{query=$taskFile.Name;status='PASS';row_count=$taskRows.Count;column_count=$taskColumns.Count;elapsed_ms=$taskWatch.ElapsedMilliseconds}
   Write-Output ('PASS rows='+$taskRows.Count+' columns='+$taskColumns.Count+' elapsed_ms='+$taskWatch.ElapsedMilliseconds)
  }catch{
   $taskWatch.Stop();$taskErrorText=$_.Exception.ToString()
   $taskReport=@{query=$taskFile.Name;status='FAIL';error=$taskErrorText;elapsed_ms=$taskWatch.ElapsedMilliseconds}
   $taskReport | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputDirectory ($taskFile.BaseName+'.json')) -Encoding utf8
   $taskSummary+=$taskReport
   Write-Output ('FAIL '+$_.Exception.Message)
  }
  $taskSummary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'execution-summary.json') -Encoding utf8
 }
}finally{$taskConnection.Close()}
$taskFailures=@($taskSummary | Where-Object {$_.status -eq 'FAIL'})
Write-Output ('FINISHED queries='+$taskSummary.Count+' failures='+$taskFailures.Count+' output='+$OutputDirectory)
if($taskFailures.Count){exit 1}
