-------------------------------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID(N'tempdb..#Collections') IS NOT NULL DROP TABLE #Collections
IF OBJECT_ID(N'tempdb..#Collections_Summary') IS NOT NULL DROP TABLE #Collections_Summary
IF OBJECT_ID(N'tempdb..#Account_Breakdown') IS NOT NULL DROP TABLE #Account_Breakdown
IF OBJECT_ID(N'tempdb..#Agency_Perf') IS NOT NULL DROP TABLE #Agency_Perf


-------------------------------------------------------------------------------------------------------------------------------------------

DECLARE @StartDate AS VARCHAR(50) = '2022-03-01';
DECLARE @EndDate AS VARCHAR(50) = '2022-03-31 23:59:59';
DECLARE @AsOfDate AS VARCHAR(50) = @EndDate;


DECLARE @date DATETIME = GETDATE()

DECLARE @country NVARCHAR(100) = 'Malaysia'
DECLARE @countryAlpha2 CHAR(2) = 'MY'
-------------------------------------------------------------------------------------------------------------------------------------------


/*COLLECTIONS*/

SELECT DISTINCT
	[Reporting_Month] = @StartDate
	,[Posting_Date] = CONVERT(DATE, DATEADD(HOUR, 8, TR.alternis_transactiondate), 23)
	,[Posting_Month] = CONVERT(DATE, DATEADD(MONTH,DATEDIFF(MONTH,0,DATEADD(HOUR, 8, TR.alternis_transactiondate)),0), 23) 
	,[Payment_Date] = CONVERT(DATE, DATEADD(HOUR, 8, TR.alternis_effectivetransactiondate), 23)
	,[Payment_Month] = CONVERT(DATE, DATEADD(MONTH,DATEDIFF(MONTH,0,DATEADD(HOUR, 8, TR.alternis_effectivetransactiondate)),0), 23) 
	,[Created_Date] = CONVERT(DATE, DATEADD(HOUR, 8, TR.CreatedOn) , 23)	
	,[Created_Month] = CONVERT(DATE,DATEADD(month, DATEDIFF(month, 0, TR.CreatedOn), 0), 23)
	,[Day] = DATEPART(DAY, DATEADD(HOUR, 8, TR.alternis_transactiondate))
	,[Week No.] = CASE WHEN DATEPART(DAY, DATEADD(HOUR, 8, TR.alternis_transactiondate)) < 8
			THEN 'Week 1'
		WHEN DATEPART(DAY, DATEADD(HOUR, 8, TR.alternis_transactiondate)) < 15
			THEN 'Week 2'
		WHEN DATEPART(DAY, DATEADD(HOUR, 8, TR.alternis_transactiondate)) < 22
			THEN 'Week 3'
		ELSE 'Week 4'
	   END 
	
	,[Account_ID] = AC.alternis_accountid
	,[Account_Number] = AC.alternis_number
	,[Card_Number] = AC.alternis_invoicenumber
	,[Base_Portfolio] = AC.alternis_portfolioidname
	,[Reporting_Portfolio] = PO.alternis_reportingname
	,[Stage] = AC.alternis_processstagename
	
	,[Business] = CASE WHEN PO.alternis_reportingname LIKE '%SVC%' THEN 'Debt Servicing'
			WHEN PO.alternis_isservicingname = 'Yes' THEN 'Debt Servicing'
			ELSE 'Debt Purchase' END 
	,[Tran_ID] = TR.alternis_transactionid
	,[PP_ID] = pp.alternis_paymentplanid
	,[GCV] = AC.alternis_debtamount
	,[Outstanding_Balance] = AC.alternis_outstandingamount
	,[Payment_Amount_LCY] = TR.alternis_amountinlocalcurrency
	,[Payment_Channel] = CASE WHEN TR.alternis_paymentchannelidname IS NULL THEN TR.alternis_paymenttypename
			ELSE TR.alternis_paymentchannelidname END
	,[Tran_Type] = TR.alternis_transactiontypename
	,[Unit] = CASE WHEN  AC.alternis_numbers_outsourcing = 1
								THEN 'Outsource'
								ELSE 'In House'
							END
	,[PP_Channel] = CASE WHEN alternis_isfromportal = 1 
							THEN 'Payment Portal'
						WHEN alternis_is_payment_gateway = 1 
							THEN 'Payment Gateway'
						ELSE ' Tele Calling'
					END	
	,[Installment_Amount] = IIF(pp.alternis_numberofinstallments = 1,pp.alternis_amountoninstallments, pp.alternis_installmentamount)
	,[Plan_Balance] =  PP.alternis_paymentplanbalance	
	,[Payment_Type] = CASE WHEN PP.alternis_paymentplanid is NOT NULL	
						THEN CASE WHEN PP.alternis_numberofinstallments  > 1	
									THEN 'Installments'
								WHEN PP.alternis_numberofinstallments  = 1 AND  PP.alternis_ispartialpaymentname = 'No'
									THEN 'Full Settlement'
								WHEN PP.alternis_numberofinstallments  = 1 AND (PP.alternis_ispartialpaymentname = 'Yes' OR PP.alternis_ispartialpaymentname IS NULL)	
									THEN 'One Off Payment'
								END 
						ELSE CASE WHEN IIF(TR.alternis_amountinlocalcurrency <=0, 0, AC.alternis_debtamount / TR.alternis_amountinlocalcurrency) < 1.5	
								THEN 'Full Settlement'
								ELSE 'Installments'
							END 
						END
	,[Settled_This_Month] = CASE WHEN ( AC.alternis_outstandingbalance <= 0 OR IIF(TR.alternis_amountinlocalcurrency <= 0, 0, AC.alternis_outstandingbalance/TR.alternis_amountinlocalcurrency) < 1.5 ) 
									THEN 'Yes'
									ELSE 'No'
							END
	,[Country] = @country
	,[Country_Code] = @countryAlpha2

