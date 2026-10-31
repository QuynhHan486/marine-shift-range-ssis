SET NOCOUNT ON; SET XACT_ABORT ON;
IF SCHEMA_ID('etl') IS NULL EXEC('CREATE SCHEMA etl');
IF SCHEMA_ID('load') IS NULL EXEC('CREATE SCHEMA load');
IF OBJECT_ID('dbo.Dim_Date','U') IS NULL
CREATE TABLE dbo.Dim_Date (id int NOT NULL PRIMARY KEY, event_date date NOT NULL UNIQUE,
 [year] int NOT NULL, decade nvarchar(10) NOT NULL, [quarter] nvarchar(2) NOT NULL,
 [month] int NOT NULL, season nvarchar(10) NOT NULL);
IF OBJECT_ID('dbo.Dim_Taxon','U') IS NULL
CREATE TABLE dbo.Dim_Taxon (id int NOT NULL PRIMARY KEY, kingdom nvarchar(256) NULL, phylum nvarchar(256) NULL,
 [class] nvarchar(256) NULL, [order] nvarchar(256) NULL, family nvarchar(256) NULL,
 genus nvarchar(256) NULL, species nvarchar(256) NULL,
 scientificName nvarchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL UNIQUE,
 taxon_rank nvarchar(20) NOT NULL);
IF OBJECT_ID('dbo.Dim_Location','U') IS NULL
CREATE TABLE dbo.Dim_Location (id int NOT NULL PRIMARY KEY, decimalLatitude decimal(14,10) NOT NULL,
 decimalLongitude decimal(14,10) NOT NULL, latitude_band nvarchar(16) NOT NULL,
 grid_cell nvarchar(32) NOT NULL, country nvarchar(128) NULL,
 shoredistance decimal(14,4) NULL, sst decimal(8,4) NULL,
 sst_group nvarchar(32) NULL, sss decimal(8,4) NULL,
 location_key binary(32) NOT NULL UNIQUE);
IF OBJECT_ID('dbo.Dim_Depth_Band','U') IS NULL
CREATE TABLE dbo.Dim_Depth_Band (id int NOT NULL PRIMARY KEY, depth_band nvarchar(64) NOT NULL UNIQUE,
 depth_min_m int NULL, depth_max_m int NULL);
IF OBJECT_ID('dbo.Dim_Quality','U') IS NULL
CREATE TABLE dbo.Dim_Quality (id int NOT NULL PRIMARY KEY, flag_on_land bit NOT NULL,
 flags nvarchar(512) NOT NULL, occurrence_status nvarchar(16) NULL,
 quality_key binary(32) NOT NULL UNIQUE);
IF OBJECT_ID('dbo.Fact_Occurrence','U') IS NULL
CREATE TABLE dbo.Fact_Occurrence (id nvarchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY,
 date_id int NOT NULL, taxon_id int NOT NULL, location_id int NOT NULL,
 depth_band_id int NOT NULL, quality_id int NOT NULL, depth decimal(20,10) NULL,
 individualCount decimal(18,4) NULL, occurrence_count int NOT NULL CHECK (occurrence_count=1));
IF OBJECT_ID('load.Dim_Date','U') IS NULL
CREATE TABLE load.Dim_Date (id int NOT NULL PRIMARY KEY, event_date date NOT NULL UNIQUE,
 [year] int NOT NULL, decade nvarchar(10) NOT NULL, [quarter] nvarchar(2) NOT NULL,
 [month] int NOT NULL, season nvarchar(10) NOT NULL);
IF OBJECT_ID('load.Dim_Taxon','U') IS NULL
CREATE TABLE load.Dim_Taxon (id int NOT NULL PRIMARY KEY, kingdom nvarchar(256) NULL, phylum nvarchar(256) NULL,
 [class] nvarchar(256) NULL, [order] nvarchar(256) NULL, family nvarchar(256) NULL,
 genus nvarchar(256) NULL, species nvarchar(256) NULL,
 scientificName nvarchar(256) COLLATE Latin1_General_100_BIN2 NOT NULL UNIQUE,
 taxon_rank nvarchar(20) NOT NULL);
IF OBJECT_ID('load.Dim_Location','U') IS NULL
CREATE TABLE load.Dim_Location (id int NOT NULL PRIMARY KEY, decimalLatitude decimal(14,10) NOT NULL,
 decimalLongitude decimal(14,10) NOT NULL, latitude_band nvarchar(16) NOT NULL,
 grid_cell nvarchar(32) NOT NULL, country nvarchar(128) NULL,
 shoredistance decimal(14,4) NULL, sst decimal(8,4) NULL,
 sst_group nvarchar(32) NULL, sss decimal(8,4) NULL,
 location_key binary(32) NOT NULL UNIQUE);
