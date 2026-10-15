CREATE TABLE dbo.Dim_Date (
    id int PRIMARY KEY,
    event_date date NOT NULL,
    [year] int NOT NULL,
    decade nvarchar(10) NOT NULL,
    [quarter] nvarchar(2) NOT NULL,
    [month] int NOT NULL,
    season nvarchar(10) NOT NULL
);

CREATE TABLE dbo.Dim_Taxon (
    id int IDENTITY(1,1) PRIMARY KEY,
    kingdom nvarchar(256),
    phylum nvarchar(256),
    [class] nvarchar(256),
    [order] nvarchar(256),
    family nvarchar(256),
    genus nvarchar(256),
    species nvarchar(256),
    scientificName nvarchar(256) NOT NULL UNIQUE,
    taxon_rank nvarchar(20) NOT NULL
);

CREATE TABLE dbo.Dim_Location (
    id int IDENTITY(1,1) PRIMARY KEY,
    decimalLatitude decimal(14,10) NOT NULL,
    decimalLongitude decimal(14,10) NOT NULL,
    latitude_band nvarchar(16) NOT NULL,
    grid_cell nvarchar(32) NOT NULL,
    country nvarchar(128),
    shoredistance decimal(14,4),
    sst decimal(8,4),
    sst_group nvarchar(32),
    sss decimal(8,4),
    sss_group nvarchar(32),
    shore_distance_group nvarchar(32),
    location_key nvarchar(512) NOT NULL UNIQUE
);

CREATE TABLE dbo.Dim_Depth_Band (
    id int PRIMARY KEY,
    depth_band nvarchar(64) NOT NULL,
    depth_min_m int,
    depth_max_m int
);

CREATE TABLE dbo.Dim_Quality (
    id int IDENTITY(1,1) PRIMARY KEY,
    flag_on_land bit NOT NULL,
    flags nvarchar(512) NOT NULL,
    occurrence_status nvarchar(16),
    quality_key nvarchar(512) NOT NULL UNIQUE
);

CREATE TABLE dbo.Fact_Occurrence (
    id nvarchar(64) PRIMARY KEY,
    date_id int NOT NULL,
    taxon_id int NOT NULL,
    location_id int NOT NULL,
    depth_band_id int NOT NULL,
    quality_id int NOT NULL,
    depth decimal(20,10),
    individualCount decimal(18,4),
    occurrence_count int NOT NULL,
    FOREIGN KEY (date_id) REFERENCES dbo.Dim_Date(id),
    FOREIGN KEY (taxon_id) REFERENCES dbo.Dim_Taxon(id),
    FOREIGN KEY (location_id) REFERENCES dbo.Dim_Location(id),
    FOREIGN KEY (depth_band_id) REFERENCES dbo.Dim_Depth_Band(id),
    FOREIGN KEY (quality_id) REFERENCES dbo.Dim_Quality(id)
);
