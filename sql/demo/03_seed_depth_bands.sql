INSERT INTO dbo.Dim_Depth_Band (id, depth_band, depth_min_m, depth_max_m)
VALUES
(0, N'Unknown', NULL, NULL),
(1, N'Coastal/surface (<50 m)', 0, 50),
(2, N'Continental shelf (50-200 m)', 50, 200),
(3, N'Continental slope (200-1000 m)', 200, 1000),
(4, N'Deep sea (>=1000 m)', 1000, NULL);
