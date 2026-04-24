# Bit Flow offline mode

Fecha: 2026-04-24

## Que funciona offline

- Arranque local/demo: Firebase, Supabase y Engine tienen timeout/catch y no bloquean la UI local.
- Crear planillas locales desde blanco o templates embebidos.
- Editar celdas y guardar en almacenamiento local.
- Cargar templates demo sin red.
- Adjuntar evidencia cuando el permiso/plataforma lo permite.
- Exportar XLSX/PDF/ZIP desde datos locales.
- Abrir diagnosticos y exportar informacion de soporte local.

## Persistencia local

- Web: `SheetStore` usa Hive/IndexedDB como almacenamiento principal y espeja/lee `SharedPreferences` para evitar versiones viejas entre lista/editor.
- Web con IndexedDB bloqueado: cae a memoria de sesion. La app sigue usable, pero los datos no sobreviven reload/cierre.
- Android/IO: usa `SharedPreferences` con tracking de writes; si init falla, cae a memoria de sesion para no bloquear el trabajo.
- Editor: guarda atomico en `SharedPreferences` y espeja el modelo hacia `SheetStore` para que lista/export vean el mismo estado.

## Modo temporal

Cuando el storage persistente falla, Bit Flow puede seguir en modo memoria. Ese modo sirve para demo o trabajo de emergencia en la sesion actual.

Riesgo: si se cierra la pestana/app o se recarga, los datos en memoria se pierden. En ese caso, exportar ZIP/XLSX apenas sea posible.

## Que requiere permisos o plataforma

- Camara, microfono y GPS dependen de permisos del sistema/navegador.
- En navegadores embebidos (WhatsApp/Instagram), camara/microfono/GPS pueden estar bloqueados.
- En Android, compartir/exportar depende de apps instaladas que acepten el archivo.

## Que no existe todavia

- Sync cloud complejo/offline multiusuario.
- Resolucion avanzada de conflictos entre dispositivos.
- Cola de sincronizacion con backend garantizada para todos los flujos.

## Futuro recomendado

- Sync explicito y auditable por workspace/proyecto.
- Estado "pendiente de sincronizar" por planilla/adjunto.
- Backup automatico programado a archivo local o carpeta elegida por el usuario.
