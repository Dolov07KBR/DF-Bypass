#!/bin/sh
# =========================================
# DF-Bypass — автотесты на fake-rootfs (без роутера).
# Запуск: sh tests/run_tests.sh
# =========================================
cd "$(dirname "$0")/.."
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ✅ $1"; }
bad() { FAIL=$((FAIL+1)); echo "  ❌ $1 — $2"; }
check() { if [ "$2" -eq 0 ]; then ok "$1"; else bad "$1" "условие не выполнено"; fi; }

echo "1. Синтаксис"
SYN=0
for f in apply.sh uninstall.sh; do
    sh -n "$f" || { SYN=1; bad "sh -n $f" "syntax"; }
done
[ "$SYN" -eq 0 ] && ok "apply.sh и uninstall.sh проходят sh -n"

echo "2. Применение и откат на fake-rootfs"
T="$(mktemp -d)"
export ZB_HOME="$T/dfb"
export ZB_CONF="$T/zapret.conf"
mkdir -p "$T"
cat > "$ZB_CONF" <<'EOF'
config zapret
	option enabled '1'
#v7
--filter-tcp=80,443 --dpi-desync=fake,split
--new
EOF

sh apply.sh --yes >/dev/null 2>&1
RC=$?
check "apply.sh отработал без ошибок" $RC
grep -q "^#DFB1$" "$ZB_CONF"
check "маркер #DFB1 записан в конфиг" $?
grep -q "ipsets/whatsapp.cidr" "$ZB_CONF" && grep -q "dpi-desync-repeats=11" "$ZB_CONF"
check "обход WhatsApp (split2/QUIC) на месте" $?
grep -q "lists/ai.hosts" "$ZB_CONF" && grep -q "split-tls=sniext" "$ZB_CONF"
check "обход AI (SNI-split) на месте" $?
grep -q "filter-l7=discord,stun" "$ZB_CONF"
check "игровой обход на месте" $?
grep -q "lists/telegram.hosts" "$ZB_CONF" && grep -q "ipsets/telegram.cidr" "$ZB_CONF"
check "обход Telegram на месте" $?
grep -q -- "--dpi-desync=fake,split" "$ZB_CONF"
check "оригинальная стратегия сохранена как catch-all" $?
grep -q "autottl=2" "$ZB_CONF"
check "низкозадержечные параметры (autottl=2) на месте" $?
[ -f "$ZB_HOME/backup/original.conf" ]
check "резервная копия создана" $?

sh uninstall.sh >/dev/null 2>&1
grep -q "^#v7$" "$ZB_CONF" && ! grep -q "^#DFB1$" "$ZB_CONF"
check "uninstall восстанавливает исходную стратегию" $?

rm -rf "$T"
echo ""
echo "============================================================"
echo "ИТОГО: $PASS успешно, $FAIL ошибок"
[ "$FAIL" -eq 0 ] && echo "Все проверки пройдены ✅" || exit 1
