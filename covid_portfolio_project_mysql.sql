/*
Covid 19 Data Exploration

Skills used: Joins, CTE's, Temp Tables, Windows Functions,
Aggregate Functions, Creating Views, Converting Data Types

*/

SELECT *
FROM covid_deaths
;
-- convert date col dtype to datetime and reformat to YY/MM/DD

SET SQL_SAFE_UPDATES = 0;
UPDATE covid_deaths
SET `date` = date_format(STR_TO_DATE(`date`, '%m/%d/%Y'), '%Y/%c/%e');
UPDATE covid_vax
SET `date` = date_format(STR_TO_DATE(`date`, '%m/%d/%Y'), '%Y/%c/%e');

ALTER TABLE covid_deaths MODIFY COLUMN `date` DATETIME;
ALTER TABLE covid_vax MODIFY COLUMN `date` DATETIME;

-- preview data tables
SELECT *
FROM covid_deaths;

SELECT *
FROM covid_vax;

-- lets check our rows and col numbers

SELECT
(SELECT COUNT(*) FROM covid_vax) as total_rows,
(SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'covid_vax'
	AND TABLE_SCHEMA = DATABASE()) as total_columns;
    
-- our covid_deaths table has a shape of (520288, 35)
-- our covid_vax table has a shape of (1040576, 41)
-- our data table import is successful

-- SELECT data that we are going to be using

SELECT country, `date`, total_cases, new_cases, total_deaths, population
FROM portfolio_project.covid_deaths
ORDER BY country, `date`;

-- Looking at total cases vs total deaths
-- shows likelihood of dying if you contract covid in your country:
SELECT country, `date`, total_cases, total_deaths, 
(total_deaths/total_cases) * 100 AS death_percentage
FROM portfolio_project.covid_deaths
WHERE country like '%states%'
ORDER BY country, `date`;

-- Looking at total cases vs. population
-- shows what percentage of population got covid
SELECT country, `date`, total_cases, population,
(total_cases/population) * 100 AS percent_population_infected
FROM portfolio_project.covid_deaths
WHERE country like '%states%' 
ORDER BY country, `date`;

-- Looking at countries with highest infection rate compared to population

SELECT country,  population, MAX(total_cases) as highest_infection_count,
MAX((total_cases/population) * 100) AS percent_population_infected
FROM portfolio_project.covid_deaths
GROUP BY country, population
ORDER BY percent_population_infected DESC;

-- Looking at countries with highest death rates compared to population

SELECT country, population, MAX(total_deaths) as total_death_count,
MAX((total_deaths/population) * 100) AS percent_population_death
FROM portfolio_project.covid_deaths
GROUP BY country, population
ORDER BY percent_population_death DESC;

-- using CTE to rank countries with the highest 
-- death rate compared to population by year

WITH death_count AS
(
SELECT country, population, 
YEAR(`date`) as years, MAX(total_deaths) as total_dead,
ROUND(MAX(total_deaths/population * 100), 4) as percent_population_death
FROM portfolio_project.covid_deaths
WHERE country NOT LIKE '%world%' AND country NOT LIKE '%high-income%'
GROUP BY country, population, YEAR(`date`)

), death_count_ranked AS
(
SELECT *,
DENSE_RANK() OVER(PARTITION BY years ORDER BY percent_population_death DESC) as death_percentage_ranking
FROM death_count

)
SELECT country, years, total_dead, percent_population_death, death_percentage_ranking
FROM death_count_ranked
WHERE death_percentage_ranking <=5
ORDER BY years, death_percentage_ranking;

-- Breaking down things by continent

SELECT country, MAX(total_deaths) as total_death_count
FROM portfolio_project.covid_deaths
WHERE continent IS NULL AND country NOT LIKE '%world%' 
GROUP BY country
ORDER by total_death_count DESC;

-- showing the continents with highest death count

SELECT continent, MAX(total_deaths) as total_death_count
FROM portfolio_project.covid_deaths
WHERE continent IS NOT NULL
GROUP BY continent
ORDER by total_death_count DESC;

-- global numbers

SELECT  SUM(new_cases) as total_cases, SUM(new_deaths) as total_deaths, 
(SUM(new_deaths)/SUM(new_cases)) * 100 as death_percentage
FROM portfolio_project.covid_deaths
WHERE continent IS NOT NULL
-- GROUP BY `date`
ORDER BY 1, 2
;

-- shows total population vs vaccinations
-- shows the percentage of population who has received 
-- at least one covid vaccine
SELECT cd.continent, cd.country, cd.`date`, cd.population, vx.new_vaccinations,
SUM(vx.new_vaccinations) OVER (PARTITION BY cd.country ORDER BY cd.country, cd.`date`)
AS rolling_people_vaccinated
From portfolio_project.covid_deaths as cd
JOIN portfolio_project.covid_vax as vx
	ON cd.country = vx.country 
    AND cd.`date` = vx.`date`
-- WHERE cd.continent LIKE '%America%'
WHERE cd.continent IS NOT NULL
ORDER BY 2, 3
;

-- using CTE to perform calculation on partition by in the previous query

WITH population_v_vaccination (Continent, Country, `Date`, Population, New_Vaccinations, Rolling_People_Vaccinated)
AS
(
SELECT cd.continent, cd.country, cd.`date`, cd.population, vx.new_vaccinations,
SUM(vx.new_vaccinations) OVER (PARTITION BY cd.country ORDER BY cd.country, cd.`date`)
AS rolling_people_vaccinated
From portfolio_project.covid_deaths as cd
JOIN portfolio_project.covid_vax as vx
	ON cd.country = vx.country 
    AND cd.`date` = vx.`date`
-- WHERE cd.continent LIKE '%America%'
WHERE cd.continent IS NOT NULL
-- ORDER BY 1, 2, `date`
)
SELECT *, (Rolling_People_Vaccinated/Population) * 100
FROM population_v_vaccination;

-- create a temp table to perform calcuation on partition by
-- in previous query

DROP TABLE IF EXISTS Percent_population_vaccinated;
CREATE TEMPORARY TABLE Percent_population_vaccinated
(
continent VARCHAR(255),
country VARCHAR(255),
`date` datetime,
population BIGINT,
new_vaccinations BIGINT,
rolling_people_vaccinated BIGINT

);

INSERT INTO Percent_population_vaccinated
(SELECT cd.continent, cd.country, cd.`date`, cd.population, vx.new_vaccinations,
SUM(vx.new_vaccinations) OVER (PARTITION BY cd.country ORDER BY cd.country, cd.`date`)
AS rolling_people_vaccinated
From portfolio_project.covid_deaths as cd
JOIN portfolio_project.covid_vax as vx
	ON cd.country = vx.country 
    AND cd.`date` = vx.`date`
-- WHERE cd.continent LIKE '%America%'
-- WHERE cd.continent IS NOT NULL
);

-- Creating view to store for later visualizations

CREATE VIEW Percent_population_vaccinated as
SELECT cd.continent, cd.country, cd.`date`, cd.population, vx.new_vaccinations,
SUM(vx.new_vaccinations) OVER (PARTITION BY cd.country ORDER BY cd.country, cd.`date`)
AS rolling_people_vaccinated
From portfolio_project.covid_deaths as cd
JOIN portfolio_project.covid_vax as vx
	ON cd.country = vx.country 
    AND cd.`date` = vx.`date`
WHERE cd.continent IS NOT NULL
;
