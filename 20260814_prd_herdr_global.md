# PRD: herdrv2 — Global + Per-Project Tab System

**Date:** 2026-08-14  
**Author:** Tony  
**Status:** Draft  
**Replaces:** `herdr.sh` v1.2.0

---

## 1. Problem Statement

`herdr.sh` hardcodea los tabs auxiliares directamente en el script de cada proyecto:

```bash
create_tab "agy"       "agy"
create_tab "pi"        "pi"
create_tab "git"       "lazygit"
create_tab "glow"      "glow"
create_tab "terminal"  "bash"
create_tab "tonyscode" "tonyscode"
```

Esto genera dos fricciones concretas:

1. **Duplicación**: si se quiere agregar un tab global (ej. un nuevo tool) hay que tocar cada `herdr.sh` de cada proyecto.
2. **Sin personalización por proyecto**: no hay mecanismo para tabs que sólo tengan sentido en un proyecto específico (ej. `docker compose logs`, `npm run dev`, un seed de DB).

---

## 2. Goal

Crear `herdrv2.sh` que soporte **dos capas de tabs**:

| Capa | Fuente | Propósito |
|---|---|---|
| **Global** | `~/herdrglobal` | Tabs presentes en TODOS los proyectos |
| **Local** | `herdr.tabs` (en el dir del proyecto) | Tabs extras, específicos de ese proyecto |

La lógica de toggle (detectar workspace existente, poblar si tiene 1 tab, cerrar si tiene más) se mantiene igual que en v1.

---

## 3. Global Config File: `~/herdrglobal`

### 3.1 Ubicación y configuración

El path se resuelve via variable de entorno con fallback:

```bash
GLOBAL_TABS_FILE="${HERDR_GLOBAL_FILE:-${HOME}/herdrglobal}"
```

Exportar `HERDR_GLOBAL_FILE` en `.bashrc`/`.zshrc` permite usar cualquier path (ej. `/home/herdrglobal`). Si no está definida, se usa `~/herdrglobal` por defecto.

### 3.2 Formato propuesto: TSV (Tab-Separated Values)

Archivo de texto plano, una línea por tab, dos campos separados por TAB literal:

```
# herdrglobal — global tabs for all herdr workspaces
# Format: <label>\t<command>
# Lines starting with # are comments. Blank lines are ignored.

agy	agy
pi	pi
git	lazygit
glow	glow
terminal	bash
tonyscode	tonyscode
```

**Justificación del formato:**
- Sin dependencias (no YAML, no TOML, no JSON).
- Legible y editable con cualquier editor o `echo`.
- Consistente con la naturaleza shell del proyecto.
- Fácil de parsear con `while read` o `awk`.

### 3.3 Reglas del archivo

- Las líneas que empiezan con `#` son comentarios y se ignoran.
- Las líneas en blanco se ignoran.
- El separador es un TAB literal, no espacios.
- El `<label>` es el nombre visible del tab.
- El `<command>` es el comando que se ejecuta en el pane raíz del tab.
- El orden de las líneas define el orden de creación de los tabs (y por tanto el orden visual).

---

## 4. Per-Project Config File: `herdr.tabs`

### 4.1 Ubicación

```
<project-dir>/herdr.tabs
```

Convive con `herdrv2.sh` en el directorio del proyecto. **Es opcional**: si no existe, sólo se crean los tabs globales.

### 4.2 Formato

Mismo formato TSV que `~/herdrglobal`:

```
# herdr.tabs — project-specific tabs
# Format: <label>\t<command>

dev	npm run dev
logs	docker compose logs -f
seed	npm run db:seed
```

### 4.3 Reglas de merge

El orden final de tabs en el workspace es:

```
[opencode] → [tabs de ~/herdrglobal] → [tabs de herdr.tabs]
```

- Los tabs globales siempre van primero, después de `opencode`.
- Los tabs locales se agregan al final.
- **No hay deduplicación automática**: si un label aparece en ambos archivos, se crean dos tabs. El autor del `herdr.tabs` es responsable de no duplicar.

> **Design Decision (abierta):** ¿querés deduplicación por label? Opciones:
> - `local wins`: si el label existe en global, se usa el comando del local.
> - `global wins`: el tab local se ignora si ya existe el label en global.
> - `no dedup` (propuesta actual): se crean ambos, label repetido visible.

---

## 5. Behavior of `herdrv2.sh`

### 5.1 Flow (igual que v1, diferente fuente de tabs)

```
herdrv2.sh ejecutado
    │
    ├─ workspace existe con > 1 tab? → TOGGLE OFF (close workspace)
    │
    ├─ workspace existe con 1 tab?   → POPULATE (usar tab raíz existente)
    │
    └─ workspace no existe?          → CREATE (nuevo workspace)
               │
               └─ En cualquier caso de populate/create:
                      1. Renombrar tab raíz → "opencode", correr opencode
                      2. Leer ~/herdrglobal → crear tabs globales
                      3. Leer ./herdr.tabs (si existe) → crear tabs locales
                      4. Focus workspace
```

### 5.2 Error handling

- Si `~/herdrglobal` **no existe**: advertencia en stderr, continuar sin tabs globales.
- Si `~/herdrglobal` existe pero tiene líneas malformadas (sin TAB): skip de esa línea con warning.
- Si `./herdr.tabs` no existe: silencioso, es opcional.

---

## 6. File Inventory

| Archivo | Rol | Versionado |
|---|---|---|
| `herdrv2.sh` | Script principal, reemplaza `herdr.sh` | En cada repo (symlink o copia) |
| `~/herdrglobal` | Tabs globales centralizados | En repo `herdr` o dotfiles |
| `./herdr.tabs` | Tabs locales por proyecto | En el repo del proyecto (puede ir en `.gitignore` o commitearse) |

> **Design Decision (abierta):** ¿`herdr.tabs` va commiteado o en `.gitignore`? Si es parte de la infra del proyecto → commit. Si es configuración personal de la máquina → `.gitignore`.

---

## 7. Out of Scope (v2)

- UI o wizard para editar `~/herdrglobal`.
- Soporte de variables de entorno o expansión de paths en los comandos (por ahora comandos literales).
- Tabs condicionales (ej. "solo si existe `docker-compose.yml`").
- Múltiples archivos globales o herencia en cascada.

---

## 8. Open Questions

| # | Pregunta | Decisión |
|---|---|---|
| 1 | ¿Deduplicación de labels entre global y local? | ✅ **No dedup** — se crean ambos tabs si el label se repite |
| 2 | ¿`herdr.tabs` se commitea o va en `.gitignore`? | ✅ **Commiteado** — es parte de la infra del proyecto |
| 3 | ¿`herdrv2.sh` convive con `herdr.sh` o lo reemplaza? | ✅ **Reemplaza** — `herdr.sh` se actualiza in-place a v2 |
| 4 | ¿Cómo se configura el path del archivo global? | ✅ **Variable de entorno** — `HERDR_GLOBAL_FILE`, default `${HOME}/herdrglobal` |

---

## 9. Acceptance Criteria

- [ ] `herdrv2.sh` sin `herdr.tabs` en el proyecto produce el mismo resultado que `herdr.sh` con las mismas entradas en `~/herdrglobal`.
- [ ] `herdrv2.sh` con `herdr.tabs` agrega los tabs locales DESPUÉS de los globales.
- [ ] Ausencia de `~/herdrglobal` genera warning pero no falla.
- [ ] Líneas malformadas en cualquier archivo se skipean con warning, no abortan.
- [ ] Toggle off funciona igual que v1 (`TAB_COUNT > 1` → close).
