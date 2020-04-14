USE [master]
GO
------------------------------------------------
--Author: Tolu Adepoju
--Date: 02-22-2018
--Description:
--Creates a linked server for fetching data off the active directory (AD)
--Dependencies: Note that objects cannot be seen, refer to BIProd.dbo.usp_table_DCSEmailAccounts for implementation
-----------------------------------------------

/****** Object:  LinkedServer [AD]    Script Date: 2/22/2018 1:24:37 PM ******/
EXEC master.dbo.sp_dropserver @server=N'AD', @droplogins='droplogins'
GO

/****** Object:  LinkedServer [AD]    Script Date: 2/22/2018 1:24:37 PM ******/
EXEC master.dbo.sp_addlinkedserver @server = N'AD', @srvproduct=N'Active Direcotry Service Interface', @provider=N'ADsDSOObject', @datasrc=N'adsdatasource', @provstr=N'ADSDSOObject'
 /* For security reasons the linked server remote logins password is changed with ######## */
EXEC master.dbo.sp_addlinkedsrvlogin @rmtsrvname=N'AD',@useself=N'False',@locallogin=NULL,@rmtuser=N'DCS\D040850',@rmtpassword='########'

GO

EXEC master.dbo.sp_serveroption @server=N'AD', @optname=N'collation compatible', @optvalue=N'false'
GO

EXEC master.dbo.sp_serveroption @server=N'AD', @optname=N'data access', @optvalue=N'true'
GO

EXEC master.dbo.sp_serveroption @server=N'AD', @optname=N'dist', @optvalue=N'false'
GO

EXEC master.dbo.sp_serveroption @server=N'AD', @optname=N'pub', @optvalue=N'false'
GO

EXEC master.dbo.sp_serveroption @server=N'AD', @optname=N'rpc', @optvalue=N'false'
GO

EXEC master.dbo.sp_serveroption @server=N'AD', @optname=N'rpc out', @optvalue=N'false'
GO

EXEC master.dbo.sp_serveroption @server=N'AD', @optname=N'sub', @optvalue=N'false'
GO

EXEC master.dbo.sp_serveroption @server=N'AD', @optname=N'connect timeout', @optvalue=N'0'
GO

EXEC master.dbo.sp_serveroption @server=N'AD', @optname=N'collation name', @optvalue=null
GO

EXEC master.dbo.sp_serveroption @server=N'AD', @optname=N'lazy schema validation', @optvalue=N'false'
GO

EXEC master.dbo.sp_serveroption @server=N'AD', @optname=N'query timeout', @optvalue=N'0'
GO

EXEC master.dbo.sp_serveroption @server=N'AD', @optname=N'use remote collation', @optvalue=N'true'
GO

EXEC master.dbo.sp_serveroption @server=N'AD', @optname=N'remote proc transaction promotion', @optvalue=N'true'
GO


