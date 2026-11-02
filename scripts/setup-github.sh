#!/usr/bin/env bash
# Learning English Zone - configura GitHub: rama develop, etiquetas, milestones (versiones) e issues.
# Uso (desde la raíz del repo, en Git Bash):
#   bash scripts/setup-github.sh            -> ejecuta
#   DRY_RUN=1 bash scripts/setup-github.sh  -> solo muestra lo que haría
# Requisitos: git y GitHub CLI (gh) con sesión iniciada: gh auth login
# Usa solo la API REST de GitHub. Es seguro correrlo dos veces: no duplica nada.

set -euo pipefail

REPO="junior-0731/learning-english-zone"
DRY_RUN="${DRY_RUN:-0}"

run() {
  if [ "$DRY_RUN" = "1" ]; then echo "[dry-run] $*" >&2; else "$@"; fi
}

# ---------- 0. Verificaciones ----------
command -v gh >/dev/null || { echo "Falta GitHub CLI. Instálalo: winget install --id GitHub.cli"; exit 1; }
gh api "repos/$REPO" >/dev/null 2>&1 || { echo "No hay acceso al repo. Inicia sesión: gh auth login"; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null || { echo "Corre esto dentro del repo."; exit 1; }

# ---------- 1. Rama develop ----------
echo "== Rama develop"
git fetch origin
if git ls-remote --exit-code --heads origin develop >/dev/null 2>&1; then
  echo "develop ya existe en GitHub"
else
  run git push origin origin/main:refs/heads/develop
fi

# ---------- 2. Etiquetas ----------
echo "== Etiquetas"
label() {
  local name="$1" color="$2" desc="$3"
  if gh api "repos/$REPO/labels/$name" >/dev/null 2>&1; then
    run gh api -X PATCH "repos/$REPO/labels/$name" -f color="$color" -f description="$desc" >/dev/null
    echo "Etiqueta actualizada: $name"
  else
    run gh api -X POST "repos/$REPO/labels" -f name="$name" -f color="$color" -f description="$desc" >/dev/null
    echo "Etiqueta creada: $name"
  fi
}

label "tipo:feature"    "1D76DB" "Funcionalidad nueva"
label "tipo:chore"      "C5DEF5" "Configuración, estructura, mantenimiento"
label "tipo:docs"       "0075CA" "Documentación"
label "tipo:bug"        "D73A4A" "Algo no funciona"
label "tipo:ci"         "5319E7" "Integración continua y pruebas automáticas"
label "tipo:data"       "FBCA04" "Datos semilla, mazos, catálogos"
label "tipo:epic"       "3E4B9E" "Agrupa las tareas de un módulo"
label "area:backend"    "0E8A16" "FastAPI, base de datos"
label "area:frontend"   "BFD4F2" "React, interfaz"
label "area:ia"         "F9D0C4" "Ollama, Whisper, Piper"
label "area:infra"      "BFDADC" "Docker, CI, entorno"
label "fase:0"          "EDEDED" "Preparación"
label "fase:1"          "D4C5F9" "MVP"
label "fase:2"          "C2E0C6" "Escucha y voz"
label "fase:3"          "FEF2C0" "Corrector y contenido"
label "fase:4"          "F9D0C4" "Conversación y portafolio"
label "prioridad:alta"  "B60205" "Bloquea otras tareas"
label "prioridad:media" "D93F0B" "Importante, no bloquea"
label "prioridad:baja"  "FEF2C0" "Puede esperar"

# ---------- 3. Milestones = versiones ----------
echo "== Milestones"
milestone() {
  local title="$1" desc="$2"
  if gh api "repos/$REPO/milestones?state=all&per_page=100" --jq '.[].title' | grep -Fxq "$title"; then
    echo "Milestone ya existe: $title"
  else
    run gh api -X POST "repos/$REPO/milestones" -f title="$title" -f description="$desc" >/dev/null
    echo "Milestone creado: $title"
  fi
}

M0="v0.1.0 · Fase 0 Preparación"
M1="v0.2.0 · Fase 1 MVP"
M2="v0.3.0 · Fase 2 Escucha y voz"
M3="v0.4.0 · Fase 3 Corrector y contenido"
M4="v1.0.0 · Fase 4 Conversación y portafolio"

milestone "$M0" "Repo, Docker Compose, CI, GPU verificada. Puerta: docker compose up levanta todo."
milestone "$M1" "Cuentas, repaso FSRS, sesión diaria, progreso. Puerta: 7 días de uso real."
milestone "$M2" "Dictado, pronunciación, lectura en voz alta y shadowing. Puerta: marca bien los fallos."
milestone "$M3" "Corrector L1, gramática a demanda, biblioteca por cobertura. Puerta: 16/20 frases."
milestone "$M4" "Roleplay, diagnóstico, README, video demo. Publicación en el portafolio."

# ---------- 4. Issues ----------
echo "== Issues"
EXISTING_ISSUES="$(gh api "repos/$REPO/issues?state=all&per_page=100" --paginate --jq '.[] | select(.pull_request == null) | .title' || true)"
issue() {
  local title="$1" labels="$2" ms="$3" body="$4"
  if printf '%s\n' "$EXISTING_ISSUES" | grep -Fxq "$title"; then
    echo "Issue ya existe: $title"
    return
  fi
  local ms_number
  ms_number="$(gh api "repos/$REPO/milestones?state=all&per_page=100" --jq ".[] | select(.title == \"$ms\") | .number" || true)"
  local args=(-X POST "repos/$REPO/issues" -f title="$title" -f body="$body")
  [ -n "$ms_number" ] && args+=(-F milestone="$ms_number")
  local l
  IFS=',' read -ra _labels <<< "$labels"
  for l in "${_labels[@]}"; do args+=(-f "labels[]=$l"); done
  run gh api "${args[@]}" >/dev/null
  echo "Issue creado: $title"
}

# ----- Fase 0 -----
issue "chore: estructura del monorepo (backend, frontend, docs)" "tipo:chore,area:infra,fase:0,prioridad:alta" "$M0" "$(cat <<'EOF'
## Objetivo
Crear la estructura base del proyecto.

## Tareas
- [ ] Carpetas `backend/`, `frontend/`, `docs/`, `data/`, `scripts/`
- [ ] `.gitignore`, `.editorconfig`, `.env.example`
- [ ] Licencia MIT

## Criterio de aceptación
- La estructura está en `develop` y el `.env` real nunca se sube.
EOF
)"

