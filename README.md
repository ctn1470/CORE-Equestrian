# CORE Equestrian · piloto MA Dressage

Web app móvil para Agenda → Ejecución → Historial, directorio/ficha del caballo y Dashboard. Preparada para un repositorio independiente en GitHub y un proyecto nuevo en Supabase.

## Estado real de esta entrega

- La app se ejecuta localmente con datos de demostración claramente identificados. Las modificaciones de demostración están en memoria y se reinician al recargar.
- El cliente de Supabase, la migración y el flujo de publicación están escritos. No se ha creado un repositorio remoto ni un proyecto Supabase porque sus conexiones aún no están habilitadas.
- La migración y las políticas requieren ejecución y pruebas en el proyecto nuevo antes de uso real. Las pruebas locales no acreditan por sí solas el aislamiento en PostgreSQL.
- Los 1.605 registros depurados y el modelo original no están disponibles en los archivos del proyecto ni como adjuntos en la conversación recuperada. El importador está preparado; no se inventaron ni importaron registros de WhatsApp.
- El sitio anterior permanece intacto. `sources/` permanece como referencia de solo lectura.

## Ejecutar

Requiere Node.js 22 o posterior. No requiere instalar paquetes.

```sh
node scripts/server.mjs
```

Abrir http://127.0.0.1:4173. Para comprobar y preparar los archivos de publicación:

```sh
node --test
node scripts/build.mjs
```

## Arquitectura

Interfaz web con módulos JavaScript estándar, HTML semántico, CSS responsive y navegación por fragmentos. No incorpora un servicio adicional ni depende de un CDN. Se puede alojar como web estática en el servicio que ya utiliza Mercado Casa.

`public/domain.js` contiene normalización, validación y métricas; `public/store.js` separa el modo demostración del acceso real a Supabase Auth y PostgREST; `public/app.js` contiene las pantallas; `supabase/migrations/` contiene el esquema y permisos versionados. Esta primera versión utiliza carga paginada de datos autorizados para el piloto. Antes de grandes volúmenes de clientes se moverán agregaciones y filtros al servidor para evitar descargar todo el historial.

## Conectar Supabase nuevo

1. Crear un proyecto nuevo dedicado a CORE Equestrian. No aplicar el SQL en Mercado Casa.
2. Aplicar `supabase/migrations/202610030001_core.sql` una vez. Guardar versiones posteriores como migraciones nuevas.
3. Invitar a las administradoras desde Supabase Auth. Confirmar sus correos e identidades reales.
4. Sustituir los dos correos de ejemplo en `supabase/bootstrap.sql` y ejecutarlo. Crea MA Dressage, las personas del equipo y sus dos membresías administrativas. No crea caballos con información inventada.
5. Configurar `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY` como variables del repositorio o del alojamiento. Solo usar clave pública publishable/anon; nunca service_role ni sb_secret en la interfaz.
6. Ejecutar el build; `dist/config.js` contiene únicamente esos valores públicos. Para desarrollo real, configurar los mismos valores en `public/config.js`; el ejemplo no contiene secretos.
7. Probar login, persistencia tras recarga, permisos y el aislamiento con la suite SQL incluida. No habilitar usuarios reales adicionales antes de verificar estos controles.

La sesión de autenticación se mantiene en sessionStorage y se renueva. Los datos operativos reales se almacenan exclusivamente en Supabase; el navegador no es su fuente de verdad. El alta/invitación y recuperación de cuentas se gestiona inicialmente desde Supabase Auth. No hay alta pública de clientes en el piloto.

## Organizaciones y roles

Cada entidad pertenece a una organización. Las relaciones entre caballo, persona, plan y ejecución incluyen la organización en sus claves foráneas para bloquear cruces accidentales. La seguridad se ejecuta en PostgreSQL mediante RLS y funciones de acceso.

- Administradoras: programan, ejecutan, editan fichas, registran salud, consultan histórico y dashboard.
- Jinetes/alumnos: consultan su agenda; consultan caballos asignados mediante `horse_access`. Su persona se vincula en `memberships.person_id`.
- Operación: consulta agenda y estado de ejecución de su organización. No registra ejecución en esta V1.
- Propietarios: consulta exclusivamente caballos autorizados mediante `horse_access`. Historial y salud necesitan permisos explícitos `history_allowed` / `health_allowed`.
- El texto original completo de WhatsApp está restringido a administradoras, incluso cuando se autoriza el historial a un propietario.

