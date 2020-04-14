/********************************

*******************************/
:setvar ServerName "GuardianMig01P"
:setvar EnvironmentReferenceName "Dev"
GO
-- Create Environment

-- Create Environment Variable

-- Map variable to Package

-- Validate the Package --//TODO

-- Create Job

-- Create Agent Schedule

-- Assign Agent Scedule To Job

--Check that script execution is in SQLCMD mode
IF ('$(ServerName)' = '$' + '(ServerName)')
BEGIN
    RAISERROR ('This script must be run in SQLCMD mode. Disconnecting.', 20, 1) WITH LOG;

END
GO
-- The below is only run if SQLCMD is on, or the user lacks permission to raise fatal errors
IF @@ERROR != 0
    SET NOEXEC ON
GO

PRINT 'INFO: Executing in SQLCMD Mode';
-- Rest of script goes here

GO
SET NOEXEC OFF
GO

SET NOCOUNT ON;
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

--JOB--
-------------------------------------
-------------------------------------

--Job Name
/**********************************************************************************************************************************************************************************************
Category - SubCategory-Frequency-Description

{Admin | Data}-{ Maint | Backup | Restore | Interface | Migration | Report | DataWarehouse}-{1Hour - 2Hour | 6Hour | Hourly | Daily | Weekly | Quarterly | Monthly | Yearly | StateFiscalYearEnd | FedFiscalEnd | Custom}-{Description}
Examples :: Admin-Backup-Daily-Backup ODS
		 :: Data-Interface-Daily-Import Employee Data From HRIS
*********************************************************************************************************************************************************************************************/
Declare @JobName sysname = 'LoadDataCatalog'; --Name of the Job, be specific: <Function>_<St>
Declare @ReturnCode INT = 0; 
Declare @JobCategory sysname = 'Guardian-DataMigration' --Guardian-Interface, Guardian-Datamigration, Guardian--Maintenance Guardian-Report Guardian-Datawarehouse
Declare @IsJobEnabled INT = 1;
Declare @JobDescription nvarchar(1000) = N'Loading of mapping data into the data catalog database';
Declare @JobOwnerLoginName sysname = (Select SUSER_SNAME()); --N'DCS\sa.tadepoju';
Declare @TargetServerName sysname = '(local)'; -- $(ServerName)
-------------------------------------------------------------------------------------
--STEPS------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

BEGIN TRANSACTION
-----------------------------------------------------------------------------
--If the Job Category does not exist, create it
-----------------------------------------------------------------------------
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name= @JobCategory AND category_class=1)
BEGIN
	PRINT 'INFO: Job Category ' + @JobCategory + ' does not exist and will be created...';
	EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=@JobCategory
	IF (@@ERROR <> 0 OR @ReturnCode <> 0) 
	BEGIN
		PRINT 'ERROR: An error occured while creating Job Category ' + @JobCategory + '. Rolling back now....';
		GOTO QuitWithRollback;
	END
END

-----------------------------------------------------------------------------
--If the Job does not exist, create it, otherwise, retrieve the Job Id for 
--consumption downstream
-----------------------------------------------------------------------------
DECLARE @jobId BINARY(16);

IF EXISTS (Select name From msdb.dbo.sysjobs where name = @JobName)
BEGIN
	PRINT 'INFO: A Job with the name "' + @JobName + '" exists';
	Select @jobId = Job_id From msdb.dbo.sysjobs where name = @JobName;
	PRINT 'INFO: The JobId is: ' PRINT(@jobId);

END
ELSE
BEGIN
	PRINT 'INFO: Creating new Job "' + @JobName + '" ...';
	EXEC @ReturnCode =  msdb.dbo.sp_add_job 
			 @job_name=@JobName
			,@enabled=@IsJobEnabled
			,@notify_level_eventlog=0
			,@notify_level_email=0
			,@notify_level_netsend=0
			,@notify_level_page=0
			,@delete_level=0
			,@description=@JobDescription
			,@category_name=@JobCategory
			,@owner_login_name=@JobOwnerLoginName
		    ,@job_id = @jobId OUTPUT
	IF (@@ERROR <> 0 OR @ReturnCode <> 0)
		GOTO QuitWithRollback
	PRINT 'SUCCESS: Created new Job "' + @JobName + '" ...';
	
	--Update the newly created job with a step
	EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
	IF (@@ERROR <> 0 OR @ReturnCode <> 0)
		GOTO QuitWithRollback
	EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = @TargetServerName
	IF (@@ERROR <> 0 OR @ReturnCode <> 0)
		GOTO QuitWithRollback
