DECLARE @StartDate AS VARCHAR(50) = '2022-04-01';
DECLARE @EndDate AS VARCHAR(50) = '2022-04-30 23:59:59';

DECLARE @date DATETIME = '2022-04-01' --IGNORE
DECLARE @AsOfDate DATE
DECLARE @country NVARCHAR(100) = 'Indonesia'
DECLARE @countryAlpha2 CHAR(2) = 'ID'
-------------------------------------------------------------------------------------------------------------------------------------------
SELECT @AsOfDate = DATEADD(DAY, 1, @date)

SELECT DISTINCT
	[Posting_Date] = CONVERT(DATE, DATEADD(HOUR, 8, TR.alternis_transactiondate), 23)
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
	,[Bank_Account_Name] = RB.alternis_bankaccountname
	,[Bank_Account_Number] = RB.alternis_name
	,[Remarks] = TR.alternis_remarks
	,[Unit] = CASE WHEN  alternis_numbers_outsourcing = 1
								THEN 'Outsource'
								ELSE 'In House'
							END
	,[Agency] = CASE WHEN (eca.alternis_ecaidname IS NOT NULL AND eca.alternis_startdate IS NOT NULL)
												THEN @countryAlpha2 +' - '+ eca.alternis_ecaidname
											WHEN (eca.alternis_ecaidname IS NULL OR eca.alternis_startdate IS NULL) AND ac.alternis_processstagename <> 'Outsourcing'
												THEN @countryAlpha2 +' - '+ 'COLLECTIUS CMS'
											WHEN (eca.alternis_ecaidname IS NULL OR eca.alternis_startdate IS NULL) AND ac.alternis_processstagename= 'Outsourcing'
												THEN @countryAlpha2 +' - '+ 'RESTING'
											WHEN ac.alternis_processstagename IN ('Pending Close Review','Closed','Pending Paid Review')
												THEN @countryAlpha2 +' - '+ 'INACTIVE'
											ELSE @countryAlpha2 +' - '+ 'COLLECTIUS CMS'
											END 
	--,[Mediator] = alternis_commissionownername
	,[Owner] = CASE WHEN pp.alternis_paymentplanid IS NOT NULL	
						THEN CASE WHEN alternis_commissionownername LIKE '%#%' OR alternis_commissionownername IS NULL OR alternis_commissionownername LIKE '%Tom F%'	
									THEN @countryAlpha2 +' - '+ 'COLLECTIUS CMS'
								  ELSE alternis_commissionownername
							END
						ELSE CASE WHEN (eca.alternis_ecaidname IS NOT NULL AND eca.alternis_startdate IS NOT NULL)
										THEN @countryAlpha2 +' - '+ eca.alternis_ecaidname
									WHEN (eca.alternis_ecaidname IS NULL OR eca.alternis_startdate IS NULL) AND ac.alternis_processstagename <> 'Outsourcing'
										THEN @countryAlpha2 +' - '+ 'COLLECTIUS CMS'
									WHEN (eca.alternis_ecaidname IS NULL OR eca.alternis_startdate IS NULL) AND ac.alternis_processstagename= 'Outsourcing'
										THEN @countryAlpha2 +' - '+ 'RESTING'
									WHEN ac.alternis_processstagename IN ('Pending Close Review','Closed','Pending Paid Review')
										THEN @countryAlpha2 +' - '+ 'INACTIVE'
									ELSE @countryAlpha2 +' - '+ 'COLLECTIUS CMS'
								END 
						END 

	,[PP_Channel] = CASE WHEN alternis_isfromportal = 1 
							THEN 'Payment Portal'
						WHEN alternis_is_payment_gateway = 1 
							THEN 'Payment Gateway'
						ELSE ' Tele Calling'
					END	
	,[Installment_Amount] = IIF(pp.alternis_numberofinstallments = 1,pp.alternis_amountoninstallments, pp.alternis_installmentamount)
	,[Plan_Balance] =  pp.alternis_paymentplanbalance	
	,[Payment_Type] = CASE WHEN pp.alternis_paymentplanid is NOT NULL	
						THEN CASE WHEN pp.alternis_numberofinstallments  > 1	
									THEN 'Installments'
								WHEN pp.alternis_numberofinstallments  = 1 AND  pp.alternis_ispartialpaymentname = 'No'
									THEN 'Full Settlement'
								WHEN pp.alternis_numberofinstallments  = 1 AND (pp.alternis_ispartialpaymentname = 'Yes' OR pp.alternis_ispartialpaymentname IS NULL)	
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

FROM [stage].[alternis_transaction] TR 
	LEFT JOIN [stage].[alternis_paymentallocation] PA
		ON TR.alternis_transactionid = PA.alternis_transactionid
			AND PA.CreatedOn =  (SELECT MIN(pa1.CreatedOn) FROM [stage].[alternis_paymentallocation] pa1 WHERE pa1.alternis_transactionid = PA.alternis_transactionid)
	LEFT JOIN [stage].[alternis_account] AC
		ON PA.alternis_accountid = AC.alternis_accountid
	LEFT JOIN [stage].[alternis_receiverbankaccount] RB
		ON PA.alternis_receiverbankaccountid = RB.alternis_receiverbankaccountid
	LEFT JOIN stage.alternis_portfolio PO
		ON AC.alternis_portfolioid = PO.alternis_portfolioid
	LEFT JOIN [stage].[alternis_ecaoutsorcing] ECA
		ON eca.statuscodename = 'In Progress'
			AND eca.alternis_accountid = ac.alternis_accountid
			AND eca.alternis_enddate IS NULL
			AND eca.alternis_startdate =  (SELECT MAX(eca1.alternis_startdate) FROM [stage].[alternis_ecaoutsorcing] eca1 WHERE eca1.alternis_accountid = eca.alternis_accountid)
	LEFT JOIN stage.alternis_paymentplan pp
		ON pp.alternis_paymentplanid = pa.alternis_paymentplanid

WHERE CAST(DATEADD(HOUR, 8, TR.alternis_transactiondate) AS DATE) BETWEEN @StartDate AND @EndDate
	AND TR.alternis_transactiontypename IN ('Payment')
	AND  (PO.alternis_ispendingdeletionname <> 'Yes' OR  PO.alternis_istestname <> 'Yes' 
			OR PO.alternis_ispendingdeletionname IS NULL OR PO.alternis_istestname IS NULL)
	AND PO.alternis_name NOT LIKE '%Delet%'
	AND PO.alternis_name NOT LIKE '%Dummy%'

ORDER BY
	CASE WHEN PO.alternis_reportingname LIKE '%SVC%' THEN 'Debt Servicing'
		  WHEN PO.alternis_isservicingname = 'Yes' THEN 'Debt Servicing'
		  ELSE 'Debt Purchase' END
	,AC.alternis_portfolioidname
	,[Posting_Date]
