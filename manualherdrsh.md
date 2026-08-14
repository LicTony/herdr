# herdr.sh — Manual de uso

`herdr.sh` abre y cierra un workspace de herdr para el proyecto actual, poblándolo con tabs configurados en dos capas: una global (compartida entre todos los proyectos) y una local (específica del proyecto).

---

## Setup rápido (primera vez)

### 1. Crear el archivo global

El archivo global define los tabs que se abren en **todos** los proyectos.
El formato es TSV: `<label><TAB><comando>`, un tab por línea.

```bash
cat > ~/herdrglobal << 'EOF'
# herdrglobal — global tabs for all herdr workspaces
# Format: <label><TAB><command>

opencode	opencode
opencode 2	opencode2
agy	agy
pi	pi
git	lazygit
glow	glow
tonyscode	tonyscode
EOF
```

> **Importante:** el separador es un TAB real (`\t`), no espacios.
> Los labels pueden tener espacios sin necesidad de comillas: `opencode 2` es un label válido.

### 2. Configurar la variable de entorno

Agregá la variable en `~/.bashrc` para que el script sepa dónde buscar el archivo global:

```bash
echo 'export HERDR_GLOBAL_FILE="/home/siranthony/herdrglobal"' >> ~/.bashrc
source ~/.bashrc
```

Verificá que esté cargada:

```bash
echo $HERDR_GLOBAL_FILE
# → /home/siranthony/herdrglobal
```

> Si `HERDR_GLOBAL_FILE` no está definida, el script usa `~/herdrglobal` como default
> y muestra un warning al arrancar.

---

## Uso diario

Desde el directorio del proyecto, ejecutá el script:

```bash
./herdr.sh
```

### Comportamiento toggle

| Situación | Resultado |
|---|---|
| No existe workspace para el proyecto | Crea el workspace y abre todos los tabs |
| Workspace existe con 1 tab | Puebla el workspace con los tabs (el 1 tab era el shell desde donde se corrió) |
| Workspace existe con más de 1 tab | **Cierra** el workspace (toggle off) |

---

## Orden de tabs en el workspace

```
[terminal]      ← siempre primero (bash, tab ancla del workspace)
[tabs globales] ← leídos de $HERDR_GLOBAL_FILE en orden
[tabs locales]  ← leídos de ./herdr.tabs en orden (si existe)
```

---

## Personalizar tabs por proyecto: `herdr.tabs`

Para agregar tabs específicos de un proyecto, creá un archivo `herdr.tabs`
en el directorio del proyecto con el mismo formato TSV:

```bash
# herdr.tabs — project-specific tabs
# Format: <label><TAB><command>

dev	npm run dev
logs	docker compose logs -f
```

- El archivo es **opcional**. Si no existe, el script sigue funcionando con los tabs globales.
- Se recomienda **commitearlo** al repositorio — es parte de la infraestructura del proyecto.
- Los tabs locales se agregan **después** de los globales.
- Si un label se repite entre global y local, se crean **dos tabs** (no hay deduplicación).

---

## Formato de los archivos de tabs

```
# Esto es un comentario y se ignora
# Las líneas vacías también se ignoran

<label><TAB><comando>
```

| Campo | Descripción |
|---|---|
| `label` | Nombre visible del tab. Puede tener espacios. Sin comillas. |
| `TAB` | Separador: un TAB real (`\t`). No espacios. |
| `comando` | Comando que se ejecuta al abrir el tab. |

### Ejemplo completo de `herdrglobal`

```
# herdrglobal

opencode	opencode
opencode 2	opencode2
agy	agy
pi	pi
git	lazygit
glow	glow
tonyscode	tonyscode
```

---

## Advertencias y errores comunes

| Síntoma | Causa | Solución |
|---|---|---|
| `warning: HERDR_GLOBAL_FILE no está definida` | Variable no exportada en el shell | `export HERDR_GLOBAL_FILE=...` en `~/.bashrc` |
| `warning: archivo global no encontrado` | El archivo no existe en el path configurado | Crearlo con el ejemplo de la sección Setup |
| `warning: línea malformada (sin TAB)` | Línea separada por espacios en lugar de TAB | Reemplazar los espacios por un TAB real |
| Workspace no se cierra | `TAB_COUNT` ≤ 1 | Asegurarse de que los tabs se hayan creado correctamente |

---

## Variables de entorno

| Variable | Default | Descripción |
|---|---|---|
| `HERDR_GLOBAL_FILE` | `~/herdrglobal` | Path al archivo de tabs globales |

