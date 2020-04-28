

--Create Environment Reference:--------------------------------------------------------------------------------------------------------------------------------
-- https://docs.microsoft.com/en-us/sql/integration-services/system-stored-procedures/catalog-create-environment-reference-ssisdb-database?view=sql-server-ver15
---------------------------------------------------------------------------------------------------------------------------------------------------------------

BEGIN TRAN
	Declare @EnvironmentName nvarchar(128) = N'', @ProjectName nvarchar(128) = N'', @FolderName nvarchar(128) = N'';
	Declare @EnvironmentReferenceTable TABLE (Id int identity(1,1), EnvironmentName nvarchar(128), ProjectName nvarchar(128), FolderName nvarchar(128));

	Insert @EnvironmentReferenceTable (EnvironmentName, ProjectName, FolderName)
	Select *
	From (values
			 ('Sandbox', 'DataCatalog','Migration')
			,('Dev', 'DataCatalog','Migration')
			,('Test', 'DataCatalog','Migration')
			,('UAT', 'DataCatalog','Migration')
			,('Prod', 'DataCatalog','Migration')
		 ) EnvironmentReferenceTable (EnvironmentName, ProjectName, FolderName)
		 Where EnvironmentName = '$(EnvironmentReferenceName)'
	--Select * From @EnvironmentReferenceTable

	Declare @i_EnvironmentReferenceTable int = 0
		   ,@i_EnvironmentReferenceTableMax int = (Select Max(Id) From @EnvironmentReferenceTable)
		   ,@ReferenceId bigint = 0
		   ,@ReturnCode int = 0;

	While (@i_EnvironmentReferenceTable < @i_EnvironmentReferenceTableMax)
	BEGIN
		Set @i_EnvironmentReferenceTable += 1;
		PRINT CONCAT('INFO: Creating environment reference ', @i_EnvironmentReferenceTable ,' of ', @i_EnvironmentReferenceTableMax, '...');
		
		Select @EnvironmentName = EnvironmentName, @ProjectName = ProjectName, @FolderName = FolderName
		From @EnvironmentReferenceTable Where Id = @i_EnvironmentReferenceTable;

		IF NOT EXISTS ( 
						Select 1
						From SSISDB.catalog.environment_references er
						Join SSISDB.catalog.projects p on er.project_id = p.project_id
						Where er.environment_name = @EnvironmentName and p.name = @ProjectName
						)
		BEGIN
			Exec @ReturnCode =  SSISDB.catalog.create_environment_reference
								@environment_name = @EnvironmentName
							   ,@project_name = @ProjectName
							   ,@folder_name = @FolderName
							   ,@reference_type = 'R' --NOTE: Error in documentation:: PR https://github.com/MicrosoftDocs/sql-docs/pull/4133 created to fix
							   ,@environment_folder_name = NULL
							   ,@reference_id = @ReferenceId OUTPUT;
		END
		ELSE PRINT ('INFO: Environment reference to "' + @EnvironmentName + '" from /' + @FolderName + '/' + @ProjectName + ' already exists. No change made');
		IF (@@ERROR <> 0 OR @ReturnCode <> 0)
		BEGIN
			PRINT 'ERROR: An error occured while creating an environment reference for "' + @EnvironmentName + '" in the "' + @FolderName + '" folder. Rolling back now....';
			ROLLBACK;
			BREAK;
		END
	END
COMMIT TRAN;
Go
