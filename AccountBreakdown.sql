DECLARE @date DATETIME = GETDATE()
DECLARE @AsOfDate DATE
DECLARE @country NVARCHAR(100)
DECLARE @countryAlpha2 CHAR(2)
DECLARE @datetimezone DATE = DATEADD(HOUR, 8, @date)
-------------------------------------------------------------------------------------------------------------------------------------------
SELECT @AsOfDate = CONVERT(DATE,IIF(DATEPART(WEEKDAY,DATEADD(HOUR,-16,GETDATE())) IN (1),DATEADD(DAY,-2,DATEADD(HOUR,-16,@Date)) 
	,IIF(DATEPART(WEEKDAY,DATEADD(HOUR,-16,@Date)) IN (7),DATEADD(DAY,-1,DATEADD(HOUR,-16,@Date)) ,DATEADD(HOUR,-16,@Date))), 23)

SET @country = 'Thailand'
SET @countryAlpha2 = 'TH'

;WITH CTEAccountCalldate
AS (
		SELECT Last_Call_Made_Date = MAX(pc.createdon),Account_ID = pc.regardingobjectid
		FROM Stage.phonecall pc
			JOIN Stage.Alternis_Account acc
				ON acc.alternis_accountid = pc.regardingobjectid
			JOIN stage.Alternis_Portfolio p
				ON p.alternis_portfolioid = acc.alternis_portfolioid
		WHERE ISNULL(p.alternis_ispendingdeletionname, '')  <> 'Yes' 
			AND ISNULL(p.alternis_reportingname, p.Alternis_Name) NOT LIKE '%Delet%'
			AND ISNULL(p.alternis_istestname, '') <> 'Yes' 
			AND ISNULL(p.alternis_reportingname, p.Alternis_Name) NOT LIKE '%Dummy%'
		GROUP BY pc.regardingobjectid

),
CTEMaxCallperAccount
AS (
	SELECT DISTINCT Account_ID = pc.regardingobjectid
			,Last_Call_Made_Date = ac.Last_Call_Made_Date
			,Last_Call_Outcome = MAX(ISNULL(pc.alternis_calloutcomename,''))
			,Last_Call_Disposition = MAX(ISNULL(pc.alternis_contactdispositionname,''))
			,Last_Called_By = ISNULL(pc.owneridname, '')
			,Call_Type = CAST('' AS NVARCHAR)
	FROM Stage.phonecall pc
		JOIN CTEAccountCalldate ac
			ON pc.regardingobjectid = ac.Account_ID
				AND ac.Last_Call_Made_Date = pc.createdon	
	GROUP BY 
		pc.regardingobjectid
			,ac.Last_Call_Made_Date
			,ISNULL(pc.owneridname, '')
),
CTEMaxPaymentPlanPerAccount
AS (
	SELECT Account_ID = acc.alternis_accountid
			,Last_PP_Date = MAX(pp.createdon)
			,Installment_Amount = SUM(IIF(pp.alternis_numberofinstallments = 1,pp.alternis_amountoninstallments, pp.alternis_installmentamount))
			,Plan_Balance =  SUM(pp.alternis_paymentplanbalance)
			,Commission_Owner =  MAX(alternis_commissionownername)
			,Plan_Status = MAX(pp.statuscodename)
	FROM stage.alternis_paymentplan pp		
		JOIN stage.alternis_account acc
			ON pp.alternis_accountid = acc.alternis_accountid
	GROUP BY acc.alternis_accountid
) 
--------------------------------------------------------------------------------------------------------------------------------------------
SELECT   AsOfDate
		,Account_ID
		,Batch_ID
		,Contact_ID
		,Account_Number
		,Card_Number
		,Customer_Name
		,Seller
		,Business 
		,Base_Portfolio
		,Reporting_Portfolio
		,GCV
		,PV
		,Outstanding_Balance
		,Outstanding_Principal
		,Stage
		,Write_Off_Year
		,Write_Off_Month
		,Load_Date
		,Last_Call_Date
		,Call_Time
		,Days_Last_Called
		,Last_Called_Date_Bucket
		,Last_Called_By = ISNULL(Last_Called_By, '')
		,Last_Call_Outcome = ISNULL(Last_Call_Outcome, '')
		,Last_Call_Disposition = ISNULL(Last_Call_Disposition, '')
		,Call_Type
		,Last_PP_Date
		,Days_Last_PP
		,Last_PP_Date_Bucket
		,Commission_Owner
		,Installment_Amount
		,Plan_Balance
		,Last_Action_Date = CONVERT(DATE,Last_Action_Date,23)
		,Country
		,Country_Alpha2
		,Days_Last_Actioned = CASE 	WHEN Stage IN  ('Pending Close Review','Pending Paid Review','Closed') 
										THEN 0
									WHEN  [Last_Action_Date] IS NULL 
										THEN 999 
									ELSE DATEDIFF(DAY,[Last_Action_Date] ,@datetimezone) 
								END 
		,Last_Action_Date_Bucket = CASE WHEN YEAR([Last_Action_Date]) = 1900 THEN  '08. No Agent Activity' 
									WHEN Stage IN  ('Pending Close Review','Pending Paid Review','Closed') THEN '10. Closed'
									WHEN DATEDIFF(DAY,[Last_Action_Date],@datetimezone) BETWEEN 0 AND 7 THEN '00. Less Than 1 Week'
									WHEN DATEDIFF(DAY,[Last_Action_Date],@datetimezone) BETWEEN 8 AND 14  THEN '01. 1 Week to 2 Weeks'
									WHEN DATEDIFF(DAY,[Last_Action_Date],@datetimezone) BETWEEN 15 AND 21  THEN '02. 2 Weeks to 3 Weeks'
									WHEN DATEDIFF(DAY,[Last_Action_Date],@datetimezone) BETWEEN 22 AND 30  THEN '03. 3 Weeks to 1 Months'
									WHEN DATEDIFF(DAY,[Last_Action_Date],@datetimezone) BETWEEN 31 AND 60  THEN '04. 1 Month to 2 Months'
									WHEN DATEDIFF(DAY,[Last_Action_Date],@datetimezone) BETWEEN 61 AND 90  THEN '05. 2 Months to 3 Months'
									WHEN DATEDIFF(DAY,[Last_Action_Date],@datetimezone) BETWEEN 91 AND 120  THEN '06. 3 Monhts to 4 Months'
									WHEN DATEDIFF(DAY,[Last_Action_Date],@datetimezone)  >= 121 THEN '07. More than 4 Months'								
									ELSE '09. Unknown' END 
		,[3_Days_Not_Called] = IIF([Days_Not_Called] > 3, 'Yes', 'No')
		,[3_Days_Not_Actioned] = IIF(CASE WHEN  [Last_Action_Date] IS NULL 
										THEN 999 
										ELSE DATEDIFF(DAY,[Last_Action_Date] ,@datetimezone) 
									END  > 3, 'Yes', 'No')
		,New_Load_Not_Called = IIF(ISNULL(Load_Date,'1900/01/01') >= (DATEADD(DAY,-2, @datetimezone)) AND [Last_Action_Date] IS NULL, 'Yes', 'No')
		,[30_Days_Not_Actioned] = IIF(CASE WHEN  [Last_Action_Date] IS NULL 
										THEN 999 
										ELSE DATEDIFF(DAY,[Last_Action_Date] ,@datetimezone) 
									END  > 30, 'Yes', 'No')
		,AgencyCountrySpecific
		,Agency
		,Unit
		,Debt_Amount
		,Principal_Value
		,Plan_Status

