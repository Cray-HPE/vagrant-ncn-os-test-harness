#!/bin/bash
# MIT License
#
# (C) Copyright 2022 Hewlett Packard Enterprise Development LP
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.
#
set -e
set +x

ENV_HANDLER_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ENV_FILE=$ENV_HANDLER_DIR/../.env

if [[ ! -f $ENV_FILE ]]; then
    cp $ENV_HANDLER_DIR/../env.tmpl $ENV_FILE
fi

SED_COMMAND="sed -i"
[[ $(uname) == "Darwin" ]] && SED_COMMAND="sed -i ''"

# Populate initial values for noninteractive sessions if they exist
[[ ! -z $ARTIFACTORY_USER ]] && $SED_COMMAND "s/ARTIFACTORY_USER=/ARTIFACTORY_USER=${ARTIFACTORY_USER}/g" $ENV_FILE
[[ ! -z $ARTIFACTORY_TOKEN ]] && $SED_COMMAND "s/ARTIFACTORY_TOKEN=/ARTIFACTORY_TOKEN=\"${ARTIFACTORY_TOKEN}\"/g" $ENV_FILE
[[ ! -z $VAGRANT_NCN_USER ]] && $SED_COMMAND "s/export VAGRANT_NCN_USER=/export VAGRANT_NCN_USER=${VAGRANT_NCN_USER}/g" $ENV_FILE
[[ ! -z $VAGRANT_NCN_PASS ]] && $SED_COMMAND "s/export VAGRANT_NCN_PASSWORD=/export VAGRANT_NCN_PASSWORD=\"${VAGRANT_NCN_PASS}\"/g" $ENV_FILE
source $ENV_FILE

if [[ -z "${ARTIFACTORY_USER}" || -z "${ARTIFACTORY_TOKEN}" ]]; then
    echo "Missing authentication information for image download. Setting ARTIFACTORY_USER and ARTIFACTORY_TOKEN environment variables."
    echo "If you haven't already, login and generate an identity token at https://artifactory.algol60.net/ui/admin/artifactory/user_profile ."
    echo "If you don't have an account yet, ping Dennis Walker in Slack."
    echo "-"

    echo -n "What is your username for artifactory.algol60.net? "
    read -r ARTI_USER
    $SED_COMMAND "s/ARTIFACTORY_USER=/ARTIFACTORY_USER=${ARTI_USER}/g" $ENV_FILE
    unset -v ARTI_USER
    echo "-"

    echo -n "What is your identity token for artifactory.algol60.net? "
    stty -echo; read -r ARTI_TOKEN; stty echo;
    $SED_COMMAND "s/ARTIFACTORY_TOKEN=/ARTIFACTORY_TOKEN=\"${ARTI_TOKEN}\"/g" $ENV_FILE
    unset -v ARTI_TOKEN
    echo "-"
fi

if [[ -z "${VAGRANT_NCN_USER}" || -z "${VAGRANT_NCN_PASSWORD}" ]]; then
    echo "Missing credentials to set in the update_box script and to use for vagrant provisioning."
    echo "These credentials could be set to anything, even something commonly seen (hint)."
    echo "Note: Network access to this local environment is private and not exposed to your LAN."
    echo "Note: Non-root users have not been tested here."
    echo "-"

    echo -n "What should the username be for your local environment? "
    read -r NCN_VAGRANT_USER
    $SED_COMMAND "s/export VAGRANT_NCN_USER=/export VAGRANT_NCN_USER=${NCN_VAGRANT_USER}/g" $ENV_FILE
    unset -v NCN_VAGRANT_USER
    echo "-"

    echo -n "What should the password be for your local environment? "
    stty -echo; read -r NCN_VAGRANT_PASS; stty echo;
    $SED_COMMAND "s/export VAGRANT_NCN_PASSWORD=/export VAGRANT_NCN_PASSWORD=\"${NCN_VAGRANT_PASS}\"/g" $ENV_FILE
    unset -v NCN_VAGRANT_PASS
    echo "-"
fi

source $ENV_FILE

if [[ -z "${ARTIFACTORY_USER}" || -z "${ARTIFACTORY_TOKEN}" ]]; then
    echo "Missing authentication information for image download. Please set ARTIFACTORY_USER and ARTIFACTORY_TOKEN environment variables."
    exit 1
fi

if [[ -z "${VAGRANT_NCN_USER}" || -z "${VAGRANT_NCN_PASSWORD}" ]]; then
    echo "Missing authentication information for ssh. Please set VAGRANT_NCN_USER and VAGRANT_NCN_PASSWORD environment variables."
    exit 1
fi
