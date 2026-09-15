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
lint  ──▶  e2e (matriz de API levels)  ──▶  release (solo en main)
```

| Job | Que hace | Duracion aprox. |
|---|---|---|
| `lint` | `maestro check-syntax` sobre `.maestro/`. No necesita emulador. | ~30 s |
| `e2e` | Levanta un emulador, instala el APK, corre la suite y sube la evidencia. | 15–25 min |
| `release` | Publica el APK como GitHub Release si la suite paso en `main`. | ~1 min |

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
- `screenshots/` — los `takeScreenshot` de los flows (`TC-CARRO-AND-004`, `005`, `010`)
- `debug/` — logs, jerarquia de vistas y capturas automaticas de los pasos fallidos

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
- **Fijar la version de Maestro.** El workflow instala la ultima por defecto;
  poner un valor en `env.MAESTRO_VERSION` (ej. `1.39.0`) hace el pipeline
  reproducible y evita que una release de Maestro rompa la suite sin aviso.
- **`maestro-cloud.yml` requiere el secret `MAESTRO_CLOUD_API_KEY`** y no hace
  nada hasta configurarlo.
- **No hay job de compilacion.** `codigo_ejemplo.kt` no se compila ni se valida;
  hoy solo sirve como archivo a modificar para disparar el pipeline.
