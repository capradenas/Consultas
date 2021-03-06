USE [BD_CAMPANIAS]
GO
/****** Object:  StoredProcedure [dbo].[sp_PreAprobados_01FusionRiesgoUniverso]    Script Date: 21/11/2016 11:40:06 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
--exec sp_PreAprobados_01FusionRiesgoUniverso 201612
ALTER PROCEDURE [dbo].[sp_PreAprobados_01FusionRiesgoUniverso]
	-- Add the parameters for the stored procedure here
	@Periodo int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @fechaLicencia varchar(10) =substring((Select CONVERT(varchar,SYSDATETIME(),126)),1,7)+'-01'


	if OBJECT_ID('BD_CAMPANIAS..TabCmp_AfiliadoLicencia') is not null Drop Table TabCmp_AfiliadoLicencia
	select Afiliado_Rut 
	into TabCmp_AfiliadoLicencia
	from BD_ODS..TabLic_Licencia 
	where substring(convert(varchar,Licencia_fFin,126),1,10) >= @fechaLicencia
	
	--Generar los maestros de creditos para la ejecucion del proceso
	exec sp_PreAprobados_CargaMaestroCreditos



	/*Volcar los datos de Riesgo en nuestro universo de afiliados [FUSION RIESGO + UNIVERSO]*/
	--Version de mes Diciembre 2016
	--Select * from BD_CAMPANIAS.dbo.TabCmp_DespuesRiesgo201612
	--OJO: falta un proceso que cargue la tabla TabCmp_PreAprobadosDespuesRiesgo que deberia ser antes de ejecutar este proceso
	
	UPDATE
    a
	SET
		a.RiesgoPerfil = isnull(b.Perfil_Priv,''),
		a.RiesgoMaxVecesRenta = isnull(b.veces_renta,0),
		a.RiesgoMaxPreAprobado = isnull(b.Max_oferta,0),
		a.RiesgoTieneOferta = b.OFERTA,
		a.RiesgoFiltro = b.Motivo_rechazo
		
	FROM
		BD_CAMPANIAS..TabCmp_UniversoAfiliados a
		--left join TabCmp_PreAprobadosDespuesRiesgo b ON a.Afiliado_Rut = b.afiliado_rut and a.Periodo=b.Periodo and a.Segmento = b.Segmento
		left join BD_CAMPANIAS.dbo.TabCmp_DespuesRiesgo201612 b ON a.Afiliado_Rut = b.afiliado_rut and a.Segmento = b.Segmento and a.Empresa_Rut = b.Empresa_Rut
		where a.Periodo=@periodo




	/*UNIVERSO AFILIADOS INTERCAJAS (NO CORRE PARA DICIEMBRE)
		Aqui solo se FUSIONAN los datos que envian desde RIESGO y se guarda en SujetoCredito_Intercaja
	*/
	--insert into BD_CAMPANIAS..TabCmp_SujetoCredito_InterCaja
	--select * , 0 vr, 0 paf
	--from TabCmp_UniversoAfiliados_Intercaja a
	----definir inner join que se hara cargo de traer los datos que salen de riesgo
	--where a.Periodo = @Periodo



	/** CALCULO DE MONTOS Y PRE APROBADOS FINALES PARA LOS AFILIADOS POR UNA PARTE ESTA EL PREAPROBADO DE RIESGO Y POR OTRA EL DE IA EL CON MENOR OFERTA SERA EL FINAL	
	*/
	/*Sin Credito*/
	UPDATE TabCmp_UniversoAfiliados 
	SET Monto_preaprobado = convert(NUMERIC, (
		case 
				when Segmento in ('Publicos') and Antiguedad_en_Meses <= 24 then ((round((MontoRenta*0.75),0)*0.25))*24
				when Segmento in ('Publicos') and Antiguedad_en_Meses > 24  then ((round((MontoRenta*0.75),0)*0.25))*60
				when Segmento in ('Privados') then ((round((MontoRenta*0.75),0)*0.25))*60 
	  end
	))
	WHERE Afiliado_Rut not in (select Rut_Afiliado from TabCmp_Maestra_Creditos)
	AND Periodo = @Periodo
	and RiesgoMaxPreAprobado is not null



	UPDATE TabCmp_UniversoAfiliados 
	SET Monto_preaprobado = (
				case 
						when Segmento <> 'Pensionados' and Monto_preaprobado > (round((MontoRenta*0.75),0)*RiesgoMaxVecesRenta) then (round((MontoRenta*0.75),0)*RiesgoMaxVecesRenta)
						when Segmento <> 'Pensionados' and Monto_preaprobado <= (round((MontoRenta*0.75),0)*RiesgoMaxVecesRenta) then Monto_preaprobado
						when Segmento = 'Pensionados' then isNull(dbo.fn_calculoMontoPreAprobadoPensionado(PensionadoFFAA,MontoPension,RiesgoMaxVecesRenta,0,0),0)
				end)
	WHERE Afiliado_Rut not in (select Rut_Afiliado from TabCmp_Maestra_Creditos)
	AND Periodo = @Periodo
	and RiesgoMaxPreAprobado is not null


	/*Con Credito*/
	UPDATE a
	SET Monto_preaprobado = (
			case 
				when Segmento in ('Publicos') and Antiguedad_en_Meses <= 24 then ((round((MontoRenta*0.75),0)*0.25)-b.SumaCoutas)*24
				when Segmento in ('Publicos') and Antiguedad_en_Meses > 24  then ((round((MontoRenta*0.75),0)*0.25)-b.SumaCoutas)*60
				when Segmento in ('Privados') then ((round((MontoRenta*0.75),0)*0.25)-b.SumaCoutas)*60 
			end)
	FROM		TabCmp_UniversoAfiliados a
	LEFT JOIN	TabCmp_Maestra_Creditos b on a.afiliado_rut=b.Rut_Afiliado
	WHERE Afiliado_Rut in (select Rut_Afiliado from TabCmp_Maestra_Creditos)
	AND Periodo = @Periodo
	and RiesgoMaxPreAprobado is not null



	UPDATE a
	SET Monto_preaprobado = (
			case 
				when Segmento <> 'Pensionados' and Monto_preaprobado+Capital_adeudado > (round((MontoRenta*0.75),0)*RiesgoMaxVecesRenta) then (round((MontoRenta*0.75),0)*RiesgoMaxVecesRenta)-Capital_adeudado
				when Segmento <> 'Pensionados' and Monto_preaprobado+Capital_adeudado <= (round((MontoRenta*0.75),0)*RiesgoMaxVecesRenta) then Monto_preaprobado
				when Segmento = 'Pensionados' then isNUll(dbo.fn_calculoMontoPreAprobadoPensionado(PensionadoFFAA,MontoPension,RiesgoMaxVecesRenta,SumaCoutas,capital_adeudado),0)
		end)
	FROM TabCmp_UniversoAfiliados a
	left join TabCmp_Maestra_Creditos b on a.afiliado_rut=b.Rut_Afiliado
	WHERE Afiliado_Rut in (select Rut_Afiliado from TabCmp_Maestra_Creditos)
	AND Periodo = @Periodo
	and RiesgoMaxPreAprobado is not null




	/* PreAprobado Final */
	UPDATE TabCmp_UniversoAfiliados
		SET
			PreAprobadoFinal = (
				CASE
					when isnull(Monto_preaprobado,0) < RiesgoMaxPreAprobado  then Monto_preaprobado 
					when isnull(Monto_preaprobado,0) >= RiesgoMaxPreAprobado  then RiesgoMaxPreAprobado
				END)
		WHERE Periodo=@Periodo 
		and RiesgoMaxPreAprobado is not null
		
		UPDATE TabCmp_UniversoAfiliados
		SET PreAprobadoFinal = (CASE 
									WHEN PreAprobadoFinal > 25000000 THEN 25000000
									ELSE PreAprobadoFinal
								 END)
		where Periodo=@Periodo 
		and RiesgoMaxPreAprobado > 0
		and RiesgoMaxPreAprobado is not null

END