issue "chore: Docker Compose con PostgreSQL, API y frontend" "tipo:chore,area:infra,fase:0,prioridad:alta" "$M0" "$(cat <<'EOF'
## Objetivo
Levantar todo el proyecto con un solo comando.

## Tareas
- [ ] Servicios `db` (PostgreSQL 16), `api` (FastAPI), `web` (Vite)
- [ ] Volumen persistente para la base de datos
- [ ] Healthchecks

## Criterio de aceptación
- `docker compose up` levanta los tres servicios desde cero en una máquina limpia.
EOF
)"

issue "chore: backend FastAPI base (config, health, Alembic)" "tipo:chore,area:backend,fase:0,prioridad:alta" "$M0" "$(cat <<'EOF'
## Tareas
- [ ] FastAPI + SQLAlchemy 2 + Alembic + Pydantic Settings
- [ ] Endpoint `GET /health` que revisa la base de datos
- [ ] Primera migración vacía
- [ ] Ruff + pytest configurados

## Criterio de aceptación
- `GET /health` responde 200 con el estado de la base de datos y hay una prueba que lo cubre.
EOF
)"

issue "chore: frontend React + TypeScript + Vite + Tailwind" "tipo:chore,area:frontend,fase:0,prioridad:alta" "$M0" "$(cat <<'EOF'
## Tareas
- [ ] Proyecto Vite con React y TypeScript
- [ ] Tailwind, React Router, cliente HTTP
- [ ] ESLint + Vitest
- [ ] Página inicial que muestra el estado de `/health`

## Criterio de aceptación
- La página muestra "API conectada" cuando el backend responde.
EOF
)"

issue "ci: GitHub Actions con lint y pruebas" "tipo:ci,area:infra,fase:0,prioridad:media" "$M0" "$(cat <<'EOF'
## Tareas
- [ ] Workflow en cada push y PR a `develop` y `main`
- [ ] Backend: ruff + pytest
- [ ] Frontend: eslint + vitest + build

