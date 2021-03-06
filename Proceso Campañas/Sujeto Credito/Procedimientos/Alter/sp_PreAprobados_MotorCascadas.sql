USE [BD_CAMPANIAS]
GO
/****** Object:  StoredProcedure [dbo].[sp_PreAprobados_MotorCascadas]    Script Date: 21/11/2016 11:41:51 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
ALTER PROCEDURE [dbo].[sp_PreAprobados_MotorCascadas]
	@Periodo int, 
	@Segmento Varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @Nombre_Filtro NVARCHAR(500), @Fuente_Filtro NVARCHAR(500), @Orden_Filtro INT, @SQL NVARCHAR(max), @Filtros_Acumulados NVARCHAR(MAX) = N'', @Perstring NVARCHAR(6), @CantPasan int, @CantCaen int

	DECLARE ValCascada_Cursor CURSOR FOR   
	SELECT Nombre_Filtro, Fuente_Filtro, Orden 
	FROM TabCmp_Cascadas_Filtro
	WHERE Segmento = @Segmento
	ORDER BY Orden asc;


	PRINT N'Creando segmentos' 
	Create table #Segtos (Segment varchar(50))
	IF (@Segmento <> 'Pensionados')
	BEGIN
		insert into #Segtos values ('Privados'), ('Publicos');
	END
	ELSE
	BEGIN
		insert into #Segtos values ('Pensionados');
	END

	PRINT N'--Limpieza de registros' 
	PRINT N'----Resumen' 
	delete from TabCmp_ResumenCascada
	where Periodo = @Periodo
	and Segmento = @Segmento
	
	PRINT N'----Universo'
	update TabCmp_UniversoAfiliados
	set Filtro = null
	where Segmento IN (SELECT Segment FROM #Segtos)
	AND Periodo = @Periodo

	PRINT N'----UCascadas'
	TRUNCATE TABLE BD_CAMPANIAS.dbo.TabCmp_UniversoAfiliadosCascadas
	INSERT INTO BD_CAMPANIAS.dbo.TabCmp_UniversoAfiliadosCascadas
	SELECT *  
	FROM BD_CAMPANIAS.dbo.TabCmp_UniversoAfiliados a
	LEFT JOIN TabCmp_Maestra_Creditos b on a.afiliado_rut=b.Rut_Afiliado 
	WHERE Periodo = @Periodo
	AND Segmento IN (SELECT Segment FROM #Segtos)
	
	PRINT N'----UCascadasIntercaja'
	TRUNCATE TABLE BD_CAMPANIAS.dbo.TabCmp_UniversoAfiliadosIntercajaCascadas
	INSERT INTO BD_CAMPANIAS.dbo.TabCmp_UniversoAfiliadosIntercajaCascadas
	SELECT *  
	FROM BD_CAMPANIAS.dbo.TabCmp_UniversoAfiliados_Intercaja a
	WHERE Periodo = @Periodo
	AND Segmento IN (SELECT Segment FROM #Segtos)
	
	PRINT N'----UCascadasDuplicados'
	TRUNCATE TABLE BD_CAMPANIAS.dbo.TabCmp_UniversoAfiliadosRutDuplicadosCascadas
	INSERT INTO BD_CAMPANIAS.dbo.TabCmp_UniversoAfiliadosRutDuplicadosCascadas
	SELECT 
			Periodo
			,Afiliado_Rut
			,Empresa_Rut 
			,Segmento
	FROM (
		SELECT *,
			ROW_NUMBER() over(partition by Afiliado_Rut Order By PreAprobadoFinal asc) rnk 
		FROM TabCmp_UniversoAfiliados A
		WHERE Periodo = @Periodo
		AND PreAprobadoFinal > 0
		AND Segmento IN (SELECT Segment FROM #Segtos)
	) T
	WHERE rnk > 1

	PRINT N'----Creditos comprados'
	truncate table BD_CAMPANIAS.dbo.TabCmp_CreditosCompradosCascadas
	insert into BD_CAMPANIAS.dbo.TabCmp_CreditosCompradosCascadas
	Select Left(RUT_AFILIADO,LEN(RUT_AFILIADO)-2)  Rut
	From BD_ODS..TabCred_Flujo_Colocaciones
	Where Left(FECHA_EJECUCION,6) in(@Periodo-1)
	And ESTADO=30
	And ESTADO_DESEMBOLSO=120
	And MARCA_REN_REP not in ('REPROGRAMACION')
	And Left(FECHA_COLOCACION,6) in(@Periodo-1)
	

	PRINT N'----Seteando castigados'
	UPDATE BD_CAMPANIAS.dbo.TabCmp_UniversoAfiliadosCascadas
	SET ind_castigo = 1
	WHERE afiliado_rut in (select distinct Rut_Afiliado from TabCmp_MaestraCreditosMorosos)

	OPEN ValCascada_Cursor
	FETCH NEXT FROM ValCascada_Cursor
	INTO @Nombre_Filtro, @Fuente_Filtro, @Orden_Filtro

	WHILE @@FETCH_STATUS = 0  
	BEGIN
	PRINT N'---------------------------------------------------------------------------------------------------------' 
		PRINT N'Procesando Filtro ' + @Fuente_Filtro
		TRUNCATE TABLE BD_CAMPANIAS.dbo.TabCmp_TemporalMotorCascadas
		SET @SQL = N'INSERT INTO BD_CAMPANIAS.dbo.TabCmp_TemporalMotorCascadas
					SELECT *  
					FROM BD_CAMPANIAS.dbo.TabCmp_UniversoAfiliadosCascadas UAC
					WHERE ' + @Fuente_Filtro

		EXEC(@SQL)


		SELECT @CantCaen = COUNT(1) 
		FROM TabCmp_UniversoAfiliados a
		WHERE NOT EXISTS (SELECT  * FROM TabCmp_TemporalMotorCascadas xy WHERE a.Afiliado_Rut = xy.Afiliado_Rut and a.Empresa_Rut = xy.Empresa_Rut)
		AND a.Segmento IN (SELECT Segment FROM #Segtos)
		AND a.Periodo = @Periodo
		And a.Filtro IS NULL
		PRINT N'CAEN: ' + CONVERT(VARCHAR(20),@CantCaen)


		SELECT @CantPasan = COUNT(1) 
		FROM TabCmp_TemporalMotorCascadas
		PRINT N'Pasan: ' + CONVERT(VARCHAR(20),@CantPasan) 

		UPDATE a
		SET a.Filtro = CONVERT(NVARCHAR(2),@Orden_Filtro) + '.- ' + @Nombre_Filtro
		FROM TabCmp_UniversoAfiliados a
		WHERE NOT EXISTS (SELECT  * FROM TabCmp_TemporalMotorCascadas xy WHERE a.Afiliado_Rut = xy.Afiliado_Rut and a.Empresa_Rut = xy.Empresa_Rut)
		AND a.Segmento IN (SELECT Segment FROM #Segtos)
		AND a.Periodo = @Periodo
		AND a.Filtro IS NULL
		PRINT N'Universo Actualizado con filtro' 
		

		INSERT INTO TabCmp_ResumenCascada
		VALUES(
			@Periodo,
			@Segmento,
			@CantPasan,
			CONVERT(NVARCHAR(2),@Orden_Filtro) + '.- ' + @Nombre_Filtro,
			@CantCaen
		)
		PRINT N'Resumen Actualizado con filtro' 


		DELETE FROM BD_CAMPANIAS.dbo.TabCmp_UniversoAfiliadosCascadas
		WHERE NOT EXISTS (SELECT  * FROM TabCmp_TemporalMotorCascadas xy WHERE BD_CAMPANIAS.dbo.TabCmp_UniversoAfiliadosCascadas.Afiliado_Rut = xy.Afiliado_Rut and BD_CAMPANIAS.dbo.TabCmp_UniversoAfiliadosCascadas.Empresa_Rut = xy.Empresa_Rut)
		PRINT N'Residuos eliminados' 


		FETCH NEXT FROM ValCascada_Cursor
		INTO @Nombre_Filtro, @Fuente_Filtro, @Orden_Filtro

	END 
	CLOSE ValCascada_Cursor;  
	DEALLOCATE ValCascada_Cursor; 

	PRINT N'Proceso Terminado'

END
