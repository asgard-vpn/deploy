# ⚡ Asgard Deploy

**Ansible-инфраструктура для развёртывания распределённой VPN-платформы на базе [Remnawave](https://github.com/remnawave/remnawave).**

---

## 📋 О проекте

Asgard Deploy — это набор Ansible playbook для автоматизированного развёртывания и управления инфраструктурой VPN-сервиса. Система поддерживает многоуровневую архитектуру с центральным сервером (main), релейными нодами (relays), MTProto-прокси для Telegram (tgproxy) и специальными hole-нодами.

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
│     RELAYS      │          │     TGPROXY     │          │      HOLES      │
│ Hysteria • TUIC │          │   MTProto       │          │  Туннель (вход) │
│ Shadowsocks •   │          │   Telemt        │          │  Клиент → Hole  │
│ Amnezia • OC    │          │                 │          │  → Relay → Сеть │
└─────────────────┘          └─────────────────┘          └─────────────────┘
```

| Группа | Назначение |
|--------|------------|
| **main** | Центральный сервер: панель Remnawave, раздача конфигов подписчикам |
| **relays** | VPN-реле: Hysteria, TUIC, Shadowsocks, Amnezia, OpenConnect (ocserv) |
| **tgproxy** | MTProto-прокси для обхода блокировок Telegram |
| **holes** | Легковесные ноды — вход туннеля для **двухзвенного** VPN (клиент → hole → relay → интернет) |

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

```bash
git clone <repository-url>
cd asgard_deply

# Копируем примеры
cp inventory/hosts.yml.example inventory/hosts.yml
cp inventory/secrets.enc.example inventory/secrets.enc.yml
```

### 2. Заполнение конфигурации

**`inventory/hosts.yml`** — хосты, домены. Редактируйте под свою инфраструктуру.

**`group_vars/`** — переменные по группам (порты, домены маскировки и т.д.):
- `all.yml` — общие значения по умолчанию
- `main.yml` — main (центральная панель)
- `relays.yml` — relays (реле-ноды)
- `tgproxy.yml` — tgproxy (Telegram MTProxy)
- `holes.yml` — holes (дырки)

**`inventory/secrets.enc.yml`** — пароли и секреты. Заполните значения, затем зашифруйте:

```bash
ansible-vault encrypt inventory/secrets.enc.yml
```

### 3. Первичная настройка нового сервера

Для **нового** VPS (root по SSH на 22 порту):

```bash
./init_server.sh <hostname> --ask-pass
```

Playbook создаст пользователя `admin`, настроит SSH (порт 1122), UFW, Docker, fail2ban и перезагрузит сервер при необходимости.

### 4. Установка SSL-сертификатов

После `init_server` обновите в `hosts.yml` порт SSH на 1122 (или свой) и выполните:

```bash
./init_web_certs.sh <hostname>
```

### 5. Деплой по группам

```bash
# Центральный сервер
./run_playbook.sh asgard_deploy_main.yml

# Реле (Hysteria, TUIC, Shadowsocks, Amnezia, ocserv)
./run_playbook.sh asgard_deploy_relay.yml

# MTProto для Telegram
./run_playbook.sh asgard_deploy_tgproxy.yml

# Hole-ноды (туннель для двухзвенного VPN)
./run_playbook.sh asgard_deploy_hole.yml
```

---

## 📂 Структура проекта

```
deploy_gen3/
├── asgard/                    # Исходники для копирования на серверы
│   ├── main/                  # Main: docker-compose, шаблоны
│   ├── relay/                 # Relay: fallback, amnezia, ocserv
│   ├── hole/                  # Hole: лёгкие туннельные ноды (двухзвенный VPN)
│   └── tgproxy/               # TGProxy: telemt, gateway
├── group_vars/                # Переменные по группам
│   ├── all.yml                # Общие (порты, defaults)
│   ├── main.yml
│   ├── relays.yml
│   ├── tgproxy.yml
│   └── holes.yml
├── roles/                     # Общие роли
│   ├── asgard_docker          # Запуск/перезапуск Docker Compose
│   ├── asgard_certs_cron       # Cron для конвертации сертификатов
│   ├── asgard_logrotate       # Logrotate для remnanode
│   └── asgard_ufw             # UFW: открытие портов
├── inventory/
│   ├── hosts.yml.example      # Пример инвентаря
│   ├── hosts.yml              # Ваш инвентарь (не в git)
│   ├── secrets.enc.example    # Пример секретов
│   └── secrets.enc.yml        # Зашифрованные секреты (не в git)
├── templates/                 # Jinja2-шаблоны Ansible
│   ├── relay.docker-compose.yml.j2
│   ├── relay.haproxy.cfg.j2
│   ├── relay.env.j2
│   └── ...
├── asgard_deploy_main.yml
├── asgard_deploy_relay.yml
├── asgard_deploy_tgproxy.yml
├── asgard_deploy_hole.yml
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
| `asgard_deploy_relay.yml` | Деплой relay: Hysteria, TUIC, SS, Amnezia, ocserv, MTProxy |
| `asgard_deploy_tgproxy.yml` | Деплой MTProto-прокси для Telegram |
| `asgard_deploy_hole.yml` | Деплой hole-нод (вход туннеля, двухзвенный VPN: клиент → hole → relay) |
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

- Все секреты хранятся в `inventory/secrets.enc.yml` и шифруются через **ansible-vault**
- При каждом запуске playbook запрашивается пароль vault (`--ask-vault-pass`)
- SSH-порт меняется с 22 на 1122 при `initial_server_setup`
- fail2ban защищает от брутфорса
- Сертификаты на серверах имеют режим `0600`

---

## 🔄 Типичный цикл деплоя

1. **Новый VPS:** `./init_server.sh new-host --ask-pass`
2. **Добавить в `hosts.yml`** с `ansible_port: 1122`
3. **Сертификаты:** `./init_web_certs.sh new-host`
4. **Деплой:** `./run_playbook.sh asgard_deploy_<main|relay|tgproxy|hole>.yml -l new-host`
5. **Периодически:** `./run_playbook.sh maintenance.yml`

---

## 📌 Заметки

- **Relay** может работать с `use_reverse_proxy: true` (HAProxy + ocserv) или `false`
- **TGProxy** с `self_steal: true` использует свой fallback вместо основного домена
- **Holes** — легковесные ноды-входы туннеля: трафик идёт по цепочке **клиент → hole → relay → интернет**. Hole минималистичен, без HAProxy и лишних сервисов.
- Порты Hysteria/TUIC/SS настраиваются в `vars` группы в `hosts.yml`
- `main_node_domain` в relays должен указывать на `assets_domain` main-сервера

---

## 📄 Лицензия

AsIs
