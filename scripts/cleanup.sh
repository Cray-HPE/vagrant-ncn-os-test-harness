#!/usr/bin/env bash
set -ex
THIS_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd $THIS_DIR/..
vagrant destroy -f || true
[[ -f .env ]] && rm .env
rm -rf images
rm -rf boot

