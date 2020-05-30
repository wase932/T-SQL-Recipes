
--Job history
;With base as
(
select  sj.name JobName
,c.name JobCategory
,sj.description JobDescription
,sh.server ServerName
,Max(sj.date_created) OVER (Partition By sj.job_id) MostRecentRun
,Case sh.run_status When 0 Then 'Failed' 
					When 1 then 'Succeeded'
					When 2 then 'Retry'
					When 3 then 'Canceled'
					When 4 then 'In Progress'
					Else 'Unknown'
					End JobOutcome
,COUNT(*) Over (Partition By sj.job_id) TotalNumberOfRuns
,SUM(IIF(run_status = 1, 1, 0)) Over (Partition By sj.job_id) TotalNumberOfSuccessfulRuns
,((sh.run_duration/10000*3600 + (sh.run_duration/100)%100*60 + sh.run_duration%100 + 31 ) / 60) RunDurationMinutes
,ISNULL(AVG(IIF(run_status = 1, ((sh.run_duration/10000*3600 + (sh.run_duration/100)%100*60 + sh.run_duration%100 + 31 ) / 60), null)) Over (Partition By sj.job_id), 0) AverageDurationOfSuccessfulRunsMinutes
,Round(cast((SUM(IIF(run_status = 1, 1, 0)) Over (Partition By sj.job_id)) as float) / cast((COUNT(*) Over (Partition By sj.job_id)) as float), 2) SuccessfulPercentage
FROM msdb.dbo.sysjobs sj
JOIN msdb.dbo.sysjobhistory sh
ON sj.job_id = sh.job_id
JOIN msdb.dbo.syscategories c on sj.category_id = c.category_id
where step_id = 0
)
,Base2
as 
(
Select ROW_NUMBER() OVER (Partition by JobName Order By MostRecentRun Desc) RowNo, *
From Base b
)
Select *
From Base2 Where RowNo = 1
