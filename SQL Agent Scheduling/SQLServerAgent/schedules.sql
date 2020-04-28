
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