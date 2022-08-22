#!/usr/bin/env bash
set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_DIR/../scripts/env_handler.sh

# Populate Artifactory creds so zypper repos work.
cat <<-EOF > /etc/environment
ARTIFACTORY_USER=${ARTIFACTORY_USER}
ARTIFACTORY_TOKEN=${ARTIFACTORY_TOKEN}
EOF

zypper -n refresh