INTO #Collections

FROM [stage].[alternis_transaction] TR 
	LEFT JOIN [stage].[alternis_paymentallocation] PA
		ON TR.alternis_transactionid = PA.alternis_transactionid
			AND PA.CreatedOn =  (SELECT MIN(pa1.CreatedOn) FROM [stage].[alternis_paymentallocation] pa1 WHERE pa1.alternis_transactionid = PA.alternis_transactionid)
	LEFT JOIN [stage].[alternis_account] FOR SYSTEM_TIME AS OF @AsOfDate AC
		ON PA.alternis_accountid = AC.alternis_accountid
	LEFT JOIN stage.alternis_portfolio PO
		ON AC.alternis_portfolioid = PO.alternis_portfolioid
	LEFT JOIN stage.alternis_paymentplan pp
		ON pp.alternis_paymentplanid = pa.alternis_paymentplanid

WHERE CAST(DATEADD(HOUR, 8, TR.alternis_transactiondate) AS DATE) BETWEEN @StartDate AND @EndDate
--WHERE TR.alternis_transactionid IN ()
	AND TR.alternis_transactiontypename IN ('Payment')
	AND  (PO.alternis_ispendingdeletionname <> 'Yes' OR  PO.alternis_istestname <> 'Yes' 
			OR PO.alternis_ispendingdeletionname IS NULL OR PO.alternis_istestname IS NULL)
	AND PO.alternis_name NOT LIKE '%Delet%'
	AND PO.alternis_name NOT LIKE '%Dummy%'
	AND PO.alternis_isservicingname = 'No'

ORDER BY
	CASE WHEN PO.alternis_reportingname LIKE '%SVC%' THEN 'Debt Servicing'
		  WHEN PO.alternis_isservicingname = 'Yes' THEN 'Debt Servicing'
		  ELSE 'Debt Purchase' END
	,AC.alternis_portfolioidname
	,[Posting_Date]


SELECT
Account_ID
,SUM(Payment_Amount_LCY) AS [Total_Payments]

INTO #Collections_Summary

FROM #Collections

GROUP BY
Account_ID

/*ACCOUNT BREAKDOWN*/

