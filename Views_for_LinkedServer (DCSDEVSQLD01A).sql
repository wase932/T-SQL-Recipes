--Create list of views that can be used to query the DCSDEVSQLD01A.REPORTING Database.
------------------------------------------------------------------------------------------
--Author: Tolu Adepoju
--Created on: Feb 15, 2017
------------------------------------------------------------------------------------------
USE CHILDS;
GO
IF EXISTS(SELECT * FROM #Schema)
BEGIN
DROP TABLE ..#Schema;
END
GO
DECLARE @TableSchema VARCHAR(300) = 'dbo'; --Name of Schema that holds the table.
DECLARE @CurrentTable VARCHAR(300) = '';
DECLARE @SQLCreateView NVARCHAR(MAX) = '';
DECLARE @ViewSchema VARCHAR(300) = 'dbo'; --Schema that will hold the view
DECLARE @DropViewIfExists NVARCHAR(MAX) = '';

--Dump Data from CHILDS Schema into a TEMP Table
SELECT *
INTO #Schema
FROM DCSDEVSQLD01A.REPORTING.INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = @TableSchema
ORDER BY Table_Name, Ordinal_Position;

--Declare Cursor:
DECLARE C CURSOR FOR
SELECT DISTINCT TABLE_NAME
FROM #Schema
ORDER BY Table_Name
OPEN C
FETCH NEXT FROM C
INTO @CurrentTable
WHILE @@FETCH_STATUS = 0
BEGIN
--Check if view exists
SELECT @DropViewIfExists += 'IF OBJECT_ID(' + '''' + @ViewSchema +'.'+'[' + @CurrentTable + ']' + '''' + ') IS NOT NULL BEGIN 
							 PRINT (' + '''' + 'View was found and was dropped' +  '''' +');' + ' DROP VIEW '
						+ @ViewSchema +'.'+@CurrentTable+ ' ; END ' + CHAR(13)
--Current Table
SELECT @SQLCreateView += ';CREATE VIEW ' + '[' + @ViewSchema + ']' + '.' + '[' + @CurrentTable + ']'
+' AS' +' ('
+' SELECT ';

--All but Last Column
SELECT @SQLCreateView += '[' + COLUMN_NAME + ']' + ','
FROM #Schema
WHERE TABLE_NAME = @CurrentTable
AND Ordinal_Position <> (
SELECT MAX(Ordinal_Position) 
FROM #Schema
WHERE Table_Name = @CurrentTable
)
ORDER BY Ordinal_Position;

--Last Column
SELECT @SQLCreateView += '[' + COLUMN_NAME + ']' + ' FROM DCSDEVSQLD01A.REPORTING.'+@TableSchema+'.'+ '[' +@CurrentTable + ']'+ ' )'
FROM #Schema
WHERE Table_Name = @CurrentTable
AND Ordinal_Position = (SELECT MAX(Ordinal_Position) FROM #Schema WHERE Table_Name = @CurrentTable);
PRINT CONCAT('------------------------------------',@CurrentTable,'------------------------------------',CHAR(13))
--PRINT @DropViewIfExists;
EXECUTE SP_ExecuteSQL @DropViewIfExists;
--PRINT @SQLCreateView;
BEGIN TRY
EXECUTE SP_ExecuteSQL @SQLCreateView;
PRINT 'View created successfully'
END TRY
BEGIN CATCH
PRINT 'Failed to Create View'
END CATCH;
SET @DropViewIfExists = '';
SET @SQLCreateView = '';
FETCH NEXT FROM C INTO @CurrentTable

END
CLOSE C
DEALLOCATE C

GO

