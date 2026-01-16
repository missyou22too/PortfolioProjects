/*

Data Cleaning and Transformation of a
Sailboat Race Dataset in SQL

Skills used:

- ALTER TABLE
- UPDATE TABLE
- Viewing database schema 
- CTEs
- CASE statements
- Subqueries
- DROP COL
- DECLARE

*/

SELECT *
FROM GP_2025_Race1;

SELECT *
INTO GP_2025_Race1_copy
FROM GP_2025_Race1;
GO --batch separator tells SQL to execute before continuing

SELECT *
FROM GP_2025_Race1_copy;

---------------------------- VIEW COLUMNS ----------------------------
/* Sanity Check: 
- confirm required cols exists
- identify null value in UTC col
- identify duplicate rows if present */

SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'GP_2025_Race1_copy';

SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'GP_2025_Race1_copy'
AND COLUMN_NAME IN ('UTC', 'TWA', 'BSP', 'VMG', 
'Lat', 'Lon', 'Targ_Twa', 'TargBsp', 'COG', 'SOG')
ORDER BY ORDINAL_POSITION ASC;

SELECT *
FROM GP_2025_Race1_copy
WHERE UTC IS NULL;

SELECT UTC, TWA, TWS, BSP, COUNT(*) as Duplicates
FROM GP_2025_Race1_copy
GROUP BY UTC, TWA, TWS, BSP
HAVING COUNT(*) > 1;

/* No null values exist in listed cols, no duplicate rows exist: proceed */

---------------------------- ADD TIME AND DIST COLS ----------------------------


ALTER TABLE GP_2025_Race1_copy
ADD record_Duration FLOAT;
GO

-- 11.57406 is our time constant
SELECT UTC,
((LEAD(UTC) OVER (ORDER BY UTC) - UTC) * 1000000) / 11.57406 AS recordDur
FROM GP_2025_Race1_copy;

-- 11.57406 is our time constant
SELECT UTC,
LEAD(UTC) OVER (ORDER BY UTC),
((LEAD(UTC) OVER (ORDER BY UTC) - UTC) * 1000000) 
FROM GP_2025_Race1_copy;

--Update record_Duration col using temp table CTE calc
WITH timeIntervals AS (
SELECT UTC,
(LEAD(UTC) OVER (ORDER BY UTC) - UTC) * 1000000 / 11.57406 AS recordDur
FROM GP_2025_Race1_copy) 
UPDATE t
SET t.record_Duration =  ti.recordDur
--SELECT t.UTC, ti.recordDur
FROM GP_2025_Race1_copy as t
JOIN timeIntervals as ti
ON t.UTC = ti.UTC;

--convert knots to feet 1knt = 1.6878ft/s

ALTER TABLE GP_2025_Race1_copy
ADD actual_Distance FLOAT, 
SOG_Distance FLOAT;
GO

SELECT BSP, SOG,
record_Duration,
BSP * record_Duration * 1.6878 as ft_per_s,
SOG * record_Duration * 1.6878 as SOG_dist
FROM GP_2025_Race1_copy;

UPDATE GP_2025_Race1_copy
SET actual_Distance = BSP * record_Duration * 1.6878,
	SOG_Distance = SOG * record_Duration * 1.6878;

---------------------------- ADD DATE & TIME COLS ----------------------------

ALTER TABLE GP_2025_Race1_copy
ADD UTC_DateTime DATETIME;
GO

SELECT UTC, UTC_DateTime,
DATEADD(SECOND, UTC * 86400, '1899-12-31') as newdatetime
FROM GP_2025_Race1_copy;

UPDATE GP_2025_Race1_copy
SET UTC_DateTime = DATEADD(SECOND, UTC * 86400, '1899-12-31');

--split UTC_DateTime into UTC_Date and UTC_Time

SELECT UTC_DateTime,
CAST(UTC_DateTime AS DATE) as ExtractedDate,
CAST(UTC_DateTime AS TIME) as ExtractedTime
FROM GP_2025_Race1_copy;

ALTER TABLE GP_2025_Race1_copy
ADD UTC_Date DATE, UTC_Time TIME;
GO

UPDATE GP_2025_Race1_copy
SET UTC_Date = CAST(UTC_DateTime AS DATE),
	UTC_Time = CAST(UTC_DateTime AS TIME);

-- Drop original datetime col

ALTER TABLE GP_2025_Race1_copy
DROP COLUMN UTC_DateTime;
GO

--identify and treat any missing lat/lon values

SELECT 
	SUM(CASE WHEN lat IS NULL THEN 1 ELSE 0 END) as lat_null_count,
	SUM(CASE WHEN lon IS NULL THEN 1 ELSE 0 END) as lon_null_count
FROM GP_2025_Race1_copy;

-- no missing latlon values in this dataset

---------------------------- ADD ANGLE BASED COLS ----------------------------

-- Create our derived calculation columns, using our distance unit 1.6878 

ALTER TABLE GP_2025_Race1_copy
ADD twa_multiplier FLOAT,
	polar_Distance FLOAT,
	targ_Distance FLOAT,
	VMG_BSP FLOAT,
	VMG_targ FLOAT,
	TargVMGPercent FLOAT,
	VMG_polar FLOAT,
	VMG_BSP_dist FLOAT,
	VMG_targ_dist FLOAT,
	VMG_polar_dist FLOAT;
GO

