# Instalar HERDR igual que Gentleman.Dots — Paso a Paso en Unix

## ¿Qué hace exactamente Gentleman.Dots con HERDR?

Antes de empezar, necesitas saber exactamente qué replicaremos.

Gentleman.Dots hace 3 cosas concretas con HERDR: instala el config en `~/.config/herdr/config.toml` como archivo editable, y actualiza Fish, Zsh y Nushell con lógica de startup para lanzar HERDR evitando sesiones anidadas de TMUX, ZELLIJ y HERDR_ENV.

Eso es todo. Vamos a replicar esas 3 cosas manualmente.

## 📋 Checklist de lo que haremos

```
✅ PASO 1 — Instalar el binario de HERDR
✅ PASO 2 — Crear el config.toml (igual que Gentleman.Dots)
✅ PASO 3 — Configurar el auto-start en tu shell
✅ PASO 4 — Instalar las integraciones de agentes
✅ PASO 5 — Verificar que todo funciona
```

## PASO 1 — Instalar el binario de HERDR

HERDR determina el path del config así: si la variable de entorno `HERDR_CONFIG_PATH` está definida, usa ese path. Si no, usa el directorio de config por defecto: `~/.config/herdr/config.toml`. Si el archivo no existe, HERDR usa sus valores por defecto internos.

Primero detecta tu arquitectura:

```bash
uname -m   # debe decir x86_64 o aarch64
uname -s   # debe decir Linux
```

Luego instala según tu arquitectura:

```bash
# Linux x86_64 (el más común)
curl -fsSL https://herdr.dev/install.sh | sh

# Si prefieres descarga directa manual (igual que hace Gentleman.Dots internamente):
# Linux x86_64:
curl -fsSL https://github.com/Gentleman-Programming/Gentleman.Dots/releases/latest/download/gentleman-installer-linux-amd64 -o gentleman.dots
# Linux ARM64 (Raspberry Pi, etc.):
curl -fsSL https://github.com/Gentleman-Programming/Gentleman.Dots/releases/latest/download/gentleman-installer-linux-arm64 -o gentleman.dots
```

⚠️ La forma más simple y directa sigue siendo:

```bash
curl -fsSL https://herdr.dev/install.sh | sh
```

Verificar:

```bash
herdr --version
```

Si no lo encuentra, agrega al PATH:

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
# o para zsh:
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && source ~/.zshrc
```

## PASO 2 — Crear el config.toml (igual que Gentleman.Dots)

HERDR funciona perfectamente sin un archivo de config. Solo necesitas crear uno cuando quieras keys personalizadas, temas, configuración de la sidebar, notificaciones o comportamiento avanzado.

Gentleman.Dots instala un config.toml preconfigurado con el tema Catppuccin (su tema por defecto). HERDR usa catppuccin como tema por defecto si no se especifica otro.

Genera y crea el archivo así:

```bash
# Crear el directorio de config
mkdir -p ~/.config/herdr

# Generar el config por defecto (igual al que instala Gentleman.Dots)
herdr --default-config > ~/.config/herdr/config.toml
```

Con `herdr --default-config > ~/.config/herdr/config.toml` obtienes un archivo de configuración auto-documentado. Si manejas dotfiles, solo necesitas trackear este único archivo.

Ahora edita el config para que quede exactamente como el de Gentleman.Dots:

```bash
# Abrir con tu editor favorito
nano ~/.config/herdr/config.toml
# o
vim ~/.config/herdr/config.toml
```

El config.toml completo equivalente al de Gentleman.Dots:

```toml
# ~/.config/herdr/config.toml
# Configuración equivalente a Gentleman.Dots

# ─── General ──────────────────────────────────────────────
onboarding = false        # Saltar el flujo de onboarding (ya configurado)
channel = "stable"        # Canal de actualizaciones

# ─── Tema (Gentleman.Dots usa Catppuccin por defecto) ─────
[ui]
theme = "catppuccin"      # opciones: catppuccin, gruvbox, nord, dracula

# ─── Sidebar ──────────────────────────────────────────────
[ui.sidebar]
enabled = true
position = "left"         # la sidebar va a la izquierda (estilo Gentleman)

# ─── Notificaciones de agentes ────────────────────────────
[notifications]
enabled = true

[notifications.sound]
enabled = true            # sonido cuando un agente termina o necesita input

# ─── Sesiones ─────────────────────────────────────────────
[session]
resume_agents_on_restore = true   # restaurar agentes al reconectar

# ─── Terminal ─────────────────────────────────────────────
[terminal]
scrollback_lines = 10000

# ─── Mouse ────────────────────────────────────────────────
[mouse]
enabled = true

# ─── Keybindings ──────────────────────────────────────────
[keys]
# Match tmux/Zellij-style prefix muscle memory.
prefix = "ctrl+a"

# Move between agents in the sidebar.
# Avoid Herdr's built-in prefix+shift+j/k pane-swap bindings.
previous_agent = "prefix+alt+k"
next_agent = "prefix+alt+j"

# Jump straight to agent N (1..9) as listed in the sidebar.
# Use Ctrl after the prefix: Alt+number is owned by skhd/yabai spaces,
# and Shift+number did not reach Herdr reliably in the current terminal setup.
focus_agent = "prefix+ctrl+1..9"
```

Verificar que el config es válido y aplicar cambios en caliente:

```bash
# Verificar que no hay errores de sintaxis
herdr server reload-config

