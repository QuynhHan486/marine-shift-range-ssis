SET NOCOUNT ON;
DECLARE @batch bigint=(SELECT batch_id FROM etl.SnapshotState WHERE singleton=1);
IF NOT EXISTS(SELECT 1 FROM etl.Batch WHERE batch_id=@batch AND status='SUCCEEDED') THROW 51100,'No published successful snapshot.',1;
IF (SELECT COUNT_BIG(*) FROM dbo.Fact_Occurrence)<>108680 THROW 51101,'Unexpected fact count for the supplied dataset.',1;
IF (SELECT COUNT(*) FROM dbo.Dim_Date)<>2314 OR (SELECT COUNT(*) FROM dbo.Dim_Taxon)<>7737
 OR (SELECT COUNT(*) FROM dbo.Dim_Location)<>3067 OR (SELECT COUNT(*) FROM dbo.Dim_Depth_Band)<>5
 OR (SELECT COUNT(*) FROM dbo.Dim_Quality)<>26 THROW 51102,'Unexpected dimension counts.',1;
IF EXISTS(SELECT id COLLATE Latin1_General_100_BIN2 FROM etl.Stg_Occurrence EXCEPT SELECT id FROM dbo.Fact_Occurrence)
 OR EXISTS(SELECT id FROM dbo.Fact_Occurrence EXCEPT SELECT id COLLATE Latin1_General_100_BIN2 FROM etl.Stg_Occurrence) THROW 51103,'Source and fact ID sets differ.',1;
IF EXISTS (
 SELECT s.id COLLATE Latin1_General_100_BIN2,s.eventDate,s.scientificName COLLATE Latin1_General_100_BIN2,s.decimalLatitude,s.decimalLongitude,s.country,s.shoredistance,s.sst,s.sss,
 s.depth_band_id,s.flag_on_land,s.flags,s.occurrenceStatus,s.depth,s.individualCount
 FROM etl.Stg_Occurrence s
 EXCEPT
 SELECT f.id,d.event_date,t.scientificName,l.decimalLatitude,l.decimalLongitude,l.country,l.shoredistance,l.sst,l.sss,
 f.depth_band_id,q.flag_on_land,q.flags,q.occurrence_status,f.depth,f.individualCount
 FROM dbo.Fact_Occurrence f JOIN dbo.Dim_Date d ON f.date_id=d.id JOIN dbo.Dim_Taxon t ON f.taxon_id=t.id
 JOIN dbo.Dim_Location l ON f.location_id=l.id JOIN dbo.Dim_Quality q ON f.quality_id=q.id
) THROW 51104,'A fact key, attribute, null, or measure differs from the source.',1;
-- Compare original numeric strings at higher precision to detect accidental rounding.
IF EXISTS (
 SELECT id COLLATE Latin1_General_100_BIN2,TRY_CONVERT(decimal(28,12),NULLIF(decimalLatitude,'')),TRY_CONVERT(decimal(28,12),NULLIF(decimalLongitude,'')),
 TRY_CONVERT(decimal(28,12),NULLIF(depth,'')),TRY_CONVERT(decimal(28,12),NULLIF(individualCount,'')),
 TRY_CONVERT(decimal(28,12),NULLIF(sst,'')),TRY_CONVERT(decimal(28,12),NULLIF(sss,'')),TRY_CONVERT(decimal(28,12),NULLIF(shoredistance,''))
 FROM etl.Stg_OccurrenceRaw
 EXCEPT
 SELECT f.id,CONVERT(decimal(28,12),l.decimalLatitude),CONVERT(decimal(28,12),l.decimalLongitude),
 CONVERT(decimal(28,12),f.depth),CONVERT(decimal(28,12),f.individualCount),
 CONVERT(decimal(28,12),l.sst),CONVERT(decimal(28,12),l.sss),CONVERT(decimal(28,12),l.shoredistance)
 FROM dbo.Fact_Occurrence f JOIN dbo.Dim_Location l ON f.location_id=l.id
) THROW 51105,'Numeric precision changed.',1;
IF (SELECT COUNT(*) FROM dbo.Fact_Occurrence WHERE depth_band_id=0 AND depth IS NULL)<>46440 THROW 51106,'Unknown depth handling failed.',1;
IF EXISTS(SELECT 1 FROM dbo.Fact_Occurrence WHERE occurrence_count<>1) THROW 51107,'Invalid occurrence measure.',1;
IF NOT EXISTS(SELECT 1 FROM dbo.Dim_Location WHERE latitude_band=N'20-23°N') THROW 51108,'Unicode latitude labels failed.',1;
IF (SELECT COUNT(*) FROM etl.TaxonConflict WHERE batch_id=@batch)<>10 THROW 51109,'Unexpected taxonomy conflict count.',1;
IF EXISTS(SELECT 1 FROM dbo.Fact_Occurrence f
 LEFT JOIN dbo.Dim_Date d ON d.id=f.date_id LEFT JOIN dbo.Dim_Taxon t ON t.id=f.taxon_id
 LEFT JOIN dbo.Dim_Location l ON l.id=f.location_id LEFT JOIN dbo.Dim_Depth_Band b ON b.id=f.depth_band_id
 LEFT JOIN dbo.Dim_Quality q ON q.id=f.quality_id
 WHERE d.id IS NULL OR t.id IS NULL OR l.id IS NULL OR b.id IS NULL OR q.id IS NULL) THROW 51110,'Orphan fact rows.',1;
IF EXISTS(SELECT 1 FROM etl.Batch WHERE batch_id=@batch AND (rejected_rows<>0 OR source_rows<>accepted_rows OR fact_rows<>accepted_rows)) THROW 51111,'Batch reconciliation failed.',1;
DBCC CHECKCONSTRAINTS ('dbo.Fact_Occurrence') WITH ALL_CONSTRAINTS;
SELECT 'PASS' AS validation, @batch AS published_batch,
 (SELECT COUNT_BIG(*) FROM dbo.Fact_Occurrence) AS fact_rows,
 (SELECT SUM(CONVERT(bigint,occurrence_count)) FROM dbo.Fact_Occurrence) AS occurrence_sum;
