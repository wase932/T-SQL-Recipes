---------------------------------------------------------------------------------------
--Create, and subsequently, add user to a database role in all databases on the server
---------------------------------------------------------------------------------------

DECLARE @dbname VARCHAR(50);
DECLARE @username VARCHAR(50);
DECLARE @rolename VARCHAR(50) = N'db_datareader'; --Role Name

DECLARE @sql NVARCHAR(max)

DECLARE db_cursor CURSOR 
LOCAL FAST_FORWARD
FOR  
select u.name UserName, d.name DatabaseName
from master.sys.server_principals u
cross join sys.databases d
Where u.type = 'U' --type of -principal
And u.name like 'DCS\%' --username pattern to include
And u.name not like 'DCS\svc.%' -- username pattern to exclude
And u.name not in ('DCS\D500873', 'DCS\D040850', 'DCS\D502941' ) --users to exclude
And d.name NOT IN ('master','model','msdb','tempdb','distribution')  --Databases to exclude
Order by UserName, DatabaseName
OPEN db_cursor  
FETCH NEXT FROM db_cursor INTO @username, @dbname 
WHILE @@FETCH_STATUS = 0  
BEGIN  

	SELECT @sql = 'use ['+ @dbname +'];'+ 'CREATE USER [' + @username 
	+ '] FOR LOGIN [' + @username 
	+ ']; EXEC sp_addrolemember N'''+ @rolename + ''', [' 
	+ @username + '];'

	Print @sql
	BEGIN TRY
		exec sp_executesql @sql
	END TRY

	BEGIN CATCH 
		DECLARE @msg NVARCHAR(255);
			SET @msg = 'An error occurred: ' + ERROR_MESSAGE();
			PRINT @msg
	END CATCH

	FETCH NEXT FROM db_cursor INTO @username, @dbname 

END  
CLOSE db_cursor  
DEALLOCATE db_cursor 
GO