SELECT
[Dynamics_ID] = AC.alternis_accountid 
,[Reporting_Month] = @StartDate
,[Account_Number] = AC.alternis_number
,[Card_Number] = AC.alternis_invoicenumber
,[Country] = @country 
,[Reporting_Portfolio] = PO.alternis_reportingname
,[Business] = CASE WHEN PO.alternis_reportingname LIKE '%SVC%' THEN 'Debt Servicing'
			WHEN PO.alternis_isservicingname = 'Yes' THEN 'Debt Servicing'
			ELSE 'Debt Purchase' END 

,[Agency] = CASE WHEN (eca.alternis_ecaidname IS NOT NULL AND eca.alternis_startdate IS NOT NULL)
												THEN eca.alternis_ecaidname
											WHEN (eca.alternis_ecaidname IS NULL OR eca.alternis_startdate IS NULL) AND ac.alternis_processstagename <> 'Outsourcing'
												THEN 'COLLECTIUS CMS'
											WHEN (eca.alternis_ecaidname IS NULL OR eca.alternis_startdate IS NULL) AND ac.alternis_processstagename= 'Outsourcing'
												THEN 'RESTING'
											WHEN ac.alternis_processstagename IN ('Pending Close Review','Closed','Pending Paid Review')
												THEN 'INACTIVE'
											ELSE 'COLLECTIUS CMS'
											END 
,[Stage] = AC.alternis_processstagename
,[Unit] = CASE WHEN  alternis_numbers_outsourcing = 1
								THEN 'Outsource'
								ELSE 'In House'
							END
,[Outstanding_Balance] = AC.alternis_outstandingbalance
,[Total_Payments] = IIF(COL.Account_ID IS NULL, 0, COL.[Total_Payments])

INTO #Account_Breakdown

FROM
[stage].[alternis_account] FOR SYSTEM_TIME AS OF @AsOfDate AC
LEFT JOIN stage.alternis_portfolio PO
		ON AC.alternis_portfolioid = PO.alternis_portfolioid
LEFT JOIN [stage].[alternis_ecaoutsorcing] FOR SYSTEM_TIME AS OF @AsOfDate ECA
		ON eca.statuscodename = 'In Progress'
			AND eca.alternis_accountid = ac.alternis_accountid
			AND eca.alternis_enddate IS NULL
			AND eca.alternis_startdate =  (SELECT MAX(eca1.alternis_startdate) FROM [stage].[alternis_ecaoutsorcing] FOR SYSTEM_TIME AS OF @AsOfDate eca1 WHERE eca1.alternis_accountid = eca.alternis_accountid)

LEFT JOIN #Collections_Summary COL
	ON  AC.alternis_accountid = COL.Account_ID


WHERE PO.alternis_reportingname NOT LIKE '%SVC%'
		AND PO.alternis_isservicingname = 'No'



/*-----------------------------------------------GENERATE REPORTS----------------------------------------------*/
/*ACCOUNT BREAKDOWN*/

SELECT * FROM #Account_Breakdown

--WHERE [Agency] = 'RESTING'



/*MONTHLY PERFORMANCE*/

SELECT
[Reporting_Month]
,[Country]
,[Portfolio] = [Reporting_Portfolio]
,[Business]
,[Agencies] = SUM(IIF([Unit] = 'OUTSOURCE', [Payment_Amount_LCY], 0))
,[In-House] = SUM(IIF([Unit] = 'IN HOUSE', [Payment_Amount_LCY], 0))


FROM #Collections

GROUP BY
[Reporting_Month]
,[Country]
,[Reporting_Portfolio]
,[Business]

ORDER BY
[Reporting_Month]
,[Country]
,[Reporting_Portfolio]
,[Business]



/*AGENCY PERFORMANCE*/

