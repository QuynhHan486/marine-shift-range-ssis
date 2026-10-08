CREATE OR ALTER VIEW etl.v_Parsed AS
SELECT r.source_row, NULLIF(TRIM(r.[id]),'') AS [id], NULLIF(TRIM(r.[country]),'') AS [country], TRY_CONVERT(decimal(14,10),NULLIF(TRIM(r.[decimalLatitude]),'')) AS [decimalLatitude], TRY_CONVERT(decimal(14,10),NULLIF(TRIM(r.[decimalLongitude]),'')) AS [decimalLongitude], TRY_CONVERT(decimal(14,4),NULLIF(TRIM(r.[shoredistance]),'')) AS [shoredistance], TRY_CONVERT(date,NULLIF(TRIM(r.eventDate),''),103) AS [eventDate], TRY_CONVERT(decimal(20,10),NULLIF(TRIM(r.[depth]),'')) AS [depth], TRY_CONVERT(decimal(8,4),NULLIF(TRIM(r.[sst]),'')) AS [sst], TRY_CONVERT(decimal(8,4),NULLIF(TRIM(r.[sss]),'')) AS [sss], COALESCE(NULLIF(TRIM(r.flags),''),N'[]') AS [flags], CASE LOWER(TRIM(r.[flag_on_land])) WHEN 'true' THEN CONVERT(bit,1) WHEN 'false' THEN CONVERT(bit,0) END AS [flag_on_land], CASE LOWER(TRIM(r.[flag_marine_unsure])) WHEN 'true' THEN CONVERT(bit,1) WHEN 'false' THEN CONVERT(bit,0) END AS [flag_marine_unsure], NULLIF(TRIM(r.[kingdom]),'') AS [kingdom], NULLIF(TRIM(r.[phylum]),'') AS [phylum], NULLIF(TRIM(r.[class]),'') AS [class], NULLIF(TRIM(r.[order]),'') AS [order], NULLIF(TRIM(r.[family]),'') AS [family], NULLIF(TRIM(r.[genus]),'') AS [genus], NULLIF(TRIM(r.[species]),'') AS [species], NULLIF(TRIM(r.[scientificName]),'') AS [scientificName], LOWER(NULLIF(TRIM(r.occurrenceStatus),'')) AS [occurrenceStatus], TRY_CONVERT(decimal(18,4),NULLIF(TRIM(r.[individualCount]),'')) AS [individualCount],
 ROW_NUMBER() OVER(PARTITION BY NULLIF(TRIM(r.id),'') COLLATE Latin1_General_100_BIN2 ORDER BY r.source_row) AS duplicate_sequence
FROM etl.Stg_OccurrenceRaw r;
GO
CREATE OR ALTER VIEW etl.v_Checked AS
SELECT p.*, CONCAT(CASE WHEN p.id IS NULL OR LEN(p.id)>64 THEN N'invalid_id;' ELSE N'' END,CASE WHEN p.duplicate_sequence>1 THEN N'duplicate_id;' ELSE N'' END,CASE WHEN p.eventDate IS NULL OR p.eventDate<'19800101' OR p.eventDate>CONVERT(date,SYSDATETIMEOFFSET() AT TIME ZONE 'SE Asia Standard Time') THEN N'invalid_date;' ELSE N'' END,CASE WHEN p.decimalLatitude IS NULL OR p.decimalLatitude NOT BETWEEN 0 AND 23 OR p.decimalLongitude IS NULL OR p.decimalLongitude NOT BETWEEN 99 AND 121 THEN N'invalid_coordinates;' ELSE N'' END,CASE WHEN p.scientificName IS NULL OR LEN(p.scientificName)>256 THEN N'invalid_scientific_name;' ELSE N'' END,CASE WHEN p.flag_on_land IS NULL OR p.flag_marine_unsure IS NULL THEN N'invalid_boolean;' ELSE N'' END,CASE WHEN p.occurrenceStatus IS NOT NULL AND p.occurrenceStatus NOT IN ('present','absent') THEN N'invalid_status;' ELSE N'' END,CASE WHEN p.depth<0 OR p.individualCount<0 THEN N'negative_measure;' ELSE N'' END,CASE WHEN LEN(p.country)>128 OR LEN(p.flags)>512 THEN N'overlength_text;' ELSE N'' END,CASE WHEN LEN(p.[kingdom])>256 THEN N'overlength_kingdom;' ELSE N'' END,CASE WHEN LEN(p.[phylum])>256 THEN N'overlength_phylum;' ELSE N'' END,CASE WHEN LEN(p.[class])>256 THEN N'overlength_class;' ELSE N'' END,CASE WHEN LEN(p.[order])>256 THEN N'overlength_order;' ELSE N'' END,CASE WHEN LEN(p.[family])>256 THEN N'overlength_family;' ELSE N'' END,CASE WHEN LEN(p.[genus])>256 THEN N'overlength_genus;' ELSE N'' END,CASE WHEN LEN(p.[species])>256 THEN N'overlength_species;' ELSE N'' END,CASE WHEN NULLIF(TRIM(r.[decimalLatitude]),'') IS NOT NULL AND p.[decimalLatitude] IS NULL THEN N'invalid_number_decimalLatitude;' ELSE N'' END,CASE WHEN NULLIF(TRIM(r.[decimalLongitude]),'') IS NOT NULL AND p.[decimalLongitude] IS NULL THEN N'invalid_number_decimalLongitude;' ELSE N'' END,CASE WHEN NULLIF(TRIM(r.[shoredistance]),'') IS NOT NULL AND p.[shoredistance] IS NULL THEN N'invalid_number_shoredistance;' ELSE N'' END,CASE WHEN NULLIF(TRIM(r.[depth]),'') IS NOT NULL AND p.[depth] IS NULL THEN N'invalid_number_depth;' ELSE N'' END,CASE WHEN NULLIF(TRIM(r.[sst]),'') IS NOT NULL AND p.[sst] IS NULL THEN N'invalid_number_sst;' ELSE N'' END,CASE WHEN NULLIF(TRIM(r.[sss]),'') IS NOT NULL AND p.[sss] IS NULL THEN N'invalid_number_sss;' ELSE N'' END,CASE WHEN NULLIF(TRIM(r.[individualCount]),'') IS NOT NULL AND p.[individualCount] IS NULL THEN N'invalid_number_individualCount;' ELSE N'' END,CASE WHEN p.flag_on_land<>CONVERT(bit,CASE WHEN CHARINDEX('ON_LAND',p.flags)>0 THEN 1 ELSE 0 END) OR p.flag_marine_unsure<>CONVERT(bit,CASE WHEN CHARINDEX('MARINE_UNSURE',p.flags)>0 THEN 1 ELSE 0 END) THEN N'flag_mismatch;' ELSE N'' END) AS reject_reason
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
IF OBJECT_ID('etl.Stg_Occurrence','U') IS NULL SELECT TOP(0) * INTO etl.Stg_Occurrence FROM etl.v_Accepted;
GO
CREATE OR ALTER VIEW etl.v_LoadDim_Date AS
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
