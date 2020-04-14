--This Query will Create list of views that can be used to query the EINSTEIN DB2 Database.
------------------------------------------------------------------------------------------
--Author: Tolu Adepoju
--Created on: Dec 30, 2016
------------------------------------------------------------------------------------------
USE CHILDS;
GO
IF EXISTS(SELECT * FROM #ChildsSchema)
BEGIN
DROP TABLE ..#ChildsSchema;
END
GO
DECLARE @TableSchema VARCHAR(300) = 'CHILDS'; --Name of Schema that holds the table.
DECLARE @CurrentTable VARCHAR(300) = '';
DECLARE @SQLCreateView NVARCHAR(MAX) = '';
DECLARE @ViewSchema VARCHAR(300) = 'dbo'; --Schema that will hold the view
DECLARE @DropViewIfExists NVARCHAR(MAX) = '';

--Dump Data from CHILDS Schema into a TEMP Table
SELECT *
INTO #ChildsSchema
FROM EINSTNDB.EINSTNDB.SYSCAT.COLUMNS
WHERE TABSCHEMA = @TableSchema
ORDER BY TabName, ColNo;

--Declare Cursor:
DECLARE C CURSOR FOR
SELECT DISTINCT TABNAME
FROM #ChildsSchema
ORDER BY TabName
OPEN C
FETCH NEXT FROM C
INTO @CurrentTable
WHILE @@FETCH_STATUS = 0
BEGIN
--Check if view exists
SELECT @DropViewIfExists += 'IF OBJECT_ID(' + '''' + @ViewSchema +'.'+@CurrentTable + '''' + ') IS NOT NULL BEGIN 
							 PRINT (' + '''' + 'View was found and was dropped' +  '''' +');' + ' DROP VIEW '
						+ @ViewSchema +'.'+@CurrentTable+ ' ; END ' + CHAR(13)
--Current Table
SELECT @SQLCreateView += ';CREATE VIEW ' + '[' + @ViewSchema + ']' + '.' + '[' + @CurrentTable + ']'
+' AS' +' ('
+' SELECT ';

--All but Last Column
SELECT @SQLCreateView += '[' + COLNAME + ']' + ','
FROM #ChildsSchema
WHERE TABNAME = @CurrentTable
AND ColNo <> (
SELECT MAX(ColNo) 
FROM #ChildsSchema 
WHERE TabName = @CurrentTable
)
ORDER BY ColNo;

--Last Column
SELECT @SQLCreateView += '[' + COLNAME + ']' + ' FROM EINSTNDB.EINSTNDB.'+@TableSchema+'.'+@CurrentTable + ' )'
FROM #ChildsSchema
WHERE TABNAME = @CurrentTable
AND ColNo = (SELECT MAX(ColNo) FROM #ChildsSchema WHERE TabName = @CurrentTable);
PRINT CONCAT('------------------------------------',@CurrentTable,'------------------------------------',CHAR(13))
--PRINT @DropViewIfExists;
EXECUTE SP_ExecuteSQL @DropViewIfExists;
--PRINT @SQLCreateView;
BEGIN TRY
EXECUTE SP_ExecuteSQL @SQLCreateView;
PRINT 'View was created successfully'
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

