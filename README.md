<p align="center">
  <img src="assets/logo.png" alt="DF логотип" width="150">
</p>

<h1 align="center">DF-Bypass — новые обходы DPI для роутера</h1>

<p align="center">
  <b>WhatsApp · Telegram · онлайн-игры · заблокированные AI-сервисы</b><br>
  Готовые стратегии для zapret (OpenWrt-роутер, работает по Wi-Fi для всех устройств),
  собранные из рабочих схем сообщества 2025–2026 и оформленные так, чтобы
  применяться одной командой и откатываться без следов.
</p>

<p align="center">
  <b>Автор: <a href="https://github.com/Dolov07KBR">@Dolov07KBR</a></b> · сайт: <a href="https://dolov07kbr.github.io">dolov07kbr.github.io</a>
</p>

---

## ⚡ Установка и применение — одна команда

Требуется установленный zapret (например, через оригинальный
[Zapret-Manager](https://github.com/StressOzz/Zapret-Manager)):

```sh
sh <(wget -qO - 'https://raw.githubusercontent.com/Dolov07KBR/DF-Bypass/main/apply.sh') -- --yes
```

или с подтверждением и проверкой Wi‑Fi:

```sh
sh <(wget -qO - 'https://raw.githubusercontent.com/Dolov07KBR/DF-Bypass/main/apply.sh')
```

Из Zapret Manager PLUS это пункт меню **11) DF-Bypass**.

## ❌ Откат и удаление

Вернуть прежнюю стратегию (файлы профиля остаются, можно применить снова):

```sh
sh <(wget -qO - 'https://raw.githubusercontent.com/Dolov07KBR/DF-Bypass/main/uninstall.sh')
```

Полное удаление — откат стратегии **и** стирание всех файлов (`/opt/df-bypass`):

```sh
sh <(wget -qO - 'https://raw.githubusercontent.com/Dolov07KBR/DF-Bypass/main/uninstall.sh') -- --purge
```

Обе команды перезапускают службу zapret автоматически; оригинальный
Zapret-Manager при этом не трогается.

## 🧠 Что внутри и почему это работает

| Профиль | Механизм (рабочие схемы сообщества, 2025–2026) |
|---|---|
| `profiles/10_telegram.opt` | TCP по ipset Telegram: `fake,split2 + autottl=2 + badseq`; QUIC-медиа: `fake + repeats=5`; **звонки**: STUN-порты `590-1400,3478` + `filter-l7=stun` (схемы из bol-van/zapret #1668, #1860) |
| `profiles/20_whatsapp.opt` | TCP `443,5222` по ipset WhatsApp: `split2 + seqovl=681 + pos=1,midsld` с паттерном; UDP/QUIC: `fake + repeats=11 + any-protocol + cutoff=d4`; звонки — STUN (bol-van/zapret #1908) |
| `profiles/30_ai.opt` | Все заблокированные AI (ChatGPT, Claude, Gemini, Copilot, Perplexity, Midjourney...): `fake,split2 + split-tls=sniext` — разрез внутри SNI ClientHello |
| `profiles/40_games.opt` | Новый игровой обход: discord/stun-диапазоны, высокие UDP (`fake,tamper,any-protocol`), типовые порты игр с `repeats=2` (минимум задержки), игровые TCP с `autottl=2` |
| `profiles/90_base.opt` | Низкозадержечный catch-all для остального трафика |

Данные для точечного применения:
- `ipsets/telegram.cidr` — актуальные префиксы AS Telegram (RIPEstat) + каноничные диапазоны;
- `ipsets/whatsapp.cidr` — крупные префиксы AS32934 (Meta) + WhatsApp-диапазоны;
- `lists/telegram.hosts`, `lists/ai.hosts` — домены для SNI-фильтров;
- `files/` — fake-пакеты QUIC/TLS (из bol-van/zapret), чтобы обман DPI выглядел как обычный трафик.

## 📱 Отдельный обход только для WhatsApp — файл для Zapret-Manager

Если нужен **только WhatsApp**, без всего остального — в репозитории лежит
готовый файл в нативном формате оригинального
[Zapret-Manager](https://github.com/StressOzz/Zapret-Manager)
(как его `StrYoutube` / `/root/custom_test.txt`):

- `files/zapret-manager/StrWhatsapp` — 5 вариантов обхода (`#Yv90`–`#Yv94`):
  `split2+seqovl=681`, `hostfakesplit`, `fake,split2+badseq`, комбо
  «сообщения + звонки + медиа», `multisplit+QUIC`;
- IP-диапазоны WhatsApp (префиксы Meta: 31.13.64.0/18, 57.144.0.0/14,
  129.134.0.0/17, 157.240.0.0/16, 163.70.128.0/17) вшиты прямо в стратегии
  через `--ipset-ip=` — **никаких дополнительных файлов не нужно**.
  (`ipset-whatsapp.txt` оставлен для тех, кто предпочитает `--ipset=<файл>`.)

**Интеграция — одна команда на роутере:**

```sh
wget -qO /root/custom_test.txt 'https://raw.githubusercontent.com/Dolov07KBR/DF-Bypass/main/files/zapret-manager/StrWhatsapp'
```

Далее в меню Zapret-Manager: **Стратегии → стратегии для YouTube → 3) Тестировать
стратегии из /root/custom_test.txt** — переберите варианты, рабочий применится
к вашей текущей стратегии отдельным блоком `--new` (основной обход не ломается).

Вручную конкретный блок можно дописать в конец `option NFQWS_OPT` в
`/etc/config/zapret` перед закрывающей кавычкой — формат строк тот же, что у
штатных стратегий менеджера.

### ⚠️ Как читать общий тест и проверять правильно

Общий тест менеджера гоняет ~60 URL (instagram, discord, торренты, зарубежные
серверы и т.п.). Обход «только для WhatsApp» точечный — он трогает **только**
диапазоны Meta, поэтому дискорд/торренты/прочее на нём падает по определению
(для всего разом — пункт 11 «DF-Bypass» в PLUS или полный DF-Bypass).

Правильная проверка именно этого обхода:

```sh
curl -m 10 -sI https://web.whatsapp.com | head -3   # с роутера
ps | grep nfqws                                      # демон запущен?
```

…и главное — приложение на телефоне: сообщения и звонки. Если не работает —
проверьте, что в роутере выключен Flow Offloading (иначе десинк не видит
трафик, особенно по Wi-Fi).

## 📶 Wi-Fi и низкая задержка

- **Точечные фильтры** (ipset/hostlist/порты) — лишний трафик не трогается, значит нет лишней обработки и задержки.
- **autottl=2 и малые repeats** в профилях игр/базы — цена обмана DPI по времени минимальна.
- **Flow Offloading**: `apply.sh` сам предложит отключить его на роутере — на Wi-Fi он ломает desync и добавляет лаги.
- Роутер применяет обход ко **всем** устройствам в сети, включая Wi‑Fi-клиенты: телефону/ноутбуку ничего ставить не нужно.

## 🔧 Совместимость

- Работает поверх оригинального Zapret-Manager: ничего не патчит, вашу прежнюю
  стратегию сохраняет в конец цепочки и восстанавливает при откате;
- маркер активной стратегии — `#DFB1` (понимается Zapret Manager PLUS v2.1+);
- POSIX sh / busybox ash; тесты — `tests/run_tests.sh` (fake-rootfs, 11 проверок).

## ⚠️ Дисклеймер

Инструмент для легального использования (доступ к своим сервисам, работе, учёбе).
Блокировки эволюционируют — если схема перестала работать, обновите репозиторий
и/или напишите в issues; профили обновляются независимо от PLUS.

---

<p align="center"><i>© 2026 <a href="https://github.com/Dolov07KBR">Dolov07KBR</a> · DF-Bypass</i></p>
