#!/usr/bin/env bash
set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_DIR/../scripts/env_handler.sh
cd $SCRIPT_DIR

vagrant destroy -f || true

vagrant up --provider=libvirt
$SCRIPT_DIR/scripts/take_snapshot.sh base
