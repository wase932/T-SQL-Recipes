/*
Post-Deployment Script Template							
--------------------------------------------------------------------------------------
 This file contains SQL statements that will be appended to the build script.		
 Use SQLCMD syntax to include a file in the post-deployment script.			
 Example:      :r .\myfile.sql								
 Use SQLCMD syntax to reference a variable in the post-deployment script.		
 Example:      :setvar TableName MyTable							
               SELECT * FROM [$(TableName)]					
--------------------------------------------------------------------------------------
*/

SET NOCOUNT ON;
--SQL Agent:
:r .\SQLServerAgent\schedules.sql
:r .\SQLServerAgent\environments.sql
GO

--SSISDB Packages:
:r .\SQLServerAgent\SSISDB\Migration\SQLServerAgent.SSISDB.Migration.DataCatalog.LoadDataCatalog.sql
GO

--SQL Agent Jobs:
--LoadDataCatalog
:r .\SQLServerAgent\Jobs\LoadDataCatalog\01EnvironmentReference.sql
:r .\SQLServerAgent\Jobs\LoadDataCatalog\02EnvironmentVariables.sql
:r .\SQLServerAgent\Jobs\LoadDataCatalog\03Job.sql
:r .\SQLServerAgent\Jobs\LoadDataCatalog\04JobSchedule.sql
GO
SET NOCOUNT OFF;