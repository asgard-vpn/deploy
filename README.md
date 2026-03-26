# ⚡ Asgard Deploy

**Ansible-инфраструктура для развёртывания распределённой VPN-платформы на базе [Remnawave](https://github.com/remnawave/remnawave).**

---

## 📋 О проекте

Asgard Deploy — это набор Ansible playbook для автоматизированного развёртывания и управления инфраструктурой VPN-сервиса. Система поддерживает многоуровневую архитектуру с центральным сервером (main), релейными нодами (relays) и MTProto-прокси для Telegram (tgproxy).

### Архитектура

```
                    ┌─────────────────────────────────────────┐
                    │              MAIN SERVER                │
                    │  Remnawave • Config Distributor         │
                    │  PostgreSQL • HAProxy • Ruleset Manager │
                    └──────────────────┬──────────────────────┘
                                       │
          ┌────────────────────────────┼────────────────────────────┐
          │                            │                            │
          ▼                            ▼                            ▼
┌─────────────────┐          ┌─────────────────┐          ┌─────────────────┐
│     RELAYS      │          │     TGPROXY     │          │ RELAY_MINIMAL    │
│ Hysteria • TUIC │          │   MTProto       │          │ (ex-hole)       │
│ Shadowsocks •   │          │   Telemt        │          │ Только remnanode │
│ Amnezia • OC    │          │                 │          │ клиент→hole→relay│
└─────────────────┘          └─────────────────┘          └─────────────────┘
```

**Роли серверов:**

- **`main`** — центральный сервер управления. Не принимает VPN-подключения от конечных клиентов, но выполняет функции координатора: хранение учётных записей пользователей, выдача подписок (списки URL для подключения), раздача конфигураций на роутеры и клиентские приложения. Принимает соединения от relay-нод и поставляет им конфигурации для X-Ray и sing-box.

- **`relay`** — шлюз, принимающий VPN-подключения от пользователей. Поддерживаются протоколы на базе X-Ray/sing-box (VLESS, TUIC, Hysteria2, Shadowsocks), AmneziaWG и OpenConnect (ocserv).

- **`tgproxy`** — отдельный узел с MTProto Proxy для обхода блокировок Telegram. Может быть связан туннелем с relay (в разработке).

**Расширения Remnawave:**

Remnawave базируется на ядре XRay. Протоколы TUIC, AmneziaWG и OpenConnect в нём не реализованы. Их поддержка добавлена за счёт дополнительных сервисов:

- **`config-distributor`** — работает на main: принимает запросы от relay-нод и отдаёт им конфигурации для sing-box, AmneziaWG и ocserv.

- **`node-agent`** — запускается на каждой relay-ноде параллельно с remnanode: получает конфигурации от config-distributor и применяет их (перезагрузка sing-box, синхронизация клиентов Amnezia, обновление пользователей ocserv).

Эти сервисы можно отключить переменными `enable_config_distributor` и `enable_node_agent`, если используются только встроенные в Remnawave протоколы.

---

## 🛠 Требования

- **Ansible** ≥ 2.15
- **Python** 3.10+
- Коллекции: `community.docker`, `community.general`, `geerlingguy.certbot`, `kwoodson.yedit`

```bash
ansible-galaxy install -r requirements.yml  # если есть
# или вручную:
ansible-galaxy collection install community.docker community.general
ansible-galaxy role install geerlingguy.certbot kwoodson.yedit
```

---

## 🚀 Быстрый старт

> **Документация Remnawave:** [Обзор](https://docs.rw) · [Quick Start](https://docs.rw/docs/overview/quick-start) · [Panel](https://docs.rw/docs/install/remnawave-panel) · [Node](https://docs.rw/docs/install/remnawave-node) · [Reverse Proxy](https://docs.rw/docs/install/reverse-proxies) · [Subscription Page](https://docs.rw/docs/install/remnawave-subscription-page)

### 1. Клонирование и настройка инвентаря

Шаблон — каталог **`deploy.example/`** в корне репозитория. Рабочая копия — **`deploy/`** (каталог в `.gitignore`, в git не попадает). Playbook’и по умолчанию берут инвентарь из `deploy/inventory` и секреты из `deploy/secrets.enc` (см. `run_playbook.sh`).

```bash
git clone <repository-url>
cd deploy

# Рабочий каталог deploy/ ещё не должен существовать
cp -a deploy.example deploy
```

### 2. Заполнение конфигурации

**`deploy/inventory/hosts.yml`** — хосты, домены. Редактируйте под свою инфраструктуру.

**`deploy/inventory/group_vars/`** — переменные по группам (порты, домены маскировки и т.д.):
- `all.yml` — общие значения по умолчанию
- `main.yml` — main; опционально: `enable_config_distributor`, `enable_ruleset_manager`.
- `relays.yml` — relays; опционально: `enable_ocserv`, `enable_amnezia`, `enable_warp`, `enable_sing_box`, `enable_pingtunnel`, `enable_node_agent`
- `relay_minimal.yml` — минимальные relay (ex-hole): все `enable_*` отключены
- `tgproxy.yml` — tgproxy (Telegram MTProxy)

**`deploy/fallback/`** — кастомные заглушки HAProxy. Положите `index.html` и/или `403.html` для переопределения дефолтов из `fallback/` в корне репозитория.

**`deploy/secrets.enc`** — пароли и секреты. Заполните значения (в т.ч. `postgres_password`, `metrics_user`, `metrics_pass` для main), затем зашифруйте:

```bash
ansible-vault encrypt deploy/secrets.enc
```

### 3. Первичная настройка нового сервера

Для **нового** VPS (root по SSH на 22 порту):

```bash
./init_server.sh <hostname> --ask-pass
```

Playbook создаст пользователя `admin`, настроит SSH (порт 1122), UFW, Docker, fail2ban и перезагрузит сервер при необходимости.

**Опционально — аутентификация по ключам:** задайте в `deploy/inventory/group_vars/all.yml` или `host_vars`:

```yaml
asgard_ssh_public_keys:
  - "ssh-ed25519 AAAAC3... ваш_email"
  # или: "{{ lookup('file', lookup('env', 'HOME') + '/.ssh/id_ed25519.pub') }}"
asgard_ssh_disable_password_auth: false  # true — отключить пароль (только после проверки входа по ключу!)
```

Запустите `init_server` — ключи будут добавлены пользователю `admin`. Перед `asgard_ssh_disable_password_auth: true` обязательно проверьте вход по ключу. Для Ansible добавьте в `deploy/inventory/hosts.yml`: `ansible_ssh_private_key_file: ~/.ssh/id_ed25519` (и при необходимости `--ask-become-pass` для sudo).

### 4. Установка SSL-сертификатов

После `init_server` обновите в `deploy/inventory/hosts.yml` порт SSH на 1122 (или свой) и выполните:

```bash
./init_web_certs.sh <hostname>
```

### 5. Деплой по группам

```bash
# Центральный сервер
./run_playbook.sh asgard_deploy_main.yml

# Реле (Hysteria, TUIC, Shadowsocks, Amnezia, ocserv)
# Минимальные relay (ex-hole) — группа relay_minimal в inventory с отключёнными сервисами
./run_playbook.sh asgard_deploy_relay.yml

# MTProto для Telegram
./run_playbook.sh asgard_deploy_tgproxy.yml
```

### 6. Настройка обфускации трафика AmneziaWG (AWG 2.0)

Параметры обфускации для relay-шаблона задаются через переменные Ansible и подставляются в `templates/relay.amnezia.env.j2`:

- `awg_jc`, `awg_jmin`, `awg_jmax`
- `awg_s1`, `awg_s2`, `awg_s3`, `awg_s4`
- `awg_h1`, `awg_h2`, `awg_h3`, `awg_h4`
- `awg_i1`, `awg_i2`, `awg_i3`, `awg_i4`, `awg_i5`

Если переменные не заданы в inventory, используются дефолты из шаблона.

Рекомендуется задавать значения в `deploy/inventory/group_vars/relays.yml` (или точечно в `host_vars`).

**Пример 1: базовый профиль AWG 2.0 (QUIC-like)**

```yaml
# deploy/inventory/group_vars/relays.yml
awg_jc: 7
awg_jmin: 50
awg_jmax: 1000

awg_s1: 86
awg_s2: 574
awg_s3: 0
awg_s4: 0

awg_h1: "471800590-471800690"
awg_h2: "1246894907-1246895000"
awg_h3: "923637689-923637690"
awg_h4: "1769581055-1869581055"

awg_i1: "<b 0xc700000001><rc 8><t><r 100>"
awg_i2: "<b 0xf6ab3267fa><t><rc 20><r 80>"
awg_i3: ""
awg_i4: ""
awg_i5: ""
```


Проверки и ограничения:

- `S1 + 56 != S2`
- Диапазоны `H1`-`H4` не должны пересекаться
- Для AWG 2.0 параметры должны совпадать на сервере и клиенте

Полезные материалы:

- Статья по AWG 2.0 и CPS: <https://habr.com/ru/companies/amnezia/articles/1014636/>
- Генератор параметров обфускации: <https://github.com/Vadim-Khristenko/AmneziaWG-Architect>

---

## 📂 Структура проекта

```
.
├── fallback/                  # Заглушки HAProxy (index.html, 403.html)
├── asgard/                    # Исходники для копирования на серверы
│   ├── main/                  # Main: docker-compose, шаблоны
│   ├── relay/                 # Relay: amnezia, ocserv
│   └── tgproxy/               # TGProxy: telemt, gateway
├── roles/                     # Общие роли
│   ├── asgard_docker          # Запуск/перезапуск Docker Compose
│   ├── asgard_certs_cron       # Cron для конвертации сертификатов
│   ├── asgard_logrotate       # Logrotate для remnanode
│   ├── asgard_ufw             # UFW: открытие портов
│   └── asgard_fallback        # Fallback-заглушки (deploy/fallback переопределяет)
├── deploy.example/            # Шаблон рабочего каталога (копируйте в deploy/)
│   ├── inventory/
│   │   ├── hosts.yml
│   │   └── group_vars/        # all, main, relays, relay_minimal, tgproxy
│   ├── secrets.enc
│   └── fallback/              # README: кастомные заглушки (опционально)
├── deploy/                    # Локально после cp -a deploy.example deploy (в .gitignore)
├── templates/                 # Jinja2-шаблоны Ansible
│   ├── relay.docker-compose.yml.j2
│   ├── relay.haproxy.cfg.j2
│   ├── relay.env.j2
│   └── ...
├── asgard_deploy_main.yml
├── asgard_deploy_relay.yml
├── asgard_deploy_tgproxy.yml
├── asgard_deploy_config.yml   # Обновление конфига main
├── initial_server_setup.yml   # Первичная настройка
├── setup_web_certs.yml        # Certbot (Let's Encrypt)
├── maintenance.yml            # Обновления, rkhunter
├── asgard_backup.yml          # Бэкап Docker volumes
├── run_playbook.sh            # Обёртка с vault
├── init_server.sh
└── init_web_certs.sh
```

---

## 📜 Playbook'и

| Playbook | Описание |
|----------|----------|
| `initial_server_setup.yml` | Первичная настройка: пользователь admin, SSH, UFW, Docker, fail2ban |
| `setup_web_certs.yml` | Установка Let's Encrypt через Certbot |
| `asgard_deploy_main.yml` | Деплой main: Remnawave, HAProxy, config-distributor |
| `asgard_deploy_relay.yml` | Деплой relay (в т.ч. relay_minimal / ex-hole с отключёнными сервисами) |
| `asgard_deploy_tgproxy.yml` | Деплой MTProto-прокси для Telegram |
| `asgard_deploy_config.yml` | Обновление конфигурации config-distributor на main |
| `maintenance.yml` | Апдейты системы, rkhunter, перезагрузка при необходимости |
| `asgard_backup.yml` | Бэкап Docker volumes на локальную машину |

### Запуск с ограничением по хостам

```bash
./run_playbook.sh asgard_deploy_relay.yml -l relay-server-01
./run_playbook.sh maintenance.yml -l main-server-01,relay-server-01
```

---

## 🔐 Безопасность

- Все секреты хранятся в `deploy/secrets.enc` и шифруются через **ansible-vault**
- При каждом запуске playbook запрашивается пароль vault (`--ask-vault-pass`)
- SSH-порт меняется с 22 на 1122 при `initial_server_setup`
- fail2ban защищает от брутфорса
- Сертификаты на серверах имеют режим `0600`

---

## 🔄 Типичный цикл деплоя

Для каждого нового сервера:

1. **Добавить запись в `deploy/inventory/hosts.yml`**.
2. **Начальная настройка:** `./init_server.sh new-host --ask-pass`
2. **Web-сертификаты:** `./init_web_certs.sh new-host` (опционально для relay и tgproxy)
3. **Деплой:** `./run_playbook.sh asgard_deploy_<main|relay|tgproxy>.yml -l new-host`
4. **Периодически:** `./run_playbook.sh maintenance.yml`

---

## 📌 Заметки

- **Relay** — HAProxy (gateway) и ocserv включаются при `enable_ocserv: true`
- **relay_minimal** (ex-hole) — дочерняя группа в `relays` в `deploy/inventory/hosts.yml`; отключение сервисов задаётся в `deploy/inventory/group_vars/relay_minimal.yml`; только remnanode, вход туннеля для двухзвенного VPN
- **TGProxy** с `self_steal: true` использует свой fallback вместо основного домена
- Порты Hysteria/TUIC/SS — в `deploy/inventory/group_vars/all.yml` (или переопределение на уровне хоста/группы)
- На хосте relay при необходимости задайте **`asgard_ufw_tcp_ports`** и **`asgard_ufw_udp_ports`** (списки портов для UFW), если дефолты из роли не подходят
- `main_node_domain` в `vars` группы `relays` в `deploy/inventory/hosts.yml` должен указывать на `assets_domain` main-сервера

---

## 📄 Лицензия

AsIs
