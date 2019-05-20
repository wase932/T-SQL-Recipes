SET QUOTED_IDENTIFIER ON
GO
SET ANSI_NULLS ON
GO
CREATE PROCEDURE [Crud].[Master_CRUD_CREATE]
(
 @SchemaName NVARCHAR(255)
,@TableName NVARCHAR(255)
)
AS
-------------------------------------------------------------------------
--Author: Tolu Adepoju
--Date: 20190505
--Description:
--This Procedure is a master CRUD for inserts into a single table.
--It creates a stored procedure that matches the specified table (in schema and name)
-------------------------------------------------------------------------

BEGIN
	IF OBJECT_ID('tempdb..#CRUD') IS NOT NULL
		DROP TABLE #CRUD;
	;WITH TableColumns AS
	(
	SELECT SCHEMA_NAME(t.schema_id) SchemaName
		  ,t.object_id TableObjectId
		  ,t.name TableName
		  ,c.name ColumnName
		  ,c.column_id ColumnId
		  ,TYPE_NAME(c.system_type_id) ColumnDataType
		  ,c.max_length ColumnMaxLength
		  ,c.precision ColumnPrecision
		  ,c.scale ColumnScale
		  ,c.is_nullable IsNullable
		  ,c.is_identity IsIdentity
		  ,IIF(c.default_object_id > 0, 1, 0) HasDefault
		  ,dc.definition DefaultConstraint
	FROM sys.tables t
	JOIN sys.columns c ON t.object_id = c.object_id
	LEFT JOIN sys.default_constraints    dc  on  dc.parent_object_id  = t.object_id
	AND dc.parent_column_id = c.column_id
	WHERE t.type = 'U'
	AND t.name <> 'sysdiagrams'
	AND SCHEMA_NAME(t.schema_id) = @SchemaName
	AND t.name = @TableName
	)
	,ForeignKeys AS
	(

	SELECT   obj.name ForeignKeyName
			,sch.name SchemaName
			,tab1.object_id TableObjectId
			,tab1.name TableName
			,col1.column_id ColumnId
			,col1.name ColumnName
			,tab2.object_id ReferencedObjectId
			,tab2.name ReferencedTableName
			,col2.column_id ReferencedColumnId
			,col2.name ReferencedColumnName		
	FROM sys.foreign_key_columns fkc
	INNER JOIN sys.objects obj
		ON obj.object_id = fkc.constraint_object_id
	INNER JOIN sys.tables tab1
		ON tab1.object_id = fkc.parent_object_id
	INNER JOIN sys.schemas sch
		ON tab1.schema_id = sch.schema_id
	INNER JOIN sys.columns col1
		ON col1.column_id = fkc.parent_column_id AND col1.object_id = tab1.object_id
	INNER JOIN sys.tables tab2
		ON tab2.object_id = fkc.referenced_object_id
	INNER JOIN sys.columns col2
		ON col2.column_id = fkc.referenced_column_id AND col2.object_id = tab2.object_id
	)
	,KeyConstraints AS
	(
	SELECT kc.object_id KeyConstraintObjectId
		  ,OBJECT_NAME(kc.object_id) KeyConstraintName
		  ,kc.schema_id KeyConstraintSchemaId
		  ,ccu.TABLE_SCHEMA TableSchemaName
		  ,kc.parent_object_id TableObjectId
		  ,OBJECT_NAME(kc.parent_object_id) TableName
		  ,ccu.COLUMN_NAME ColumnName
		  ,kc.type KeyConstraintType
		  ,kc.type_desc KeyConstraintDescription
		  ,ISNULL(OBJECTPROPERTY(kc.object_id, 'IsPrimaryKey'),0) IsPrimaryKey
		  ,ISNULL(OBJECTPROPERTY(kc.object_id, 'IsUniqueCnst'),0) IsUniqueKey
		  ,kc.unique_index_id TableUniqueColumnId
	FROM sys.key_constraints kc 
	JOIN information_schema.constraint_column_usage ccu ON kc.schema_id = SCHEMA_ID(ccu.TABLE_SCHEMA) AND  ccu.CONSTRAINT_NAME = kc.name
	)
	SELECT  tc.*
		   ,fk.ForeignKeyName
		   ,fk.ReferencedObjectId
		   ,fk.ReferencedTableName
		   ,fk.ReferencedColumnId
		   ,fk.ReferencedColumnName
		   ,kc.KeyConstraintObjectId
		   ,kc.KeyConstraintName
		   ,kc.KeyConstraintSchemaId
		   ,kc.KeyConstraintType
		   ,kc.KeyConstraintDescription
		   ,ISNULL(kc.IsPrimaryKey,0) IsPrimaryKey
		   ,ISNULL(kc.IsUniqueKey,0) IsUniqueKey
	INTO #CRUD
	FROM TableColumns tc
	LEFT JOIN ForeignKeys fk ON tc.TableObjectId = fk.TableObjectId AND fk.ColumnId = tc.ColumnId
	LEFT JOIN KeyConstraints kc ON tc.TableObjectId = kc.TableObjectId AND tc.ColumnName = kc.ColumnName

	--Now that we have the required fields, inserts should be super easy!

	--Get the required parameters needed to populate

	BEGIN
		DECLARE @variables VARCHAR(MAX) = N'';

		SELECT @variables += 
		JSON_VALUE(
		   REPLACE(
			 (
			 SELECT _ = CONCAT('@', ColumnName,' ', ColumnDataType, IIF(ColumnScale > 0, CONCAT('(',ColumnScale,')'),''), IIF(ColumnDataType LIKE '%char%', CONCAT('(',ColumnMaxLength,')'),'') , IIF( IsNullable = 1 OR HasDefault = 1, ' = NULL', '' ), CHAR(10))
			 FROM #CRUD 
			 WHERE IsIdentity = 0
			 ORDER BY ColumnId
			 FOR JSON PATH
			 )
			,'"},{"_":"',', '),'$[0]._'
		)

		--PRINT @variables
		--schema
		DECLARE @Schema VARCHAR(200) = N'';
		SELECT DISTINCT @Schema = SchemaName
		FROM #CRUD

		--table
		DECLARE @Table VARCHAR(200) = N'';
		SELECT DISTINCT @Table = TableName
		FROM #CRUD
		--------------------------------------
		--Insert table
		DECLARE @insertStatement_Table VARCHAR(MAX) = N'';

		SELECT DISTINCT @insertStatement_Table += CONCAT(QUOTENAME(SchemaName),'.', QUOTENAME(TableName))
		FROM #CRUD
		--PRINT @insertStatement_Table
		--Insert Column list
		DECLARE @insertStatement_Columns VARCHAR(MAX) = N'';
		SELECT @insertStatement_Columns += 
		JSON_VALUE(
		   REPLACE(
			 (
			 SELECT _ = QUOTENAME(ColumnName)
			 FROM #CRUD 
			 WHERE HasDefault = 0 AND IsPrimaryKey = 0 AND IsUniqueKey = 0
			 ORDER BY ColumnId
			 FOR JSON PATH
			 )
			,'"},{"_":"',', '),'$[0]._'
		)
		--PRINT @insertStatement_Columns

		--Values
		DECLARE @insertStatement_Values VARCHAR(MAX) = N'';
		SELECT @insertStatement_Values += 
		JSON_VALUE(
		   REPLACE(
			 (
			 SELECT _ = CONCAT('@', ColumnName)
			 FROM #CRUD
			 WHERE HasDefault = 0 AND IsPrimaryKey = 0 AND IsUniqueKey = 0
			 ORDER BY ColumnId
			 FOR JSON PATH
			 )
			,'"},{"_":"',', '),'$[0]._'
		)
		--PRINT @insertStatement_Values;

		--FullSQL:
		DECLARE @sql NVARCHAR(max) = N'';
		DECLARE @StoredProcedureName NVARCHAR(255) = '';
		SET @StoredProcedureName = @Schema + '.' +'usp_CRUD_CREATE_' + @Schema + '_' + @Table;

		SET @sql +=
		  + 'IF OBJECT_ID(''' + @StoredProcedureName + ''') IS NOT NULL' + CHAR(10)
		  + 'BEGIN' + CHAR(10)
		  + 'DROP PROCEDURE ' + @StoredProcedureName + ';' + CHAR(10)
		  + 'END' + CHAR(10)
	  
		EXEC SP_ExecuteSQL @SQL;
		SET @sql = '';
		----------------------------------------------------------------------
		--NEW BATCH
		----------------------------------------------------------------------

		SET @sql +=
		  + 'CREATE PROCEDURE ' + @StoredProcedureName + CHAR(10)
		  + '(' + CHAR(10)
		  + @variables + CHAR(10)
		  + ')' + CHAR(10)
		  + 'AS' + CHAR(10)

		SET @sql +=
		  + 'BEGIN' + CHAR(10)
		  + 'SET XACT_ABORT ON;' + CHAR(10)
		  + 'SET NOCOUNT ON; ' + CHAR(10)
		  + 'BEGIN TRAN' + CHAR(10)
		  + 'BEGIN TRY' + CHAR(10)
		  + 'INSERT ' + @insertStatement_Table + ' (' + @insertStatement_Columns + ') ' + ' VALUES (' + @insertStatement_Values + ')'  + CHAR(10)
		  + 'SELECT Scope_Identity();' + CHAR(10)
		  + 'END TRY' + CHAR(10)
		  + 'BEGIN CATCH' + CHAR(10)
		  + 'SELECT ERROR_NUMBER() ErrorNumber, ERROR_SEVERITY() ErrorSeverity, ERROR_STATE() ErrorState, ERROR_PROCEDURE() ErrorProcedure, ERROR_LINE() ErrorLine, ERROR_MESSAGE() ErrorMessage; ' + CHAR(10)
		  + '   ROLLBACK TRAN' + CHAR(10)
		  + 'END CATCH' + CHAR(10)
		  + 'COMMIT TRAN' + CHAR(10)
		  + 'SET NOCOUNT OFF; ' + CHAR(10)
		  + 'SET XACT_ABORT OFF;' + CHAR(10)
		  + 'END' + CHAR(10);
		 --PRINT @sql
	END
	
	EXEC SP_ExecuteSQL @SQL;
	PRINT(@StoredProcedureName + ' was created successfully');
END
GO