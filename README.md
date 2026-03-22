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

| Группа | Назначение |
|--------|------------|
| **main** | Центральный сервер: панель Remnawave, раздача конфигов подписчикам |
| **relays** | VPN-реле: Hysteria, TUIC, Shadowsocks, Amnezia, OpenConnect (ocserv) |
| **relay_minimal** | Минимальные relay (ex-hole): только remnanode, вход туннеля для двухзвенного VPN (клиент → hole → relay → интернет) |
| **tgproxy** | MTProto-прокси для обхода блокировок Telegram |

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
cp inventory/secrets.enc.example inventory/secrets.enc
```

### 2. Заполнение конфигурации

**`inventory/hosts.yml`** — хосты, домены. Редактируйте под свою инфраструктуру.

**`group_vars/`** — переменные по группам (порты, домены маскировки и т.д.):
- `all.yml` — общие значения по умолчанию
- `main.yml` — main; опционально: `enable_config_distributor`, `enable_ruleset_manager`
- `relays.yml` — relays; опционально: `enable_ocserv`, `enable_amnezia`, `enable_warp`, `enable_sing_box`, `enable_pingtunnel`, `enable_node_agent`
- `relay_minimal.yml` — минимальные relay (ex-hole): все `enable_*` отключены

**`inventory/fallback/`** — кастомные заглушки HAProxy. Положите `index.html` и/или `403.html` для переопределения дефолтов из `fallback/`.
- `relays.yml` — relays (реле-ноды)
- `tgproxy.yml` — tgproxy (Telegram MTProxy)

**`inventory/secrets.enc`** — пароли и секреты. Заполните значения, затем зашифруйте:

```bash
ansible-vault encrypt inventory/secrets.enc
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
# Минимальные relay (ex-hole) — группа relay_minimal в inventory с отключёнными сервисами
./run_playbook.sh asgard_deploy_relay.yml

# MTProto для Telegram
./run_playbook.sh asgard_deploy_tgproxy.yml
```

---

## 📂 Структура проекта

```
deploy_gen3/
├── fallback/                  # Заглушки HAProxy (index.html, 403.html)
├── asgard/                    # Исходники для копирования на серверы
│   ├── main/                  # Main: docker-compose, шаблоны
│   ├── relay/                 # Relay: amnezia, ocserv
│   └── tgproxy/               # TGProxy: telemt, gateway
├── group_vars/                # Переменные по группам
│   ├── all.yml                # Общие (порты, defaults)
│   ├── main.yml
│   ├── relays.yml
│   ├── relay_minimal.yml      # Минимальные relay (ex-hole): все enable_* = false
│   └── tgproxy.yml
├── roles/                     # Общие роли
│   ├── asgard_docker          # Запуск/перезапуск Docker Compose
│   ├── asgard_certs_cron       # Cron для конвертации сертификатов
│   ├── asgard_logrotate       # Logrotate для remnanode
│   ├── asgard_ufw             # UFW: открытие портов
│   └── asgard_fallback        # Fallback-заглушки (inventory/fallback переопределяет)
├── inventory/
│   ├── hosts.yml.example      # Пример инвентаря
│   ├── hosts.yml              # Ваш инвентарь (не в git)
│   ├── secrets.enc.example    # Пример секретов
│   ├── secrets.enc            # Зашифрованные секреты (не в git)
│   └── fallback/              # Опционально: свои index.html, 403.html (заглушки HAProxy)
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

- Все секреты хранятся в `inventory/secrets.enc` и шифруются через **ansible-vault**
- При каждом запуске playbook запрашивается пароль vault (`--ask-vault-pass`)
- SSH-порт меняется с 22 на 1122 при `initial_server_setup`
- fail2ban защищает от брутфорса
- Сертификаты на серверах имеют режим `0600`

---

## 🔄 Типичный цикл деплоя

1. **Новый VPS:** `./init_server.sh new-host --ask-pass`
2. **Добавить в `hosts.yml`** с `ansible_port: 1122`
3. **Сертификаты:** `./init_web_certs.sh new-host`
4. **Деплой:** `./run_playbook.sh asgard_deploy_<main|relay|tgproxy>.yml -l new-host`
5. **Периодически:** `./run_playbook.sh maintenance.yml`

---

## 📌 Заметки

- **Relay** — HAProxy (gateway) и ocserv включаются при `enable_ocserv: true`
- **relay_minimal** (ex-hole) — группа в `relays` с `enable_*: false` в `group_vars/relay_minimal.yml`; только remnanode, вход туннеля для двухзвенного VPN
- **TGProxy** с `self_steal: true` использует свой fallback вместо основного домена
- Порты Hysteria/TUIC/SS настраиваются в `vars` группы в `hosts.yml`
- `main_node_domain` в relays должен указывать на `assets_domain` main-сервера

---

## 📄 Лицензия

AsIs
