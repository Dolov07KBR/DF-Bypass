#!/bin/sh
# =========================================
# DF-Bypass — откат: восстанавливает конфиг zapret, который был до
# применения обходов, и перезапускает службу. Файлы в ZB_HOME сохраняются
# (резервные копии и профили); --purge удаляет всё.
# =========================================
ZB_HOME="${ZB_HOME:-/opt/df-bypass}"
ZB_CONF="${ZB_CONF:-/etc/config/zapret}"

if [ -f "$ZB_HOME/backup/original.conf" ]; then
    cp -f "$ZB_HOME/backup/original.conf" "$ZB_CONF"
    echo "Конфиг zapret восстановлен из резервной копии."
else
    echo "Резервная копия не найдена — конфиг не изменён."
fi

if [ -x /opt/zapret/sync_config.sh ]; then /opt/zapret/sync_config.sh >/dev/null 2>&1 || true; fi
if [ -x /etc/init.d/zapret ]; then /etc/init.d/zapret restart >/dev/null 2>&1 || true; fi

if [ "$1" = "--purge" ]; then
    rm -rf "$ZB_HOME"
    echo "Каталог $ZB_HOME удалён (--purge)."
fi
echo "Готово. DF-Bypass отключён; оригинальный Zapret-Manager не тронут."
