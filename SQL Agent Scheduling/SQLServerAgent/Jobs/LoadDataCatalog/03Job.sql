-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
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
