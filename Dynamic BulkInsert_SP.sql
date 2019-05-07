/*****************************************************************************************************************************/
--This SP was created primarily to load CSV files to SQL Server tables. However, it can be used for the following DML/DDL functions:
--1.) Dropping and restoring constraints
--2.) Deleting data from all tables.
--I recommend going through the code to understand how it works before executing (mail toluwase@adepoju.info for questions). Be sure to also note the post-execution messages.

/*
A little note on how it works:
1.)Based on the target table, it creates a staging table with the suffix 'staging' (eg. if targte table is Addressbook, in schema Sales, the staging table created will be : Sales.StagingAddressBook
2.)The staging table is modified to NVACHAR(MAX) on all columns to mitigate inserting failure.
3.)The data is read from the target file into the staging table. If it fails, an error file will be created in the read directory.
4.)Constraints are dropped and stored in a table called dbo.ConstraintsSaved
5.)The data is moved to the target table from the staging table
6.)Constraints are restored from dbo.ConstraintsSaved
 Of course, the steps described above will be skipped, and additional processes executed based on user input.
 For instance setting parameter @DeleteDateFromTables to 1, will delete data from all tables in the database provided constraints do not exist.If constraints are stored in table dbo.ConstraintsSaved, it will be outputed in the messages window and user must execute manually to restore constraints.
*/
IF OBJECT_ID('dbo.USP_Bulk_Insert') IS NOT NULL
DROP PROCEDURE dbo.USP_Bulk_Insert;
GO
CREATE PROCEDURE dbo.USP_Bulk_Insert (
									  @Directory NVARCHAR(MAX), --The directory of the source CSV file (eg.Z:\My Computer\Source Directory 
									  @File NVARCHAR(500), --The Name of the source file without the extenstion (e.g. SourceFile)
									  @Schema NVARCHAR(100) = 'dbo', --The Target Schema. Default is dbo
									  @Table NVARCHAR(500), --The name of the target table
									  @SaveConstraints BIT = 0, --Should constraints be saved? if yes (1), All existing Table constraints will be saved in a table: dbo.constraintsSaved
									  @DropConstraints BIT =0, --Should Constriants be dropped? If yes, all table constraints will be dropped to ease the loading of data.
									  @RestoreConstraints BIT = 0, --When set to 1, all constraints found in the create_script column of table: dbo.constraintsSaved will be used in restoring constraints.
									  @DeleteDataFromTables BIT =0, --When set to 1, all data will be deleted from all tables in the datababse. In the event that parameter @SaveConstraints is also set to 1, or data is found in the dbo.constriantsSaved table, they will be printed out in the message window.
									  @MoveDataToProduction BIT = 0, -- When set to 1 (yes), data found in the staging table will be moved to the target table.
									  @DeleteStagingTable BIT = 0 --If set to 1, Staging table will be dropped.
									  )
AS
BEGIN
--**************************************************************
	--Check User Input on Parameter: @SaveConstraints.
IF @SaveConstraints = 0
BEGIN
	IF OBJECT_ID('dbo.ConstraintsSaved') IS NOT NULL
BEGIN
	PRINT N'Note that Some Constraints Are currently Preserved in Table "dbo.ConstraintsSaved" and have been left unchanged'
END
END
ELSE
BEGIN
	IF OBJECT_ID('dbo.ConstraintsSaved') IS NOT NULL
	BEGIN
		PRINT N'I see that you wish to have constraints saved. Kindly note that I found some constraints previously preserved in Table "dbo.ConstraintsSaved" ' + ' and per your instructions, will proceed to delete them. Below are the constraints found:'
		DECLARE @FoundConstraints NVARCHAR (MAX) = '';
		PRINT '<-----Drop Script----->'
		SELECT @FoundConstraints += drop_Script FROM dbo.ConstraintsSaved
		PRINT @FoundConstraints;
		PRINT '<-----Create Script----->'
		SET @FoundConstraints = '';
		SELECT @FoundConstraints += Create_Script FROM dbo.ConstraintsSaved
		PRINT @FoundConstraints;
		DROP TABLE dbo.ConstraintsSaved;
	END
	CREATE TABLE dbo.ConstraintsSaved
	(
	  Drop_Script NVARCHAR(MAX),
	  Create_Script NVARCHAR(MAX)
	);

	DECLARE @drop   NVARCHAR(MAX) = N'',
			@create NVARCHAR(MAX) = N'';

	-- Find and populate @Drop with all Constraints:
	SELECT @drop += N'
	ALTER TABLE ' + QUOTENAME(cs.name) + '.' + QUOTENAME(ct.name) 
		+ ' DROP CONSTRAINT ' + QUOTENAME(fk.name) + ';'
	FROM sys.foreign_keys AS fk
	INNER JOIN sys.tables AS ct
	  ON fk.parent_object_id = ct.[object_id]
	INNER JOIN sys.schemas AS cs 
	  ON ct.[schema_id] = cs.[schema_id];

	INSERT INTO dbo.ConstraintsSaved(drop_script) SELECT @drop;

	--Find and populate @Create with all constraints.
	SELECT @create += N'
	ALTER TABLE ' 
	   + QUOTENAME(cs.name) + '.' + QUOTENAME(ct.name) 
	   + ' ADD CONSTRAINT ' + QUOTENAME(fk.name) 
	   + ' FOREIGN KEY (' + STUFF((SELECT ',' + QUOTENAME(c.name)
	   -- get all the columns in the constraint table
		FROM sys.columns AS c 
		INNER JOIN sys.foreign_key_columns AS fkc 
		ON fkc.parent_column_id = c.column_id
		AND fkc.parent_object_id = c.[object_id]
		WHERE fkc.constraint_object_id = fk.[object_id]
		ORDER BY fkc.constraint_column_id 
		FOR XML PATH(N''), TYPE).value(N'.[1]', N'nvarchar(max)'), 1, 1, N'')
	  + ') REFERENCES ' + QUOTENAME(rs.name) + '.' + QUOTENAME(rt.name)
	  + '(' + STUFF((SELECT ',' + QUOTENAME(c.name)
	   -- get all the referenced columns
		FROM sys.columns AS c 
		INNER JOIN sys.foreign_key_columns AS fkc 
		ON fkc.referenced_column_id = c.column_id
		AND fkc.referenced_object_id = c.[object_id]
		WHERE fkc.constraint_object_id = fk.[object_id]
		ORDER BY fkc.constraint_column_id 
		FOR XML PATH(N''), TYPE).value(N'.[1]', N'nvarchar(max)'), 1, 1, N'') + ');'
	FROM sys.foreign_keys AS fk
	INNER JOIN sys.tables AS rt -- referenced table
	  ON fk.referenced_object_id = rt.[object_id]
	INNER JOIN sys.schemas AS rs 
	  ON rt.[schema_id] = rs.[schema_id]
	INNER JOIN sys.tables AS ct -- constraint table
	  ON fk.parent_object_id = ct.[object_id]
	INNER JOIN sys.schemas AS cs 
	  ON ct.[schema_id] = cs.[schema_id]
	WHERE rt.is_ms_shipped = 0 AND ct.is_ms_shipped = 0;

	UPDATE dbo.ConstraintsSaved SET create_script = @create;

	--DELETE DATA
	DECLARE @delete NVARCHAR(MAX) = '';
	SELECT @delete += 'DELETE FROM '+ QUOTENAME(name) + '; '
	FROM sys.tables
	PRINT N'Constraints Saved in Table "dbo.ConstraintsSaved" '
END
--Check User Input on Parameter: @DropConstraints.
IF @DropConstraints = 0
	BEGIN
		PRINT N'##------No Constraints Dropped------##'; 
	END
ELSE	
	BEGIN
		SET @drop = N'';
		SELECT @drop += drop_script FROM dbo.ConstraintsSaved;
		EXECUTE sp_executesql @drop;
		PRINT N'##------The Following Constraints Dropped------##';
		PRINT @drop;
	END

--Check User Input on Parameter: @RestoreConstraints.
IF @RestoreConstraints = 0
	BEGIN
		PRINT N'##------No Constraints were Restored------##'; 
	END
ELSE	
	BEGIN
		SET @create = N'';
		SELECT @create += create_script FROM dbo.ConstraintsSaved;
		EXECUTE sp_executesql @create;
		PRINT N'##------Following Constraints were Restored------##';
		PRINT @Create;
	END

	--Delete Data From All Tables?
IF (@DeleteDataFromTables = 0)
BEGIN
	PRINT N'##------Per User Request: No Data Deleted From Tables------##';
END
ELSE IF (@DeleteDataFromTables = 1 AND EXISTS(SELECT * FROM dbo.ConstraintsSaved))
BEGIN
	PRINT N'##------Although you have requested to delete data from all tables, I found some constraints preserved in table "dbo.ConstraintsSaved. In case this was an error, here are the constraints found, and have been deleted:------##';
		DECLARE @FoundConstraints2 NVARCHAR (MAX) = '';
		PRINT '<-----Drop Script----->'
		SELECT @FoundConstraints2 += drop_Script FROM dbo.ConstraintsSaved
		PRINT @FoundConstraints2;
		PRINT '<-----Create Script----->'
		SET @FoundConstraints2 = '';
		SELECT @FoundConstraints2 += Create_Script FROM dbo.ConstraintsSaved
		PRINT @FoundConstraints2;
		DROP TABLE dbo.ConstraintsSaved;
		EXEC sp_ExecuteSQL @delete;
		PRINT N'##------Data Deleted From All Tables------##';
END
ELSE
BEGIN
	EXEC sp_ExecuteSQL @delete;
	PRINT N'##------Data Deleted From All Tables------##';
END
--****************************************************************

	--Bulk Insert into Staging Table:
	DECLARE @SourceDir NVARCHAR(MAX)= @Directory + '\';
	DECLARE @CSVFile NVARCHAR(MAX)= @File;
	DECLARE @SQL_BulkInsert NVARCHAR(MAX) = '';
	DECLARE @TargetSchema NVARCHAR(100) = @Schema;
	DECLARE @TargetTable NVARCHAR(200) = @Table;
	DECLARE @ErrorFile NVARCHAR(MAX) = 'Error';
	DECLARE @StagingTable NVARCHAR(100) ='';
	DECLARE @SQL_DropStagingTable NVARCHAR(MAX) = '';
	DECLARE @SQL_CreateStageTable NVARCHAR(MAX) = '';
	--CREATE Staging TABLE:
	SELECT @StagingTable += 'Staging' + @TargetTable;
	SELECT @SQL_DropStagingTable += ' DROP TABLE ' + @StagingTable;
	DECLARE @SQL_IdentityInsert NVARCHAR(MAX) ='';
	DECLARE @ListOfColumns NVARCHAR(MAX) = '';
	DECLARE @SQL_MoveToTargetTable NVARCHAR(MAX) = '';
	DECLARE @ColName NVARCHAR(MAX) = '';
	DECLARE @SQL_DropColumns NVARCHAR(MAX) = '';
	DECLARE @SQL_CreateColumns NVARCHAR(MAX) = '';

	IF EXISTS (
	SELECT * FROM INFORMATION_SCHEMA.TABLES
	WHERE TABLE_NAME = @StagingTable
	)
	BEGIN
		EXECUTE SP_ExecuteSQL @SQL_DropStagingTable;
	END

	SELECT @SQL_CreateStageTable +=
	'	SELECT *
		INTO ' + @StagingTable +
		' FROM ' + @TargetTable

	EXECUTE Sp_ExecuteSQL @SQL_CreateStageTable;

	--Alter Staging table to allow NVARCHAR MAX ON ALL COLUMNS

	--Create Dummy Column:
	SELECT @SQL_DropColumns +=
		' ALTER TABLE ' + @TargetSchema + '.' + @StagingTable +
		' ADD Dummy_Col NVARCHAR(MAX)';
		 PRINT ' A dummy Column was added to Table: '+ @TargetSchema + '.' + @StagingTable
	--Create Cursor
	DECLARE C CURSOR FOR
	SELECT COLUMN_NAME
	FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_NAME = @StagingTable
	AND TABLE_SCHEMA = @TargetSchema
	OPEN C
	FETCH NEXT FROM C
	INTO @ColName
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @SQL_DropColumns +=
		' ALTER TABLE ' + @TargetSchema +'.'+ @StagingTable +
		' DROP COLUMN ' + @ColName + '; ';
		PRINT ('COLUMN: '+@ColName + ' scheduled to be DROPPED')
		SELECT @SQL_CreateColumns +=
		' ALTER TABLE ' + @TargetSchema +'.'+ @StagingTable +
		' ADD ' + @ColName + ' NVARCHAR(MAX); ';
		PRINT ('COLUMN: '+@ColName + ' scheduled to be changed to type: NVARCHAR(MAX)')
		FETCH NEXT FROM C INTO @ColName;
	END
	--Drop Dummy Column:
	SELECT @SQL_CreateColumns +=
		' ALTER TABLE ' + @TargetSchema + '.' + @StagingTable +
		' DROP COLUMN Dummy_Col; '
	PRINT ' A dummy Column was removed from Table: '+ @TargetSchema + '.' + @StagingTable
	CLOSE C
	DEALLOCATE C;

	--EXECUTE:
	EXECUTE SP_ExecuteSQL @SQL_DropColumns;
	EXECUTE SP_ExecuteSQL @SQL_CreateColumns;

	--Check if Table has an Identity Column:

	IF EXISTS 
	(
		SELECT	[schema] = s.name,
				[table] = t.name
		FROM sys.schemas AS s
		INNER JOIN sys.tables AS t
		  ON s.[schema_id] = t.[schema_id]
		WHERE S.name = @TargetSchema
		AND T.name = @StagingTable
		 AND  EXISTS 
		(
		  SELECT 1 
		  FROM sys.identity_columns
		  WHERE [object_id] = t.[object_id]
		)
	)
	BEGIN
		SELECT @SQL_IdentityInsert += 
		' SET IDENTITY_INSERT ' + @TargetSchema +'.'+ @StagingTable + ' ON';
		EXECUTE SP_ExecuteSQL @SQL_IdentityInsert;
		PRINT 'Identity Insert Turned ON for table: '+ @TargetSchema +'.'+ @StagingTable
	END
	--Insert the Data into the StagingTable:(Perform Bulk Insert)

	SELECT @SQL_BulkInsert +=
	'
		BULK INSERT ' + @TargetSchema + '.'+ @StagingTable +
		' FROM ' + '''' + @SourceDir + @CSVFile + '.csv' + '''' +
		' WITH 
		('+
		' MAXERRORS = 100 ' + ',' +
		' DATAFILETYPE = '+'''char''' + ', ' +
		' FIRSTROW = 2, ' +
		' FIELDTERMINATOR = ' +''',''' +', ' +
		' ROWTERMINATOR = ' + '''\n''' + ', ' +
		' ERRORFILE = ' + '''' + @SourceDir + @ErrorFile + CAST(REPLACE(REPLACE(SYSDATETIME(),':',''), '.', '') AS NVARCHAR(100)) +'.csv' + '''' +
		' ) ' +
		' PRINT (CONCAT('+ '''A total of ''' +', '+ ' @@ROWCOUNT ' + ',' + ''' new record(s) inserted into ''' + ', ' + '''' + @TargetSchema + '''' + ',' +'''.''' +',' + '''' + @StagingTable + '''' +'));
	'
	
	BEGIN TRY
	BEGIN TRANSACTION
		EXECUTE SP_EXECUTESQL @SQL_BulkInsert
		PRINT 'Successfully loaded'+' data '+' from CSV File: ' + @CSVFile + ' to DataBase Table '+@TargetSchema+'.'+@StagingTable
	COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		PRINT error_message()
		PRINT 'Failed to load data from CSV File: ' + @CSVFile + ' to DataBase Table '+@TargetSchema+'.'+@StagingTable
		ROLLBACK
	END CATCH

	--UPDATE STAGING TABLE TO REMOVE QUOTES:
	DECLARE @SQL_RemoveQuotes NVARCHAR(MAX) = '';
	SET @ColName = '';

	DECLARE C CURSOR FOR
	SELECT COLUMN_NAME
	FROM INFORMATION_SCHEMA.COLUMNS
	WHERE TABLE_NAME = @StagingTable
	AND TABLE_SCHEMA = @TargetSchema

	OPEN C
	FETCH NEXT FROM C
	INTO @ColName
	WHILE @@FETCH_STATUS = 0
	BEGIN
		SELECT @SQL_RemoveQuotes +=
		' UPDATE ' + @TargetSchema +'.'+ @StagingTable +
		' SET ' + @ColName + ' = REPLACE( ' + @ColName +',' + '''"''' +  ',' + '''' +  '''' +' )' +'; ';
		PRINT ('Removed Quotes in Column : '+ @ColName)
		FETCH NEXT FROM C INTO @ColName;
	END
	CLOSE C
	DEALLOCATE C;
	EXECUTE SP_ExecuteSQL @SQL_RemoveQuotes;


	--GENERATE A LIST OF COLUMNS ON TARGET TABLE
	SELECT @ListOfColumns += STUFF(
	(SELECT 
	',' + COLUMN_NAME AS [text()]
	FROM 
	INFORMATION_SCHEMA.COLUMNS
	WHERE 
	TABLE_NAME = @StagingTable
	Order By Ordinal_position
	FOR XML PATH('')
	), 1,1, '')

	--MOVE TO TARGET TABLE:
	SET @SQL_IdentityInsert = '';
	IF EXISTS 
	(
		SELECT	[schema] = s.name,
				[table] = t.name
		FROM sys.schemas AS s
		INNER JOIN sys.tables AS t
		  ON s.[schema_id] = t.[schema_id]
		WHERE S.name = @TargetSchema
		AND T.name = @TargetTable
		 AND  EXISTS 
		(
		  SELECT 1 FROM sys.identity_columns
		  WHERE [object_id] = t.[object_id]
		)
	)
	BEGIN
	SET @SQL_MoveToTargetTable = '';
	SELECT @SQL_MoveToTargetTable += 
	' SET IDENTITY_INSERT ' + @TargetSchema +'.'+ @TargetTable + ' ON' + ';' +
	' INSERT INTO ' + @TargetSchema +'.' + @TargetTable + ' ( ' + @ListOfColumns + ' ) ' +
	' SELECT ' + @ListOfColumns +
	' FROM ' + @StagingTable + ';' +
	' SET IDENTITY_INSERT ' + @TargetSchema +'.'+ @TargetTable + ' OFF' + ';';
	END;
	ELSE
	BEGIN
	SET @SQL_MoveToTargetTable = '';
	SELECT @SQL_MoveToTargetTable += 
	' INSERT INTO ' + @TargetSchema +'.' + @TargetTable + ' ( ' + @ListOfColumns + ' ) ' +
	' SELECT ' + @ListOfColumns +
	' FROM ' + @StagingTable + ';'
	END;
	--EXECUTE:
	IF @MoveDataToProduction = 0
	BEGIN
		PRINT '##------Per User Request, Data will not be moved to Target Table------## '
	END
	ELSE
	BEGIN
		BEGIN TRY
			BEGIN TRANSACTION MoveToTarget
		EXECUTE SP_ExecuteSQL @SQL_MoveToTargetTable;
		PRINT ('Successfully Moved Data From ' + @StagingTable + ' to ' + @TargetTable);
			COMMIT TRANSACTION MoveToTarget
		END TRY
		BEGIN CATCH
		PRINT ('Failed to Move Data From ' + @StagingTable + ' to ' + @TargetTable);
		ROLLBACK TRANSACTION MoveToTarget
		END CATCH
	END
	--Drop Staging Table
	IF @DeleteStagingTable = 0
	BEGIN
		PRINT '##------Per User Request, Staging Table ' + @StagingTable + ' will not be dropped'+ '------##'
	END
	ELSE
	BEGIN
		IF EXISTS (
		SELECT * FROM INFORMATION_SCHEMA.TABLES
		WHERE TABLE_NAME = @StagingTable
		)
		BEGIN
			EXECUTE SP_ExecuteSQL @SQL_DropStagingTable;
		END
	END
END
