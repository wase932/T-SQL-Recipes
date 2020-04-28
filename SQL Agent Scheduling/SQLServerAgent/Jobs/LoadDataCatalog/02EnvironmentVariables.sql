
--Create Environment variables:
-- https://docs.microsoft.com/en-us/sql/integration-services/system-stored-procedures/catalog-create-environment-variable-ssisdb-database?view=sql-server-ver15
--!IMPORTANT: Be sure to preface variable values with the "N" Modifier. ie. N'my_value';
Declare @FolderName nvarchar(128) = N'Migration',
		@ReturnCode int = 0,
		@EnvironmentName nvarchar(128), @VariableName nvarchar(128), @VariableValue sql_variant, @DataType nvarchar(128), @IsSensitive bit, @VariableDescription nvarchar(1024);

Declare @EnvironmentVariables TABLE (Id int Identity(1,1), EnvironmentName nvarchar(128), VariableName nvarchar(128), VariableValue sql_variant, DataType nvarchar(128), IsSensitive bit, VariableDescription nvarchar(1024))
Insert @EnvironmentVariables (EnvironmentName, VariableName, VariableValue, DataType, IsSensitive, VariableDescription)
Select *
From (Values
		-- Sandbox-----------------------------------------------------------------------------------------------
		 (N'Sandbox', N'SourceDataCatalog_InitialCatalog', N'DataCatalog', 'String', 0, 'Source Database' )
		,(N'Sandbox', N'SourceDataCatalog_ServerName', N'guardianmig01p', 'String', 0, 'Source Server' )
		,(N'Sandbox', N'TargetDataCatalog_InitialCatalog', N'DataCatalog', 'String', 0, 'Destination Database' )
		,(N'Sandbox', N'TargetDataCatalog_ServerName', N'guardianmig01p\Sandbox', 'String', 0, 'Destination Server' )
		-- Dev-----------------------------------------------------------------------------------------------
		,(N'Dev', N'SourceDataCatalog_InitialCatalog', N'DataCatalog', 'String', 0, 'Source Database' )
		,(N'Dev', N'SourceDataCatalog_ServerName', N'guardianmig01p', 'String', 0, 'Source Server' )
		,(N'Dev', N'TargetDataCatalog_InitialCatalog', N'DataCatalog', 'String', 0, 'Destination Database' )
		,(N'Dev', N'TargetDataCatalog_ServerName', N'guardianmig01T', 'String', 0, 'Destination Server' )
		-- Test-----------------------------------------------------------------------------------------------
		,(N'Test', N'SourceDataCatalog_InitialCatalog', N'DataCatalog', 'String', 0, 'Source Database' )
		,(N'Test', N'SourceDataCatalog_ServerName', N'guardianmig01p', 'String', 0, 'Source Server' )
		,(N'Test', N'TargetDataCatalog_InitialCatalog', N'DataCatalog', 'String', 0, 'Destination Database' )
		,(N'Test', N'TargetDataCatalog_ServerName', N'guardianmig01T', 'String', 0, 'Destination Server' )
		-- UAT-----------------------------------------------------------------------------------------------
		,(N'UAT', N'SourceDataCatalog_InitialCatalog', N'DataCatalog', 'String', 0, 'Source Database' )
		,(N'UAT', N'SourceDataCatalog_ServerName', N'guardianmig01p', 'String', 0, 'Source Server' )
		,(N'UAT', N'TargetDataCatalog_InitialCatalog', N'DataCatalog', 'String', 0, 'Destination Database' )
		,(N'UAT', N'TargetDataCatalog_ServerName', N'Unknown', 'String', 0, 'Destination Server' )
		-- Prod-----------------------------------------------------------------------------------------------
		,(N'Prod', N'SourceDataCatalog_InitialCatalog', N'DataCatalog', 'String', 0, 'Source Database' )
		,(N'Prod', N'SourceDataCatalog_ServerName', N'guardianmig01p', 'String', 0, 'Source Server' )
		,(N'Prod', N'TargetDataCatalog_InitialCatalog', N'DataCatalog', 'String', 0, 'Destination Database' )
		,(N'Prod', N'TargetDataCatalog_ServerName', N'Unknown', 'String', 0, 'Destination Server' )
	 )  T(EnvironmentName, VariableName, VariableValue, DataType, IsSensitive, VariableDescription)
	 Where EnvironmentName = '$(EnvironmentReferenceName)';

