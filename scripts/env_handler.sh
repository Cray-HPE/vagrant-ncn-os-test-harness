#!/usr/bin/env bash
ENV_HANDLER_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ENV_FILE=$ENV_HANDLER_DIR/../.env

if [[ ! -f $ENV_FILE ]]; then
    cp $ENV_HANDLER_DIR/../env.tmpl $ENV_FILE
fi

SED_COMMAND="sed -i"
[[ $(uname) == "Darwin" ]] && SED_COMMAND="sed -i ''"

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
    $SED_COMMAND "s/ARTIFACTORY_TOKEN=/ARTIFACTORY_TOKEN=${ARTI_TOKEN}/g" $ENV_FILE
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
    $SED_COMMAND "s/VAGRANT_NCN_USER=/VAGRANT_NCN_USER=${NCN_VAGRANT_USER}/g" $ENV_FILE
    unset -v NCN_VAGRANT_USER
    echo "-"

    echo -n "What should the password be for your local environment? "
    stty -echo; read -r NCN_VAGRANT_PASS; stty echo;
    $SED_COMMAND "s/VAGRANT_NCN_PASSWORD=/VAGRANT_NCN_PASSWORD=${NCN_VAGRANT_PASS}/g" $ENV_FILE
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
