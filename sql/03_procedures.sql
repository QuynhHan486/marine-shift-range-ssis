CREATE OR ALTER PROCEDURE etl.usp_BeginBatch @source_file nvarchar(2048)
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
 TRUNCATE TABLE load.Dim_Date;
 TRUNCATE TABLE load.Dim_Taxon;
 TRUNCATE TABLE load.Dim_Location;
 TRUNCATE TABLE load.Dim_Depth_Band;
 TRUNCATE TABLE load.Dim_Quality;
 TRUNCATE TABLE load.Fact_Occurrence;
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
 DELETE dbo.Dim_Date;
 DELETE dbo.Dim_Taxon;
 DELETE dbo.Dim_Location;
 DELETE dbo.Dim_Depth_Band;
 DELETE dbo.Dim_Quality;
 INSERT dbo.Dim_Date ([id],[event_date],[year],[decade],[quarter],[month],[season]) SELECT [id],[event_date],[year],[decade],[quarter],[month],[season] FROM load.Dim_Date;
 INSERT dbo.Dim_Taxon ([id],[kingdom],[phylum],[class],[order],[family],[genus],[species],[scientificName],[taxon_rank]) SELECT [id],[kingdom],[phylum],[class],[order],[family],[genus],[species],[scientificName],[taxon_rank] FROM load.Dim_Taxon;
 INSERT dbo.Dim_Location ([id],[decimalLatitude],[decimalLongitude],[latitude_band],[grid_cell],[country],[shoredistance],[sst],[sst_group],[sss],[location_key]) SELECT [id],[decimalLatitude],[decimalLongitude],[latitude_band],[grid_cell],[country],[shoredistance],[sst],[sst_group],[sss],[location_key] FROM load.Dim_Location;
 INSERT dbo.Dim_Depth_Band ([id],[depth_band],[depth_min_m],[depth_max_m]) SELECT [id],[depth_band],[depth_min_m],[depth_max_m] FROM load.Dim_Depth_Band;
 INSERT dbo.Dim_Quality ([id],[flag_on_land],[flags],[occurrence_status],[flag_marine_unsure],[quality_key]) SELECT [id],[flag_on_land],[flags],[occurrence_status],[flag_marine_unsure],[quality_key] FROM load.Dim_Quality;
 INSERT dbo.Fact_Occurrence ([id],[date_id],[taxon_id],[location_id],[depth_band_id],[quality_id],[depth],[individualCount],[occurrence_count]) SELECT [id],[date_id],[taxon_id],[location_id],[depth_band_id],[quality_id],[depth],[individualCount],[occurrence_count] FROM load.Fact_Occurrence;
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
