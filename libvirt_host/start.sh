#!/usr/bin/env bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_DIR/../scripts/env_handler.sh
cd $SCRIPT_DIR
vagrant up --provider=virtualbox
cd $OLDPWD