FROM 
	(
		SELECT  DISTINCT AsOfDate = @AsOfDate 
				,Account_ID = acc.alternis_accountid
				,Batch_ID = acc.alternis_batchid
				,Contact_ID = acc.alternis_contactid
				,Account_Number = acc.alternis_number
				,Card_Number = acc.alternis_invoicenumber
				,Customer_Name = acc.alternis_contactidname
				,Seller = acc.alternis_seller
				,Business = IIF(ISNULL(p.alternis_reportingname, p.Alternis_Name) LIKE '%SVC%' OR p.alternis_isservicingname = 'Yes' , 'Debt Servicing','Debt Purchase')		
				,Base_Portfolio = p.alternis_name
				,Reporting_Portfolio = ISNULL(p.alternis_reportingname, p.Alternis_Name)
				,GCV = acc.alternis_debtamount  
				,PV = acc.alternis_principaldept
				,Outstanding_Balance = acc.alternis_outstandingbalance
				,Outstanding_Principal = acc.alternis_outstandingprincipal
				,Stage = acc.alternis_processstagename
				,Write_Off_Year = YEAR(acc.alternis_writeoff)
				,Write_Off_Month = CONVERT(DATE,DATEADD(month, DATEDIFF(month, 0, acc.alternis_writeoff), 0), 23)
				,Load_Date = CONVERT(DATE,btch.createdon, 23)
				,Last_Call_Date = DATEADD(HOUR,8,Last_Call_Made_Date)
				,Call_Time = CONVERT(TIME,DATEADD(HOUR,8,Last_Call_Made_Date))
				,Days_Last_Called = DATEDIFF(DAY, DATEADD(HOUR,8,Last_Call_Made_Date), @datetimezone )
				,Last_Called_Date_Bucket = CASE WHEN YEAR(DATEADD(HOUR,8,mcacc.Last_Call_Made_Date)) = 1900 THEN  '08. No Agent Activity' 
												WHEN acc.alternis_processstagename IN  ('Pending Close Review','Pending Paid Review','Closed') THEN '10. Closed'
												WHEN DATEDIFF(DAY,DATEADD(HOUR,8,mcacc.Last_Call_Made_Date),@datetimezone) BETWEEN 0 AND 7 THEN '00. Less Than 1 Week'
												WHEN DATEDIFF(DAY,DATEADD(HOUR,8,mcacc.Last_Call_Made_Date),@datetimezone) BETWEEN 8 AND 14  THEN '01. 1 Week to 2 Weeks'
												WHEN DATEDIFF(DAY,DATEADD(HOUR,8,mcacc.Last_Call_Made_Date),@datetimezone) BETWEEN 15 AND 21  THEN '02. 2 Weeks to 3 Weeks'
												WHEN DATEDIFF(DAY,DATEADD(HOUR,8,mcacc.Last_Call_Made_Date),@datetimezone) BETWEEN 22 AND 30  THEN '03. 3 Weeks to 1 Months'
												WHEN DATEDIFF(DAY,DATEADD(HOUR,8,mcacc.Last_Call_Made_Date),@datetimezone) BETWEEN 31 AND 60  THEN '04. 1 Month to 2 Months'
												WHEN DATEDIFF(DAY,DATEADD(HOUR,8,mcacc.Last_Call_Made_Date),@datetimezone) BETWEEN 61 AND 90  THEN '05. 2 Months to 3 Months'
												WHEN DATEDIFF(DAY,DATEADD(HOUR,8,mcacc.Last_Call_Made_Date),@datetimezone) BETWEEN 91 AND 120  THEN '06. 3 Monhts to 4 Months'
												WHEN DATEDIFF(DAY,DATEADD(HOUR,8,mcacc.Last_Call_Made_Date),@datetimezone)  >= 121 THEN '07. More than 4 Months'								
											ELSE '09. Unknown' 
										END 
				,mcacc.Last_Called_By
				,mcacc.Last_Call_Outcome
				,mcacc.Last_Call_Disposition
				,Call_Type

				,Last_PP_Date =  DATEADD(HOUR,8,Last_PP_Date)
				,Days_Last_PP = DATEDIFF(DAY, DATEADD(HOUR,8,Last_PP_Date), @datetimezone )
				,Last_PP_Date_Bucket = CASE WHEN YEAR(DATEADD(HOUR,8,Last_PP_Date)) = 1900 THEN  '08. No Agent Activity' 
												WHEN acc.alternis_processstagename IN  ('Pending Close Review','Pending Paid Review','Closed') THEN '10. Closed'
												WHEN DATEDIFF(DAY,DATEADD(HOUR,8,Last_PP_Date),@datetimezone) BETWEEN 0 AND 7 THEN '00. Less Than 1 Week'
												WHEN DATEDIFF(DAY,DATEADD(HOUR,8,Last_PP_Date),@datetimezone) BETWEEN 8 AND 14  THEN '01. 1 Week to 2 Weeks'
												WHEN DATEDIFF(DAY,DATEADD(HOUR,8,Last_PP_Date),@datetimezone) BETWEEN 15 AND 21  THEN '02. 2 Weeks to 3 Weeks'
												WHEN DATEDIFF(DAY,DATEADD(HOUR,8,Last_PP_Date),@datetimezone) BETWEEN 22 AND 30  THEN '03. 3 Weeks to 1 Months'
												WHEN DATEDIFF(DAY,DATEADD(HOUR,8,Last_PP_Date),@datetimezone) BETWEEN 31 AND 60  THEN '04. 1 Month to 2 Months'
												WHEN DATEDIFF(DAY,DATEADD(HOUR,8,Last_PP_Date),@datetimezone) BETWEEN 61 AND 90  THEN '05. 2 Months to 3 Months'
												WHEN DATEDIFF(DAY,DATEADD(HOUR,8,Last_PP_Date),@datetimezone) BETWEEN 91 AND 120  THEN '06. 3 Monhts to 4 Months'
												WHEN DATEDIFF(DAY,DATEADD(HOUR,8,Last_PP_Date),@datetimezone)  >= 121 THEN '07. More than 4 Months'								
											ELSE '09. Unknown' 
										END 
				,Commission_Owner

				,mppacc.Installment_Amount
				,mppacc.Plan_Balance

				,[Last_Action_Date] = CASE WHEN ISNULL(CONVERT(DATE,DATEADD(HOUR, 8, (mcacc.Last_Call_Made_Date)),23), '1900-01-01') >= ISNULL(CONVERT(DATE,DATEADD(HOUR, 8, (mppacc.Last_PP_Date)),23), '1900-01-01') 
												THEN DATEADD(HOUR, 8, (mcacc.Last_Call_Made_Date))
												ELSE DATEADD(HOUR, 8, (mppacc.Last_PP_Date))
											END 
											
				,[Days_Not_Called] = CASE WHEN  CONVERT(DATE,DATEADD(HOUR, 8, mcacc.Last_Call_Made_Date),23) IS NULL 
											THEN 999 
											ELSE DATEDIFF(DAY, CONVERT(DATE,DATEADD(HOUR, 8, mcacc.Last_Call_Made_Date),23),@datetimezone) 
									END

				,Country = @country
				,Country_Alpha2 = @countryAlpha2
				,AgencyCountrySpecific = CASE WHEN (eca.alternis_ecaidname IS NOT NULL AND eca.alternis_startdate IS NOT NULL)
												THEN @countryAlpha2 +' - '+ eca.alternis_ecaidname
											WHEN (eca.alternis_ecaidname IS NULL OR eca.alternis_startdate IS NULL) AND acc.alternis_processstagename <> 'Outsourcing'
												THEN @countryAlpha2 +' - '+ 'COLLECTIUS CMS'
											WHEN (eca.alternis_ecaidname IS NULL OR eca.alternis_startdate IS NULL) AND acc.alternis_processstagename= 'Outsourcing'
												THEN @countryAlpha2 +' - '+ 'RESTING'
											WHEN acc.alternis_processstagename IN ('Pending Close Review','Closed','Pending Paid Review')
												THEN @countryAlpha2 +' - '+ 'INACTIVE'
											ELSE @countryAlpha2 +' - '+ 'COLLECTIUS CMS'
											END 
				,Agency = CASE WHEN (eca.alternis_ecaidname IS NOT NULL AND eca.alternis_startdate IS NOT NULL)
								THEN eca.alternis_ecaidname
							WHEN (eca.alternis_ecaidname IS NULL OR eca.alternis_startdate IS NULL) AND acc.alternis_processstagename <> 'Outsourcing'
								THEN 'COLLECTIUS CMS'
							WHEN (eca.alternis_ecaidname IS NULL OR eca.alternis_startdate IS NULL) AND acc.alternis_processstagename= 'Outsourcing'
								THEN 'RESTING'
							WHEN acc.alternis_processstagename IN ('Pending Close Review','Closed','Pending Paid Review')
								THEN 'INACTIVE'
							ELSE 'COLLECTIUS CMS'
							END 

				,Unit = CASE WHEN  alternis_numbers_outsourcing = 1
								THEN 'Outsource'
								ELSE 'In House'
							END
				,Debt_Amount = acc.alternis_debtamount
				,Principal_Value = acc.alternis_principaldept
				,Plan_Status

		FROM stage.alternis_Account acc
			JOIN [stage].[alternis_batch] btch
				ON btch.alternis_batchid= acc.alternis_batchid
			JOIN stage.alternis_portfolio p
				ON p.alternis_portfolioid = acc.alternis_portfolioid
			LEFT JOIN CTEMaxCallperAccount mcacc
				ON mcacc.Account_ID = acc.alternis_accountid
			LEFT JOIN CTEMaxPaymentPlanPerAccount mppacc
				ON mppacc.Account_ID = acc.alternis_accountid
			LEFT JOIN [stage].[alternis_ecaoutsorcing] eca
				ON eca.statuscodename = 'In Progress'
					AND eca.alternis_accountid = acc.alternis_accountid
					AND eca.alternis_enddate IS NULL
					AND eca.alternis_startdate =  (SELECT MAX(eca1.alternis_startdate) FROM [stage].[alternis_ecaoutsorcing] eca1 WHERE eca1.alternis_accountid = eca.alternis_accountid)
	
		WHERE ISNULL(p.alternis_ispendingdeletionname, '')  <> 'Yes' 
			AND ISNULL(p.alternis_reportingname, p.Alternis_Name) NOT LIKE '%Delet%'
			AND ISNULL(p.alternis_istestname, '') <> 'Yes' 
			AND ISNULL(p.alternis_reportingname, p.Alternis_Name) NOT LIKE '%Dummy%'
			--AND acc.alternis_processstagename NOT IN ('Outsourcing','Pending Close Review','Pending Paid Review','Closed')
		) Final