Declare @i_environmentVariables int = 0;
While(@i_environmentVariables < (Select Max(Id) From @EnvironmentVariables))
BEGIN
	Set @i_environmentVariables += 1;

	Select @EnvironmentName = EnvironmentName,  @VariableName = VariableName, @VariableValue = VariableValue, @DataType = DataType, @IsSensitive = IsSensitive, @VariableDescription = VariableDescription
	From @EnvironmentVariables Where Id = @i_environmentVariables;

	--If the environment variable exists, but does not hold the same values, delete it
	IF Exists	  (	
					Select 1
					From SSISDB.catalog.environments e 
					Join SSISDB.catalog.folders f on e.folder_id = f.folder_id
					Join SSISDB.catalog.environment_variables ev on e.environment_id = ev.environment_id
					Join @EnvironmentVariables iev on e.name = @EnvironmentName and f.name = @FolderName and ev.name = iev.VariableName
					Where iev.Id = @i_environmentVariables
					AND(
						   (ev.value <> iev.VariableValue)
						OR (ev.description <> iev.VariableDescription)
						OR (ev.sensitive <> iev.IsSensitive)
						OR (ev.type <> iev.DataType)
					   )
				  )
	  BEGIN
		PRINT ('INFO : Environment variable [' + @FolderName + '].[' + @EnvironmentName + '].[' + @VariableName + ']' + ' exists but does not hold the same value(s) and will therefore be deleted');
		Exec @ReturnCode = SSISDB.catalog.delete_environment_variable
							  @environment_name = @EnvironmentName
							 ,@folder_name = @FolderName
							 ,@variable_name = @VariableName;
		IF (@@ERROR <> 0 OR @ReturnCode <> 0)
		BEGIN
			PRINT 'ERROR: An error occured while deleting environment variable [' + @FolderName + '].[' + @EnvironmentName + '].[' + @VariableName + ']' + '. Rolling back now....';
			ROLLBACK TRAN;
			BREAK;
		END
	  END

	--If the environment variable does not exist, create it:
	IF NOT Exists (
					Select 1
					From SSISDB.catalog.environments e 
					Join SSISDB.catalog.folders f on e.folder_id = f.folder_id
					Join SSISDB.catalog.environment_variables ev on e.environment_id = ev.environment_id
					Join @EnvironmentVariables iev on e.name = @EnvironmentName and f.name = @FolderName and ev.name = iev.VariableName
					Where iev.Id = @i_environmentVariables
					)
	BEGIN
		Print ('INFO: Creating Environment variable ['  + @FolderName + '].[' + @EnvironmentName + '].[' + @VariableName + ']' + ' ...');
		Exec @ReturnCode = SSISDB.catalog.create_environment_variable
								@environment_name = @EnvironmentName
								,@folder_name = @FolderName
								,@variable_name = @VariableName
								,@data_type = @DataType
								,@sensitive = @IsSensitive
								,@value = @VariableValue
								,@description = @VariableDescription
		IF (@@ERROR <> 0 OR @ReturnCode <> 0)
		BEGIN
			PRINT 'ERROR: An error occured while creating environment variable [' + @FolderName + '].[' + @EnvironmentName + '].[' + @VariableName + ']' + '. Rolling back now....';
			ROLLBACK
			BREAK;
		END
	END
	BEGIN
		Print ('INFO: No change was made to the existing environmental variable [' +  @FolderName + '].[' + @EnvironmentName + '].[' + @VariableName + ']');
	END
END
GO
