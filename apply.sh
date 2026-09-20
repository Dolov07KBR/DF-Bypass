#!/bin/sh
# =========================================
# DF-Bypass — применение новых обходов DPI (Telegram, WhatsApp, AI, игры)
# к zapret, установленному оригинальным Zapret-Manager (StressOzz).
#
# Стратегии собраны из рабочих схем сообщества bol-van/zapret (2025-2026):
# см. README.md и комментарии в profiles/*.opt. Всё точечное (ipset/hostlist),
# поэтому лишний трафик не трогается — задержка минимальна.
#
# Использование:
#   sh apply.sh [--yes]            применить (с подтверждением без --yes)
#   Переопределения для тестов: ZB_HOME, ZB_CONF, ZB_REPO_RAW
#
# Работает поверх оригинала: оригинальная стратегия сохраняется в конце
# цепочки как catch-all и восстанавливается uninstall.sh.
# =========================================
set -e
ZB_HOME="${ZB_HOME:-/opt/df-bypass}"
ZB_CONF="${ZB_CONF:-/etc/config/zapret}"
ZB_REPO_RAW="${ZB_REPO_RAW:-https://raw.githubusercontent.com/Dolov07KBR/DF-Bypass/main}"
YES=0
[ "$1" = "--yes" ] && YES=1

SRC_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ -d "$SRC_DIR/profiles" ]; then
    MODE="local"
else
    MODE="remote"
fi

say()  { printf "%s\n" "$*"; }
warn() { printf "⚠ %s\n" "$*"; }

[ "$(id -u 2>/dev/null || echo 0)" = "0" ] || warn "Рекомендуется запуск от root (на роутере обычно так и есть)."

say "=== DF-Bypass: обход DPI (Telegram / WhatsApp / AI / игры) ==="
say "Режим источников: $MODE · целевой конфиг: $ZB_CONF"

if [ ! -f "$ZB_CONF" ]; then
    warn "$ZB_CONF не найден. Сначала установите оригинальный Zapret-Manager:"
    say "  sh <(wget -qO - 'https://raw.githubusercontent.com/StressOzz/Zapret-Manager/main/Zapret-Manager.sh')"
    exit 1
fi

mkdir -p "$ZB_HOME/profiles" "$ZB_HOME/lists" "$ZB_HOME/ipsets" "$ZB_HOME/files" "$ZB_HOME/backup"

# ---------- 1. раскладываем файлы ----------
need="profiles/10_telegram.opt profiles/20_whatsapp.opt profiles/30_ai.opt profiles/40_games.opt profiles/90_base.opt
lists/telegram.hosts lists/ai.hosts
ipsets/telegram.cidr ipsets/whatsapp.cidr
files/quic_initial_www_google_com.bin files/tls_clienthello_www_google_com.bin"
for f in $need; do
    if [ "$MODE" = "local" ]; then
        cp -f "$SRC_DIR/$f" "$ZB_HOME/$f"
    else
        if [ ! -s "$ZB_HOME/$f" ]; then
            wget -q -T 10 -O "$ZB_HOME/$f" "$ZB_REPO_RAW/$f" || { warn "не удалось скачать $f"; exit 1; }
        fi
    fi
done
say "Файлы размещены в $ZB_HOME"

# ---------- 2. Wi-Fi/задержка: flow offloading ----------
if command -v uci >/dev/null 2>&1; then
    FO="$(uci get firewall.@defaults[0].flow_offloading 2>/dev/null || echo 0)"
    if [ "$FO" = "1" ]; then
        warn "Включен Flow Offloading — на Wi-Fi он ломает desync и добавляет лаги."
        if [ "$YES" = "1" ]; then FIX="y"; else printf "Отключить его сейчас (рекомендуется для Wi-Fi)? (y/n): "; read -r FIX; fi
        case "$FIX" in
            y|Y) uci set firewall.@defaults[0].flow_offloading='0'; uci set firewall.@defaults[0].flow_offloading_hw='0' 2>/dev/null || true
                 uci commit firewall; /etc/init.d/firewall reload 2>/dev/null || true
                 say "Flow Offloading отключён." ;;
        esac
    fi
fi

# ---------- 3. бэкап текущей стратегии (один раз) ----------
if [ ! -f "$ZB_HOME/backup/original.conf" ]; then
    cp -f "$ZB_CONF" "$ZB_HOME/backup/original.conf"
    say "Резервная копия исходного конфига: $ZB_HOME/backup/original.conf"
fi

ORIG_MARKER="$(grep -oE '^#(v|Yv|Gv|Dv|DFB)[0-9]*' "$ZB_CONF" 2>/dev/null | tail -1)"

# ---------- 4. собираем новую стратегию ----------
NEW_OPT="#DFB1
"
for p in 10_telegram 20_whatsapp 30_ai 40_games 90_base; do
    BLOCK="$(sed "s|@ZB@|$ZB_HOME|g" "$ZB_HOME/profiles/$p.opt" | grep -v '^#' | grep -v '^$')"
    NEW_OPT="${NEW_OPT}${BLOCK}
--new
"
done

# оригинальная стратегия — в конец как catch-all (если была и это не наш маркер)
case "$ORIG_MARKER" in
    ""|"#DFB1") : ;;
    *)
        BODY="$(awk -v m="$ORIG_MARKER" 'f{print} $0==m{f=1}' "$ZB_HOME/backup/original.conf")"
        if [ -n "$BODY" ]; then
            NEW_OPT="${NEW_OPT}${BODY}
"
        fi
        ;;
esac

# ---------- 5. пишем конфиг ----------
TMP_NEW="$ZB_HOME/backup/config.new"
if [ -n "$ORIG_MARKER" ]; then
    # голова файла: всё до первого маркера
    awk '/^#(v|Yv|Gv|Dv|DFB)[0-9]*$/{exit} {print}' "$ZB_CONF" > "$TMP_NEW"
else
    cat "$ZB_CONF" > "$TMP_NEW"
fi
printf "%s" "$NEW_OPT" >> "$TMP_NEW"
cp -f "$TMP_NEW" "$ZB_CONF"
say "Стратегия #DFB1 записана в $ZB_CONF"

# ---------- 6. применение ----------
if [ -x /opt/zapret/sync_config.sh ]; then /opt/zapret/sync_config.sh >/dev/null 2>&1 || true; fi
if [ -x /etc/init.d/zapret ]; then /etc/init.d/zapret restart >/dev/null 2>&1 || true; say "Служба zapret перезапущена."; fi

say ""
say "✔ Применено: Telegram (сообщения/медиа/звонки), WhatsApp (+звонки), AI-сервисы, игры."
say "  Проверьте работу; откат — sh uninstall.sh (или пункт PLUS)."
say "  Автор: @Dolov07KBR · https://github.com/Dolov07KBR/DF-Bypass"