END
	
COMMIT TRANSACTION
	GOTO EndSave

QuitWithRollback:
	IF (@@TRANCOUNT > 0)
	BEGIN
		PRINT 'ERROR: An error occured during execution. Rolling back transaction...';
		ROLLBACK TRANSACTION;
		RETURN;
	END
EndSave:
PRINT 'SUCCESS: Processing of SQL Server Agent Job ' + @JobName + ' is complete';

--JOB STEPS--------------------------------------------------------------------------
/*******************************************************************************************************************************************
		Example usage:
		1 --<StepId>
        ,'Rebuild Indexes' --<StepName>
        ,'SSIS' --<StepType>: [SSIS, TSQL, CmdExec,PowerShell, Merge...] To get a full list => Select Subsystem From msdb.dbo.SysSubsystems
        ,1 --<IsEnabled> [0, 1]
        ,3 --<OnSuccessAction> [1:Quit with Success, 2:Quit with failure, 3: Go to next step, 4: Go to step identified in <OnSuccessStepId>]
        ,0 --<OnSuccessStepId> Optional. Required if <OnSuccessAction> = 4.
        ,2 --<OnFailureAction> [1:Quit with Success, 2:Quit with failure, 3: Go to next step, 4: Go to step identified in <OnFailureStepId>]
        ,0 --<OnFailureStepId> Optional. Required if <OnFailureAction> = 4.
        ,0 --<RetryAttempts>
        ,0  --<RetryInterval> Amount of time between retry attempts
        ,'svc.guardianssis'  --<ProxyName>
        ,'/ISSERVER "\"\SSISDB\Migration\SourceSystemReplication\OLCR_System.dtsx\"" /SERVER GuardianMig01P /Par "\"DataRetentionPolicyID(Int32)\"";1 /Par "\"$ServerOption::LOGGING_LEVEL(Int16)\"";1 /Par "\"$ServerOption::SYNCHRONIZED(Boolean)\"";True /CALLERINFO SQLAGENT /REPORTING E' --<SQLCommand>
        
		#########################################################################################################################################
        #For SSIS Packages, see reference for dtexec Utility:
        #https://docs.microsoft.com/en-us/sql/integration-services/packages/dtexec-utility?view=sql-server-ver15
        #Syntax Rules: https://docs.microsoft.com/en-us/sql/integration-services/packages/dtexec-utility?view=sql-server-ver15#syntaxRules
        #Specify Package: /ISServer \<catalog name>\<folder name>\<project name>\package file name
        #Parameters:
        #    --Project Parameter: /Parameter $Project::parameter_name(data_type);parameter_value
        #    --Package Parameter: /Parameter $Package::parameter_name(data_type);parameter_value
		##########################################################################################################################################

*******************************************************************************************************************************************/
Declare @JobStepsTable Table
(
	 StepId int
    ,StepName sysname
	,SSISProjectName sysname
	,SSISFolderName sysname
    ,StepType nvarchar(40)
    ,IsEnabled bit
    ,OnSuccessAction tinyint
    ,OnSuccessStepId int
    ,OnFailureAction tinyint
    ,OnFailureStepId int
    ,RetryAttempts int
    ,RetryInterval int
    ,ProxyName sysname
    ,Command nvarchar(max)
);