La administración de miembros y asignaciones se realiza en Supabase durante el piloto. No hay selector que permita simular un rol en producción. La app ofrece cambio de organización solo entre membresías reales.

## Reglas

- Caminar → Paseo; Soltar → Potrero; Caminar de tiro → responsable Palafrenero, sin jinete.
- Cada actividad futura se elige explícitamente; el nombre de Alicia o de otra persona no determina Clase/Trabajo.
- Clase exige jinete/alumno; entrenadora opcional. No se restringe Trabajo a Mariana/Cristina.
- Programación y ejecución están en tablas distintas. La ejecución no modifica lo programado.
- Las actividades pendientes pueden editarse; cada cambio conserva una versión anterior. Una actividad con ejecución registrada bloquea cambios posteriores de programación.
- Una ejecución por actividad; no realizada exige motivo. Duración y calificación son opcionales.
- Histórico inmutable con origen, texto original, marca de inferencia y estado `unknown` si la ejecución no está confirmada.
- Cumplimiento = ejecuciones realizadas / planes del periodo. El histórico sin ejecución confirmada no se cuenta como trabajo real. Trabajo ejecutado y clases impartidas se calculan por separado.
- Fechas operativas del piloto: America/Bogota.

## Histórico

El importador acepta un JSON normalizado de exactamente 1.605 registros y hace una importación transaccional. Debe vincular primero los nombres de los archivos originales con los IDs reales de caballos/personas de MA Dressage. Ejemplo de estructura, NO un registro real:

```json
[{
  "source_key": "identificador-estable-del-origen",
  "date": "2026-05-01",
  "horse_id": "UUID_DEL_CABALLO",
  "activity": "Clase",
  "person_id": null,
  "trainer_id": null,
  "outcome": "unknown",
  "inferred": true,
  "raw_text": "Texto original íntegro",
  "notes": "",
  "location": ""
}]
```

No deducir `done` por existir una programación en WhatsApp. Las clases inferidas de montas de alumnos pueden conservarse con `inferred: true`. Repetir el mismo archivo no duplica registros; un identificador existente con datos distintos cancela la importación. Los archivos fuente no se modifican.

## Publicación

GitHub almacena el código en un repositorio independiente. El flujo manual `package.yml` prepara un archivo de publicación sin desplegar ni contratar servicios; usa las dos variables públicas de Supabase. El alojamiento se elegirá después de comprobar la configuración de Mercado Casa y sus límites gratuitos, creando un sitio separado para CORE. GitHub Pages no se utiliza como destino porque limita el uso para productos comerciales SaaS y desaconseja transacciones sensibles como contraseñas: https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits . No están activados repositorio, publicación o cuentas desde este entorno.

## Separación y coste

La cuenta existente del usuario puede ser la misma; los recursos de CORE deben ser nuevos: repositorio, proyecto Supabase, claves, usuarios, datos y dirección de la app. No modificar, compartir tablas ni reutilizar claves de Mercado Casa.

El usuario exige planes gratuitos. Antes de crear el proyecto se debe comprobar que queda capacidad en su cuota Free de Supabase (máximo dos proyectos activos según la página oficial consultada el 3 de octubre de 2026: https://supabase.com/pricing ). Si no queda capacidad, detener la creación; no pausar ni eliminar proyectos ajenos, no activar pago y no crear organizaciones para eludir la cuota. Revisar también cuotas/cargos de GitHub Actions antes de activar los flujos remotos. No contratar dominios ni planes adicionales.

Estado de acceso al 3 de octubre de 2026: las integraciones aparecen instaladas, pero sus herramientas no están expuestas en esta sesión. Se abrieron los paneles de GitHub y Supabase; ambos requieren iniciar sesión. No se ha comprobado aún la cantidad de proyectos activos del usuario ni creado recursos remotos.

## Pendientes para cerrar el piloto real

Conectar GitHub/Supabase, crear recursos nuevos, aplicar y verificar el esquema, confirmar correos de administradoras, cargar fichas verificadas, recuperar/importar el histórico y medir el registro de ejecución con el equipo. La interfaz requiere pocos toques, pero el objetivo de 20 segundos necesita validación con personas reales.

Funciones comerciales pospuestas: suscripciones, cobros, registro autónomo de organizaciones y personalización de catálogos. Esta V1 no promete escala ilimitada ni reemplaza historia clínica veterinaria.