## Criterio de aceptación
- Un PR con una prueba fallando queda en rojo y no se puede fusionar.
EOF
)"

issue "chore: Ollama con la GPU NVIDIA (RTX 4070) en Docker" "tipo:chore,area:ia,area:infra,fase:0,prioridad:media" "$M0" "$(cat <<'EOF'
## Tareas
- [ ] Servicio `ollama` en Compose con acceso a la GPU (Docker Desktop + WSL2)
- [ ] Descargar un modelo de 7-8B cuantizado a 4 bits
- [ ] Script que mide los tokens por segundo

## Criterio de aceptación
- `nvidia-smi` dentro del contenedor ve la RTX 4070 y el modelo responde en menos de 3 s una frase corta.
EOF
)"

issue "docs: README, CONTRIBUTING y plan en docs/" "tipo:docs,fase:0,prioridad:media" "$M0" "$(cat <<'EOF'
## Tareas
- [ ] README: qué es, stack, cómo correrlo
- [ ] CONTRIBUTING: flujo de ramas (feature/* -> develop -> main), commits convencionales, versionado semántico
- [ ] `docs/`: plan de trabajo, filtro de métodos, contexto hispanohablantes

## Criterio de aceptación
- Alguien que no conoce el proyecto puede correrlo siguiendo solo el README.
EOF
)"

issue "data: catálogo de errores de hispanohablantes como datos semilla" "tipo:data,area:backend,fase:0,prioridad:baja" "$M0" "$(cat <<'EOF'
## Tareas
- [ ] Agregar `data/errores_l1_es.json` (53 errores)
- [ ] Validar el formato con un esquema Pydantic

## Criterio de aceptación
- Una prueba carga el JSON y verifica que todos los ids son únicos y todas las categorías existen.
EOF
)"

# ----- Fase 1 -----
issue "epic: M0 Cuentas y perfil" "tipo:epic,tipo:feature,area:backend,area:frontend,fase:1,prioridad:alta" "$M1" "$(cat <<'EOF'
Registro, login, perfil (nivel, objetivo, minutos diarios).

## Criterio de aceptación
- Dos usuarios no ven los datos del otro.
- Contraseñas con hash (argon2 o bcrypt); JWT con expiración.
EOF
)"

issue "epic: M2 Repaso espaciado (FSRS)" "tipo:epic,tipo:feature,area:backend,area:frontend,fase:1,prioridad:alta" "$M1" "$(cat <<'EOF'
Tarjetas de frase (inglés -> significado) con audio y algoritmo FSRS.

## Criterio de aceptación
- Si el repaso del día pasa del tope de minutos, la app baja sola las tarjetas nuevas.
- Calificación Again / Hard / Good / Easy actualiza la próxima fecha con FSRS.
EOF
)"

issue "data: mazo inicial de las 1000 palabras más frecuentes en frases" "tipo:data,fase:1,prioridad:alta" "$M1" "$(cat <<'EOF'
## Criterio de aceptación
- 1000 tarjetas con frase de ejemplo, traducción al español y audio generado.
- Fuente de frecuencias documentada y con licencia compatible.
EOF
)"

issue "feat: audio de tarjetas con Piper (TTS, acento americano)" "tipo:feature,area:ia,fase:1,prioridad:media" "$M1" "$(cat <<'EOF'
## Criterio de aceptación
- Cada tarjeta tiene su audio generado localmente y guardado en caché.
EOF
)"

issue "epic: SD Sesión diaria guiada" "tipo:epic,tipo:feature,area:frontend,fase:1,prioridad:alta" "$M1" "$(cat <<'EOF'
Encadena los módulos en ~30-45 min con temporizador por bloque.

## Criterio de aceptación
- Se puede iniciar, pausar y retomar; registra el tiempo por módulo.
EOF
)"

issue "epic: M9 Progreso (horas, racha, vocabulario)" "tipo:epic,tipo:feature,area:backend,area:frontend,fase:1,prioridad:media" "$M1" "$(cat <<'EOF'
## Criterio de aceptación
- Las horas cuadran con la suma de las sesiones.
- Aviso si fallas un día para no fallar dos seguidos.
EOF
)"

# ----- Fase 2 -----
issue "feat: integrar faster-whisper (voz a texto) en la capa de IA" "tipo:feature,area:ia,fase:2,prioridad:alta" "$M2" "$(cat <<'EOF'
## Criterio de aceptación
- Endpoint que recibe audio del navegador y devuelve la transcripción en menos de 2 s para 10 s de audio (GPU).
EOF
)"

issue "epic: M4 Escucha intensiva y dictado" "tipo:epic,tipo:feature,area:frontend,area:backend,fase:2,prioridad:alta" "$M2" "$(cat <<'EOF'
## Criterio de aceptación
- Compara lo escrito con el texto, marca las palabras falladas y las manda al repaso.
- Velocidad 0.75x a 1.0x.
EOF
)"

issue "epic: M5 Pronunciación con pares mínimos" "tipo:epic,tipo:feature,area:ia,area:frontend,fase:2,prioridad:media" "$M2" "$(cat <<'EOF'
Usa los ítems S01-S10 del catálogo de errores.

## Criterio de aceptación
- Si Whisper entiende la palabra contraria del par (sheep por ship), lo marca como fallo y repite el par.
EOF
)"

issue "epic: LV Lectura en voz alta y shadowing" "tipo:epic,tipo:feature,area:frontend,area:ia,fase:2,prioridad:media" "$M2" "$(cat <<'EOF'
## Criterio de aceptación
- Guarda la grabación, muestra la transcripción junto al original y resalta las diferencias.
EOF
)"

# ----- Fase 3 -----
issue "epic: M6 Corrector de errores (catálogo L1 + LLM)" "tipo:epic,tipo:feature,area:ia,area:backend,fase:3,prioridad:alta" "$M3" "$(cat <<'EOF'
## Criterio de aceptación
- En 20 frases de prueba con errores conocidos detecta al menos 16 con la categoría correcta.
- La versión corregida pasa al repaso.
EOF
)"

issue "epic: M8 Gramática a demanda" "tipo:epic,tipo:feature,area:ia,area:frontend,fase:3,prioridad:media" "$M3" "$(cat <<'EOF'
## Criterio de aceptación
- Se activa al tercer error de la misma categoría; nunca bloquea la sesión.
EOF
)"

issue "epic: M3 Biblioteca y cobertura léxica" "tipo:epic,tipo:feature,area:backend,area:frontend,fase:3,prioridad:media" "$M3" "$(cat <<'EOF'
## Criterio de aceptación
- Carga texto o .srt, calcula el % de palabras conocidas y lo clasifica: fácil (>98 %), ideal (95-98 %), difícil (<95 %).
EOF
)"

# ----- Fase 4 -----
issue "epic: M7 Roleplay con el LLM (vida diaria y dev)" "tipo:epic,tipo:feature,area:ia,area:frontend,fase:4,prioridad:alta" "$M4" "$(cat <<'EOF'
## Criterio de aceptación
- Correcciones al final, nunca a mitad de la conversación; vocabulario limitado a tu nivel.
- Escenarios: pedir comida, presentarte, daily, code review, entrevista.
EOF
)"

issue "epic: M1 Diagnóstico de nivel" "tipo:epic,tipo:feature,area:backend,area:frontend,fase:4,prioridad:media" "$M4" "$(cat <<'EOF'
## Criterio de aceptación
- Test de vocabulario por frecuencia que recomienda el mazo inicial; se repite cada 3 meses y recuerda hacer el EF SET.
EOF
)"

issue "docs: README final, video demo y publicación en el portafolio" "tipo:docs,fase:4,prioridad:alta" "$M4" "$(cat <<'EOF'
## Tareas
- [ ] README en inglés y español con capturas y diagrama de arquitectura
- [ ] Sección "Why these methods" con fuentes
- [ ] Video de 3-5 min
- [ ] Release v1.0.0 con notas
EOF
)"

echo
echo "Listo. Revisa: https://github.com/$REPO/issues y https://github.com/$REPO/milestones"
