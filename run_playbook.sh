#!/bin/bash

ansible-playbook -e @inventory/secrets.enc --ask-vault-pass -i inventory/hosts.yml "$@"
