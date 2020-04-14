SET ANSI_NULLS ON 
SET ANSI_WARNINGS ON    


Declare @DatabaseName sysname = 'DB2T_0';
Declare @LinkedServerName sysname = 'DES_DB2T';

Declare @LinkedServerSchema Table
(
 TABLE_CAT sysname,
 TABLE_SCHEM sysname,
 TABLE_NAME sysname,
 COLUMN_NAME sysname,
 DATA_TYPE smallint,
 [TYPE_NAME] varchar(13),
 COLUMN_SIZE int,
 BUFFER_LENGTH int,
 DECIMAL_DIGITS smallint,
 NUM_PREC_RADIX smallint,
 NULLABLE smallint,
 REMARKS varchar(254),
 COLUMN_DEF varchar(254),
 SQL_DATA_TYPE smallint,
 SQL_DATETIME_SUB smallint,
 CHAR_OCTET_LENGTH int,
 ORDINAL_POSITION int,
 IS_NULLABLE varchar(254),
 SS_DATA_TYPE tinyint
 );

 Insert @LinkedServerSchema exec sp_columns_ex @LinkedServerName;

--Select DatabaseName, SchemaName, TableName
--From @LinkedServerSchema
--where ObjectType = 'Table'

DECLARE @SchemaName sysname; --Name of Schema that holds the table.
DECLARE @TableName sysname;
DECLARE @SQLCreateTable NVARCHAR(MAX) = N'';
DECLARE @SQLCreateSchema NVARCHAR(MAX) = N'';
DECLARE @SQLDropTable NVARCHAR(MAX) = N'';
DECLARE @i int = 1;
DECLARE @Max_i int = (SELECT COUNT(*) FROM @LinkedServerSchema);


--Declare Cursor:
DECLARE C CURSOR FOR
SELECT TABLE_SCHEM, TABLE_NAME
FROM @LinkedServerSchema
ORDER BY TABLE_NAME
OPEN C
FETCH NEXT FROM C
INTO @SchemaName, @TableName;

WHILE @@FETCH_STATUS = 0
BEGIN

	--Drop table
	Set @SQLDropTable = 'DROP TABLE IF EXISTS ' + QUOTENAME(@DatabaseName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName);
	--Create Schema
	Exec (@SQLDropTable);

	IF (NOT EXISTS (SELECT * FROM sys.schemas WHERE name = @SchemaName)) 
	BEGIN
		EXEC ('CREATE SCHEMA ' +  @SchemaName);
	END

	--Create Table
	BEGIN TRY
		Print(Concat('Creating Table  ', @i, ' of ', @Max_i));

		Set @i += 1;
		Set @SQLCreateTable = 'SELECT * INTO ' + QUOTENAME(@DatabaseName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) + ' FROM ' + QUOTENAME(@LinkedServerName) + '.' + QUOTENAME(@LinkedServerName) + '.' +  QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName)
		EXEC(@SQLCreateTable)
		Print('SUCCESS: Successfully created table ' + QUOTENAME(@DatabaseName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) )
	END TRY
	BEGIN CATCH
		Print('ERROR: Failed to create table ' + QUOTENAME(@DatabaseName) + '.' + QUOTENAME(@SchemaName) + '.' + QUOTENAME(@TableName) )
		Print ERROR_MESSAGE()
		PRINT ('Create Statement: ' + @SQLCreateTable)
	END CATCH

	FETCH NEXT FROM C INTO @SchemaName, @TableName

END
CLOSE C
DEALLOCATE C
GO