
DECLARE @dbname VARCHAR(50);
DECLARE @rolename VARCHAR(50) = N'db_executor'; --Role Name
DECLARE @rights VARCHAR(50) = N'EXECUTE'; --Name of rights to grant to role


DECLARE @sql NVARCHAR(max)

DECLARE db_cursor CURSOR 
LOCAL FAST_FORWARD
FOR  
select d.name DatabaseName
from sys.databases d
Where d.name NOT IN ('master','model','msdb','tempdb','distribution')  --Databases to exclude
Order by DatabaseName
OPEN db_cursor  
FETCH NEXT FROM db_cursor INTO @dbname 
WHILE @@FETCH_STATUS = 0  
BEGIN  

	SELECT @sql = 'use ['+ @dbname +']; ' + 'CREATE ROLE [' + @rolename 
	+ ']; GRANT ' + @rights + ' TO [' + @rolename + '];'

	Print @sql
	BEGIN TRY
		exec sp_executesql @sql
	END TRY

	BEGIN CATCH 
		DECLARE @msg NVARCHAR(255);
			SET @msg = 'An error occurred: ' + ERROR_MESSAGE();
			PRINT @msg
	END CATCH

	FETCH NEXT FROM db_cursor INTO @dbname 

END  
CLOSE db_cursor  
DEALLOCATE db_cursor
GO
