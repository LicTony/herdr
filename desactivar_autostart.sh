#!/bin/bash
# Script para desactivar temporalmente el autostart de HERDR y permitir su actualización

mkdir -p "$HOME/.config/herdr"
touch "$HOME/.config/herdr/disable-autostart"

echo "=========================================================="
echo "✔ Autostart de HERDR desactivado temporalmente."
echo "=========================================================="
echo "Instrucciones para actualizar:"
echo "1. Salí de tu sesión actual de HERDR (por ejemplo, cerrando la terminal o con tu shortcut para desasociar)."
echo "2. Abrí una nueva terminal o entrá por TTY. Ahora no se iniciará HERDR automáticamente."
echo "3. Ejecutá el comando para actualizar:"
echo "   herdr update"
echo "4. Una vez actualizado, ejecutá el script para restaurar el comportamiento por defecto:"
echo "   ./activar_autostart.sh"
echo "=========================================================="
