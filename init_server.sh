#!/bin/bash

# Проверяем, передан ли аргумент (имя хоста)
if [ $# -eq 0 ]; then
    echo "Usage: $0 <hostname> [--ask-pass]"
    exit 1
fi

HOST=$1
ASK_PASS=""

# Если нужно запросить пароль (для первого подключения)
if [ "$2" == "--ask-pass" ]; then
    ASK_PASS="--ask-pass"
fi

# Временные переменные для подключения (значения по умолчанию для нового сервера)
TEMP_USER="root"
TEMP_PORT="22"
TEMP_SSH_KEY="~/.ssh/id_rsa"

# Playbook для начальной настройки
PLAYBOOK="initial_server_setup.yml"

# Запускаем ansible-playbook с переопределёнными параметрами для конкретного хоста
./run_playbook.sh $ASK_PASS \
    -l "$HOST" \
    -e "ansible_user=$TEMP_USER" \
    -e "ansible_port=$TEMP_PORT" \
    $PLAYBOOK

echo "Initial setup completed for host $HOST"