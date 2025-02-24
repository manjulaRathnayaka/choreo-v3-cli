#!/bin/bash
# Based on Deno and nvm installer: Copyright 2023 the Deno authors. All rights reserved. MIT license.
# TODO(everyone): Keep this script simple and easily auditable.
set -e

GITHUB_REPO="manjulaRathnayaka/choreo-v3-cli"
GITHUB_BRANCH="main"

getArchitecture() {
    local ARCH=$(uname -m | tr '[:upper:]' '[:lower:]')
    if [[ "$ARCH" == "x86_64" ]]; then
        echo "amd64"
    elif [[ "$ARCH" == "i386" ]]; then
        echo "386"
    elif [[ "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]]; then
        echo "arm64"
    elif [[ "$ARCH" == "arm" ]]; then
        echo "arm"
    else
        echo "Unsupported architecture: $ARCH"
        exit 1
    fi
}

downloadRelease() {
    local OS=$1
    local ARCH=$2
    local TARGET_DIR=$3
    local DOWNLOAD_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}/dist/${OS}-${ARCH}/choreoctl"

    echo "Downloading choreoctl from ${DOWNLOAD_URL}..."
    if command -v curl > /dev/null; then
        curl -fsSL "${DOWNLOAD_URL}" -o "${TARGET_DIR}/choreoctl"
    elif command -v wget > /dev/null; then
        wget -q "${DOWNLOAD_URL}" -O "${TARGET_DIR}/choreoctl"
    else
        echo "Error: curl or wget is required for installation"
        exit 1
    fi

    if [ $? -ne 0 ]; then
        echo "Error: Failed to download choreoctl for ${OS}-${ARCH}"
        exit 1
    fi
}

main() {
    local OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    local ARCH=$(getArchitecture)
    local SHELL_TYPE=$(basename $SHELL)
    local CHOREO_DIR=~/.choreoctl
    local CHOREO_BIN_DIR=$CHOREO_DIR/bin
    local CHOREO_CLI_EXEC=$CHOREO_BIN_DIR/choreoctl

    mkdir -p $CHOREO_BIN_DIR

    echo "Installing choreoctl..."
    downloadRelease "$OS" "$ARCH" "$CHOREO_BIN_DIR"
    chmod +x "$CHOREO_CLI_EXEC"

    cd $CHOREO_BIN_DIR
    touch ./choreoctl-completion

    ./choreoctl completion $SHELL_TYPE > ./choreoctl-completion
    chmod +x ./choreoctl-completion

    local PROFILE=$(detect_profile)

    if [ -z $PROFILE ]; then
        echo "No profile detected"
        echo "Please add the following lines at the beginning of your shell profile:"
        echo "export CHOREOCTL_DIR=$CHOREO_DIR"
        echo "export PATH=$CHOREO_DIR/bin:\${PATH}"
        echo "[ -f \$CHOREOCTL_DIR/bin/choreoctl-completion ] && source \$CHOREOCTL_DIR/bin/choreoctl-completion"
    else
        echo "Detected profile: $PROFILE"
        if ! grep -qc "$CHOREO_DIR" "$PROFILE"; then
            echo "Adding choreoctl to PATH in $PROFILE"
            # Add to beginning of PATH to take precedence
            sed -i.bak "1i\\
export CHOREOCTL_DIR=$CHOREO_DIR\\
export PATH=$CHOREO_DIR/bin:\${PATH}\\
[ -f \$CHOREOCTL_DIR/bin/choreoctl-completion ] && source \$CHOREOCTL_DIR/bin/choreoctl-completion
" "$PROFILE"
            rm "${PROFILE}.bak"
        else
            echo "choreoctl is already in PATH"
        fi
    fi

    # Add verification step
    echo "Verifying installation..."
    source "$PROFILE" 2>/dev/null || true
    INSTALLED_PATH=$(which choreoctl)
    if [ "$INSTALLED_PATH" != "$CHOREO_CLI_EXEC" ]; then
        echo "Warning: choreoctl is pointing to $INSTALLED_PATH"
        echo "Please ensure $CHOREO_DIR/bin is first in your PATH"
        echo "You may need to start a new terminal session or run: source $PROFILE"
    else
        echo "choreoctl was installed successfully 🎉"
    fi
}


detect_profile() {
    if [ "${PROFILE-}" = '/dev/null' ]; then
        # the user has specifically requested NOT to touch their profile
        return
    fi

    if [ -n "${PROFILE}" ] && [ -f "${PROFILE}" ]; then
        nvm_echo "${PROFILE}"
        return
    fi

    local DETECTED_PROFILE
    DETECTED_PROFILE=''


    if [ "${SHELL#*bash}" != "$SHELL" ]; then
        if [ -f "$HOME/.bashrc" ]; then
            DETECTED_PROFILE="$HOME/.bashrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            DETECTED_PROFILE="$HOME/.bash_profile"
        fi
    elif [ "${SHELL#*zsh}" != "$SHELL" ]; then
        if [ -f "$HOME/.zshrc" ]; then
            DETECTED_PROFILE="$HOME/.zshrc"
        elif [ -f "$HOME/.zprofile" ]; then
            DETECTED_PROFILE="$HOME/.zprofile"
        fi
    fi

    if [ -z "$DETECTED_PROFILE" ]; then
        if [ -f "$HOME/.profile" ]; then
            DETECTED_PROFILE="$HOME/.profile"
        elif [ -f "$HOME/.bashrc" ]; then
            DETECTED_PROFILE="$HOME/.bashrc"
        elif [ -f "$HOME/.bash_profile" ]; then
            DETECTED_PROFILE="$HOME/.bash_profile"
        elif [ -f "$HOME/.zshrc" ]; then
            DETECTED_PROFILE="$HOME/.zshrc"
        elif [ -f "$HOME/.zprofile" ]; then
            DETECTED_PROFILE="$HOME/.zprofile"
        fi
    fi

    if [ ! -z "$DETECTED_PROFILE" ]; then
        echo "$DETECTED_PROFILE"
    fi
}


main "$@"
unset -f main detect_profile getArchitecture downloadRelease