# Ver el path exacto de tu config
herdr --help | grep config
```

HERDR soporta live reload de muchas configuraciones en runtime sin reiniciar el servidor ni los panes activos: los keybindings y la prefix key se re-parsean en vivo, el tema cambia los colores de la UI inmediatamente, y las políticas de UI como ancho de la sidebar, orden del panel de agentes, toasts y sonidos también se actualizan inmediatamente.

## PASO 3 — Configurar el auto-start en el shell

Gentleman.Dots actualiza Fish, Zsh y Nushell con lógica de startup para lanzar el multiplexor seleccionado evitando sesiones anidadas de TMUX, ZELLIJ y HERDR_ENV.

Aplica esto a tu shell manualmente:

### Para Bash (~/.bashrc):

```bash
cat >> ~/.bashrc << 'EOF'

# ── HERDR auto-start (equivalente a Gentleman.Dots) ──────
if [ -z "$HERDR_ENV" ] && [ -z "$TMUX" ] && [ -z "$ZELLIJ" ]; then
  if command -v herdr &>/dev/null; then
    exec herdr
  fi
fi
# ─────────────────────────────────────────────────────────
EOF
```

### Para Zsh (~/.zshrc):

```bash
cat >> ~/.zshrc << 'EOF'

# ── HERDR auto-start (equivalente a Gentleman.Dots) ──────
if [[ -z "$HERDR_ENV" && -z "$TMUX" && -z "$ZELLIJ" ]]; then
  if command -v herdr &>/dev/null; then
    exec herdr
  fi
fi
# ─────────────────────────────────────────────────────────
EOF
```

### Para Fish (~/.config/fish/config.fish):

```bash
cat >> ~/.config/fish/config.fish << 'EOF'

# ── HERDR auto-start (equivalente a Gentleman.Dots) ──────
if not set -q HERDR_ENV; and not set -q TMUX; and not set -q ZELLIJ
    if command -q herdr
        exec herdr
    end
end
# ─────────────────────────────────────────────────────────
EOF
```

### Para Nushell (~/.config/nushell/config.nu):

```bash
cat >> ~/.config/nushell/config.nu << 'EOF'

# ── HERDR auto-start (equivalente a Gentleman.Dots) ──────
if ($env | get -i HERDR_ENV | is-empty) and ($env | get -i TMUX | is-empty) and ($env | get -i ZELLIJ | is-empty) {
    if (which herdr | is-not-empty) {
        exec herdr
    }
}
# ─────────────────────────────────────────────────────────
EOF
```

Aplicar los cambios:

```bash
# Para bash
source ~/.bashrc

# Para zsh
source ~/.zshrc

# Para fish (se aplica automáticamente al abrir nueva terminal)
```

## PASO 4 — Instalar las integraciones de tus agentes

Ya tienes pi, opencode y antigravity. Instala sus integraciones exactamente como lo haría Gentleman.Dots:

```bash
# Instalar integración para Pi
herdr integration install pi

# Instalar integración para OpenCode
herdr integration install opencode

# Instalar integración para Antigravity
herdr integration install antigravity

# Verificar todas las integraciones
herdr integration status
```

Cuando el hook está actualizado y lanzas un agente dentro de un pane de HERDR, el hook notifica a HERDR de la información de sesión, que se refleja en el estado de la barra lateral.

## PASO 5 — Verificación final completa

```bash
# 1. Verificar binario
herdr --version

# 2. Verificar config
cat ~/.config/herdr/config.toml

# 3. Verificar integraciones
herdr integration status

# 4. Lanzar HERDR
herdr
```

Cuando lances HERDR verás esto, que es idéntico a lo que tendrías con Gentleman.Dots:

```
┌─ herdr ──────────────────────────────────────────────────┐
│                                          │ AGENTS         │
│  [workspace-1]                           │                │
│  ┌────────────────────────────────────┐  │ ● idle         │
│  │                                    │  │                │
│  │  $  _                              │  │                │
│  │                                    │  │                │
│  └────────────────────────────────────┘  │                │
│                                          │                │
│  [workspace-1]                           │                │
└──────────────────────────────────────────────────────────┘
```

## PASO 6 — Usar tus agentes dentro de HERDR

```bash
# Ya dentro de herdr:

# Pane 1: Pi
pi

# Ctrl+b | → split → Pane 2: OpenCode
opencode

# Ctrl+b | → split → Pane 3: Antigravity
antigravity
```

La característica más práctica de HERDR es el tracking de estado de agentes. Sin ella, manejar múltiples agentes AI concurrentes requiere cambiar entre panes para verificar el estado de cada uno. La vista de sidebar provee eso de un vistazo.

## 📊 Comparativa: Gentleman.Dots vs. Tutorial Manual

| Qué hace Gentleman.Dots | Equivalente manual en este tutorial |
|---|---|
| Instala el binario HERDR | `curl -fsSL https://herdr.dev/install.sh \| sh` |
| Crea `~/.config/herdr/config.toml` | `herdr --default-config > ~/.config/herdr/config.toml` |
| Tema Catppuccin por defecto | `theme = "catppuccin"` en el config |
| Parchea Fish/Zsh/Nushell para auto-start | Los bloques `if` que agregamos al shell |
| Evita sesiones anidadas | Las variables `$HERDR_ENV`, `$TMUX`, `$ZELLIJ` en el if |

✅ **Resultado:** Tienes exactamente el mismo setup que si hubieras usado Gentleman.Dots, pero sin instalar Neovim, LazyVim ni nada que no necesitas.

## 🔄 Cómo actualizar HERDR después

```bash
herdr update
```

Las instalaciones directas en Linux y macOS usan el canal `stable` por defecto.