UPDATE GP_2025_Race1_copy
SET polar_Distance = PolBsp * record_Duration * 1.6878,
	targ_Distance = TargBsp * record_Duration * 1.6878;


WITH temp_multiplier AS(
SELECT UTC, TWA,
COS(ABS(RADIANS(CASE WHEN ABS(TWA) >= 90 THEN 180 - ABS(TWA) 
	 WHEN ABS(TWA) < 90 THEN ABS(TWA) 
	 END))) as twa_mult,
COS(ABS(RADIANS(CASE WHEN ABS(Targ_Twa) >= 90 THEN 180 - ABS(Targ_Twa) 
	 WHEN ABS(Targ_Twa) < 90 THEN ABS(Targ_Twa) 
	 END))) as twa_mult_targets
FROM GP_2025_Race1_copy)
UPDATE t
SET VMG_BSP = t.BSP * temp.twa_mult,
	VMG_targ = t.TargBsp * temp.twa_mult_targets,
	VMG_polar = t.PolBsp * temp.twa_mult_targets,
	VMG_BSP_dist = t.actual_Distance * temp.twa_mult,
	VMG_polar_dist = t.PolBsp * t.record_Duration * 1.6878
FROM GP_2025_Race1_copy AS t
JOIN temp_multiplier AS temp
	ON t.UTC = temp.UTC;

--Add more derived cols
UPDATE GP_2025_Race1_copy
SET VMG_targ_dist = VMG_targ * record_Duration * 1.6878,
	TargVMGPercent = (VMG_BSP / VMG_targ) * 100;


---------------------------- CALC PORT AND STARBOARD, UPDN ----------------------------

ALTER TABLE GP_2025_Race1_copy
ADD PS VARCHAR(50),
	UpDn VARCHAR(50);
GO

UPDATE GP_2025_Race1_copy
SET PS = CASE WHEN TWA >= 0 THEN 'S' ELSE 'P' END,
	UpDn = CASE WHEN ABS(TWA) >= 90 THEN 'Dn' ELSE 'Up' END


---------------------------- CALC ANGLE LOSS COLS ----------------------------


ALTER TABLE GP_2025_Race1_copy
ADD angle_loss_distance FLOAT;
GO

WITH temp_angle AS (
SELECT UTC,
CASE WHEN ABS(calcTWA) - ABS(calcTargTWA) < 0 THEN
	-1 * actual_Distance * SQRT(2 - 2 * COS(ABS(anglediffradians))) ELSE
	actual_Distance * SQRT(2 - 2 * COS(ABS(anglediffradians))) END AS angle_loss 
FROM (SELECT calcTargTWA, calcTWA, actual_Distance, UTC,
ABS(RADIANS(ABS(calcTWA) - ABS(calcTargTWA))) as anglediffradians
FROM (SELECT 
actual_Distance, UTC,
CASE WHEN UpDn = 'Up' THEN ABS(TWA) ELSE 180 - ABS(TWA) END AS calcTWA,
CASE WHEN UpDn = 'Up' THEN ABS(Targ_Twa) ELSE 180 - ABS(Targ_Twa) END as calcTargTWA
FROM GP_2025_Race1_copy) as angle_calc) as angle_dist_calc)
UPDATE t
SET t.angle_loss_distance = ta.angle_loss
FROM GP_2025_Race1_copy t
JOIN temp_angle ta
	ON t.UTC = ta.UTC;


ALTER TABLE GP_2025_Race1_copy
ADD angle_time_loss FLOAT,
	speed_distance_lost_target FLOAT,
	speed_distance_lost_polar FLOAT,
	speed_time_lost_target FLOAT,
	speed_time_lost_polar FLOAT;
GO

UPDATE GP_2025_Race1_copy
SET angle_time_loss = angle_loss_distance / actual_Distance,
	speed_distance_lost_target = targ_distance - actual_Distance,
	speed_distance_lost_polar = polar_Distance - actual_Distance;

UPDATE GP_2025_Race1_copy
SET speed_time_lost_target = speed_distance_lost_target / TargBsp,
	speed_time_lost_polar = speed_distance_lost_polar / PolBsp;

-- view cols with all null values

--set up variables 
DECLARE @tableName NVARCHAR(255) = 'GP_2025_Race1_copy';
DECLARE @schemaName NVARCHAR(255) = 'dbo';
DECLARE @sql NVARCHAR(MAX) = N'SELECT ';

-- loop through column names and count num null values

SELECT @sql += N'COUNT(CASE WHEN ' + QUOTENAME(name) + ' IS NULL THEN 1 END) AS '
	+ QUOTENAME(name + '_NULLCount')
	+ CASE WHEN name != (SELECT TOP 1 name FROM sys.columns
		WHERE object_id = OBJECT_ID(@schemaName + '.' + @tableName)
		ORDER BY column_id DESC)
	  THEN ',' ELSE '' END
	  +NCHAR(10)
FROM sys.columns
WHERE object_id = OBJECT_ID(@schemaName + '.' + @tableName)
ORDER BY column_id;

SET @sql += N'FROM ' + QUOTENAME(@schemaName) + '.' + QUOTENAME(@tableName) + ';';

--show num null per col
PRINT @sql;

EXEC sp_executesql @sql;

/*
From here I would either drop all null cols depending on what my
further purpose with this dataset is, or I would keep them in 
preparation to eventually reintegrate the dataset into the expedition
sailing platform
*/

SELECT *
FROM GP_2025_Race1_copy;

