# Maestro CI/CD con GitHub Actions

Suite E2E de Maestro para la app Android `com.tricot_app`, con pipeline de
integracion y entrega continua.

## Estructura

```
.maestro/
  config.yaml                          # solo *.yaml de primer nivel son ejecutables
  carro-agregar-producto-exitoso.yaml  # tags: e2e, exitoso, carro
  carro-agregar-producto-fallido.yaml  # tags: e2e, fallido, negativo, carro
  subflows/
    buscar-y-abrir-pdp.yaml            # paso reutilizable, no se ejecuta solo
app/
  codigo_ejemplo.kt                    # codigo fuente de ejemplo: al modificarlo
                                       # y pushear se dispara el pipeline
  build/
    app-android-dev_2.5.apk            # APK que consume la suite E2E
.github/workflows/
  maestro-e2e.yml                      # pipeline principal (emulador en el runner)
  maestro-cloud.yml                    # alternativa en dispositivos gestionados
```

## Pipeline principal (`maestro-e2e.yml`)

```
lint  ──▶  e2e (matriz de API levels)  ──▶  release (DESACTIVADO)
```

| Job | Que hace | Duracion aprox. |
|---|---|---|
| `lint` | `maestro check-syntax` sobre `.maestro/`. No necesita emulador. | ~30 s |
| `e2e` | Levanta un emulador, instala el APK, corre la suite y sube la evidencia. | 15–25 min |
| `release` | **Comentado.** Publicaba el APK como GitHub Release tras pasar la suite en `main`. Descomentar el bloque al final de `maestro-e2e.yml` para activarlo. | ~1 min |

### Disparadores

- **`push` en cualquier rama** que toque `app/**`, `.maestro/**` o el propio
  workflow. Editar `app/codigo_ejemplo.kt` y pushear dispara la suite.
- `pull_request` sobre `main`, con el mismo filtro de rutas
- Cron nocturno a las 03:00 UTC
- Manual (`workflow_dispatch`), aceptando `tags` y `api-level`

Los cambios a `README.md` u otra documentacion no disparan nada, para no gastar
20 minutos de emulador en una correccion de texto.

> **Importante:** `codigo_ejemplo.kt` no se compila dentro del APK. El pipeline
> se dispara con el push, pero la suite siempre prueba el mismo binario
> prebuild. Sirve para demostrar el encadenamiento *push -> CI -> E2E*; no para
> validar que el cambio de codigo funciona.

Para correr solo el caso negativo desde la UI de Actions: ejecutar el workflow
con `tags = fallido`. Eso se traduce en `maestro test --include-tags=fallido`.

### Evidencia

Cada corrida sube el artefacto `maestro-evidencia-api-<N>` con:

- `report.xml` — reporte JUnit, tambien renderizado en el resumen del run
- `run/takeScreenshot/` — las 14 capturas de los flows, nombradas por caso de prueba
- `run/logs/` — logs de la corrida
- `run/manifest.json` y `run/commands.json` — que se ejecuto y con que resultado

Maestro soporta cuatro formatos de reporte (`JUNIT`, `HTML`, `HTML-DETAILED`,
`NOOP`) pero acepta uno solo por corrida. El pipeline usa `JUNIT` porque es el
que alimenta el check de GitHub y hace fallar el PR; `HTML-DETAILED` da un
reporte visual mas comodo de leer, a cambio de perder ese check.

La evidencia se concentra via `--test-output-dir`, que escribe todo en una ruta
fija sin subcarpetas con timestamp.

### Capturas

Los flows toman captura en cada punto verificable del caso de prueba: estado
inicial, PDP abierto, modal de talla, producto agregado, carro con el detalle,
cantidad incrementada y disminuida, carro persistido tras reiniciar y checkout
disponible. El flujo negativo cubre su propio estado inicial, el PDP, el boton
deshabilitado, el modal que persiste y el carro vacio.

Los nombres del flujo negativo llevan `-neg` en los pasos que comparte con el
flujo exitoso (`001`, `003`): como todas las capturas caen en el mismo
directorio, dos flows con el mismo nombre se sobrescribirian.

## Decisiones que importan para esta suite

**Animaciones apagadas.** Los flows dependen de `extendedWaitUntil` sobre un
WebView hibrido. El job pasa `disable-animations: true` y ademas fuerza las tres
escalas de animacion por `adb`, porque los tiempos del WebView son la principal
fuente de flakiness.

**Cache del AVD.** El primer job crea el AVD y guarda un snapshot; las corridas
siguientes lo reutilizan y ahorran unos 4 minutos.

**KVM.** Los runners de GitHub traen KVM, pero sin permisos para el usuario del
runner. Sin la regla `udev` del workflow, el emulador x86_64 arranca por
software y la suite se vuelve inviablemente lenta.

**Taps por coordenada.** Los flows tocan el stepper del carro y el buscador por
porcentaje de pantalla, asi que el perfil del emulador (`pixel_6`) no es
intercambiable: cambiarlo exige revalidar esas coordenadas.

## Ejecutar en local

```bash
maestro test .maestro/                      # la suite completa
maestro test .maestro/ --include-tags=exitoso
maestro test .maestro/carro-agregar-producto-fallido.yaml
```

## Pendientes antes de usarlo en serio

- **El APK pesa 64 MB y esta versionado en `app/build/`.** Funciona para un demo,
  pero engorda el historial de git de forma permanente. Lo habitual es que un
  job de build lo genere y el job `e2e` lo tome con `actions/download-artifact`,
  o guardarlo con Git LFS.
- **`maestro-cloud.yml` requiere el secret `MAESTRO_CLOUD_API_KEY`** y no hace
  nada hasta configurarlo.
- **El job `release` esta comentado**, asi que los pushes a `main` no generan
  releases todavia. Activarlo cuando el pipeline este estable.
- **No hay job de compilacion.** `codigo_ejemplo.kt` no se compila ni se valida;
  hoy solo sirve como archivo a modificar para disparar el pipeline.
