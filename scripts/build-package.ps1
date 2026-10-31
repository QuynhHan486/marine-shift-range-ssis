param([string]$ServerName='.',[string]$DatabaseName='MARINE_SHIFT_RANGE_DW')
$ErrorActionPreference='Stop'
$taskRoot=Split-Path $PSScriptRoot -Parent
$taskSdk='C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\SSIS\170\Binn'
if (-not (Test-Path -LiteralPath "$taskSdk\Microsoft.SqlServer.ManagedDTS.dll")) {
    throw 'Edit $taskSdk to point to the SQL Server 2025 SSIS SDK Binn directory.'
}
New-Item -ItemType Directory -Force -Path "$taskRoot\bin" | Out-Null
$taskRefs=@('Microsoft.SqlServer.ManagedDTS.dll','Microsoft.SQLServer.DTSPipelineWrap.dll','Microsoft.SqlServer.DTSRuntimeWrap.dll','Microsoft.SQLServer.PipelineHost.dll')
$taskArgs=@('/nologo','/target:exe',"/out:$taskRoot\bin\BuildPackage.exe",'/r:Microsoft.CSharp.dll')
foreach($taskRef in $taskRefs) {
    $taskAssemblyName=[IO.Path]::GetFileNameWithoutExtension($taskRef)
    $taskGac=Get-ChildItem "$env:WINDIR\Microsoft.NET\assembly\GAC_64\$taskAssemblyName\v4.0_17.0.0.0*\$taskRef","$env:WINDIR\Microsoft.NET\assembly\GAC_MSIL\$taskAssemblyName\v4.0_17.0.0.0*\$taskRef" -ErrorAction SilentlyContinue | Select-Object -First 1
    if($taskGac){$taskArgs+="/r:$($taskGac.FullName)"}else{$taskArgs+="/r:$taskSdk\$taskRef"}
}
$taskArgs+="$PSScriptRoot\BuildPackage.cs"
$taskArgs+='/r:C:\Program Files\Microsoft SQL Server\170\DTS\Tasks\Microsoft.SqlServer.SQLTask.dll'
& "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" @taskArgs
if($LASTEXITCODE -ne 0){throw 'SSIS builder compilation failed.'}
Push-Location $taskRoot
try {
    & "$taskRoot\bin\BuildPackage.exe" $taskRoot $ServerName $DatabaseName
    if($LASTEXITCODE -ne 0){throw 'SSIS package generation failed.'}
    [xml]$taskPackageXml=Get-Content -LiteralPath "$taskRoot\ssis\Package.dtsx" -Raw
    [xml]$taskProjectXml=Get-Content -LiteralPath "$taskRoot\ssis\MARINE_SHIFT_RANGE_SSIS.dtproj" -Raw
    $taskNs=[Xml.XmlNamespaceManager]::new($taskProjectXml.NameTable)
    $taskNs.AddNamespace('s','www.microsoft.com/SqlServer/SSIS')
    $taskMetadata=$taskProjectXml.SelectSingleNode('//s:PackageMetaData/s:Properties',$taskNs)
    $taskMap=@{ID='DTSID';Name='ObjectName';VersionGUID='VersionGUID'}
    foreach($taskKey in $taskMap.Keys) {
        $taskNode=$taskMetadata.SelectSingleNode("s:Property[@s:Name='$taskKey']",$taskNs)
        $taskNode.InnerText=$taskPackageXml.DocumentElement.GetAttribute($taskMap[$taskKey],'www.microsoft.com/SqlServer/Dts')
    }
    $taskProjectXml.Save("$taskRoot\ssis\MARINE_SHIFT_RANGE_SSIS.dtproj")
} finally {Pop-Location}
