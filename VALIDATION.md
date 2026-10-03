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

- Autenticación y persistencia con usuarios reales: requiere alta de administradoras.
- Importación de los 1.605 registros reales: archivo no disponible.
- Publicación web: alojamiento pendiente. El código ya está en GitHub (ctn1470/CORE-Equestrian), separado de Mercado Casa.
- Registro en menos de 20 segundos por Mariana/Cristina en una jornada real: requiere prueba del piloto.

No considerar esta entrega como producción habilitada hasta completar esos puntos.

## Supabase conectado

- Proyecto independiente CORE-Equestrian: crcriztfrcgzoxikeqbs.
- Esquema instalado mediante SQL Editor, con respuesta Success.
- Suite isolation.sql ejecutada sin errores, rollback incluido.
- Verificación: 10 tablas públicas, todas con RLS; 0 funciones SECURITY DEFINER públicas.
- Organizaciones, histórico y usuarios después de las pruebas: 0 / 0 / 0.
- Admin Cristina: correo confirmado por el usuario; Mariana pendiente.
- No se modificó Mercado Casa ni se activaron planes de pago.

- Suite SQL repetida después de aplicar advisor-improvements.sql: pasó.
- Invitación a Cristina enviada por Supabase y membresía admin configurada en MA Dressage.
- App local conectada con clave publicable; pantalla de login visible.
- 18 pruebas locales pasan, incluidas activación de invitación y envío de actualización de contraseña mediante PUT.
- Login real, creación de contraseña por Cristina y persistencia operativa aún pendientes.
- Advertencia del asesor: protección de contraseñas filtradas requiere Pro; no se activó pago. Índices nuevos todavía sin uso.
