#!/bin/sh
# =========================================
# DF-Bypass WhatsApp — самостоятельный скрипт обхода блокировки WhatsApp
# для роутеров с zapret (OpenWrt). Диапазоны вшиты в стратегию (--ipset-ip),
# фейк-файлы докачиваются сами, ваш текущий обход сохраняется и остаётся
# работать для остального трафика.
#
# Установка и применение одной командой:
#   sh <(wget -qO - 'https://raw.githubusercontent.com/Dolov07KBR/DF-Bypass/main/whatsapp.sh')
# Откат:   sh whatsapp.sh --uninstall
# Проверка: sh whatsapp.sh --status
# Переопределения для тестов: WA_CONF, WA_HOME
#
# Автор: @Dolov07KBR
# =========================================

WA_HOME="${WA_HOME:-/opt/df-bypass}"
WA_CONF="${WA_CONF:-/etc/config/zapret}"
RAW="https://raw.githubusercontent.com/Dolov07KBR/DF-Bypass/main"
MARKER="#DFB9"
FAKE_DIR="/opt/zapret/files/fake"
FAKE_TLS="$FAKE_DIR/tls_clienthello_www_google_com.bin"
FAKE_QUIC="$FAKE_DIR/quic_initial_www_google_com.bin"
IPSET="31.13.64.0/18,57.144.0.0/14,129.134.0.0/17,157.240.0.0/16,163.70.128.0/17"

say()  { printf "%s\n" "$*"; }
ok()   { printf "✔ %s\n" "$*"; }
warn() { printf "⚠ %s\n" "$*"; }
err()  { printf "✖ %s\n" "$*"; }

# ---------- фейк-файлы (скачиваются сами, если их нет) ----------
ensure_fake() {
    # $1 = путь, $2 = имя в репозитории
    [ -s "$1" ] && return 0
    mkdir -p "$(dirname "$1")" 2>/dev/null || true
    wget -q -T 10 -O "$1" "$RAW/files/$2" 2>/dev/null && ok "Скачан $2" || warn "Не удалось скачать $2 (обход может работать хуже)"
}

# ---------- проверка работы ватсапа ----------
check_whatsapp() {
    say "Проверяем доступность WhatsApp (с роутера)..."
    if curl -m 10 -sI https://web.whatsapp.com >/dev/null 2>&1; then
        ok "web.whatsapp.com доступен — обход работает!"
    else
        err "web.whatsapp.com пока недоступен."
        warn "Если включён Flow Offloading — отключите его (иначе десинк не видит трафик):"
        say  "  uci set firewall.@defaults[0].flow_offloading='0'; uci commit firewall; /etc/init.d/firewall reload"
        warn "Либо попробуйте другой вариант стратегии (пункт меню 11 в Zapret Manager PLUS)."
    fi
}

