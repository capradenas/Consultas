USE [BD_CAMPANIAS]
GO
/****** Object:  StoredProcedure [dbo].[sp_PreAprobados_CargaMaestroCreditos]    Script Date: 21/11/2016 11:41:31 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[sp_PreAprobados_CargaMaestroCreditos]
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	-- select * from [dbo].[TabCmp_MaestraCreditosMorosos]

	
	--if OBJECT_ID('BD_CAMPANIAS..TabCmp_MaestraCreditos') is not null Drop Table TabCmp_Maestra_Creditos
   
   truncate table TabCmp_Maestra_Creditos

   insert into TabCmp_Maestra_Creditos
   select 
	 Rut_Afiliado
	,SUM(monto_total_cuota) SumaCoutas
	,MAX(Fecha_Colocacion) max_fecha_desembolso
	,COUNT(Folio_Antig_Credito) cantidad_creditos
	,Max(Meses_Morosos) Meses_Morosos
	,case when sum(K_Efectivo)<>sum(K_Calculado) and sum(K_Calculado) > 0 then sum(K_Calculado) else  sum(K_Efectivo) end Capital_adeudado
	,case when MAX(castigo)='' then 0 when MAX(castigo)='X' then 1 end ind_castigo
	from BD_ODS..TabCred_MaestroCreditos 
	where Periodo = (select MAX(periodo) from BD_ODS..TabCred_MaestroCreditos) 
	and Estado=30 
	and Tipo_Producto in ('C_SOCIAL', 'C_EDUCA' )  -- C_EXTINC, CTA_CTE_EM
	and Desembolso<>'NO Existe'
	and Tipo_Financiamiento not in ('Intermediado','Intermediado')
	and (case when K_calculado<>K_Efectivo and K_Calculado>0 then K_Calculado else K_Efectivo end)>0
	group by Rut_Afiliado



		truncate table TabCmp_MaestraCreditosMorosos
		
		insert into TabCmp_MaestraCreditosMorosos
		select		Rut_Afiliado
				   ,SUM(monto_total_cuota) SumaCoutas
				   ,MAX(Fecha_Colocacion) max_fecha_desembolso
				   ,COUNT(Folio_Antig_Credito) cantidad_creditos
				   ,Max(Meses_Morosos) Meses_Morosos
				   ,case when sum(K_Efectivo)<>sum(K_Calculado) and sum(K_Calculado) > 0 then sum(K_Calculado) else  sum(K_Efectivo) end Capital_adeudado
				   ,1 ind_castigo
       from BD_ODS..TabCred_MaestroCreditos a
       inner join serv_265.RSG_ODS.dbo.TabCre_CastigosSuseso b ON a.Folio_Credito = b.FolioCredito
       where Periodo = (select MAX(periodo) from BD_ODS..TabCred_MaestroCreditos) 
	   and Rut_Afiliado not in (select Rut_Afiliado from TabCmp_MaestraCreditosMorosos)
       group by Rut_Afiliado



	   insert into TabCmp_MaestraCreditosMorosos
	   select 
	 Rut_Afiliado
	,SUM(monto_total_cuota) SumaCoutas
	,MAX(Fecha_Colocacion) max_fecha_desembolso
	,COUNT(Folio_Antig_Credito) cantidad_creditos
	,Max(Meses_Morosos) Meses_Morosos
	,case when sum(K_Efectivo)<>sum(K_Calculado) and sum(K_Calculado) > 0 then sum(K_Calculado) else  sum(K_Efectivo) end Capital_adeudado
	,case when MAX(castigo)='' then 0 when MAX(castigo)='X' then 1 end ind_castigo
	from BD_ODS..TabCred_MaestroCreditos 
	where Periodo = (select MAX(periodo) from BD_ODS..TabCred_MaestroCreditos) 
	and Estado=30 
	and Tipo_Producto in ('C_SOCIAL', 'C_EDUCA' )  -- C_EXTINC, CTA_CTE_EM
	and Desembolso<>'NO Existe'
	and Tipo_Financiamiento not in ('Intermediado','Intermediado')
	and (case when K_calculado<>K_Efectivo and K_Calculado>0 then K_Calculado else K_Efectivo end)>0
	and Rut_Afiliado not in (select Rut_Afiliado from TabCmp_MaestraCreditosMorosos)
	group by Rut_Afiliado
	having MAX(Meses_Morosos)>1 OR MAX(castigo)='X';

	   
	   --exec sp_PreAprobados_CargaMaestroCreditos



END
