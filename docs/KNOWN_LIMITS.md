# Known Limits (actual)

## Alcance actual
- Auth esta desactivado por defecto (`BITFLOW_AUTH=false`) para priorizar demo sell-ready sin backend.
- El modo local-first depende del almacenamiento del navegador/dispositivo.
- Integraciones externas avanzadas no son requisito para esta version de demo.

## Limitaciones no bloqueantes
- Existen warnings/deprecations legacy en `flutter analyze` fuera del alcance de este PR.
- Algunas pantallas legacy del repo no forman parte del flujo comercial principal.
- El bundle puede contener codigo de auth legacy no ejecutado cuando auth esta OFF.

## Mitigacion aplicada
- Flujo principal de demo protegido y validado (landing/start/editor/premium/agent).
- Tests smoke para text scale/mobile/CTA visibles.
- Build release validado para Pages con auth OFF.
