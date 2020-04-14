USE BIProd

IF OBJECT_ID ('tempdb..#queries') IS NOT NULL
	DROP TABLE #queries

SELECT execquery.last_execution_time AS RunDate, 'DBName' AS DB, execsql.text AS Script  
INTO #queries  
FROM sys.dm_exec_query_stats AS execquery  
CROSS APPLY sys.dm_exec_sql_text(execquery.sql_handle) AS execsql
WHERE CAST(execquery.last_execution_time AS DATE) = '2018-03-29'

SELECT DB, Script, CONVERT(NVARCHAR, Max(RunDate), 120) RunDate  
FROM #queries  
WHERE DB='DBName'  
GROUP BY DB, Script -- this removes duplicate entries, keeping only the most recent version  
--HAVING MAX(RunDate) > '2015-10-15' -- again, you can filter here like this
ORDER BY RunDate DESC  
FOR XML PATH('Query'), ROOT('Queries'), ELEMENTS  