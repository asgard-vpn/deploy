#!/bin/bash

# Проверяем, передан ли аргумент (имя хоста)
if [ $# -eq 0 ]; then
    echo "Usage: $0 <hostname>"
    exit 1
fi

HOST=$1

# Playbook для начальной настройки
PLAYBOOK="setup_web_certs.yml"

# Запускаем ansible-playbook
./run_playbook.sh $ASK_PASS \
    -l "$HOST" \
    $PLAYBOOK

echo "Initial certificates installation completed for host $HOST"