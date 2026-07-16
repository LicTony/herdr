# Guía Rápida de Actualización de HERDR (v2)

Cuando intentás actualizar HERDR ejecutando `herdr update` dentro de una sesión activa de terminal multiplexada por el mismo, el sistema fallará con el siguiente error:
> `update failed: run herdr update outside herdr after detaching from the session`

### Cómo actualizar ahora

1. Dentro de HERDR (en cualquiera de tus paneles activos), ejecutá el script para desactivar el autostart:
   `/home/siranthony/Infraestructura/herdr/desactivar_autostart.sh`

2. Salí de HERDR (cerrando las terminales o desasociando la sesión).
3. Abrí una terminal nueva o TTY. Verás que ahora entrás directamente a tu shell normal.
4. Ejecutá la actualización:
   `herdr update`

5. Restaurá el comportamiento por defecto ejecutando:
   `/home/siranthony/Infraestructura/herdr/activar_autostart.sh`