IF OBJECT_ID('load.Dim_Depth_Band','U') IS NULL
CREATE TABLE load.Dim_Depth_Band (id int NOT NULL PRIMARY KEY, depth_band nvarchar(64) NOT NULL UNIQUE,
 depth_min_m int NULL, depth_max_m int NULL);
IF OBJECT_ID('load.Dim_Quality','U') IS NULL
CREATE TABLE load.Dim_Quality (id int NOT NULL PRIMARY KEY, flag_on_land bit NOT NULL,
 flags nvarchar(512) NOT NULL, occurrence_status nvarchar(16) NULL,
 quality_key binary(32) NOT NULL UNIQUE);
IF OBJECT_ID('load.Fact_Occurrence','U') IS NULL
CREATE TABLE load.Fact_Occurrence (id nvarchar(64) COLLATE Latin1_General_100_BIN2 NOT NULL PRIMARY KEY,
 date_id int NOT NULL, taxon_id int NOT NULL, location_id int NOT NULL,
 depth_band_id int NOT NULL, quality_id int NOT NULL, depth decimal(20,10) NULL,
 individualCount decimal(18,4) NULL, occurrence_count int NOT NULL CHECK (occurrence_count=1));
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_Fact_Dim_Date')
ALTER TABLE dbo.Fact_Occurrence ADD CONSTRAINT FK_Fact_Dim_Date FOREIGN KEY (date_id) REFERENCES dbo.Dim_Date(id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.Fact_Occurrence') AND name='IX_Fact_date_id') CREATE INDEX IX_Fact_date_id ON dbo.Fact_Occurrence(date_id);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_Fact_Dim_Taxon')
ALTER TABLE dbo.Fact_Occurrence ADD CONSTRAINT FK_Fact_Dim_Taxon FOREIGN KEY (taxon_id) REFERENCES dbo.Dim_Taxon(id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.Fact_Occurrence') AND name='IX_Fact_taxon_id') CREATE INDEX IX_Fact_taxon_id ON dbo.Fact_Occurrence(taxon_id);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_Fact_Dim_Location')
ALTER TABLE dbo.Fact_Occurrence ADD CONSTRAINT FK_Fact_Dim_Location FOREIGN KEY (location_id) REFERENCES dbo.Dim_Location(id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.Fact_Occurrence') AND name='IX_Fact_location_id') CREATE INDEX IX_Fact_location_id ON dbo.Fact_Occurrence(location_id);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_Fact_Dim_Depth_Band')
ALTER TABLE dbo.Fact_Occurrence ADD CONSTRAINT FK_Fact_Dim_Depth_Band FOREIGN KEY (depth_band_id) REFERENCES dbo.Dim_Depth_Band(id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.Fact_Occurrence') AND name='IX_Fact_depth_band_id') CREATE INDEX IX_Fact_depth_band_id ON dbo.Fact_Occurrence(depth_band_id);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name='FK_Fact_Dim_Quality')
ALTER TABLE dbo.Fact_Occurrence ADD CONSTRAINT FK_Fact_Dim_Quality FOREIGN KEY (quality_id) REFERENCES dbo.Dim_Quality(id);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID('dbo.Fact_Occurrence') AND name='IX_Fact_quality_id') CREATE INDEX IX_Fact_quality_id ON dbo.Fact_Occurrence(quality_id);
IF OBJECT_ID('etl.Stg_OccurrenceRaw','U') IS NULL CREATE TABLE etl.Stg_OccurrenceRaw (source_row bigint IDENTITY(2,1) PRIMARY KEY,
[id] nvarchar(512) NULL,
[country] nvarchar(512) NULL,
[decimalLatitude] nvarchar(512) NULL,
[decimalLongitude] nvarchar(512) NULL,
[latitude_band] nvarchar(512) NULL,
[shoredistance] nvarchar(512) NULL,
[eventDate] nvarchar(512) NULL,
[depth] nvarchar(512) NULL,
[depth_band] nvarchar(512) NULL,
[sst] nvarchar(512) NULL,
[sss] nvarchar(512) NULL,
[flags] nvarchar(512) NULL,
[flag_on_land] nvarchar(512) NULL,
[kingdom] nvarchar(512) NULL,
[phylum] nvarchar(512) NULL,
[class] nvarchar(512) NULL,
[order] nvarchar(512) NULL,
[family] nvarchar(512) NULL,
[genus] nvarchar(512) NULL,
[species] nvarchar(512) NULL,
[scientificName] nvarchar(512) NULL,
[occurrenceStatus] nvarchar(512) NULL,
[individualCount] nvarchar(512) NULL);
IF OBJECT_ID('etl.Batch','U') IS NULL CREATE TABLE etl.Batch (
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
