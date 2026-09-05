# Instalar terminal-browser con el plugin de Herdr

Guía para Linux Mint. Objetivo: usar `terminal-browser` dentro de Herdr con
renderizado real (kitty graphics), reemplazando la sesión previa donde se veía
todo en negro.

## Por qué se veía negro

- `terminal-browser` dibuja imágenes en la terminal vía protocolo gráfico kitty.
- GNOME Terminal (la terminal default de Mint) no soporta ese protocolo.
- Herdr sí soporta kitty graphics (setting `kitty_graphics` en su config), pero
  si la terminal host no pinta, no hay nada que hacer.

Conclusión: se necesita una terminal compatible (kitty, Ghostty o WezTerm).

## Pasos

### 1. Instalar kitty — ✅ hecho (kitty 0.32.2)

```bash
sudo apt install kitty
```

### 2. Instalar la CLI de terminal-browser

```bash
curl -fsSL https://terminal-browser.sh/install | bash
```

Requiere versión >= 0.5.1 (es la que agregó soporte para Herdr).
No necesita Bun ni Chrome: trae su propio runtime Electron.

Verificar:

```bash
terminal-browser --version
```

### 3. Instalar el plugin de Herdr

```bash
herdr plugin install zenbu-labs/terminal-browser/herdr-plugin
```

El plugin registra una acción `open-split` que abre el navegador en un pane
split a la derecha del pane enfocado.

### 4. Abrir Herdr dentro de kitty

Importante: lanzar Herdr desde kitty (no desde GNOME Terminal), si no, vuelve
el problema original.

En el primer uso, la integración de terminal-browser detecta Herdr y habilita
automáticamente `kitty_graphics = true` en `~/.config/herdr/config.toml`,
recargando la config del server (`herdr server reload-config`). Si hiciera
falta, se puede habilitar a mano y recargar.

## Uso básico

```bash
terminal-browser                      # lanza el navegador
terminal-browser open <url>           # abre el navegador en una url
terminal-browser --split right        # abre en un split a la derecha
terminal-browser ls                   # lista navegadores abiertos
terminal-browser action               # CLI estilo agent-browser para
                                      # interactuar con navegadores abiertos
```

Casos de uso:

- Un agente de código y un sitio web en el mismo tab de terminal.
- El agente interactúa con los navegadores abiertos vía `terminal-browser action`.
- Previsualizar HTML local generado por el agente en un split al lado.
- Funciona sobre SSH (`--ssh <user@host>`) para previsualizar sitios corriendo
  en máquinas remotas.

## Estado de esta instalación (2026-08-25)

| Paso                              | Estado |
| --------------------------------- | ------ |
| kitty                             | ✅ 0.32.2 |
| CLI terminal-browser              | ✅ v0.6.0 |
| Plugin de Herdr                   | ✅ zenbu-labs.terminal-browser v0.1.1 (enabled) |
| `kitty_graphics = true` en config | ✅ (~/.config/herdr/config.toml) |
| Probar Herdr dentro de kitty      | ⬜ pendiente |
