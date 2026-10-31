USE [MARINE_SHIFT_RANGE_DW];
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @rows_before bigint=(SELECT COUNT_BIG(*) FROM dbo.Fact_Occurrence);
DECLARE @checksum_before int=(SELECT CHECKSUM_AGG(BINARY_CHECKSUM(id,date_id,taxon_id,location_id,depth_band_id,quality_id,depth,individualCount,occurrence_count)) FROM dbo.Fact_Occurrence);
DECLARE @quality_before int=(SELECT COUNT(*) FROM dbo.Dim_Quality);
BEGIN TRY
 BEGIN TRANSACTION;
 DECLARE @lock_result int;
 EXEC @lock_result=sys.sp_getapplock @Resource=N'MarineShiftETL',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
 IF @lock_result<0 THROW 51300,'An ETL run is active; no migration performed.',1;
 IF COL_LENGTH(N'etl.Stg_OccurrenceRaw',N'flag_marine_unsure') IS NOT NULL
 EXEC(N'IF EXISTS(SELECT 1 FROM etl.Stg_OccurrenceRaw WHERE LOWER(TRIM(flag_marine_unsure)) NOT IN (''false'',''0'')) THROW 51301,''Nonzero flag found; migration stopped to preserve information.'',1;');
 IF COL_LENGTH(N'etl.Stg_Occurrence',N'flag_marine_unsure') IS NOT NULL
 EXEC(N'IF EXISTS(SELECT 1 FROM etl.Stg_Occurrence WHERE flag_marine_unsure<>0) THROW 51301,''Nonzero flag found; migration stopped to preserve information.'',1;');
 IF COL_LENGTH(N'load.Dim_Quality',N'flag_marine_unsure') IS NOT NULL
 EXEC(N'IF EXISTS(SELECT 1 FROM load.Dim_Quality WHERE flag_marine_unsure<>0) THROW 51301,''Nonzero flag found; migration stopped to preserve information.'',1;');
 IF COL_LENGTH(N'dbo.Dim_Quality',N'flag_marine_unsure') IS NOT NULL
 EXEC(N'IF EXISTS(SELECT 1 FROM dbo.Dim_Quality WHERE flag_marine_unsure<>0) THROW 51301,''Nonzero flag found; migration stopped to preserve information.'',1;');
 IF EXISTS(SELECT 1 FROM dbo.Dim_Quality GROUP BY flag_on_land,flags,occurrence_status HAVING COUNT(*)>1)
 THROW 51302,'Removing the flag would merge quality groups; migration stopped.',1;
 EXEC(N'CREATE OR ALTER VIEW etl.v_Parsed AS
SELECT r.source_row, NULLIF(TRIM(r.[id]),'''') AS [id], NULLIF(TRIM(r.[country]),'''') AS [country], TRY_CONVERT(decimal(14,10),NULLIF(TRIM(r.[decimalLatitude]),'''')) AS [decimalLatitude], TRY_CONVERT(decimal(14,10),NULLIF(TRIM(r.[decimalLongitude]),'''')) AS [decimalLongitude], TRY_CONVERT(decimal(14,4),NULLIF(TRIM(r.[shoredistance]),'''')) AS [shoredistance], TRY_CONVERT(date,NULLIF(TRIM(r.eventDate),''''),103) AS [eventDate], TRY_CONVERT(decimal(20,10),NULLIF(TRIM(r.[depth]),'''')) AS [depth], TRY_CONVERT(decimal(8,4),NULLIF(TRIM(r.[sst]),'''')) AS [sst], TRY_CONVERT(decimal(8,4),NULLIF(TRIM(r.[sss]),'''')) AS [sss], COALESCE(NULLIF(TRIM(r.flags),''''),N''[]'') AS [flags], CASE LOWER(TRIM(r.[flag_on_land])) WHEN ''true'' THEN CONVERT(bit,1) WHEN ''false'' THEN CONVERT(bit,0) END AS [flag_on_land], NULLIF(TRIM(r.[kingdom]),'''') AS [kingdom], NULLIF(TRIM(r.[phylum]),'''') AS [phylum], NULLIF(TRIM(r.[class]),'''') AS [class], NULLIF(TRIM(r.[order]),'''') AS [order], NULLIF(TRIM(r.[family]),'''') AS [family], NULLIF(TRIM(r.[genus]),'''') AS [genus], NULLIF(TRIM(r.[species]),'''') AS [species], NULLIF(TRIM(r.[scientificName]),'''') AS [scientificName], LOWER(NULLIF(TRIM(r.occurrenceStatus),'''')) AS [occurrenceStatus], TRY_CONVERT(decimal(18,4),NULLIF(TRIM(r.[individualCount]),'''')) AS [individualCount],
 ROW_NUMBER() OVER(PARTITION BY NULLIF(TRIM(r.id),'''') COLLATE Latin1_General_100_BIN2 ORDER BY r.source_row) AS duplicate_sequence
FROM etl.Stg_OccurrenceRaw r;');
 EXEC(N'CREATE OR ALTER VIEW etl.v_Checked AS
SELECT p.*, CONCAT(CASE WHEN p.id IS NULL OR LEN(p.id)>64 THEN N''invalid_id;'' ELSE N'''' END,CASE WHEN p.duplicate_sequence>1 THEN N''duplicate_id;'' ELSE N'''' END,CASE WHEN p.eventDate IS NULL OR p.eventDate<''19800101'' OR p.eventDate>CONVERT(date,SYSDATETIMEOFFSET() AT TIME ZONE ''SE Asia Standard Time'') THEN N''invalid_date;'' ELSE N'''' END,CASE WHEN p.decimalLatitude IS NULL OR p.decimalLatitude NOT BETWEEN 0 AND 23 OR p.decimalLongitude IS NULL OR p.decimalLongitude NOT BETWEEN 99 AND 121 THEN N''invalid_coordinates;'' ELSE N'''' END,CASE WHEN p.scientificName IS NULL OR LEN(p.scientificName)>256 THEN N''invalid_scientific_name;'' ELSE N'''' END,CASE WHEN p.flag_on_land IS NULL THEN N''invalid_boolean;'' ELSE N'''' END,CASE WHEN p.occurrenceStatus IS NOT NULL AND p.occurrenceStatus NOT IN (''present'',''absent'') THEN N''invalid_status;'' ELSE N'''' END,CASE WHEN p.depth<0 OR p.individualCount<0 THEN N''negative_measure;'' ELSE N'''' END,CASE WHEN LEN(p.country)>128 OR LEN(p.flags)>512 THEN N''overlength_text;'' ELSE N'''' END,CASE WHEN LEN(p.[kingdom])>256 THEN N''overlength_kingdom;'' ELSE N'''' END,CASE WHEN LEN(p.[phylum])>256 THEN N''overlength_phylum;'' ELSE N'''' END,CASE WHEN LEN(p.[class])>256 THEN N''overlength_class;'' ELSE N'''' END,CASE WHEN LEN(p.[order])>256 THEN N''overlength_order;'' ELSE N'''' END,CASE WHEN LEN(p.[family])>256 THEN N''overlength_family;'' ELSE N'''' END,CASE WHEN LEN(p.[genus])>256 THEN N''overlength_genus;'' ELSE N'''' END,CASE WHEN LEN(p.[species])>256 THEN N''overlength_species;'' ELSE N'''' END,CASE WHEN NULLIF(TRIM(r.[decimalLatitude]),'''') IS NOT NULL AND p.[decimalLatitude] IS NULL THEN N''invalid_number_decimalLatitude;'' ELSE N'''' END,CASE WHEN NULLIF(TRIM(r.[decimalLongitude]),'''') IS NOT NULL AND p.[decimalLongitude] IS NULL THEN N''invalid_number_decimalLongitude;'' ELSE N'''' END,CASE WHEN NULLIF(TRIM(r.[shoredistance]),'''') IS NOT NULL AND p.[shoredistance] IS NULL THEN N''invalid_number_shoredistance;'' ELSE N'''' END,CASE WHEN NULLIF(TRIM(r.[depth]),'''') IS NOT NULL AND p.[depth] IS NULL THEN N''invalid_number_depth;'' ELSE N'''' END,CASE WHEN NULLIF(TRIM(r.[sst]),'''') IS NOT NULL AND p.[sst] IS NULL THEN N''invalid_number_sst;'' ELSE N'''' END,CASE WHEN NULLIF(TRIM(r.[sss]),'''') IS NOT NULL AND p.[sss] IS NULL THEN N''invalid_number_sss;'' ELSE N'''' END,CASE WHEN NULLIF(TRIM(r.[individualCount]),'''') IS NOT NULL AND p.[individualCount] IS NULL THEN N''invalid_number_individualCount;'' ELSE N'''' END,CASE WHEN p.flag_on_land<>CONVERT(bit,CASE WHEN CHARINDEX(''ON_LAND'',p.flags)>0 THEN 1 ELSE 0 END) THEN N''flag_mismatch;'' ELSE N'''' END) AS reject_reason
FROM etl.v_Parsed p JOIN etl.Stg_OccurrenceRaw r ON p.source_row=r.source_row;');
 EXEC(N'CREATE OR ALTER VIEW etl.v_Accepted AS
SELECT p.*,
 CASE WHEN decimalLatitude<5 THEN N''0-5°N'' WHEN decimalLatitude<10 THEN N''5-10°N''
      WHEN decimalLatitude<15 THEN N''10-15°N'' WHEN decimalLatitude<20 THEN N''15-20°N'' ELSE N''20-23°N'' END AS latitude_band,
 CONCAT(FLOOR(decimalLatitude),N''N_'',FLOOR(decimalLongitude),N''E'') AS grid_cell,
 CASE WHEN depth IS NULL THEN 0 WHEN depth<50 THEN 1 WHEN depth<200 THEN 2 WHEN depth<1000 THEN 3 ELSE 4 END AS depth_band_id,
 CASE WHEN sst IS NULL THEN NULL WHEN sst<25 THEN N''<25°C'' WHEN sst<27 THEN N''25-27°C'' WHEN sst<29 THEN N''27-29°C'' ELSE N''>=29°C'' END AS sst_group,
 CONVERT(binary(32),HASHBYTES(''SHA2_256'',CONVERT(nvarchar(max),(SELECT p.decimalLatitude AS lat,p.decimalLongitude AS lon,p.country,p.shoredistance,p.sst,p.sss FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)))) AS location_key,
 CONVERT(binary(32),HASHBYTES(''SHA2_256'',CONVERT(nvarchar(max),(SELECT p.flag_on_land,p.flags,p.occurrenceStatus FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)))) AS quality_key
FROM etl.v_Checked p WHERE p.reject_reason=N'''';');
 EXEC(N'IF OBJECT_ID(''etl.Stg_Occurrence'',''U'') IS NULL SELECT TOP(0) * INTO etl.Stg_Occurrence FROM etl.v_Accepted;');
 EXEC(N'CREATE OR ALTER VIEW etl.v_LoadDim_Date AS
SELECT CONVERT(int,CONVERT(char(8),eventDate,112)) AS id,eventDate AS event_date,
 YEAR(eventDate) AS [year],CONVERT(nvarchar(10),CONCAT(YEAR(eventDate)/10*10,N''s'')) AS decade,
 CONVERT(nvarchar(2),CONCAT(N''Q'',DATEPART(quarter,eventDate))) AS [quarter],MONTH(eventDate) AS [month],
 CONVERT(nvarchar(10),CASE WHEN MONTH(eventDate) IN (12,1,2) THEN N''Winter'' WHEN MONTH(eventDate) IN (3,4,5) THEN N''Spring'' WHEN MONTH(eventDate) IN (6,7,8) THEN N''Summer'' ELSE N''Autumn'' END) AS season
FROM etl.Stg_Occurrence GROUP BY eventDate;');
 EXEC(N'CREATE OR ALTER VIEW etl.v_LoadDim_Taxon AS
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
 CONVERT(nvarchar(20),CASE WHEN scientificName=species THEN N''species'' WHEN scientificName=genus THEN N''genus''
 WHEN scientificName=family THEN N''family'' WHEN scientificName=[order] THEN N''order''
 WHEN scientificName=[class] THEN N''class'' WHEN scientificName=phylum THEN N''phylum''
 WHEN scientificName=kingdom THEN N''kingdom'' ELSE N''unknown'' END) AS taxon_rank
FROM ranked WHERE choice=1;');
 EXEC(N'CREATE OR ALTER VIEW etl.v_LoadDim_Location AS
SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY location_key)) AS id,decimalLatitude,decimalLongitude,
 CONVERT(nvarchar(16),latitude_band) AS latitude_band,CONVERT(nvarchar(32),grid_cell) AS grid_cell,
 CONVERT(nvarchar(128),country) AS country,shoredistance,sst,
 CONVERT(nvarchar(32),sst_group) AS sst_group,sss,location_key
FROM etl.Stg_Occurrence GROUP BY location_key,decimalLatitude,decimalLongitude,latitude_band,grid_cell,country,shoredistance,sst,sst_group,sss;');
 EXEC(N'CREATE OR ALTER VIEW etl.v_LoadDim_Depth_Band AS
SELECT id,CONVERT(nvarchar(64),depth_band) AS depth_band,depth_min_m,depth_max_m FROM (VALUES
 (0,N''Unknown'',NULL,NULL),(1,N''Coastal/surface (<50 m)'',0,50),
 (2,N''Continental shelf (50-200 m)'',50,200),(3,N''Continental slope (200-1000 m)'',200,1000),
 (4,N''Deep sea (>=1000 m)'',1000,NULL)) b(id,depth_band,depth_min_m,depth_max_m);');
 EXEC(N'CREATE OR ALTER VIEW etl.v_LoadDim_Quality AS
SELECT CONVERT(int,ROW_NUMBER() OVER(ORDER BY quality_key)) AS id,flag_on_land,
 CONVERT(nvarchar(512),flags) AS flags,CONVERT(nvarchar(16),occurrenceStatus) AS occurrence_status,
 quality_key
FROM etl.Stg_Occurrence GROUP BY quality_key,flag_on_land,flags,occurrenceStatus;');
 EXEC(N'CREATE OR ALTER VIEW etl.v_LoadFact_Occurrence AS
SELECT CONVERT(nvarchar(64),s.id) AS id,d.id AS date_id,t.id AS taxon_id,l.id AS location_id,
 s.depth_band_id,q.id AS quality_id,s.depth,s.individualCount,CONVERT(int,1) AS occurrence_count
FROM etl.Stg_Occurrence s JOIN load.Dim_Date d ON d.event_date=s.eventDate
 JOIN load.Dim_Taxon t ON t.scientificName=s.scientificName COLLATE Latin1_General_100_BIN2
 JOIN load.Dim_Location l ON l.location_key=s.location_key
 JOIN load.Dim_Quality q ON q.quality_key=s.quality_key;');
 IF COL_LENGTH(N'etl.Stg_OccurrenceRaw',N'flag_marine_unsure') IS NOT NULL ALTER TABLE etl.Stg_OccurrenceRaw DROP COLUMN flag_marine_unsure;
 IF COL_LENGTH(N'etl.Stg_Occurrence',N'flag_marine_unsure') IS NOT NULL ALTER TABLE etl.Stg_Occurrence DROP COLUMN flag_marine_unsure;
 IF COL_LENGTH(N'load.Dim_Quality',N'flag_marine_unsure') IS NOT NULL ALTER TABLE load.Dim_Quality DROP COLUMN flag_marine_unsure;
 IF COL_LENGTH(N'dbo.Dim_Quality',N'flag_marine_unsure') IS NOT NULL ALTER TABLE dbo.Dim_Quality DROP COLUMN flag_marine_unsure;
 EXEC(N'CREATE OR ALTER PROCEDURE etl.usp_BeginBatch @source_file nvarchar(2048)
AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @lock_result int;
 EXEC @lock_result=sys.sp_getapplock @Resource=N''MarineShiftETL'',@LockMode=''Exclusive'',@LockOwner=''Session'',@LockTimeout=0;
 IF @lock_result<0 THROW 51001,''Another marine ETL execution is active.'',1;
 INSERT etl.Batch(status,source_file) VALUES(''RUNNING'',@source_file);
 SELECT CONVERT(bigint,SCOPE_IDENTITY()) AS batch_id;
END;');
 EXEC(N'CREATE OR ALTER PROCEDURE etl.usp_ClearWorking
AS
BEGIN
 SET NOCOUNT ON;
 TRUNCATE TABLE etl.Stg_OccurrenceRaw;
 TRUNCATE TABLE etl.Stg_Occurrence;
 TRUNCATE TABLE load.Dim_Date;
 TRUNCATE TABLE load.Dim_Taxon;
 TRUNCATE TABLE load.Dim_Location;
 TRUNCATE TABLE load.Dim_Depth_Band;
 TRUNCATE TABLE load.Dim_Quality;
 TRUNCATE TABLE load.Fact_Occurrence;
END;');
 EXEC(N'CREATE OR ALTER PROCEDURE etl.usp_ValidateStage @batch_id bigint,@max_rejects int=0
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 INSERT etl.Reject(batch_id,source_row,occurrence_id,reason,raw_json)
 SELECT @batch_id,c.source_row,c.id,c.reject_reason,
 (SELECT r.* FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)
 FROM etl.v_Checked c JOIN etl.Stg_OccurrenceRaw r ON r.source_row=c.source_row WHERE c.reject_reason<>N'''';
 INSERT etl.Stg_Occurrence SELECT * FROM etl.v_Accepted;
 UPDATE etl.Batch SET source_rows=(SELECT COUNT_BIG(*) FROM etl.Stg_OccurrenceRaw),
 accepted_rows=(SELECT COUNT_BIG(*) FROM etl.Stg_Occurrence),
 rejected_rows=(SELECT COUNT_BIG(*) FROM etl.Reject WHERE batch_id=@batch_id) WHERE batch_id=@batch_id;
 IF NOT EXISTS(SELECT 1 FROM etl.Stg_Occurrence) THROW 51002,''The source contains no accepted occurrences.'',1;
 IF (SELECT rejected_rows FROM etl.Batch WHERE batch_id=@batch_id)>@max_rejects THROW 51003,''Reject threshold exceeded; the published warehouse is unchanged. Inspect etl.Reject.'',1;
 WITH variants AS (
 SELECT scientificName COLLATE Latin1_General_100_BIN2 AS scientificName,kingdom,phylum,[class],[order],family,genus,species,COUNT_BIG(*) AS source_records
 FROM etl.Stg_Occurrence GROUP BY scientificName COLLATE Latin1_General_100_BIN2,kingdom,phylum,[class],[order],family,genus,species
 ), conflicts AS (SELECT scientificName,COUNT(*) AS n FROM variants GROUP BY scientificName HAVING COUNT(*)>1)
 INSERT etl.TaxonConflict SELECT @batch_id,c.scientificName,c.n,
 (SELECT v.* FROM variants v WHERE v.scientificName=c.scientificName FOR JSON PATH,INCLUDE_NULL_VALUES)
 FROM conflicts c;
END;');
 EXEC(N'CREATE OR ALTER PROCEDURE etl.usp_Publish @batch_id bigint
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF NOT EXISTS (SELECT 1 FROM etl.Batch WHERE batch_id=@batch_id AND status=''RUNNING'') THROW 51004,''No active batch.'',1;
 IF (SELECT COUNT_BIG(*) FROM load.Fact_Occurrence)<>(SELECT accepted_rows FROM etl.Batch WHERE batch_id=@batch_id) THROW 51005,''Fact/source reconciliation failed.'',1;
 IF EXISTS(SELECT 1 FROM load.Fact_Occurrence f
 LEFT JOIN load.Dim_Date d ON d.id=f.date_id LEFT JOIN load.Dim_Taxon t ON t.id=f.taxon_id
 LEFT JOIN load.Dim_Location l ON l.id=f.location_id LEFT JOIN load.Dim_Depth_Band b ON b.id=f.depth_band_id
 LEFT JOIN load.Dim_Quality q ON q.id=f.quality_id
 WHERE d.id IS NULL OR t.id IS NULL OR l.id IS NULL OR b.id IS NULL OR q.id IS NULL) THROW 51006,''An unresolved dimension key was found.'',1;
 IF EXISTS(SELECT 1 FROM etl.Batch WHERE batch_id=@batch_id AND source_rows<>accepted_rows+rejected_rows) THROW 51007,''Input/reject reconciliation failed.'',1;
 BEGIN TRY
 BEGIN TRANSACTION;
 DELETE dbo.Fact_Occurrence;
 DELETE dbo.Dim_Date;
 DELETE dbo.Dim_Taxon;
 DELETE dbo.Dim_Location;
 DELETE dbo.Dim_Depth_Band;
 DELETE dbo.Dim_Quality;
 INSERT dbo.Dim_Date ([id],[event_date],[year],[decade],[quarter],[month],[season]) SELECT [id],[event_date],[year],[decade],[quarter],[month],[season] FROM load.Dim_Date;
 INSERT dbo.Dim_Taxon ([id],[kingdom],[phylum],[class],[order],[family],[genus],[species],[scientificName],[taxon_rank]) SELECT [id],[kingdom],[phylum],[class],[order],[family],[genus],[species],[scientificName],[taxon_rank] FROM load.Dim_Taxon;
 INSERT dbo.Dim_Location ([id],[decimalLatitude],[decimalLongitude],[latitude_band],[grid_cell],[country],[shoredistance],[sst],[sst_group],[sss],[location_key]) SELECT [id],[decimalLatitude],[decimalLongitude],[latitude_band],[grid_cell],[country],[shoredistance],[sst],[sst_group],[sss],[location_key] FROM load.Dim_Location;
 INSERT dbo.Dim_Depth_Band ([id],[depth_band],[depth_min_m],[depth_max_m]) SELECT [id],[depth_band],[depth_min_m],[depth_max_m] FROM load.Dim_Depth_Band;
 INSERT dbo.Dim_Quality ([id],[flag_on_land],[flags],[occurrence_status],[quality_key]) SELECT [id],[flag_on_land],[flags],[occurrence_status],[quality_key] FROM load.Dim_Quality;
 INSERT dbo.Fact_Occurrence ([id],[date_id],[taxon_id],[location_id],[depth_band_id],[quality_id],[depth],[individualCount],[occurrence_count]) SELECT [id],[date_id],[taxon_id],[location_id],[depth_band_id],[quality_id],[depth],[individualCount],[occurrence_count] FROM load.Fact_Occurrence;
 UPDATE etl.Batch SET status=''SUCCEEDED'',completed_at=SYSUTCDATETIME(),
 fact_rows=(SELECT COUNT_BIG(*) FROM dbo.Fact_Occurrence) WHERE batch_id=@batch_id;
 UPDATE etl.SnapshotState SET batch_id=@batch_id WHERE singleton=1;
 COMMIT;
 END TRY
 BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
 END CATCH;
 IF APPLOCK_MODE(''public'',''MarineShiftETL'',''Session'')<>''NoLock'' EXEC sys.sp_releaseapplock @Resource=N''MarineShiftETL'',@LockOwner=''Session'';
END;');
 EXEC(N'CREATE OR ALTER PROCEDURE etl.usp_FailBatch @batch_id bigint,@message nvarchar(2048)
AS
BEGIN
 SET NOCOUNT ON;
 UPDATE etl.Batch SET status=''FAILED'',completed_at=SYSUTCDATETIME(),error_message=LEFT(@message,2048)
 WHERE batch_id=@batch_id AND status=''RUNNING'';
 IF APPLOCK_MODE(''public'',''MarineShiftETL'',''Session'')<>''NoLock'' EXEC sys.sp_releaseapplock @Resource=N''MarineShiftETL'',@LockOwner=''Session'';
END;');
 UPDATE q SET quality_key=CONVERT(binary(32),HASHBYTES('SHA2_256',CONVERT(nvarchar(max),(SELECT q.flag_on_land,q.flags,q.occurrence_status AS occurrenceStatus FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)))) FROM dbo.Dim_Quality q;
 UPDATE q SET quality_key=CONVERT(binary(32),HASHBYTES('SHA2_256',CONVERT(nvarchar(max),(SELECT q.flag_on_land,q.flags,q.occurrence_status AS occurrenceStatus FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)))) FROM load.Dim_Quality q;
 UPDATE s SET quality_key=CONVERT(binary(32),HASHBYTES('SHA2_256',CONVERT(nvarchar(max),(SELECT s.flag_on_land,s.flags,s.occurrenceStatus FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)))) FROM etl.Stg_Occurrence s;
 IF EXISTS(SELECT 1 FROM sys.columns c JOIN sys.tables t ON t.object_id=c.object_id WHERE c.name='flag_marine_unsure')
 THROW 51303,'The removed column remains in a table; migration rolled back.',1;
 IF EXISTS(SELECT 1 FROM sys.sql_modules WHERE definition LIKE '%flag_marine_unsure%')
 THROW 51304,'A SQL module still references the column; migration rolled back.',1;
 IF (SELECT COUNT_BIG(*) FROM dbo.Fact_Occurrence)<>@rows_before
 OR (SELECT CHECKSUM_AGG(BINARY_CHECKSUM(id,date_id,taxon_id,location_id,depth_band_id,quality_id,depth,individualCount,occurrence_count)) FROM dbo.Fact_Occurrence)<>@checksum_before
 OR (SELECT COUNT(*) FROM dbo.Dim_Quality)<>@quality_before
 THROW 51305,'Published fact rows or quality IDs changed; migration rolled back.',1;
 COMMIT;
 SELECT 'MIGRATION PASS' AS result,@rows_before AS preserved_fact_rows,@quality_before AS preserved_quality_groups;
END TRY
BEGIN CATCH
 IF XACT_STATE()<>0 ROLLBACK;
 THROW;
END CATCH;
