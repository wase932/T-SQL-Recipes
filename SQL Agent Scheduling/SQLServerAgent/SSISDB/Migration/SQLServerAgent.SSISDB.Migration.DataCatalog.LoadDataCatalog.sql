--Map variable to Package:--------------------------------------------------------------------------------------------------------------------------------
-- https://docs.microsoft.com/en-us/sql/integration-services/system-stored-procedures/catalog-set-object-parameter-value-ssisdb-database?view=sql-server-ver15
--<ParameterType> : 20 (Project Parameter) | 30 (Package Parameter)
--<ReferenceType> : R (Parameter value is an environment variable | V (Parameter value is default value)

BEGIN TRAN
	Declare @ParameterType smallint,@ProjectName nvarchar(128), @FolderName nvarchar(128), @ParameterName nvarchar(128), @ParameterValue sql_variant, @PackageName nvarchar(260), @ReferenceType char(1);
	Declare @SetPackageParametersTable TABLE (Id int PRIMARY KEY Identity (1,1), ParameterType smallint CHECK(ParameterType IN(20,30)) NOT NULL, FolderName nvarchar(128) NOT NULL, ProjectName nvarchar(128) NOT NULL, ParameterName nvarchar(128) NOT NULL, ParameterValue sql_variant NULL, PackageName nvarchar(260) NULL, ReferenceType char(1) default ('R') CHECK (ReferenceType IN ('R','V')) NOT NULL
											  --Check constraint to ensure that if the Parameter is a Pacakage Parameter (30), the Package Name is specified
											 ,CHECK ( IIF(PackageName IS NULL,1,0) = IIF(ParameterType=20,1,0))
											 );
	
	Insert @SetPackageParametersTable (ParameterType ,FolderName, ProjectName, ParameterName, ParameterValue, PackageName, ReferenceType)
	Select *
	From (values
			 (20, N'Migration', N'DataCatalog', N'SourceDataCatalog_InitialCatalog', N'SourceDataCatalog_InitialCatalog', NULL, N'R')
			,(20, N'Migration', N'DataCatalog', N'SourceDataCatalog_ServerName', N'SourceDataCatalog_ServerName', NULL, N'R')
			,(20, N'Migration', N'DataCatalog', N'TargetDataCatalog_InitialCatalog', N'TargetDataCatalog_InitialCatalog', NULL, N'R')
			,(20, N'Migration', N'DataCatalog', N'TargetDataCatalog_ServerName', N'TargetDataCatalog_ServerName', NULL, N'R')
		 )SetPackageParametersTable (ParameterType ,FolderName, ProjectName, ParameterName, ParameterValue, PackageName, ReferenceType)

	Declare @i_SetPackageParametersTable int = 0
		   ,@i_SetPackageParametersTableMax int = (Select Max(Id) From @SetPackageParametersTable)
		   ,@ParameterTypeString nvarchar(128)
		   ,@ReturnCode int = 0;

	While (@i_SetPackageParametersTable < @i_SetPackageParametersTableMax)
	BEGIN
		Set @i_SetPackageParametersTable += 1;
		Select @ParameterTypeString = IIF(@ParameterType = 20, 'Project' , 'Package');
		PRINT CONCAT('INFO: Assigning parameter value ', @i_SetPackageParametersTable ,' of ', @i_SetPackageParametersTableMax, '...');

		Select @ParameterType = ParameterType ,@FolderName = FolderName, @ProjectName = ProjectName, @ParameterName = ParameterName, @ParameterValue = ParameterValue, @PackageName = PackageName, @ReferenceType = ReferenceType
		From @SetPackageParametersTable Where Id = @i_SetPackageParametersTable;

		PRINT CONCAT('INFO: Assigning "', @ParameterTypeString, '" Parameter { ', @ParameterName,' = ' ,CONVERT(nvarchar(128), @ParameterValue),' }...');
		Exec @ReturnCode = SSISDB.catalog.set_object_parameter_value
											 @object_type = @ParameterType
											,@folder_name = @FolderName
											,@project_name = @ProjectName
											,@parameter_name = @ParameterName
											,@parameter_value = @ParameterValue
											,@object_name = @PackageName
											,@value_type = @ReferenceType;
		
		IF (@@ERROR <> 0 OR @ReturnCode <> 0)
		BEGIN
			PRINT CONCAT('ERROR: An error occured while Assigning a "', @ParameterTypeString, '" Parameter { ', @ParameterName,' = ' ,CONVERT(nvarchar(128), @ParameterValue),' }...');
			ROLLBACK;
			BREAK;
		END
	END
COMMIT TRAN;
GO