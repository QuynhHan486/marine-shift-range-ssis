"""Generate versioned SQL Server DDL and transformations. No third-party packages."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RAW_COLUMNS = ['id','country','decimalLatitude','decimalLongitude','latitude_band','shoredistance','eventDate','depth','depth_band','sst','sss','flags','flag_on_land','flag_marine_unsure','kingdom','phylum','class','order','family','genus','species','scientificName','occurrenceStatus','individualCount']
TABLES = {
 'Dim_Date': '''id int NOT NULL PRIMARY KEY, event_date date NOT NULL UNIQUE,
 [year] int NOT NULL, decade nvarchar(10) NOT NULL, [quarter] nvarchar(2) NOT NULL,
 [month] int NOT NULL, season nvarchar(10) NOT NULL''',
 'Dim_Taxon': '''id int NOT NULL PRIMARY KEY, kingdom nvarchar(256) NULL, phylum nvarchar(256) NULL,
 [class] nvarchar(256) NULL, [order] nvarchar(256) NULL, family nvarchar(256) NULL,
 genus nvarchar(256) NULL, species nvarchar(256) NULL,
 scientificName nvarchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL UNIQUE,
 taxon_rank nvarchar(20) NOT NULL''',
 'Dim_Location': '''id int NOT NULL PRIMARY KEY, decimalLatitude decimal(14,10) NOT NULL,
 decimalLongitude decimal(14,10) NOT NULL, latitude_band nvarchar(16) NOT NULL,
 grid_cell nvarchar(32) NOT NULL, country nvarchar(128) NULL,
 shoredistance decimal(14,4) NULL, sst decimal(8,4) NULL,
 sst_group nvarchar(32) NULL, sss decimal(8,4) NULL,
 location_key binary(32) NOT NULL UNIQUE''',
 'Dim_Depth_Band': '''id int NOT NULL PRIMARY KEY, depth_band nvarchar(64) NOT NULL UNIQUE,
 depth_min_m int NULL, depth_max_m int NULL''',
 'Dim_Quality': '''id int NOT NULL PRIMARY KEY, flag_on_land bit NOT NULL,
 flags nvarchar(512) NOT NULL, occurrence_status nvarchar(16) NULL,
 flag_marine_unsure bit NOT NULL, quality_key binary(32) NOT NULL UNIQUE''',
 'Fact_Occurrence': '''id nvarchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY,
 date_id int NOT NULL, taxon_id int NOT NULL, location_id int NOT NULL,
 depth_band_id int NOT NULL, quality_id int NOT NULL, depth decimal(20,10) NULL,
 individualCount decimal(18,4) NULL, occurrence_count int NOT NULL CHECK (occurrence_count=1)'''
}

def main():
    chunks = ["SET NOCOUNT ON; SET XACT_ABORT ON;", "IF SCHEMA_ID('etl') IS NULL EXEC('CREATE SCHEMA etl');\nIF SCHEMA_ID('load') IS NULL EXEC('CREATE SCHEMA load');"]
    for schema in ['dbo','load']:
        for table, cols in TABLES.items():
            chunks.append(f"IF OBJECT_ID('{schema}.{table}','U') IS NULL\nCREATE TABLE {schema}.{table} ({cols});")
    for col, dim in [('date_id','Dim_Date'),('taxon_id','Dim_Taxon'),('location_id','Dim_Location'),('depth_band_id','Dim_Depth_Band'),('quality_id','Dim_Quality')]:
        chunks.append(f"IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_Fact_{dim}')\nALTER TABLE dbo.Fact_Occurrence ADD CONSTRAINT FK_Fact_{dim} FOREIGN KEY ({col}) REFERENCES dbo.{dim}(id);")
        chunks.append(f"IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.Fact_Occurrence') AND name='IX_Fact_{col}') CREATE INDEX IX_Fact_{col} ON dbo.Fact_Occurrence({col});")
    raw = ',\n'.join(f'[{c}] nvarchar(512) NULL' for c in RAW_COLUMNS)
    chunks.append(f"IF OBJECT_ID('etl.Stg_OccurrenceRaw','U') IS NULL CREATE TABLE etl.Stg_OccurrenceRaw (source_row bigint IDENTITY(2,1) PRIMARY KEY,\n{raw});")
    chunks.append('''IF OBJECT_ID('etl.Batch','U') IS NULL CREATE TABLE etl.Batch (
 batch_id bigint IDENTITY PRIMARY KEY, started_at datetime2 NOT NULL DEFAULT SYSUTCDATETIME(),
 completed_at datetime2 NULL, status varchar(16) NOT NULL, source_file nvarchar(2048) NULL,
 source_rows bigint NULL, accepted_rows bigint NULL, rejected_rows bigint NULL,
 fact_rows bigint NULL, error_message nvarchar(2048) NULL);
IF OBJECT_ID('etl.Reject','U') IS NULL CREATE TABLE etl.Reject (
 reject_id bigint IDENTITY PRIMARY KEY, batch_id bigint NOT NULL REFERENCES etl.Batch(batch_id),
 source_row bigint NOT NULL, occurrence_id nvarchar(512) NULL, reason nvarchar(1024) NOT NULL,
 raw_json nvarchar(max) NOT NULL);
IF OBJECT_ID('etl.TaxonConflict','U') IS NULL CREATE TABLE etl.TaxonConflict (
 batch_id bigint NOT NULL REFERENCES etl.Batch(batch_id), scientificName nvarchar(256) NOT NULL,
 variant_count int NOT NULL, variants_json nvarchar(max) NOT NULL,
 PRIMARY KEY(batch_id,scientificName));
IF OBJECT_ID('etl.SnapshotState','U') IS NULL CREATE TABLE etl.SnapshotState (
 singleton int PRIMARY KEY CHECK(singleton=1), batch_id bigint NULL REFERENCES etl.Batch(batch_id));
IF NOT EXISTS (SELECT 1 FROM etl.SnapshotState) INSERT etl.SnapshotState VALUES (1,NULL);
''')
    (ROOT/'sql/01_schema.sql').write_text('\n'.join(chunks),encoding='utf-8')

    # Parse dates explicitly with style 103; preserve missing measures as SQL NULL.
    casts = {'decimalLatitude':'decimal(14,10)','decimalLongitude':'decimal(14,10)','shoredistance':'decimal(14,4)','depth':'decimal(20,10)','sst':'decimal(8,4)','sss':'decimal(8,4)','individualCount':'decimal(18,4)'}
    fields=[]
    for c in RAW_COLUMNS:
        if c in ['latitude_band','depth_band']: continue  # Recompute from numeric values.
        if c in casts: expr=f"TRY_CONVERT({casts[c]},NULLIF(TRIM(r.[{c}]),''))"
        elif c=='eventDate': expr="TRY_CONVERT(date,NULLIF(TRIM(r.eventDate),''),103)"
        elif c in ['flag_on_land','flag_marine_unsure']: expr=f"CASE LOWER(TRIM(r.[{c}])) WHEN 'true' THEN CONVERT(bit,1) WHEN 'false' THEN CONVERT(bit,0) END"
        elif c=='flags': expr="COALESCE(NULLIF(TRIM(r.flags),''),N'[]')"
        elif c=='occurrenceStatus': expr="LOWER(NULLIF(TRIM(r.occurrenceStatus),''))"
        else: expr=f"NULLIF(TRIM(r.[{c}]),'')"
        fields.append(f'{expr} AS [{c}]')
    reasons = [
        "CASE WHEN p.id IS NULL OR LEN(p.id)>64 THEN N'invalid_id;' ELSE N'' END",
        "CASE WHEN p.duplicate_sequence>1 THEN N'duplicate_id;' ELSE N'' END",
        "CASE WHEN p.eventDate IS NULL OR p.eventDate<'19800101' OR p.eventDate>CONVERT(date,SYSDATETIMEOFFSET() AT TIME ZONE 'SE Asia Standard Time') THEN N'invalid_date;' ELSE N'' END",
        "CASE WHEN p.decimalLatitude IS NULL OR p.decimalLatitude NOT BETWEEN 0 AND 23 OR p.decimalLongitude IS NULL OR p.decimalLongitude NOT BETWEEN 99 AND 121 THEN N'invalid_coordinates;' ELSE N'' END",
        "CASE WHEN p.scientificName IS NULL OR LEN(p.scientificName)>256 THEN N'invalid_scientific_name;' ELSE N'' END",
        "CASE WHEN p.flag_on_land IS NULL OR p.flag_marine_unsure IS NULL THEN N'invalid_boolean;' ELSE N'' END",
        "CASE WHEN p.occurrenceStatus IS NOT NULL AND p.occurrenceStatus NOT IN ('present','absent') THEN N'invalid_status;' ELSE N'' END",
        "CASE WHEN p.depth<0 OR p.individualCount<0 THEN N'negative_measure;' ELSE N'' END",
        "CASE WHEN LEN(p.country)>128 OR LEN(p.flags)>512 THEN N'overlength_text;' ELSE N'' END",
    ]
    for c in ['kingdom','phylum','class','order','family','genus','species']:
        reasons.append(f"CASE WHEN LEN(p.[{c}])>256 THEN N'overlength_{c};' ELSE N'' END")
    for c in casts:
        reasons.append(f"CASE WHEN NULLIF(TRIM(r.[{c}]),'') IS NOT NULL AND p.[{c}] IS NULL THEN N'invalid_number_{c};' ELSE N'' END")
    reasons += ["CASE WHEN p.flag_on_land<>CONVERT(bit,CASE WHEN CHARINDEX('ON_LAND',p.flags)>0 THEN 1 ELSE 0 END) OR p.flag_marine_unsure<>CONVERT(bit,CASE WHEN CHARINDEX('MARINE_UNSURE',p.flags)>0 THEN 1 ELSE 0 END) THEN N'flag_mismatch;' ELSE N'' END"]
    views = f'''CREATE OR ALTER VIEW etl.v_Parsed AS
SELECT r.source_row, {', '.join(fields)},
 ROW_NUMBER() OVER(PARTITION BY NULLIF(TRIM(r.id),'') COLLATE Latin1_General_100_BIN2 ORDER BY r.source_row) AS duplicate_sequence
FROM etl.Stg_OccurrenceRaw r;
GO
CREATE OR ALTER VIEW etl.v_Checked AS
SELECT p.*, CONCAT({','.join(reasons)}) AS reject_reason
FROM etl.v_Parsed p JOIN etl.Stg_OccurrenceRaw r ON p.source_row=r.source_row;
GO
CREATE OR ALTER VIEW etl.v_Accepted AS
SELECT p.*,
 CASE WHEN decimalLatitude<5 THEN N'0-5°N' WHEN decimalLatitude<10 THEN N'5-10°N'
      WHEN decimalLatitude<15 THEN N'10-15°N' WHEN decimalLatitude<20 THEN N'15-20°N' ELSE N'20-23°N' END AS latitude_band,
 CONCAT(FLOOR(decimalLatitude),N'N_',FLOOR(decimalLongitude),N'E') AS grid_cell,
 CASE WHEN depth IS NULL THEN 0 WHEN depth<50 THEN 1 WHEN depth<200 THEN 2 WHEN depth<1000 THEN 3 ELSE 4 END AS depth_band_id,
 CASE WHEN sst IS NULL THEN NULL WHEN sst<25 THEN N'<25°C' WHEN sst<27 THEN N'25-27°C' WHEN sst<29 THEN N'27-29°C' ELSE N'>=29°C' END AS sst_group,
 CONVERT(binary(32),HASHBYTES('SHA2_256',CONVERT(nvarchar(max),(SELECT p.decimalLatitude AS lat,p.decimalLongitude AS lon,p.country,p.shoredistance,p.sst,p.sss FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)))) AS location_key,
 CONVERT(binary(32),HASHBYTES('SHA2_256',CONVERT(nvarchar(max),(SELECT p.flag_on_land,p.flags,p.occurrenceStatus,p.flag_marine_unsure FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)))) AS quality_key
FROM etl.v_Checked p WHERE p.reject_reason=N'';
GO
'''
    # Materialize once so dimensional pipelines do not repeatedly parse the entire CSV.
    views += '''CREATE OR ALTER VIEW etl.v_LoadDim_Date AS
SELECT CONVERT(int,CONVERT(char(8),eventDate,112)) AS id,eventDate AS event_date,
 YEAR(eventDate) AS [year],CONVERT(nvarchar(10),CONCAT(YEAR(eventDate)/10*10,N's')) AS decade,
 CONVERT(nvarchar(2),CONCAT(N'Q',DATEPART(quarter,eventDate))) AS [quarter],MONTH(eventDate) AS [month],
 CONVERT(nvarchar(10),CASE WHEN MONTH(eventDate) IN (12,1,2) THEN N'Winter' WHEN MONTH(eventDate) IN (3,4,5) THEN N'Spring' WHEN MONTH(eventDate) IN (6,7,8) THEN N'Summer' ELSE N'Autumn' END) AS season
FROM etl.Stg_Occurrence GROUP BY eventDate;
GO
CREATE OR ALTER VIEW etl.v_LoadDim_Taxon AS
WITH variants AS (
 SELECT scientificName COLLATE Latin1_General_100_BIN2 AS scientificName,kingdom,phylum,[class],[order],family,genus,species,
 COUNT_BIG(*) AS n,MIN(source_row) AS first_row FROM etl.Stg_Occurrence
 GROUP BY scientificName COLLATE Latin1_General_100_BIN2,kingdom,phylum,[class],[order],family,genus,species
), ranked AS (
 SELECT *,ROW_NUMBER() OVER(PARTITION BY scientificName ORDER BY
 (CASE WHEN kingdom IS NULL THEN 0 ELSE 1 END+CASE WHEN phylum IS NULL THEN 0 ELSE 1 END+
 CASE WHEN [class] IS NULL THEN 0 ELSE 1 END+CASE WHEN [order] IS NULL THEN 0 ELSE 1 END+
 CASE WHEN family IS NULL THEN 0 ELSE 1 END+CASE WHEN genus IS NULL THEN 0 ELSE 1 END+
 CASE WHEN species IS NULL THEN 0 ELSE 1 END) DESC,n DESC,first_row) AS choice FROM variants
)
SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY scientificName)) AS id,
 CONVERT(nvarchar(256),kingdom) AS kingdom,CONVERT(nvarchar(256),phylum) AS phylum,
 CONVERT(nvarchar(256),[class]) AS [class],CONVERT(nvarchar(256),[order]) AS [order],
 CONVERT(nvarchar(256),family) AS family,CONVERT(nvarchar(256),genus) AS genus,
 CONVERT(nvarchar(256),species) AS species,CONVERT(nvarchar(256),scientificName) AS scientificName,
 CONVERT(nvarchar(20),CASE WHEN scientificName=species THEN N'species' WHEN scientificName=genus THEN N'genus'
 WHEN scientificName=family THEN N'family' WHEN scientificName=[order] THEN N'order'
 WHEN scientificName=[class] THEN N'class' WHEN scientificName=phylum THEN N'phylum'
 WHEN scientificName=kingdom THEN N'kingdom' ELSE N'unknown' END) AS taxon_rank
FROM ranked WHERE choice=1;
GO
CREATE OR ALTER VIEW etl.v_LoadDim_Location AS
SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY location_key)) AS id,decimalLatitude,decimalLongitude,
 CONVERT(nvarchar(16),latitude_band) AS latitude_band,CONVERT(nvarchar(32),grid_cell) AS grid_cell,
 CONVERT(nvarchar(128),country) AS country,shoredistance,sst,
 CONVERT(nvarchar(32),sst_group) AS sst_group,sss,location_key
FROM etl.Stg_Occurrence GROUP BY location_key,decimalLatitude,decimalLongitude,latitude_band,grid_cell,country,shoredistance,sst,sst_group,sss;
GO
CREATE OR ALTER VIEW etl.v_LoadDim_Depth_Band AS
SELECT id,CONVERT(nvarchar(64),depth_band) AS depth_band,depth_min_m,depth_max_m FROM (VALUES
 (0,N'Unknown',NULL,NULL),(1,N'Coastal/surface (<50 m)',0,50),
 (2,N'Continental shelf (50-200 m)',50,200),(3,N'Continental slope (200-1000 m)',200,1000),
 (4,N'Deep sea (>=1000 m)',1000,NULL)) b(id,depth_band,depth_min_m,depth_max_m);
GO
CREATE OR ALTER VIEW etl.v_LoadDim_Quality AS
SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY quality_key)) AS id,flag_on_land,
 CONVERT(nvarchar(512),flags) AS flags,CONVERT(nvarchar(16),occurrenceStatus) AS occurrence_status,
 flag_marine_unsure,quality_key
FROM etl.Stg_Occurrence GROUP BY quality_key,flag_on_land,flags,occurrenceStatus,flag_marine_unsure;
GO
CREATE OR ALTER VIEW etl.v_LoadFact_Occurrence AS
SELECT CONVERT(nvarchar(64),s.id) AS id,d.id AS date_id,t.id AS taxon_id,l.id AS location_id,
 s.depth_band_id,q.id AS quality_id,s.depth,s.individualCount,CONVERT(int,1) AS occurrence_count
FROM etl.Stg_Occurrence s JOIN load.Dim_Date d ON d.event_date=s.eventDate
 JOIN load.Dim_Taxon t ON t.scientificName=s.scientificName COLLATE Latin1_General_100_BIN2
 JOIN load.Dim_Location l ON l.location_key=s.location_key
 JOIN load.Dim_Quality q ON q.quality_key=s.quality_key;
GO
'''
    # Create the empty typed materialization before its dependent views.
    first, rest = views.split('CREATE OR ALTER VIEW etl.v_LoadDim_Date AS',1)
    first += "IF OBJECT_ID('etl.Stg_Occurrence','U') IS NULL SELECT TOP(0) * INTO etl.Stg_Occurrence FROM etl.v_Accepted;\nGO\n"
    (ROOT/'sql/02_views.sql').write_text(first+'CREATE OR ALTER VIEW etl.v_LoadDim_Date AS'+rest,encoding='utf-8')

    procedures = '''CREATE OR ALTER PROCEDURE etl.usp_BeginBatch @source_file nvarchar(2048)
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @lock_result int;
 EXEC @lock_result=sys.sp_getapplock @Resource=N'MarineShiftETL',@LockMode='Exclusive',@LockOwner='Session',@LockTimeout=0;
 IF @lock_result<0 THROW 51001,'Another marine ETL execution is active.',1;
 INSERT etl.Batch(status,source_file) VALUES('RUNNING',@source_file);
 SELECT CONVERT(bigint,SCOPE_IDENTITY()) AS batch_id;
END;
GO
CREATE OR ALTER PROCEDURE etl.usp_ClearWorking
AS
BEGIN
 SET NOCOUNT ON;
 TRUNCATE TABLE etl.Stg_OccurrenceRaw;
 TRUNCATE TABLE etl.Stg_Occurrence;
'''
    procedures += '\n'.join(f' TRUNCATE TABLE load.{t};' for t in TABLES)
    procedures += '''
END;
GO
CREATE OR ALTER PROCEDURE etl.usp_ValidateStage @batch_id bigint,@max_rejects int=0
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 INSERT etl.Reject(batch_id,source_row,occurrence_id,reason,raw_json)
 SELECT @batch_id,c.source_row,c.id,c.reject_reason,
 (SELECT r.* FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)
 FROM etl.v_Checked c JOIN etl.Stg_OccurrenceRaw r ON r.source_row=c.source_row WHERE c.reject_reason<>N'';
 INSERT etl.Stg_Occurrence SELECT * FROM etl.v_Accepted;
 UPDATE etl.Batch SET source_rows=(SELECT COUNT_BIG(*) FROM etl.Stg_OccurrenceRaw),
 accepted_rows=(SELECT COUNT_BIG(*) FROM etl.Stg_Occurrence),
 rejected_rows=(SELECT COUNT_BIG(*) FROM etl.Reject WHERE batch_id=@batch_id) WHERE batch_id=@batch_id;
 IF NOT EXISTS(SELECT 1 FROM etl.Stg_Occurrence) THROW 51002,'The source contains no accepted occurrences.',1;
 IF (SELECT rejected_rows FROM etl.Batch WHERE batch_id=@batch_id)>@max_rejects THROW 51003,'Reject threshold exceeded; the published warehouse is unchanged. Inspect etl.Reject.',1;
 WITH variants AS (
 SELECT scientificName COLLATE Latin1_General_100_BIN2 AS scientificName,kingdom,phylum,[class],[order],family,genus,species,COUNT_BIG(*) AS source_records
 FROM etl.Stg_Occurrence GROUP BY scientificName COLLATE Latin1_General_100_BIN2,kingdom,phylum,[class],[order],family,genus,species
 ), conflicts AS (SELECT scientificName,COUNT(*) AS n FROM variants GROUP BY scientificName HAVING COUNT(*)>1)
 INSERT etl.TaxonConflict SELECT @batch_id,c.scientificName,c.n,
 (SELECT v.* FROM variants v WHERE v.scientificName=c.scientificName FOR JSON PATH,INCLUDE_NULL_VALUES)
 FROM conflicts c;
END;
GO
CREATE OR ALTER PROCEDURE etl.usp_Publish @batch_id bigint
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF NOT EXISTS (SELECT 1 FROM etl.Batch WHERE batch_id=@batch_id AND status='RUNNING') THROW 51004,'No active batch.',1;
 IF (SELECT COUNT_BIG(*) FROM load.Fact_Occurrence)<>(SELECT accepted_rows FROM etl.Batch WHERE batch_id=@batch_id) THROW 51005,'Fact/source reconciliation failed.',1;
 IF EXISTS(SELECT 1 FROM load.Fact_Occurrence f
 LEFT JOIN load.Dim_Date d ON d.id=f.date_id LEFT JOIN load.Dim_Taxon t ON t.id=f.taxon_id
 LEFT JOIN load.Dim_Location l ON l.id=f.location_id LEFT JOIN load.Dim_Depth_Band b ON b.id=f.depth_band_id
 LEFT JOIN load.Dim_Quality q ON q.id=f.quality_id
 WHERE d.id IS NULL OR t.id IS NULL OR l.id IS NULL OR b.id IS NULL OR q.id IS NULL) THROW 51006,'An unresolved dimension key was found.',1;
 IF EXISTS(SELECT 1 FROM etl.Batch WHERE batch_id=@batch_id AND source_rows<>accepted_rows+rejected_rows) THROW 51007,'Input/reject reconciliation failed.',1;
 BEGIN TRY
 BEGIN TRANSACTION;
 DELETE dbo.Fact_Occurrence;
'''
    procedures += '\n'.join(f' DELETE dbo.{t};' for t in TABLES if t!='Fact_Occurrence')
    for table, cols in TABLES.items():
        # Extract column names independently of DDL commas inside type specifications.
        names = {'Dim_Date':['id','event_date','year','decade','quarter','month','season'],
                 'Dim_Taxon':['id','kingdom','phylum','class','order','family','genus','species','scientificName','taxon_rank'],
                 'Dim_Location':['id','decimalLatitude','decimalLongitude','latitude_band','grid_cell','country','shoredistance','sst','sst_group','sss','location_key'],
                 'Dim_Depth_Band':['id','depth_band','depth_min_m','depth_max_m'],
                 'Dim_Quality':['id','flag_on_land','flags','occurrence_status','flag_marine_unsure','quality_key'],
                 'Fact_Occurrence':['id','date_id','taxon_id','location_id','depth_band_id','quality_id','depth','individualCount','occurrence_count']}[table]
        column_list=','.join(f'[{c}]' for c in names)
        procedures += f'\n INSERT dbo.{table} ({column_list}) SELECT {column_list} FROM load.{table};'
    procedures += '''
 UPDATE etl.Batch SET status='SUCCEEDED',completed_at=SYSUTCDATETIME(),
 fact_rows=(SELECT COUNT_BIG(*) FROM dbo.Fact_Occurrence) WHERE batch_id=@batch_id;
 UPDATE etl.SnapshotState SET batch_id=@batch_id WHERE singleton=1;
 COMMIT;
 END TRY
 BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
 END CATCH;
 IF APPLOCK_MODE('public','MarineShiftETL','Session')<>'NoLock' EXEC sys.sp_releaseapplock @Resource=N'MarineShiftETL',@LockOwner='Session';
END;
GO
CREATE OR ALTER PROCEDURE etl.usp_FailBatch @batch_id bigint,@message nvarchar(2048)
AS
BEGIN
 SET NOCOUNT ON;
 UPDATE etl.Batch SET status='FAILED',completed_at=SYSUTCDATETIME(),error_message=LEFT(@message,2048)
 WHERE batch_id=@batch_id AND status='RUNNING';
 IF APPLOCK_MODE('public','MarineShiftETL','Session')<>'NoLock' EXEC sys.sp_releaseapplock @Resource=N'MarineShiftETL',@LockOwner='Session';
END;
GO
'''
    (ROOT/'sql/03_procedures.sql').write_text(procedures,encoding='utf-8')
    (ROOT/'sql/00_create_database.sql').write_text("IF DB_ID(N'MARINE_SHIFT_RANGE_DW') IS NULL CREATE DATABASE [MARINE_SHIFT_RANGE_DW];\n",encoding='utf-8')

if __name__=='__main__': main()
