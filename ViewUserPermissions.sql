create table #tempUserPermissions
(
 _Owner nvarchar(100)
,_Object nvarchar(100)
,_Grantee nvarchar(100)	
,_Grantor nvarchar(100)	
,_ProtectType nvarchar(100)	
,_Action	nvarchar(100)
,_Column nvarchar(100)
);

insert #tempUserPermissions
exec sp_MSforeachdb 'sp_helprotect';


select *
From #tempUserPermissions;
