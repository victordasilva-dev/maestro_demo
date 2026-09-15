#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Corre la suite Maestro dentro del emulador levantado por
# reactivecircus/android-emulator-runner.
#
# IMPORTANTE: ese action ejecuta su parametro `script:` con /bin/sh (dash en
# Ubuntu), que no soporta `set -o pipefail`. Por eso el workflow invoca este
# archivo explicitamente con bash en lugar de pegar los comandos inline.
# ---------------------------------------------------------------------------
set -euo pipefail

APK_PATH="${APK_PATH:?falta la variable APK_PATH}"
MAESTRO_TAGS="${MAESTRO_TAGS:-}"

adb wait-for-device

# Refuerzo de lo que ya hace disable-animations: los waits sobre el WebView
# dependen de que las tres escalas esten en cero.
adb shell settings put global window_animation_scale 0
adb shell settings put global transition_animation_scale 0
adb shell settings put global animator_duration_scale 0

echo "::group::Instalar APK"
adb install -r -g "$APK_PATH"
echo "::endgroup::"

mkdir -p artifacts

# Argumentos opcionales como parametros posicionales: evita el word splitting
# de una variable sin comillas.
set --
if [ -n "$MAESTRO_TAGS" ]; then
  set -- --include-tags="$MAESTRO_TAGS"
  echo "Filtrando por tags: $MAESTRO_TAGS"
fi

# --test-output-dir concentra la evidencia de la corrida (manifest.json,
# commands.json, logs/ y takeScreenshot/) en una ruta fija, sin subcarpetas
# con timestamp. Reemplaza el rastreo manual de los .png por el cwd.
maestro test .maestro/ "$@" \
  --format JUNIT \
  --output artifacts/report.xml \
  --test-suite-name "Carro - Agregar producto al carro" \
  --test-output-dir artifacts/run
