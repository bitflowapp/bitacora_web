# README DEMO BITFLOW

Fecha: 2026-02-24

## Que resuelve Bit Flow

Bit Flow centraliza relevamientos de campo y evidencia (fotos/adjuntos) en una planilla operativa para capturar, ordenar, validar y exportar informacion rapidamente.

## Flujo demo recomendado (5-10 min)

1. Abrir la home demo y entrar por `Nueva planilla` (o `Probar demo`).
2. Cargar 3-5 registros en la grilla (texto, estados, observaciones).
3. Editar algunas celdas y guardar manualmente para mostrar feedback.
4. Exportar `XLSX` o `PDF` para salida simple.
5. Exportar `ZIP` para mostrar paquete con datos/evidencia.
6. Probar `Compartir` (si el dispositivo/plataforma lo soporta).

## Que probar (check rapido)

- Crear planilla
- Abrir planilla existente
- Editar celdas (texto/filas)
- Guardar
- Exportar XLSX / PDF / ZIP
- Compartir (cuando aplique)
- Mensajes de error/cancelacion (cancelar export y verificar feedback)

## Limites actuales de demo web

- Persistencia local en navegador (no backend multiusuario en demo).
- En modo temporal o incognito el navegador puede borrar datos/adjuntos al cerrar o recargar.
- Adjuntos grandes pueden chocar con cuota de storage del navegador.
- Compatibilidad de compartir depende de navegador/dispositivo; puede caer a descarga local.
- Auth esta desactivada en demo con flags (`DEMO_MODE=true`, `AUTH_ENABLED=false`).

## Que faltaria para MVP cobrable (resumen)

- Persistencia durable backend + sincronizacion multiusuario
- Auth/roles y seguridad de datos productiva
- Telemetria/observabilidad y trazabilidad de errores
- Hardening adicional de storage/adjuntos y politicas de backup
- Paquete comercial (soporte, onboarding, pricing, SLA)
