#!/bin/bash

ansible-playbook -e @deploy/secrets.enc --ask-vault-pass -i deploy/inventory "$@"
