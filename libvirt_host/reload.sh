#!/usr/bin/env bash
set -e

THIS_SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $THIS_SCRIPT_DIR/../scripts/env_handler.sh

vagrant reload
