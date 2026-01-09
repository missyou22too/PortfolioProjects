
/*

Nashville Housing Data Cleaning Project in SQL

Skills used: Joins, case statements, CTE's, feature creation


*/
USE PortfolioProjects
--view data

SELECT *
From PortfolioProjects.dbo.NashvilleHousing

--Check Property Address Data where null

SELECT *
From PortfolioProjects.dbo.NashvilleHousing
WHERE PropertyAddress is null
order by ParcelID

--ParcelID is equivalent to PropertyAddress
--Use this to fill in null values if there is a duplicate via self join

SELECT df1.ParcelID, df1.PropertyAddress, df2.ParcelID, df2.PropertyAddress, ISNULL(df1.PropertyAddress, df2. PropertyAddress)
From PortfolioProjects.dbo.NashvilleHousing df1
JOIN PortfolioProjects.dbo.NashvilleHousing df2
	on df1.ParcelID = df2.ParcelID --join col
	AND df1.[UniqueID] <> df2.[UniqueID] --where UID df1 != UID df2
WHERE df1.PropertyAddress is null

--Update table set where df1.PropertyAddress == null
Update df1
SET PropertyAddress = ISNULL(df1.PropertyAddress, df2.PropertyAddress)
From PortfolioProjects.dbo.NashvilleHousing df1
JOIN PortfolioProjects.dbo.NashvilleHousing df2
	on df1.ParcelID = df2.ParcelID
	AND df1.[UniqueID] <> df2.[UniqueID]
WHERE df1.PropertyAddress is null


--Break address col into individual cols (Address, City, State)

---------------------------------------------------------------------------------------------------

--view Address col
SELECT PropertyAddress
From PortfolioProjects.dbo.NashvilleHousing

--split Property Address on ',' value with -1/+1 to remove the comma from col
SELECT
SUBSTRING(PropertyAddress,1, CHARINDEX(',', PropertyAddress) -1) as Address
, SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) +1, LEN(PropertyAddress)) as Address
From PortfolioProjects.dbo.NashvilleHousing

--Add new cols to table
ALTER TABLE NashvilleHousing
Add PropertySplitAddress Nvarchar(255);

Update NashvilleHousing
SET PropertySplitAddress = SUBSTRING(PropertyAddress,1, CHARINDEX(',', PropertyAddress) -1) 

ALTER TABLE NashvilleHousing
Add PropertySplitCity Nvarchar(255);

Update NashvilleHousing
SET PropertySplitCity = SUBSTRING(PropertyAddress, CHARINDEX(',', PropertyAddress) +1, LEN(PropertyAddress)) 

SELECT *
From PortfolioProjects.dbo.NashvilleHousing


--Try delimiting owner address using PARSENAME
--convert ',' to '.' so PARSENAME will recognize

SELECT 
PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3) as OwnerSplitAddress
,PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2) as OwnerSplitCity
,PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1) as OwnerSplitState
From PortfolioProjects.dbo.NashvilleHousing

--Add all the new columns

ALTER TABLE NashvilleHousing
Add OwnerSplitAddress Nvarchar(255);

ALTER TABLE NashvilleHousing
Add OwnerSplitCity Nvarchar(255);

ALTER TABLE NashvilleHousing
Add OwnerSplitState Nvarchar(255);

--Set their col values

Update NashvilleHousing
SET OwnerSplitAddress = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 3),
	OwnerSplitCity = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 2),
	OwnerSplitState = PARSENAME(REPLACE(OwnerAddress, ',', '.'), 1);

----------------------------------------------------------------------------------

-- Change 1 and 0 to Yes and No in the 'Sold as Vacant' Field

--View current columns
SELECT Distinct(SoldAsVacant), Count(SoldAsVacant)
From PortfolioProjects.dbo.NashvilleHousing
Group by SoldAsVacant
order by 2

--Create Case statement to rename columns
SELECT SoldAsVacant
, CASE WHEN SoldAsVacant = 1 THEN 'Yes'
	 WHEN SoldAsVacant = 0 THEN 'No'
	 ELSE 'Unknown'
	 END
From PortfolioProjects.dbo.NashvilleHousing

--convert col type from INT to VARCHAR to make this change
ALTER TABLE NashvilleHousing
ALTER COLUMN SoldAsVacant VARCHAR(10)

Update NashvilleHousing
SET SoldAsVacant = CASE WHEN SoldAsVacant = 1 THEN 'Yes'
	WHEN SoldAsVacant = 0 THEN 'No'
	ELSE 'Unknown'
	END

---------------------------------------------------------------------------------------------------------------------

-- Identify and Remove Duplicates

WITH RowNumCTE AS (
SELECT *,
	ROW_NUMBER() OVER (
	PARTITION BY ParcelID,
				PropertyAddress,
				SalePrice,
				SaleDate,
				LegalReference
				ORDER BY
					UniqueID
					) row_num

From PortfolioProjects.dbo.NashvilleHousing
--order by ParcelID
)
DELETE
From RowNumCTE
WHERE row_num > 1
--Order by PropertyAddress

---------------------------------------------------------------------------------------------------

-- Delete Unused Columns


SELECT *
From PortfolioProjects.dbo.NashvilleHousing

ALTER TABLE PortfolioProjects.dbo.NashvilleHousing

DROP COLUMN OwnerAddress, TaxDistrict, PropertyAddress
