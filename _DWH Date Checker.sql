SELECT DISTINCT MAX(EffectiveStartDts) AS [Account] FROM [stage].[alternis_account]

SELECT DISTINCT MAX(EffectiveStartDts) AS [Contact]  FROM [stage].[contact] 

SELECT DISTINCT MAX(EffectiveStartDts) AS [Phone] FROM [stage].[alternis_phone]

SELECT DISTINCT MAX(EffectiveStartDts) AS [EMail] FROM [stage].[alternis_email]

SELECT DISTINCT MAX(EffectiveStartDts) AS [PhoneCall] FROM [stage].[phonecall]

SELECT DISTINCT MAX(EffectiveStartDts) AS [Task] FROM [stage].[task]

SELECT DISTINCT MAX(EffectiveStartDts) AS [Pament Allocation] FROM [stage].[alternis_paymentallocation]

SELECT DISTINCT MAX(EffectiveStartDts) AS [Payment Plan] FROM [stage].[alternis_paymentplan]

SELECT DISTINCT MAX(EffectiveStartDts) AS [Transaction] FROM [stage].[alternis_transaction]