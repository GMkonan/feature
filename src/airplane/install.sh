#!/usr/bin/env bash
set -e

# Clean up
rm -rf /var/lib/apt/lists/*

AIRPLANE_VERSION=${VERSION:-"latest"}

echo "Airplane CLI version: ${AIRPLANE_VERSION}"

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# Figure out correct version of a three part version number is not passed
find_version_from_git_tags() {
    local variable_name=$1
    local requested_version=${!variable_name}
    if [ "${requested_version}" = "none" ]; then return; fi
    local repository=$2
    local prefix=${3:-"tags/v"}
    local separator=${4:-"."}
    local last_part_optional=${5:-"false"}
    if [ "$(echo "${requested_version}" | grep -o "." | wc -l)" != "2" ]; then
        local escaped_separator=${separator//./\\.}
        local last_part
        if [ "${last_part_optional}" = "true" ]; then
            last_part="(${escaped_separator}[0-9]+)?"
        else
            last_part="${escaped_separator}[0-9]+"
        fi
        local regex="${prefix}\\K[0-9]+${escaped_separator}[0-9]+${last_part}$"
        local version_list="$(git ls-remote --tags ${repository} | grep -oP "${regex}" | tr -d ' ' | tr "${separator}" "." | sort -rV)"
        if [ "${requested_version}" = "latest" ] || [ "${requested_version}" = "current" ] || [ "${requested_version}" = "lts" ]; then
            declare -g ${variable_name}="$(echo "${version_list}" | head -n 1)"
        else
            set +e
            declare -g ${variable_name}="$(echo "${version_list}" | grep -E -m 1 "^${requested_version//./\\.}([\\.\\s]|$)")"
            set -e
        fi
    fi
    if [ -z "${!variable_name}" ] || ! echo "${version_list}" | grep "^${!variable_name//./\\.}$" > /dev/null 2>&1; then
        echo -e "Invalid ${variable_name} value: ${requested_version}\nValid values:\n${version_list}" >&2
        exit 1
    fi
    echo "${variable_name}=${!variable_name}"
}

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        if [ "$(find /var/lib/apt/lists/* | wc -l)" = "0" ]; then
            echo "Running apt-get update..."
            apt-get update -y
        fi
        apt-get -y install --no-install-recommends "$@"
    fi
}

architecture="$(uname -m)"
case $architecture in
    x86_64) architecture="x86_64";;
    aarch64 | armv8* | arm64) architecture="arm64";;
    *) echo "(!) Architecture $architecture unsupported"; exit 1 ;;
esac

# Use a temporary directory for airplane install
export TMP_DIR="/tmp/tmp-airplanectl"
mkdir -p ${TMP_DIR}
chmod 700 ${TMP_DIR}

install() {    
# Install curl
check_packages curl git tar ca-certificates

find_version_from_git_tags AIRPLANE_VERSION https://github.com/airplanedev/cli

AIRPLANE_VERSION="${AIRPLANE_VERSION#"v"}"

# Install airplane CLI
curl -sSL -o ${TMP_DIR}/airplane.tar.gz "https://github.com/airplanedev/cli/releases/download/v${AIRPLANE_VERSION}/airplane_linux_${architecture}.tar.gz"

tar -xzf "${TMP_DIR}/airplane.tar.gz" -C "${TMP_DIR}" airplane
mv ${TMP_DIR}/airplane /usr/local/bin/airplane
chmod 0755 /usr/local/bin/airplane

}

echo "Installing airplane CLI..."
install

# Clean up
rm -rf /var/lib/apt/lists/*

echo "Done installing airplane CLI!"