Insert @JobStepsTable
Select   StepId, StepName, SSISProjectName, SSISFolderName, StepType, IsEnabled, OnSuccessAction, OnSuccessStepId, OnFailureAction, OnFailureStepId, RetryAttempts, RetryInterval, ProxyName, SQLCommand
From (values 
		  (1,'Run DataCatalog Package', 'DataCatalog','Migration', 'SSIS',1,1,2,2,0,0,0,'svc.guardianssis','/ISSERVER "\"\SSISDB\Migration\DataCatalog\LoadDataCatalog.dtsx\"" /CALLERINFO SQLAGENT /REPORTING V /X86 /SERVER $(ServerName) /ENVREFERENCE {{EnvRefId}}')
	   --,(2,'Rebuild Indexes','SSIS',1,3,0,2,0,0,0,'svc.guardianssis','/ISSERVER "\"\SSISDB\Migration\SourceSystemReplication\OLCR_System.dtsx\"" /SERVER GuardianMig01P /Par "\"DataRetentionPolicyID(Int32)\"";1 /Par "\"$ServerOption::LOGGING_LEVEL(Int16)\"";1 /Par "\"$ServerOption::SYNCHRONIZED(Boolean)\"";True /CALLERINFO SQLAGENT /REPORTING V /X86')
	   --,(3,'Rebuild Indexes1','SSIS',1,3,0,2,0,0,0,'svc.guardianssis','/ISSERVER "\"\SSISDB\Migration\SourceSystemReplication\OLCR_System.dtsx\"" /SERVER GuardianMig01P /Par "\"DataRetentionPolicyID(Int32)\"";1 /Par "\"$ServerOption::LOGGING_LEVEL(Int16)\"";1 /Par "\"$ServerOption::SYNCHRONIZED(Boolean)\"";True /CALLERINFO SQLAGENT /REPORTING E')
	   --,(4,'Rebuild Indexes2','SSIS',1,3,0,2,0,0,0,'svc.guardianssis','/ISSERVER "\"\SSISDB\Migration\SourceSystemReplication\OLCR_System.dtsx\"" /SERVER GuardianMig01P /Par "\"DataRetentionPolicyID(Int32)\"";1 /Par "\"$ServerOption::LOGGING_LEVEL(Int16)\"";1 /Par "\"$ServerOption::SYNCHRONIZED(Boolean)\"";True /CALLERINFO SQLAGENT /REPORTING E')
	   --,(5,'Rebuild Indexes3','SSIS',1,1,2,2,0,0,0,'svc.guardianssis','/ISSERVER "\"\SSISDB\Migration\SourceSystemReplication\OLCR_System.dtsx\"" /SERVER GuardianMig01P /Par "\"DataRetentionPolicyID(Int32)\"";1 /Par "\"$ServerOption::LOGGING_LEVEL(Int16)\"";1 /Par "\"$ServerOption::SYNCHRONIZED(Boolean)\"";True /CALLERINFO SQLAGENT /REPORTING E')
	  )
	  JobStepsTable (StepId,StepName, SSISProjectName, SSISFolderName,StepType,IsEnabled,OnSuccessAction,OnSuccessStepId,OnFailureAction,OnFailureStepId,RetryAttempts,RetryInterval,ProxyName,SQLCommand);


Declare  @StepId int
	    ,@StepName sysname
		,@SSISProjectName sysname
		,@SSISFolderName sysname
	    ,@StepType nvarchar(40) = N''
	    ,@IsEnabled bit
	    ,@OnSuccessAction tinyint
	    ,@OnSuccessStepId int
	    ,@OnFailureAction tinyint
	    ,@OnFailureStepId int
	    ,@RetryAttempts int
	    ,@RetryInterval int
	    ,@ProxyName sysname
	    ,@Command nvarchar(max) = N'';

