-- SQL Script for Full Loading or 'Flush and Fill' using the Truncate technique

/*----------------------------------------------------------------------------------------------------------------------------------------------------------*/
/*  The following SQL Script flushes the data warehouse */
/*----------------------------------------------------------------------------------------------------------------------------------------------------------*/

USE [DWTaxiService_xxx]
go

-- First drop all foreign key constraints

ALTER TABLE dbo.DimStreet DROP CONSTRAINT [FK_DimStreet_DimCity]

ALTER TABLE dbo.FactTrips DROP CONSTRAINT [FK_FactTrips_DimCarType]

ALTER TABLE dbo.FactTrips DROP CONSTRAINT [FK_FactTrips_DimDates]

ALTER TABLE dbo.FactTrips DROP CONSTRAINT [FK_FactTrips_DimStreet]




Go

-- Now Truncate each table

TRUNCATE TABLE [dbo].[DimCarType]
TRUNCATE TABLE [dbo].[DimCity]
TRUNCATE TABLE [dbo].[DimDates]
TRUNCATE TABLE [dbo].[DimStreet]
TRUNCATE TABLE [dbo].[FactTrips]

-- ----------------------------------------------------------------------------------------------------------
-- Add back all foreign Key constraints

ALTER TABLE dbo.DimStreet WITH CHECK ADD CONSTRAINT [FK_DimStreet_DimCity]
FOREIGN KEY (CityKey) REFERENCES dbo.DimCity (CityKey)

ALTER TABLE dbo.FactTrips WITH CHECK ADD CONSTRAINT [FK_FactTrips_DimDates]
FOREIGN KEY (TripKey) REFERENCES dbo.DimDates (DateKey)

ALTER TABLE dbo.FactTrips WITH CHECK ADD CONSTRAINT [FK_FactTrips_DimCarType]
FOREIGN KEY (TripKey) REFERENCES dbo.DimCarType (CarTypeKey)

ALTER TABLE dbo.FactTrips WITH CHECK ADD CONSTRAINT [FK_FactTrips_DimStreet]
FOREIGN KEY (TripKey) REFERENCES dbo.DimStreet (StreetKey)

/*--------------------------------------------------------------------------------------------------------------------------------------------------------------*/
/* The following script transforms and then loads  (FILLS) data from OLTP ServiceDB into OLAP DWTaxiService Data Warehouse */
/*--------------------------------------------------------------------------------------------------------------------------------------------------------------*/

-- First populate tables with No Foreign Keys.   
INSERT INTO dbo.DimCarType
( 
	CarTypeId,
	CarType
 )
 (

	SELECT 
		[CarTypeId]		= CAST (( [CarModel_Id]) as nchar(5)),
		[CarType]	= CAST (( 'Unknown') as nchar(8))
	FROM [serviceDB_xxx].[dbo].[CarModel]
)
go

INSERT INTO dbo.DimCity
(	CityId , 
	CityName,
	[State]
) 
(
	SELECT 
		[CityId]  =  CAST ( [City_Code] AS nchar(4) ),
		[CityName] = CAST ( isNull( [City], 'Unknown' ) as nvarchar(50) ),
		[State] = CAST (isNull([State], 'Unknown') as nvarchar(50))
	FROM [serviceDB_xxx].[dbo].[City]
)
go

Insert into dbo.DimDates
(
	[Date], 
	[DateName],
	[Month],
	[MonthName],
	[Year],
	[YearName]
)
(
	Select 
		[Date] = cast(datetime), 
		[DateName] = cast ([date_name] as nVarchar(50)),
		[Month] = CAST (([MONTH] as int),
		[MonthName] = CAST (([mnthname] as nvarchar(50)),
		[Year] = CAST (([year] as int)
		[YearName] = CAST (([yr_name] as nvarchar(50))
	From [serviceDB_xxx].[dbo].[Trip]
 )
go

-- Populate the DimDate table. Since no source data exists, we will have to do this programmatically -- 
-- the following SQL script Populates DimDate table with dates between 1990 and 1995


Declare @StartDate datetime = '01/01/1990'   /* variable @StartDate of type DateTime is initialized the start date '01/01/1990' */
Declare @EndDate datetime = '12/31/1995' /* variable @EndDate of type DateTime is initialized the end date '12/31/1994' */

-- Use a while loop to add dates to the table
Declare @DateInProcess datetime                 /* Variable @DateInProcess is a loop counter, holds the date value being processed, and will track when loop needs to end */
Set @DateInProcess = @StartDate

While @DateInProcess <= @EndDate
 Begin
 -- Add a row into the date dimension table for this date
 Insert Into DimDates
 (	[Date], 
	[DateName], 
	[Month], 
	[MonthName], 
	[Year], 
	[YearName] 
 )
 Values 
 ( 
	  @DateInProcess,										-- [Date]
	  DateName ( weekday, @DateInProcess ),					-- [DateName]  
	  Month( @DateInProcess ),								-- [Month]   
	  DateName( month, @DateInProcess ),					-- [MonthName]
	  Cast( Year(@DateInProcess ) as nVarchar(50) )			 -- [Year] 
 )  
 -- Add a day and loop again
 Set @DateInProcess = DateAdd(d, 1, @DateInProcess)

 End  -- END OF DATE LOOP

  --Add one more date records to handle nulls and incorrect date data

Set Identity_Insert [DWPubsSales-xxxx].[dbo].[DimDates] On

Insert Into [dbo].[DimDates] 
  ( 
[DateKey],
	[Date],
	[DateName], 
	[Month],
	[MonthName],
	[Year], 
	[YearName] 
  )
  (
	  Select 
		[DateKey] = -1,
		[Date] =  '01/01/1989',
		[DateName] = Cast('Unknown Day' as nVarchar(50)),
		[Month] = -1,
		[MonthName] = Cast('Unknown Month' as nVarchar(50)),
		[YearName] = Cast('Unknown Year' as nVarchar(50))
  )
  Go

  Set Identity_Insert [DWTaxiService_xxx].[dbo].[DimDates] off  -- don't forget this!

GO

 /*------------------------------------------------------------------
-- Next populate the Dimension tables with FK constraint - 
--------------------------------------------------------------------*/

INSERT INTO [dbo].[DimStreet]
( 
	CityKey
	 
)
(
	SELECT  
		CityKey =	  CAST ( [City_Code] as int  )


	FROM (	[serviceDB_xxx].[dbo].[City]  INNER JOIN  DimCity
				ON [serviceDB_xxx].[dbo].[City].[City_Code] = DimCity.CityId)
			
)
GO

--Next Populate the FactTRIPS Table

INSERT INTO [dbo].[FactTrips]
(
	DateKey,
	CarTypeKey,
	StreetKey
 )
 (
	SELECT        
		DateKey = DimDates.DateKey,
		CarTypeKey = DimCarType.CarTypeKey, 
		StreetKey = DimStreet.StreetKey
	FROM            
		(DimDates INNER JOIN serviceDB_xxx.dbo.Trip AS TR
			ON DimDates.DateKey = TR.Date)
			  inner join DimCarType on DimCarType.CarTypeId = TR.CarModel_Id
)
go
