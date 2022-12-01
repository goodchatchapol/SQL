--RUN IN DWH
IF OBJECT_ID(N'tempdb..#Calls_Made') IS NOT NULL DROP TABLE #Calls_Made


DECLARE @StartDate AS VARCHAR(50) = '2021-03-30';
DECLARE @EndDate AS VARCHAR(50) = '2022-01-31 23:59:59';

DECLARE @date DATETIME = GETDATE()
DECLARE @AsOfDate DATE
DECLARE @countryAlpha2 CHAR(2)
DECLARE @country NVARCHAR(100)
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT @AsOfDate = CONVERT(DATE,IIF(DATEPART(WEEKDAY,DATEADD(HOUR,-16,GETDATE())) IN (1),DATEADD(DAY,-2,DATEADD(HOUR,-16,@Date))
,IIF(DATEPART(WEEKDAY,DATEADD(HOUR,-16,@Date)) IN (7),DATEADD(DAY,-1,DATEADD(HOUR,-16,@Date)) ,DATEADD(HOUR,-16,@Date))), 23)

SET @countryAlpha2 = 'PH'
SET @country = 'Philippines'

---------------------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT Call_Made_Date = CAST(DATEADD(HOUR,8,pc.Createdon) AS DATE)
,Call_Made_Month = CAST(DATEADD(MONTH,DATEDIFF(MONTH,0,DATEADD(HOUR, 8, pc.Createdon)),0) AS DATE)
,Account_ID = pc.regardingobjectid
,Account_Number = acc.alternis_number
,Card_Number = acc.alternis_invoicenumber
,Call_Made_Time_Bucket = CASE (DATEPART(HOUR,DATEADD(HOUR,8,pc.Createdon)))
WHEN 0 THEN '00:00 to 01:00'
WHEN 1 THEN '01:00 to 02:00'
WHEN 2 THEN '02:00 to 03:00'
WHEN 3 THEN '03:00 to 04:00'
WHEN 4 THEN '04:00 to 05:00'
WHEN 5 THEN '05:00 to 06:00'
WHEN 6 THEN '06:00 to 07:00'
WHEN 7 THEN '07:00 to 08:00'
WHEN 8 THEN '08:00 to 09:00'
WHEN 9 THEN '09:00 to 10:00'
WHEN 10 THEN '10:00 to 11:00'
WHEN 11 THEN '11:00 to 12:00'
WHEN 12 THEN '12:00 to 13:00'
WHEN 13 THEN '13:00 to 14:00'
WHEN 14 THEN '14:00 to 15:00'
WHEN 15 THEN '15:00 to 16:00'
WHEN 16 THEN '16:00 to 17:00'
WHEN 17 THEN '17:00 to 18:00'
WHEN 18 THEN '18:00 to 19:00'
WHEN 19 THEN '19:00 to 20:00'
WHEN 20 THEN '20:00 to 21:00'
WHEN 21 THEN '21:00 to 22:00'
WHEN 22 THEN '22:00 to 23:00'
ELSE '23:00 to 24:00'
END
,Portfolio = p.alternis_name
,Business = IIF(ISNULL(p.alternis_reportingname, p.Alternis_Name) LIKE '%SVC%' OR p.alternis_isservicingname = 'Yes' , 'Debt Servicing','Debt Purchase')
,Mediator = pc.owneridname
,Called_By_Flag =
CASE
WHEN pc.owneridname IN ('System Admin','Senthan Shanmugaratnam','Joseph Lo','Raymon Osoteo'
,'agents #','agents2 #','agents3 #','SSIS3 PACKAGE','SSIS1 PACKAGE'
,'SSIS2 PACKAGE','ssis1-ph','ssis2-ph','ssis3-ph','Test01 #','Test02 #'
,'Test03 #', 'Naw Seng')
OR pc.owneridname LIKE '%SSIS%'
OR pc.owneridname LIKE '%#%'
THEN 'Dialler'
ELSE 'Agent'
END
,alternis_contactdispositionname
,alternis_calloutcomename

INTO #Calls_Made

FROM stage.phonecall pc
JOIN Stage.alternis_account acc
ON acc.alternis_accountid = pc.regardingobjectid
JOIN stage.alternis_portfolio p
ON p.alternis_portfolioid = acc.alternis_portfolioid

WHERE CAST(DATEADD(HOUR,8,pc.createdon) AS DATE) BETWEEN @StartDate AND @EndDate
AND (pc.owneridname NOT IN ('System Admin','Senthan Shanmugaratnam','Joseph Lo','Raymon Osoteo'
,'agents #','agents2 #','agents3 #','SSIS3 PACKAGE','SSIS1 PACKAGE'
,'SSIS2 PACKAGE','ssis1-ph','ssis2-ph','ssis3-ph','Test01 #','Test02 #'
,'Test03 #', 'Naw Seng')
OR pc.owneridname NOT LIKE '%SSIS%'
OR pc.owneridname NOT LIKE '%#%')
AND ISNULL(p.alternis_ispendingdeletionname, '') <> 'Yes'
AND ISNULL(p.alternis_reportingname, p.Alternis_Name) NOT LIKE '%Delet%'
AND ISNULL(p.alternis_istestname, '') <> 'Yes'
AND ISNULL(p.alternis_reportingname, p.Alternis_Name) NOT LIKE '%Dummy%'


/*USE THIS TO FILTER*/

SELECT * FROM #Calls_Made WHERE Business = 'Debt Purchase' AND Called_By_Flag = 'Agent'

ORDER BY Call_Made_Date