Declare @i_JobStepsTable int = 1
Declare @i_JobStepsTableMax int = (Select Count(*) from @JobStepsTable);
Declare @AddJobStepReturnCode int;
While(1=1)
Begin
	Print('INFO: Adding Job Step ' + Cast(@i_JobStepsTable as varchar(3)) + ' of ' + Cast(@i_JobStepsTableMax as varchar(3)) + '...');
	Select 	 @StepId = StepId
			,@StepName = StepName
			,@SSISProjectName = SSISProjectName
			,@SSISFolderName = SSISFolderName
			,@StepType = StepType
			,@IsEnabled = IsEnabled
			,@OnSuccessAction = OnSuccessAction
			,@OnSuccessStepId = OnSuccessStepId
			,@OnFailureAction = OnFailureAction
			,@OnFailureStepId = OnFailureStepId
			,@RetryAttempts = RetryAttempts
			,@RetryInterval = RetryInterval
			,@ProxyName = ProxyName
			,@Command = Command
	From @JobStepsTable
	Where StepId = @i_JobStepsTable;

	--Create the step
	BEGIN TRAN AddJobStep
		--If the step exists, remove it:
		IF EXISTS ( Select 1 From msdb.dbo.sysjobsteps where job_id = @jobId and (step_id = @StepId or step_name = @StepName))
		BEGIN
		PRINT 'INFO: A Job step match was found and will be deleted.'
		EXEC @ReturnCode = msdb.dbo.sp_delete_jobstep 
							 @job_id = @JobId
							,@step_id = @StepId;
		END
		IF (@@ERROR <> 0 OR @ReturnCode <> 0)
		BEGIN
			PRINT 'ERROR: An error occured while creating Job Step "' + @StepName + '". Rolling back now....';
			ROLLBACK TRAN AddJobStep;
			BREAK;
		END


		--For ssis jobs, need to update the environment reference id:
		IF(@StepType = 'SSIS')
		BEGIN
			--Using the server name, determine the environment reference:
			Declare @EnvironmentReferenceId int;
			
			PRINT 'INFO: Retriving the environment reference Id for the "$(EnvironmentReferenceName)" environment....';

			Select @EnvironmentReferenceId = er.reference_id
			From SSISDB.catalog.environment_references er
			Join SSISDB.catalog.projects p on p.project_id = er.project_id
			Join SSISDB.catalog.folders f on p.folder_id = f.folder_id
			where p.name = @SSISProjectName
			and	  f.name = @SSISFolderName
			and   er.environment_name = '$(EnvironmentReferenceName)';
			
			IF @EnvironmentReferenceId < 1
			BEGIN
				PRINT Concat('ERROR: Unable the retrieve the "$(EnvironmentReferenceName)" environment reference for SSIS Project "', @SSISProjectName,'" in the "',@SSISFolderName,'" folder');
				ROLLBACK TRAN AddJobStep;
				BREAK;
			END

			PRINT Concat('INFO: The "$(EnvironmentReferenceName)" environment reference for SSIS Project "', @SSISProjectName,'" in the "',@SSISFolderName,'" folder is: "',@EnvironmentReferenceId,'"');
			PRINT 'INFO: Updating dtexec-utility command...';
			PRINT Concat('INFO: OLD COMMAND::', @Command,'"');
			Set @Command = REPLACE(@Command, '{{EnvRefId}}', @EnvironmentReferenceId);
			PRINT Concat('INFO: NEW COMMAND::', @Command,'"');

		END

		EXEC @ReturnCode = msdb.dbo.sp_add_jobstep
							 @job_id=@jobId
							,@step_name=@StepName
							,@step_id=@StepId
							,@cmdexec_success_code=0
							,@on_success_action=@OnSuccessAction
							,@on_success_step_id=@OnSuccessStepId
							,@on_fail_action=@OnFailureAction
							,@on_fail_step_id=@OnFailureStepId
							,@retry_attempts=@RetryAttempts
							,@retry_interval=@RetryInterval
							,@os_run_priority=0, @subsystem=@StepType
							,@command=@Command
							,@database_name=N'master'
							,@flags=0;
		IF (@@ERROR <> 0 OR @ReturnCode <> 0)
		BEGIN
			PRINT 'ERROR: An error occured while creating Job Step "' + @StepName + '". Rolling back now....';
			ROLLBACK TRAN AddJobStep;
			BREAK;
		END
	COMMIT TRAN AddJobStep;

	--Increment by 1
	Set @i_JobStepsTable += 1;

	--Print( 'Completed the creation of'
	IF(@i_JobStepsTable = @i_JobStepsTableMax + 1)
	Break;
End
Go


-- Create a Job Schedule----------------------------------------------------------------------------------------------------------------------------------------------------
-- https://docs.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-add-schedule-transact-sql?view=sql-server-ver15
-- Creates a schedule that can be used by any number of jobs
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Declare  @ScheduleName sysname
		,@IsEnabled tinyint
		,@FrequencyType int /*[{1: once},{4 : Daily},{8 : Weekly},{16 : Monthly}, {32 : Monthly relative to the @FrequencyInterval}, {64 : Run when SQL Agent Service Starts}]*/
		,@FrequencyInterval int /*[{1 : once},{4 : Daily}, {8 : Weekly}, {16 : Monthly}, {32 : Monthly relative to @FrequencyInterval}, {64 : When SQLServerAgent service starts}, {128 : @FrequencyInterval is unused}]*/
		,@FrequencySubdayType int /*[{0x1 : At the specified time}, {0x4 : Minutes}, { 0x8 : Hours}]*/
		,@FrequencySubdayInterval int /*Number of frequency_subday_type periods to occur between each execution of the job*/
		,@FrequencyRelativeInterval int /*indicates the occurrence of the interval. For example, if frequency_relative_interval is set to 2, frequency_type is set to 32, and frequency_interval is set to 3, the scheduled job would occur on the second Tuesday of each month*/
		,@FrequencyRecurrenceFactor int /*Number of weeks or months between the scheduled execution of the job. frequency_recurrence_factor is used only if frequency_type is set to 8, 16, or 32. frequency_recurrence_factor is int, with a default of 0.*/
		,@ActiveStartDate int /*Date on which job execution can begin. Format is YYYYMMDD*/
		,@ActiveEndDate int /*Date on which job execution can stop. Format is YYYYMMDD*/
		,@ActiveStartTime int /*Time is formated as HHMMSS*/
		,@ActiveEndTime int /*Time is formated as HHMMSS*/
		,@ScheduleId int; /*Output*/

Declare @SQLServerAgentScheduleTable TABLE (
											  Id int PRIMARY KEY IDENTITY(1,1), ScheduleName sysname, IsEnabled tinyInt, FrequencyType int, FrequencyInterval int
											, FrequencySubdayType int, FrequencySubdayInterval int, FrequencyRelativeInterval int, FrequencyRecurrenceInterval int
											, FrequencyRecurrencyFactor int, ActiveStartDate int, ActiveEndDate int, ActiveStartTime int, ActiveEndTime int
										   );
BEGIN TRAN
	Insert @SQLServerAgentScheduleTable (ScheduleName, IsEnabled, FrequencyType, FrequencyInterval, FrequencySubdayType, FrequencySubdayInterval, FrequencyRelativeInterval, FrequencyRecurrenceInterval, FrequencyRecurrencyFactor, ActiveStartDate, ActiveEndDate, ActiveStartTime, ActiveEndTime)
								  Select ScheduleName, IsEnabled, FrequencyType, FrequencyInterval, FrequencySubdayType, FrequencySubdayInterval, FrequencyRelativeInterval, FrequencyRecurrenceInterval, FrequencyRecurrencyFactor, ActiveStartDate, ActiveEndDate, ActiveStartTime, ActiveEndTime
	From 
	(		   --ScheduleName, IsEnabled, FrequencyType, FrequencyInterval, FrequencySubdayType, FrequencySubdayInterval, FrequencyRelativeInterval, FrequencyRecurrenceInterval, FrequencyRecurrencyFactor, ActiveStartDate, ActiveEndDate, ActiveStartTime, ActiveEndTime
		Values ('Daily_Midnight_0000hrs',1, 8, 62, 1, 0, 0, 0, 1, 20200228, 99991231, 0, 235959)
			--,('Weekly_Monday_0500hrs',1, 8, 3, 1, 0, 0, 1, 0, 20200219, 99991231, 50000, 235959)
			--,('Monthly_SecondWednesday_0000hrs',1, 32, 4, 1, 0, 2, 0, 1, 20200219, 99991231, 0, 235959)
			--,('Monthly_LastWeekday_Every8hrs',1, 32, 9, 8, 8, 16, 0, 1, 20200219, 99991231, 0, 235959)
			--,('Name',0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
			--,('Name',0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
			--,('Name',0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
			--,('Name',0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
	) SQLServerAgentScheduleTable (ScheduleName, IsEnabled, FrequencyType, FrequencyInterval, FrequencySubdayType, FrequencySubdayInterval, FrequencyRelativeInterval, FrequencyRecurrenceInterval, FrequencyRecurrencyFactor, ActiveStartDate, ActiveEndDate, ActiveStartTime, ActiveEndTime);
	-- Select * From @SQLServerAgentScheduleTable

	Select   @ScheduleName = ScheduleName
			,@IsEnabled = IsEnabled
			,@FrequencyType = FrequencyType
			,@FrequencyInterval = FrequencyInterval
			,@FrequencySubdayType = FrequencySubdayType
			,@FrequencySubdayInterval = FrequencySubdayInterval
			,@FrequencyRelativeInterval = FrequencyRelativeInterval
			,@FrequencyRecurrenceFactor = FrequencyRecurrencyFactor
			,@ActiveStartDate = ActiveStartDate
			,@ActiveEndDate = ActiveEndDate
			,@ActiveStartTime = ActiveStartTime
			,@ActiveEndTime = ActiveEndTime
	From @SQLServerAgentScheduleTable

	Declare  @i_SQLServerAgentScheduleTable int = 0
			,@i_SQLServerAgentScheduleTableMax int = (Select Max(Id) From @SQLServerAgentScheduleTable)

	While (@i_SQLServerAgentScheduleTable < @i_SQLServerAgentScheduleTableMax)
	BEGIN
		SET @i_SQLServerAgentScheduleTable += 1;
		PRINT Concat('INFO: Creating Agent Schedule ', @i_SQLServerAgentScheduleTable, ' of ', @i_SQLServerAgentScheduleTableMax, '...' );
		SET @i_SQLServerAgentScheduleTable += 1;
		CheckIfScheduleExists:
			IF Exists (Select * From msdb.dbo.sysschedules Where name = @ScheduleName)
			BEGIN
				PRINT concat('INFO: A schedule with the same name "', @ScheduleName, '" currently exists and will be dropped...');
				Declare @ReturnCode int = 200;
				Select @ScheduleId = schedule_id From msdb.dbo.sysschedules Where name = @ScheduleName;

				Exec @ReturnCode = msdb.dbo.sp_delete_schedule @schedule_id = @ScheduleId, @force_delete = 1;
				IF(@ReturnCode = 0)
				PRINT concat('INFO: Successfully deleted Server Agent schedule "', @ScheduleName,'"');
				ELSE IF (@ReturnCode = 1 OR @@ERROR <> 0)
				BEGIN
					PRINT CONCAT('ERROR: An error occured while trying to delete Server Agent schedule: "', @ScheduleName,'"');
					ROLLBACK;
					BREAK;
				END
				GOTO CheckIfScheduleExists
			END

		Exec msdb.dbo.sp_add_schedule
			 @schedule_name=@ScheduleName
			,@enabled=@IsEnabled
			,@freq_type=@FrequencyType
			,@freq_interval=@FrequencyInterval
			,@freq_subday_type=@FrequencySubdayType
			,@freq_subday_interval=@FrequencySubdayInterval
			,@freq_relative_interval=@FrequencyRelativeInterval
			,@freq_recurrence_factor=@FrequencyRecurrenceFactor
			,@active_start_date=@ActiveStartDate
			,@active_end_date=@ActiveEndDate
			,@active_start_time=@ActiveStartTime
			,@active_end_time=@ActiveEndTime
			,@schedule_id = @ScheduleId OUTPUT
	END
	IF (@@ERROR <> 0)
	BEGIN
		PRINT CONCAT('ERROR: An error occured while creating schedule: "', @ScheduleName,'"');
		ROLLBACK;
	END
COMMIT TRAN

-- Assign a schedule to the job:
-- https://docs.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-attach-schedule-transact-sql?view=sql-server-ver15
--Creates a SQL Server Agent Job Schedule
-- Either Job ID or Name can be specified, but not both...
GO

BEGIN
	Declare  @ReturnCode int
			,@JobName sysname = 'LoadDataCatalog'
			,@ScheduleName sysname = 'Daily_Midnight_0000hrs';

	--If the job is already attached to the schedule, do nothing
	IF EXISTS(
				Select 1
				From msdb.dbo.sysjobschedules js
				Join msdb.dbo.sysjobs j on js.job_id = j.job_id
				Join msdb.dbo.sysschedules s on s.schedule_id = js.schedule_id
				where j.name = @JobName and s.name = @ScheduleName
			 )
	BEGIN
		Print Concat('INFO: Job "',@JobName, '" is already attached to the "', @ScheduleName, '"...');
	END
	ELSE 
	BEGIN
		Exec @ReturnCode = msdb.dbo.sp_attach_schedule @job_name = @JobName
													  ,@schedule_name = @ScheduleName;

		IF(@@ERROR <> 0 OR @ReturnCode <> 0)
		BEGIN
			Print CONCAT('ERROR: An Error Occured while attaching the job to the schedule. The Error Code returned is ', @ReturnCode);
		END
		ELSE
		BEGIN
			Print Concat('SUCCESS: The "', @JobName , '" job was successfully attached to the "', @ScheduleName,'" schedule.')
		END
	END
END

GO

SET NOCOUNT OFF;







/**
-- Validate the Package:--------------------------------------------------------------------------------------------------------------------------------
-- https://docs.microsoft.com/en-us/sql/integration-services/system-stored-procedures/catalog-validate-package-ssisdb-database?view=sql-server-ver15
-- https://docs.microsoft.com/en-us/sql/integration-services/system-views/catalog-validations-ssisdb-database?view=sql-server-ver15

Declare	 @FolderName nvarchar(128) = N'Migration'
		,@ProjectName nvarchar(128) = N'DataCatalog'
		,@PackageName nvarchar(260) = N'LoadDataCatalog.dtsx'
		,@ValidationId bigint
		,@Use32BitRunTime bit = 1
		,@EnvironmentScope char(1) = 'A'; --[{A: All environments}, {D: No environment. Use default value}]
EXEC SSISDB.catalog.validate_package @folder_name = @FolderName  
									,@project_name = @ProjectName  
									,@package_name = @PackageName  
									,@validation_id = @ValidationId OUTPUT  
									,@use32bitruntime = @Use32BitRunTime
									,@environment_scope = @EnvironmentScope

--Save the ValidationID in an execution Context Variable
Exec sp_set_session_context @Key = N'ValidationId', @Value = @ValidationId;
PRINT CONCAT('Validation ID = ' , @ValidationId); --40272
GO


--Get the lastest validation ID from 
DECLARE @PackageName nvarchar(260) = N'LoadDataCatalog.dtsx';
Declare @ValidationStatus int = (Select status From SSISDB.catalog.validations Where validation_id = SESSION_CONTEXT(N'ValidationId'));

DECLARE @ValidationMessagesTable TABLE 
(
	 Id int IDENTITY(1,1)
	,[Time] DateTimeOffSet
	,[Message] nvarchar(max)
);
--Select * From SSISDB.catalog.validations Where validation_id = 40274
--Because this is an async call, need to await...
While ( @ValidationStatus IN (1,2,5)) --statuses see https://docs.microsoft.com/en-us/sql/integration-services/system-views/catalog-validations-ssisdb-database?view=sql-server-ver15
BEGIN
	
	Print CONCAT('Validation of "' , @PackageName , '" [Execution Id:',CONVERT(nvarchar(128), SESSION_CONTEXT(N'ValidationId')),'is in progress with a status ID of "',@ValidationStatus,'"...');
	Set @ValidationStatus = (Select status From SSISDB.catalog.validations Where validation_id = SESSION_CONTEXT(N'ValidationId'))
END


--Populate the Table Variable created for validation messages:
Insert @ValidationMessagesTable (Time, Message)
Select MSG.message_time, MSG.message
FROM ssisdb.catalog.operation_messages MSG
Inner Join  ssisdb.catalog.operations OPR ON OPR.operation_id = MSG.operation_id
	WHERE MSG.message_type In (120,130)
And MSG.operation_id = @ValidationId

--Print 
Declare @i_ValidationMessagesTable int = 1
	   ,@Time DateTimeOffSet 
	   ,@Message nvarchar(max) = N'';

While (@i_ValidationMessagesTable < (Select Max(Id) From @ValidationMessagesTable) )
BEGIN
	SELECT @Time = [Time]
		  ,@Message = [Message]
	FROM @ValidationMessagesTable
	Where Id = @i_ValidationMessagesTable

	PRINT Concat('ERROR: >', @Time, ' > ',@Message);
	SET @i_ValidationMessagesTable += 1;
END

--SELECT      
--			  OPR.object_name PackageName
--            , MSG.message_time Time
--            , MSG.message Message
--			, OPR.caller_name CallerName
--			, OPR.server_name ServerName, *
--FROM        ssisdb.catalog.operation_messages  AS MSG
--INNER JOIN  ssisdb.catalog.operations          AS OPR
--    ON      OPR.operation_id            = MSG.operation_id
--WHERE       MSG.message_type            IN (120,130)
--And MSG.operation_id = 40273-- @ValidationId

--Declare @s xml;
--SELECT     @s = CONCAT( 
--			  OPR.object_name 
--            , MSG.message_time 
--            , MSG.message 
--			, OPR.caller_name 
--			, OPR.server_name )
--FROM        ssisdb.catalog.operation_messages  AS MSG
--INNER JOIN  ssisdb.catalog.operations          AS OPR
--    ON      OPR.operation_id            = MSG.operation_id
--WHERE       MSG.message_type            IN (120,130)

--PRINT @s
**/

--Checking$25,292.05;

--Savings $74,120.80;
