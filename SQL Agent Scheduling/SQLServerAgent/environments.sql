--ENVIRONMENT------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------
--Create Environments:
-- https://docs.microsoft.com/en-us/sql/integration-services/system-stored-procedures/catalog-create-environment-ssisdb-database?view=sql-server-ver15
Declare @Environments TABLE (Id int identity(1,1), EnvironmentName nvarchar(128), FolderName nvarchar(128), EnvironmentDescription nvarchar(1024))
Declare @EnvironmentName nvarchar(128),
		@FolderName nvarchar(128),
		@EnvironmentDescription nvarchar(1024);

Insert @Environments (EnvironmentName, FolderName, EnvironmentDescription)
Select *
From (Values 
			 ('Sandbox', 'Migration', 'Sandbox environment for simulating deployments')
			,('Dev', 'Migration', 'Dev environment for development work')
			,('Test', 'Migration', 'Test environment for QA Assessment')
			,('UAT', 'Migration', 'User acceptance environment for User Acceptance Testing')
			,('Prod', 'Migration', 'Sandbox environment for Production')
	 )T(EnvironmentName, FolderName, EnvironmentDescription)
 where EnvironmentName = '$(EnvironmentReferenceName)';

Declare @i_environments int = 0;

WHILE (@i_environments < (Select Max(id) From @Environments))
BEGIN
	Set @i_environments += 1;
	Select  @EnvironmentName = EnvironmentName
		   ,@FolderName = FolderName
		   ,@EnvironmentDescription = EnvironmentDescription
	From @Environments Where Id = @i_environments;

	IF NOT EXISTS (Select 1 From ssisdb.catalog.environments e
					Join SSISDB.catalog.folders f on e.folder_id = f.folder_id
					where e.name = @EnvironmentName and f.name = @FolderName)
		BEGIN
			PRINT 'INFO: The "' + @EnvironmentName + '" environment does not exist in the "' + @FolderName + '" folder and will be created';
			Exec SSISDB.[catalog].create_environment 
							  @environment_name = @EnvironmentName
							 ,@folder_name = @FolderName
							 ,@environment_description = @EnvironmentDescription;
		END
	ELSE 
	BEGIN
		PRINT 'INFO: The "' + @EnvironmentName + '" environment already exists in the "' + @FolderName + '" folder and will not be modified';
	END
END
GO
