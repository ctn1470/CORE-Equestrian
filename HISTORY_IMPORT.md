# Histórico e importación incremental

El importador admite de 1 a 5.000 registros por transacción. La base consolidada
y los archivos fuente se entregan fuera del repositorio: no publicar datos de
WhatsApp, fichas ni registros ejecutados en GitHub o en el directorio web.

El paquete con nombres usa este contrato:

```json
{
  "format": "core-history-v2",
  "records": [{
    "source_key": "identificador-estable-por-registro-de-origen",
    "date": "2026-10-14",
    "horse_name": "Nombre verificado",
    "activity": null,
    "person_name": null,
    "trainer_name": null,
    "time": null,
    "location": "",
    "record_kind": "plan",
    "source_system": "WhatsApp",
    "outcome": "unknown",
    "inferred": false,
    "revision_keys": [],
    "raw_text": "Texto y trazabilidad de origen",
    "notes": ""
  }]
}
```

Este ejemplo solo describe el formato. No es un registro real para importar.

- `plan`: planificación, estado `unknown`.
- `revision`: cambio de planificación, estado `unknown`; `revision_keys`
  referencia los registros anteriores, que siguen intactos.
- `execution`: actividad confirmada, estado `done` o `not_done`.
- `activity: null` conserva una modalidad sin especificar. No se inventa Trabajo.
- El catálogo histórico conserva también Caminar, Clínica, Odontología, Fisio,
  Concurso y D/nto. Estos valores no amplían el selector de programación nueva.
- Las celdas vacías del seguimiento no demuestran actividades no realizadas.
- La coincidencia de fecha y caballo por sí sola no autoriza eliminar un registro.

`public.import_named_history` crea únicamente caballos y personas operativas;
no crea usuarios, invitaciones ni permisos. Resuelve los IDs de la organización
y llama al importador en la misma transacción. Exige una administradora real.
Reimportar datos idénticos devuelve cero registros nuevos. Una clave ya existente
con datos distintos cancela el lote completo, incluida la creación de catálogos.
Los lotes de una organización se serializan con un bloqueo transaccional.

Se mantiene compatible el arreglo JSON anterior con IDs de caballos y personas.
Ahora acepta incrementos; no exige un total fijo de 1.605 filas.

## Agenda, ejecución e historial

Los planes importados se muestran por fecha en Agenda como referencia de solo
lectura. «Llevar a agenda» exige confirmar una actividad válida y un responsable;
no modifica el histórico. `historical_source_key` vincula la nueva programación
con su fuente. Una restricción única impide adoptar la misma fuente dos veces,
incluso con solicitudes simultáneas. Una ejecución confirmada del mismo caballo
se señala para que el equipo pueda revisar si se trata de otra sesión.

Historial filtra por origen, tipo de registro, fecha, caballo, actividad, persona,
entrenadora y ubicación. Las ejecuciones de Excel tienen una fuente distinta de
los planes de WhatsApp. El dashboard cuenta únicamente ejecuciones confirmadas;
las inferencias y cambios de planificación no se convierten en trabajo real.
El texto original completo sigue disponible solo para administradoras.

## Instalación y verificación

Las migraciones `20261013135953_historical_incremental_import.sql` y
`20261013140413_agenda_history_source_link.sql` ya se aplicaron al proyecto CORE
`crcriztfrcgzoxikeqbs`. No volver a ejecutarlas manualmente en ese proyecto.
El proyecto Mercado Casa no participa en estos cambios.

Validación: 27 pruebas locales aprobadas; suites SQL `history-import.sql` e
`isolation.sql` ejecutadas en CORE con rollback de todos los datos de prueba.
El asesor no detectó nuevos problemas de seguridad derivados de estas funciones.
La revisión visual local quedó pendiente porque el navegador integrado agotó
el tiempo de conexión al servidor local.

La rama propone reconectar la interfaz al proyecto Supabase existente. La
publicación actual permanece en demostración hasta incorporar esta propuesta.
La carga de datos reales y la validación de acceso de Cristina son pasos distintos
de preparar la estructura de importación.