SELECT
[Reporting_Month]
,[Country]
,[Reporting_Portfolio]
,[Business]
,[Agency] = CASE WHEN [Total_Payments] = 0 AND [Stage] IN ('Closed','Pending Close Review','Pending Paid Review') THEN 'INACTIVE'
				 WHEN [Total_Payments] <> 0 AND [Stage] IN ('Closed','Pending Close Review','Pending Paid Review') AND [Unit] = 'In House'  THEN 'SETTLED IN HOUSE'
				 WHEN [Total_Payments] <> 0 AND [Stage] IN ('Closed','Pending Close Review','Pending Paid Review') AND [Unit] = 'Outsource'  THEN 'SETTLED OUTSOURCE'
				 WHEN [Unit] = 'In House' THEN 'COLLECTIUS CMS'
				 WHEN [Unit] = 'Outsource' AND [Agency] = 'COLLECTIUS CMS' THEN 'RESTING'
				 ELSE [Agency] END
,[Unit]
,COUNT([Dynamics_ID]) AS [Number_of_Accounts]
,SUM([Outstanding_Balance]) AS [Outstanding_Balance]
,SUM([Total_Payments]) AS [Total_Payments]


INTO #Agency_Perf
FROM #Account_Breakdown

GROUP BY
[Reporting_Month]
,[Country]
,[Reporting_Portfolio]
,[Business]
,CASE WHEN [Total_Payments] = 0 AND [Stage] IN ('Closed','Pending Close Review','Pending Paid Review') THEN 'INACTIVE'
				 WHEN [Total_Payments] <> 0 AND [Stage] IN ('Closed','Pending Close Review','Pending Paid Review') AND [Unit] = 'In House'  THEN 'SETTLED IN HOUSE'
				 WHEN [Total_Payments] <> 0 AND [Stage] IN ('Closed','Pending Close Review','Pending Paid Review') AND [Unit] = 'Outsource'  THEN 'SETTLED OUTSOURCE'
				 WHEN [Unit] = 'In House' THEN 'COLLECTIUS CMS'
				 WHEN [Unit] = 'Outsource' AND [Agency] = 'COLLECTIUS CMS' THEN 'RESTING'
				 ELSE [Agency] END
,[Unit]

ORDER BY
[Reporting_Portfolio]
,[Unit]
,CASE WHEN [Total_Payments] = 0 AND [Stage] IN ('Closed','Pending Close Review','Pending Paid Review') THEN 'INACTIVE'
				 WHEN [Total_Payments] <> 0 AND [Stage] IN ('Closed','Pending Close Review','Pending Paid Review') AND [Unit] = 'In House'  THEN 'SETTLED IN HOUSE'
				 WHEN [Total_Payments] <> 0 AND [Stage] IN ('Closed','Pending Close Review','Pending Paid Review') AND [Unit] = 'Outsource'  THEN 'SETTLED OUTSOURCE'
				 WHEN [Unit] = 'In House' THEN 'COLLECTIUS CMS'
				 WHEN [Unit] = 'Outsource' AND [Agency] = 'COLLECTIUS CMS' THEN 'RESTING'
				 ELSE [Agency] END

SELECT * FROM #Agency_Perf WHERE [Agency] <> 'INACTIVE'




/*PAYMENT BREAKDOWN*/

SELECT DISTINCT
[Reporting_Month]
,[Country]
,[Portfolio] = [Reporting_Portfolio]
,[Payment_Type]
,[Unit]
,[Accounts] = COUNT([Tran_ID])
,[Collections] = SUM([Payment_Amount_LCY])


FROM #Collections

GROUP BY
[Reporting_Month]
,[Country]
,[Reporting_Portfolio]
,[Unit]
,[Payment_Type]


ORDER BY
[Reporting_Month]
,[Country]
,[Reporting_Portfolio]
,[Unit]
,[Payment_Type]


/*STATUS*/


SELECT
[Reporting_Month]
,[Country]
,[Portfolio] = [Reporting_Portfolio]
,[Business]
,[Status] = [Stage]
,[Accounts] = COUNT([Dynamics_ID])

FROM #Account_Breakdown

WHERE [Stage] NOT IN ('Outsourcing','Closed','Pending Close Review','Pending Paid Review')

GROUP BY
[Reporting_Month]
,[Country]
,[Reporting_Portfolio]
,[Business]
,[Stage]

ORDER BY
[Reporting_Month]
,[Country]
,[Reporting_Portfolio]
,[Business]
,[Stage]