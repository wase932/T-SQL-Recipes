-- Start a Job:
-- https://docs.microsoft.com/en-us/sql/relational-databases/system-stored-procedures/sp-start-job-transact-sql?view=sql-server-2016
-- Starts a job 
-- Either Job ID or Name can be specified, but not both...

BEGIN
	Declare  @ReturnCode int
			,@JobName sysname = 'LoadDataCatalog';

	--If the job does not exist, exit
	IF NOT EXISTS( Select 1 From msdb.dbo.sysjobs j where name =  @JobName )
	BEGIN
		RAISERROR('The Job does not exist', 18, -1)
		Print CONCAT('ERROR: Job "',@JobName, '" does not exist. Aborting execution...""...');
		RETURN;
	END

	ELSE 
	--Check if the Job is currently running. If it is, stop it
	IF EXISTS (
				SELECT
					job.name, 
					job.job_id, 
					job.originating_server, 
					activity.run_requested_date, 
					DATEDIFF( SECOND, activity.run_requested_date, GETDATE() ) as Elapsed
				FROM msdb.dbo.sysjobs_view job
				JOIN msdb.dbo.sysjobactivity activity
				ON job.job_id = activity.job_id
				JOIN msdb.dbo.syssessions sess
				ON sess.session_id = activity.session_id
				JOIN
				(
					SELECT MAX( agent_start_date ) AS max_agent_start_date
					FROM msdb.dbo.syssessions
				) sess_max
				ON sess.agent_start_date = sess_max.max_agent_start_date
				WHERE run_requested_date IS NOT NULL AND stop_execution_date IS NULL
				And job.name = @JobName
				)
	BEGIN
		Print CONCAT('INFO: SQL Agent Job "',@JobName, '"is currently running and will be stopped...');
		Exec @ReturnCode = msdb.dbo.sp_stop_job @JobName;
		PRINT 'Stopping job...';
		WAITFOR DELAY '00:00:02'; --wait for 2 seconds in an attempt to stop the job
	END

	--Check again if the Job is currently running. If it is, stop it
	CHECKIFJOBISRUNNING:
	IF EXISTS (
				SELECT
					job.name, 
					job.job_id, 
					job.originating_server, 
					activity.run_requested_date, 
					DATEDIFF( SECOND, activity.run_requested_date, GETDATE() ) as Elapsed
				FROM msdb.dbo.sysjobs_view job
				JOIN msdb.dbo.sysjobactivity activity
				ON job.job_id = activity.job_id
				JOIN msdb.dbo.syssessions sess
				ON sess.session_id = activity.session_id
				JOIN
				(
					SELECT MAX( agent_start_date ) AS max_agent_start_date
					FROM msdb.dbo.syssessions
				) sess_max
				ON sess.agent_start_date = sess_max.max_agent_start_date
				WHERE run_requested_date IS NOT NULL AND stop_execution_date IS NULL
				And job.name = @JobName
				)
	BEGIN
		PRINT CONCAT('WARNING: SQL Agent Job "',@JobName, '"is still running, despite an attempt to stop it.');
		PRINT('INFO: Pausing execution for 2 seconds while Job is being stoped...');
		WAITFOR DELAY '00:00:02';
		GOTO CHECKIFJOBISRUNNING;
	END

	--Start the Job
	BEGIN
		Print CONCAT('INFO: Starting execution of SQL Agent Job "',@JobName, '"...');
		EXEC @ReturnCode = msdb.dbo.sp_start_job @JobName;

		IF(@@ERROR <> 0 OR @ReturnCode <> 0)
		BEGIN
			Print CONCAT('ERROR: An Error Occured while trying to execute the Job "',@JobName, '"');
		END
		ELSE
		BEGIN
			Print CONCAT('SUCCESS: Job "', @JobName , '" is now running...');
		END
	END
END

GO