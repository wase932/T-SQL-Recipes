-- Assign a schedule to the job:
-- https://docs.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-attach-schedule-transact-sql?view=sql-server-ver15
--Creates a SQL Server Agent Job Schedule
-- Either Job ID or Name can be specified, but not both...

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