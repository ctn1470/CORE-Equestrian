# Validación del piloto local

Fecha: 3 de octubre de 2026.

## Ejecutado

- Pruebas automatizadas de normalización, actividades explícitas, alumno de Clase, fechas/horas, rangos de duración/calificación, plan independiente de ejecución y métricas.
- Validación de importación con 1.605 filas sintéticas en memoria: cuenta esperada, identificadores únicos, inferencia y ejecución desconocida. No es una importación del archivo real.
- Pruebas de doble ejecución, protección del plan ejecutado, cambios de programación con versión anterior, roles de consulta y carga paginada.
- App servida y abierta en el navegador.
- Programación sin hora de Caminar de tiro: Palafrenero seleccionado automáticamente, selector de jinete deshabilitado.
- Registro de Maestro programado como Trabajo/Cristina y ejecutado como Cuerda/Mariana: agenda e historial conservan ambos.
- Registro de Noor como no realizado con motivo; aparición correcta en historial y dashboard.
- Navegación a ficha y dashboard; cálculo de sesiones confirmadas y separación de trabajo/clases.
- Edición de una actividad pendiente a Paseo/Alicia y actualización correcta de la agenda.
- Revisión a 390 × 844 y escritorio: controles, navegación y ausencia de desbordamiento horizontal en agenda/ficha.

## Aún no verificado

- Migración SQL en PostgreSQL/Supabase, suite de aislamiento real, autenticación y persistencia remota: requieren proyecto conectado.
- Importación de los 1.605 registros reales: archivo no disponible.
- Publicación web: alojamiento pendiente. El código ya está en GitHub (ctn1470/CORE-Equestrian), separado de Mercado Casa.
- Registro en menos de 20 segundos por Mariana/Cristina en una jornada real: requiere prueba del piloto.

No considerar esta entrega como producción habilitada hasta completar esos puntos.