# ---------- применение ----------
apply() {
    [ "$(id -u 2>/dev/null || echo 0)" = "0" ] || warn "Рекомендуется запуск от root."
    [ -f "$WA_CONF" ] || { err "$WA_CONF не найден. Сначала установите zapret (оригинальный Zapret-Manager)."; exit 1; }
    [ -f /etc/init.d/zapret ] || warn "/etc/init.d/zapret не найден — конфиг будет записан, но служба не перезапустится."

    say "=== DF-Bypass: обход WhatsApp (только диапазоны Meta) ==="
    ensure_fake "$FAKE_TLS" "tls_clienthello_www_google_com.bin"
    ensure_fake "$FAKE_QUIC" "quic_initial_www_google_com.bin"

    mkdir -p "$WA_HOME/backup" 2>/dev/null || true
    if [ ! -f "$WA_HOME/backup/original.conf" ]; then
        cp -f "$WA_CONF" "$WA_HOME/backup/original.conf" 2>/dev/null && ok "Резервная копия: $WA_HOME/backup/original.conf"
    fi

    CUR_MARKER="$(grep -oE '^#(v|Yv|Gv|Dv|DFB)[0-9]*' "$WA_CONF" 2>/dev/null | tail -1)"
    # если уже применён наш маркер — берём чистое тело из бэкапа, чтобы не дублировать
    if [ "$CUR_MARKER" = "$MARKER" ] && [ -f "$WA_HOME/backup/original.conf" ]; then
        SRC="$WA_HOME/backup/original.conf"
        CUR_MARKER="$(grep -oE '^#(v|Yv|Gv|Dv|DFB)[0-9]*' "$SRC" 2>/dev/null | tail -1)"
        say "Обход уже применялся — обновляю поверх резервной копии."
    else
        SRC="$WA_CONF"
    fi

    TMP_NEW="$WA_HOME/backup/config.new"
    mkdir -p "$(dirname "$TMP_NEW")" 2>/dev/null || TMP_NEW="/tmp/dfb-wa.conf"
    # голова файла: всё до первого маркера
    awk '/^#(v|Yv|Gv|Dv|DFB)[0-9]*$/{exit} {print}' "$SRC" > "$TMP_NEW"
    {
        echo "$MARKER"
        echo "--filter-tcp=443,5222"
        echo "--ipset-ip=$IPSET"
        echo "--dpi-desync=split2"
        echo "--dpi-desync-split-seqovl=681"
        echo "--dpi-desync-split-pos=1,midsld"
        echo "--dpi-desync-split-seqovl-pattern=$FAKE_TLS"
        echo "--new"
        echo "--filter-udp=443"
        echo "--ipset-ip=$IPSET"
        echo "--dpi-desync=fake"
        echo "--dpi-desync-repeats=11"
        echo "--dpi-desync-any-protocol"
        echo "--dpi-desync-cutoff=d4"
        echo "--dpi-desync-fake-quic=$FAKE_QUIC"
        echo "--new"
        echo "--filter-udp=590-1400,3478,3482"
        echo "--filter-l7=stun"
        echo "--dpi-desync=fake"
        echo "--dpi-desync-fake-quic=$FAKE_QUIC"
        echo "--new"
    } >> "$TMP_NEW"
    # ваша прежняя стратегия — после обхода ватсапа (для остального трафика)
    if [ -n "$CUR_MARKER" ]; then
        awk -v m="$CUR_MARKER" 'f{print} $0==m{f=1}' "$SRC" >> "$TMP_NEW"
    fi
    cp -f "$TMP_NEW" "$WA_CONF"
    ok "Стратегия $MARKER записана в $WA_CONF"

    # дописываем нужные порты, если их нет (по образцу оригинального менеджера)
    if grep -q "option NFQWS_PORTS_UDP '" "$WA_CONF"; then
        grep -q "option NFQWS_PORTS_UDP '.*590-1400" "$WA_CONF" || \
            sed -i "/option NFQWS_PORTS_UDP '/s/'$/,590-1400,3478,3482'/" "$WA_CONF"
    fi
    if grep -q "option NFQWS_PORTS_TCP '" "$WA_CONF"; then
        grep -q "option NFQWS_PORTS_TCP '.*5222" "$WA_CONF" || \
            sed -i "/option NFQWS_PORTS_TCP '/s/'$/,5222'/" "$WA_CONF"
    fi

    # Flow Offloading — главный враг десинка на Wi-Fi
    if command -v uci >/dev/null 2>&1; then
        FO="$(uci get firewall.@defaults[0].flow_offloading 2>/dev/null || echo 0)"
        if [ "$FO" = "1" ]; then
            warn "Включён Flow Offloading — отключаю (иначе обход не работает по Wi-Fi)."
            uci set firewall.@defaults[0].flow_offloading='0' 2>/dev/null || true
            uci set firewall.@defaults[0].flow_offloading_hw='0' 2>/dev/null || true
            uci commit firewall 2>/dev/null || true
            /etc/init.d/firewall reload >/dev/null 2>&1 || true
            ok "Flow Offloading отключён."
        fi
    fi

    if [ -x /opt/zapret/sync_config.sh ]; then /opt/zapret/sync_config.sh >/dev/null 2>&1 || true; fi
    if [ -x /etc/init.d/zapret ]; then /etc/init.d/zapret restart >/dev/null 2>&1 || true; ok "Служба zapret перезапущена."; fi

    [ -x /etc/init.d/zapret ] && check_whatsapp
    say ""
    say "Готово. Обход действует только на диапазоны Meta (WhatsApp, звонки, медиа)."
    say "Остальной трафик обрабатывает ваша прежняя стратегия — она не тронута."
    say "Откат: sh <(wget -qO - '$RAW/whatsapp.sh') -- --uninstall"
}

# ---------- откат ----------
uninstall() {
    if [ -f "$WA_HOME/backup/original.conf" ]; then
        cp -f "$WA_HOME/backup/original.conf" "$WA_CONF"
        ok "Конфиг восстановлен из резервной копии."
    else
        warn "Резервная копия не найдена — удаляю блок $MARKER вручную."
        [ -f "$WA_CONF" ] || { err "$WA_CONF не найден"; exit 1; }
        # удаляем маркер и идущие подряд строки нашего блока до первой «чужой» строки
        awk -v m="$MARKER" '
            $0==m {skip=1; next}
            skip && /^(--new|--filter-tcp=443,5222|--ipset-ip=31\.13|--dpi-desync=split2|--dpi-desync-split-seqovl=681|--dpi-desync-split-pos=1,midsld|--dpi-desync-split-seqovl-pattern=|--filter-udp=443|--dpi-desync=fake|--dpi-desync-repeats=11|--dpi-desync-any-protocol|--dpi-desync-cutoff=d4|--dpi-desync-fake-quic=|--filter-udp=590-1400|--filter-l7=stun)$/ {next}
            {skip=0; print}
        ' "$WA_CONF" > "$WA_CONF.tmp" && cp -f "$WA_CONF.tmp" "$WA_CONF"; rm -f "$WA_CONF.tmp"
    fi
    if [ -x /opt/zapret/sync_config.sh ]; then /opt/zapret/sync_config.sh >/dev/null 2>&1 || true; fi
    if [ -x /etc/init.d/zapret ]; then /etc/init.d/zapret restart >/dev/null 2>&1 || true; fi
    say "Обход WhatsApp отключён. Автор: @Dolov07KBR"
}

# ---------- статус ----------
status() {
    if grep -q "^$MARKER" "$WA_CONF" 2>/dev/null; then
        ok "Обход WhatsApp ($MARKER) применён."
    else
        warn "Обход WhatsApp сейчас не применён."
    fi
    check_whatsapp
}

case "$1" in
    --uninstall|uninstall) uninstall ;;
    --status|status) status ;;
    *) apply ;;
esac
