# Bit Flow sellable readiness

Fecha: 2026-04-24

## 1. Estado general

Bit Flow esta casi listo para mostrar como producto B2B en una demo guiada. La direccion visual Apple B2B azul ya es coherente en landing, inicio, listado de planillas, tabla, corporate y fallback. La app comunica mejor el valor: planillas inteligentes para relevamientos tecnicos, evidencias, campo/oficina y exportacion profesional.

Recomendacion actual: casi listo para demo, no todavia como release publico sin QA visual final en browser.

## 2. Que ya esta presentable

- Landing: mensaje B2B claro, CTA directo, demo tecnica visible y tono mas profesional.
- StartPage V2: primera experiencia mas orientada a relevamientos, plantillas y trabajo real.
- SheetsScreen: empty/no results mas accionables y coherentes con producto terminado.
- SmartSheet/Gridnote: tabla con estilo Apple B2B y mensajes de pegado/exportacion mas claros.
- Corporate screens: estados vacios y errores menos tecnicos, con acciones de recuperacion.
- Demo templates: casos tecnicos mas creibles para proteccion catodica, puesta a tierra, evidencias, inspeccion y control operativo.
- Export XLSX: archivo real con hojas, encabezados mas profesionales y texto de instrucciones alineado a Bit Flow.

## 3. Pantallas que conviene mostrar

- Landing desktop y mobile.
- Demo `/?template=proteccion-catodica`.
- StartPage V2 con acciones principales.
- SheetsScreen con 2 o 3 planillas creadas desde templates.
- SmartSheet con demo de proteccion catodica o puesta a tierra.
- Export XLSX de una planilla con datos.
- Corporate dashboard solo si la base/demo corporate esta preparada.

## 4. Pantallas que conviene evitar por ahora

- Diagnostics salvo que el cliente pregunte por soporte tecnico.
- Flujos de auth real si no hay tenant/demo preparada.
- Pantallas corporate conectadas a datos reales incompletos.
- Cualquier flujo que dependa de permisos de camara/GPS en un navegador no preparado.

## 5. Demo flow recomendado

1. Abrir landing y explicar en 15 segundos: "Bit Flow convierte relevamientos tecnicos en planillas con evidencia y exportacion".
2. Click en "Probar demo tecnica".
3. Mostrar columnas: fecha, progresiva, punto, ON/OFF, IR drop, estado, responsable, evidencia.
4. Pegar una mini tabla o editar una celda.
5. Mostrar empty/search si hace falta, pero no quedarse ahi.
6. Exportar XLSX y abrir el archivo generado.
7. Cerrar con el caso B2B: campo registra una vez, oficina revisa/exporta sin transcripcion.

## 6. Screenshots recomendados

- Landing hero desktop.
- Landing hero mobile.
- StartPage V2 con quick actions.
- SheetsScreen empty state.
- SheetsScreen con planillas recientes.
- SmartSheet con proteccion catodica cargada.
- Export modal o archivo XLSX abierto.
- Corporate empty state y dashboard si hay datos consistentes.

## 7. Bugs y riesgos conocidos

- `flutter analyze` global sigue fallando por deuda preexistente del repo; no bloquear este bloque visual si los archivos tocados pasan.
- La rama `main` remota esta muy adelantada respecto de ramas locales viejas; no abrir PR directa a main sin revisar base.
- `codex/apple-b2b-base` fue creada localmente en `cd71abd`; si se necesita PR en GitHub hay que publicar esa base o rebasear con cuidado.
- Auth/corporate real requiere tenant o sesion preparada para demo.
- Permisos de camara/GPS pueden variar segun navegador y contexto HTTPS.

## 8. Que bloquea vender

- Bloqueo real para venta publica: falta QA visual final en navegador real y decision de rama/base para PR limpia.
- Bloqueo real para demo corporate: datos/tenant preparados y flujo de auth definido.
- No bloquea demo guiada: deuda global de analyzer si se comunica como deuda tecnica preexistente y no afecta build.

## 9. Que puede esperar

- Refactor global de analyzer.
- AppMotion como PR separada.
- Redisenio profundo de corporate.
- Nuevas dependencias o motores de automatizacion.
- Optimizaciones de performance teoricas sin medicion.

## 10. Checklist antes de demo

- [ ] Correr `flutter build web --release`.
- [ ] Abrir build web local en desktop y mobile viewport.
- [ ] Probar `/?template=proteccion-catodica`.
- [ ] Crear una planilla desde StartPage V2.
- [ ] Exportar XLSX y abrirlo.
- [ ] Verificar que no haya textos TODO/dev/debug visibles.
- [ ] Verificar que el navegador permita descarga.
- [ ] Tener preparado el relato comercial de 2 minutos.
- [ ] Evitar auth real si no hay tenant listo.

## 11. Recomendacion final

Casi listo para demo. Para mostrar a un cliente real, abrir una PR limpia desde `codex/apple-b2b-base` hacia la rama de polish, correr build web release, tomar screenshots y hacer una pasada manual en Chrome con viewport desktop y mobile.
