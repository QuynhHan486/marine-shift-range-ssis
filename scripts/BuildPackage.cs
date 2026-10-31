using System;
using System.IO;
using System.Collections.Generic;
using Microsoft.SqlServer.Dts.Runtime;
using Microsoft.SqlServer.Dts.Pipeline.Wrapper;
using DataType = Microsoft.SqlServer.Dts.Runtime.Wrapper.DataType;
using IDTSName100 = Microsoft.SqlServer.Dts.Runtime.Wrapper.IDTSName100;
using IDTSConnectionManagerFlatFile100 = Microsoft.SqlServer.Dts.Runtime.Wrapper.IDTSConnectionManagerFlatFile100;
using IDTSConnectionManagerFlatFileColumn100 = Microsoft.SqlServer.Dts.Runtime.Wrapper.IDTSConnectionManagerFlatFileColumn100;
using Microsoft.SqlServer.Dts.Tasks.ExecuteSQLTask;

// Build actual SSIS components through Microsoft's runtime, then persist .dtsx.
class BuildPackage {
 static Package pkg;
 static ConnectionManager warehouse, audit;
 static TaskHost previous;
 static Application app;
 static string[] cols = {"id","country","decimalLatitude","decimalLongitude","latitude_band","shoredistance","eventDate","depth","depth_band","sst","sss","flags","flag_on_land","kingdom","phylum","class","order","family","genus","species","scientificName","occurrenceStatus","individualCount"};
 static string Component(string name) {
  foreach(PipelineComponentInfo info in app.PipelineComponentInfos) if(info.Name==name) return info.CreationName;
  throw new Exception("SSIS component missing: "+name);
 }
 static void Connect(TaskHost task) {
  task.DelayValidation = true;
  if(previous!=null) pkg.PrecedenceConstraints.Add(previous,task).Value=DTSExecResult.Success;
  previous=task;
 }
 static TaskHost Sql(string name, string statement) {
  TaskHost h=(TaskHost)pkg.Executables.Add("Microsoft.ExecuteSQLTask");h.Name=name;
  h.Properties["Connection"].SetValue(h,audit.ID);
  h.Properties["SqlStatementSource"].SetValue(h,statement);
  h.Properties["BypassPrepare"].SetValue(h,true);
  Connect(h);return h;
 }
 static void Param(TaskHost h,string variable,string name,int type) {
  IDTSExecuteSQL inner=(IDTSExecuteSQL)h.InnerObject;
  IDTSParameterBinding b=inner.ParameterBindings.Add();b.DtsVariableName=variable;b.ParameterName=name;
  b.ParameterDirection=ParameterDirections.Input; b.DataType=type; b.ParameterSize=-1;
 }
 static void Wire(IDTSComponentMetaData100 component,ConnectionManager connection) {
  component.RuntimeConnectionCollection[0].ConnectionManagerID=connection.ID;
  component.RuntimeConnectionCollection[0].ConnectionManager=DtsConvert.GetExtendedInterface(connection);
 }
 static void Metadata(CManagedComponentWrapper component) {
  component.AcquireConnections(null);component.ReinitializeMetaData();component.ReleaseConnections();
 }
 static void Destination(MainPipe pipe,IDTSComponentMetaData100 source,string table) {
  IDTSComponentMetaData100 meta=pipe.ComponentMetaDataCollection.New();meta.Name="OLE DB Destination - "+table.Replace('.','_');
  meta.ComponentClassID=Component("OLE DB Destination");
  CManagedComponentWrapper dest=meta.Instantiate();dest.ProvideComponentProperties();Wire(meta,warehouse);
  dest.SetComponentProperty("AccessMode",3);dest.SetComponentProperty("OpenRowset",table);
  dest.SetComponentProperty("FastLoadOptions","TABLOCK,CHECK_CONSTRAINTS");
  dest.SetComponentProperty("FastLoadMaxInsertCommitSize",0);
  Metadata(dest);
  pipe.PathCollection.New().AttachPathAndPropagateNotifications(source.OutputCollection[0],meta.InputCollection[0]);
  IDTSInput100 input=meta.InputCollection[0];IDTSVirtualInput100 virtualInput=input.GetVirtualInput();
  foreach(IDTSVirtualInputColumn100 col in virtualInput.VirtualInputColumnCollection) {
   IDTSInputColumn100 selected=dest.SetUsageType(input.ID,virtualInput,col.LineageID,DTSUsageType.UT_READONLY);
   foreach(IDTSExternalMetadataColumn100 external in input.ExternalMetadataColumnCollection)
    if(external.Name==col.Name) dest.MapInputColumn(input.ID,selected.ID,external.ID);
  }
 }
 static TaskHost Flow(string name) {
  TaskHost host=(TaskHost)pkg.Executables.Add("STOCK:PipelineTask");host.Name=name;Connect(host);return host;
 }
 static void LoadTable(string table) {
  TaskHost host=Flow("DFT Load "+table);MainPipe pipe=(MainPipe)host.InnerObject;
  IDTSComponentMetaData100 meta=pipe.ComponentMetaDataCollection.New();meta.Name="OLE DB Source - "+table;
  meta.ComponentClassID=Component("OLE DB Source");
  CManagedComponentWrapper src=meta.Instantiate();src.ProvideComponentProperties();Wire(meta,warehouse);
  src.SetComponentProperty("AccessMode",2);
  src.SetComponentProperty("SqlCommand","SELECT * FROM etl.v_Load"+table+";");Metadata(src);
  Destination(pipe,meta,"load."+table);
 }
 public static void Main(string[] args) {
  string root=Path.GetFullPath(args[0]);string server=args.Length>1?args[1]:".";
  string database=args.Length>2?args[2]:"MARINE_SHIFT_RANGE_DW";
  app=new Application();pkg=new Package();pkg.Name="MarineShiftETL";
  pkg.Description="OBIS CSV -> staging -> five dimensions -> occurrence fact -> atomic publish and audit";
  pkg.ProtectionLevel=DTSProtectionLevel.DontSaveSensitive;
  pkg.TransactionOption=DTSTransactionOption.NotSupported;pkg.MaxConcurrentExecutables=1;
  pkg.Variables.Add("ServerName",false,"User",server);
  pkg.Variables.Add("DatabaseName",false,"User",database);
  pkg.Variables.Add("DataFile",false,"User","data\\occurrence_clean.csv");
  pkg.Variables.Add("MaxRejects",false,"User",0);
  pkg.Variables.Add("BatchId",false,"User",(long)0);
  string cs="Provider=MSOLEDBSQL;Data Source="+server+";Initial Catalog="+database+";Integrated Security=SSPI;Auto Translate=False;";
  warehouse=pkg.Connections.Add("OLEDB");warehouse.Name="Warehouse";warehouse.ConnectionString=cs;
  audit=pkg.Connections.Add("OLEDB");audit.Name="AuditSession";audit.ConnectionString=cs;audit.Properties["RetainSameConnection"].SetValue(audit,true);
  foreach(ConnectionManager c in new[]{warehouse,audit}) c.SetExpression("ConnectionString","\"Provider=MSOLEDBSQL;Data Source=\" + @[User::ServerName] + \";Initial Catalog=\" + @[User::DatabaseName] + \";Integrated Security=SSPI;Auto Translate=False;\"");
  TaskHost begin=Sql("SQL Begin Batch","EXEC etl.usp_BeginBatch ?;");Param(begin,"User::DataFile","0",130);
  ((IDTSExecuteSQL)begin.InnerObject).ResultSetType=ResultSetType.ResultSetType_SingleRow;
  IDTSExecuteSQL beginInner=(IDTSExecuteSQL)begin.InnerObject;IDTSResultBinding result=beginInner.ResultSetBindings.Add();result.ResultName="0";result.DtsVariableName="User::BatchId";
  Sql("SQL Clear Working Tables","EXEC etl.usp_ClearWorking;");
  ConnectionManager csv=pkg.Connections.Add("FLATFILE");csv.Name="OBIS Clean CSV";
  csv.ConnectionString=Path.Combine(root,"data","occurrence_clean.csv");csv.SetExpression("ConnectionString","@[User::DataFile]");
  IDTSConnectionManagerFlatFile100 ff=(IDTSConnectionManagerFlatFile100)csv.InnerObject;
  ff.Format="Delimited";ff.CodePage=65001;ff.Unicode=false;ff.TextQualifier="\"";
  ff.HeaderRowsToSkip=0;ff.ColumnNamesInFirstDataRow=true;ff.RowDelimiter="\r\n";
  for(int i=0;i<cols.Length;i++) {
   IDTSConnectionManagerFlatFileColumn100 col=ff.Columns.Add();((IDTSName100)col).Name=cols[i];
   col.ColumnType="Delimited";col.ColumnDelimiter=i==cols.Length-1?"\r\n":",";
   col.DataType=DataType.DT_WSTR;col.MaximumWidth=512;col.TextQualified=true;
  }
  TaskHost raw=Flow("DFT CSV to Raw Staging");MainPipe rawPipe=(MainPipe)raw.InnerObject;
  IDTSComponentMetaData100 rawMeta=rawPipe.ComponentMetaDataCollection.New();rawMeta.Name="Flat File Source - UTF8 CSV";rawMeta.ComponentClassID=Component("Flat File Source");
  CManagedComponentWrapper rawSrc=rawMeta.Instantiate();rawSrc.ProvideComponentProperties();Wire(rawMeta,csv);Metadata(rawSrc);
  Destination(rawPipe,rawMeta,"etl.Stg_OccurrenceRaw");
  TaskHost validate=Sql("SQL Validate and Transform","EXEC etl.usp_ValidateStage ?,?;");Param(validate,"User::BatchId","0",20);Param(validate,"User::MaxRejects","1",3);
  foreach(string table in new[]{"Dim_Date","Dim_Taxon","Dim_Location","Dim_Depth_Band","Dim_Quality","Fact_Occurrence"}) LoadTable(table);
  TaskHost publish=Sql("SQL Reconcile and Publish","EXEC etl.usp_Publish ?;");Param(publish,"User::BatchId","0",20);
  DtsEventHandler onError=(DtsEventHandler)pkg.EventHandlers.Add("OnError");
  TaskHost failure=(TaskHost)onError.Executables.Add("Microsoft.ExecuteSQLTask");failure.Name="SQL Record Failure";failure.DelayValidation=true;
  failure.Properties["Connection"].SetValue(failure,audit.ID);
  failure.Properties["SqlStatementSource"].SetValue(failure,"EXEC etl.usp_FailBatch ?,?;");failure.Properties["BypassPrepare"].SetValue(failure,true);
  Param(failure,"User::BatchId","0",20);Param(failure,"System::ErrorDescription","1",130);
  // The saved package keeps a relative source path; run-etl.ps1 supplies an absolute override.
  string target=Path.Combine(root,"ssis","Package.dtsx");app.SaveToXml(target,pkg,null);
  Console.WriteLine("Saved "+target+" with "+pkg.Executables.Count+" control-flow tasks.");
 }
}
