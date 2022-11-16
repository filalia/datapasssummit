Create Schema DM
GO 

Create view DM.Product as 
select 
	P.ProductID ,
	P.Name,
	PC.Name as CategoryName

from [SalesLT].[Product] P 
inner join [SalesLT].[ProductCategory] PC 
	on PC.productCategoryID = P.ProductCategoryID 

GO 

Create view DM.Sales 
as 
Select 
	SH.SalesOrderID,
	SH.ORderDate,
	SH.OnlineOrderFlag,
	SH.SalesOrderNumber,
	SH.TotalDue,
	SD.ProductID,
	SD.OrderQty,
	SD.LineTotal

From [SalesLT].[SalesOrderHeader] SH
inner join [SalesLT].[SalesOrderDetail] SD 
	on SD.SalesOrderID = SH.SalesOrderID 
GO