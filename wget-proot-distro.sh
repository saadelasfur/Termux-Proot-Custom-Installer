#!/data/data/com.termux/files/usr/bin/bash
#
# Copyright (C) 2025 23xvx
# Copyright (C) 2025 saadelasfur
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# [
abort()
{
    echo ""
    echo red "ERROR: $@"
    exit 1
}

# https://github.com/RandomCoderOrg/fs-manager-udroid/blob/5874a7d40e56f4ab86377ccf4701f20b11ac0063/udroid/src/udroid.sh#L104-L128
ask()
{
    local msg="$*"

    echo green "$msg"

    while true; do
        read -p "[y/n]: " choice

        case "$choice" in
            y | Y | yes | YES)
                return 0
                ;;
            n | N | no | NO)
                return 1
                ;;
            *)
                echo yellow "Invalid input: ${choice}"
                echo yellow "Please enter [yes/no] or [y/n]"
                ;;
        esac
    done
}

echo()
{
    case "$1" in
        cyan)
            command echo -e "\033[0;96m$2\033[0m"
            ;;
        green)
            command echo -e "\033[0;92m$2\033[0m"
            ;;
        red)
            command echo -e "\033[0;91m$2\033[0m"
            ;;
        yellow)
            command echo -e "\033[0;93m$2\033[0m"
            ;;
        *)
            command echo "$@"
            ;;
    esac
}
# ]

# Set HOME path
HOME="$(echo ~)"

# Set common variables
SCRIPT="$PREFIX/etc/proot-distro"
PD="$PREFIX/var/lib/proot-distro/installed-rootfs"

# Get architecture
ARCHITECTURE="$(dpkg --print-architecture)"

# Arguments taken if needed
if [[ -z "$1" ]]; then
    MODE="normal"
else
    MODE="args"
    while [[ "$#" -gt 0 ]]
    do
        case "$1" in
            -h | --help)
                echo ""
                echo green "Usage: $0 <options>"

                echo ""
                echo green "The script will ask for the URL and name of the distro during installation as default"
                echo green "If you want to provide the URL and name as arguments, use the following options:"

                echo ""
                echo green "    --url <url>          URL of the rootfs tarball"
                echo green "    --name <name>        name of the distro"
                exit 0
                ;;
            -u | --url)
                [[ -z "$2" ]] && abort "URL not provided after \"--url\""
                [[ "$2" == "-"* ]] && abort "option \"${2}\" cannot be used after \"--url\""
                URL="$2"
                shift 2
                ;;
            -n | --name)
                [[ -z "$2" ]] && abort "Name not provided after \"--name\""
                [[ "$2" == "-"* ]] && abort "option \"${2}\" cannot be used after \"--name\""
                NAME="$2"
                shift 2
                ;;
            *)
                abort "Unknown option \"${1}\""
                ;;
        esac
    done
fi

# Check if the required arguments are provided
if [[ "$MODE" == "args" ]]; then
    if [[ -z "$URL" ]]; then
        abort "URL not provided with \"--url\""
    fi
    if [[ -z "$NAME" ]]; then
        abort "Name not provided with \"--name\""
    fi
fi

FILE_NAME="$(basename "$URL")"
TARBALL_TYPE="${FILE_NAME##*.}"

case "$TARBALL_TYPE" in
    xz | gz)
        ;;
    *)
        echo yellow "Supported tarball types are \"xz\" and \"gz\""
        abort "Rootfs file is not a supported tarball"
        ;;
esac

# Warning
sleep 2 && clear

echo red "Warning!
This script is based on the functions of proot-distro
Errors may occur during installation."

echo ""
echo cyan "Script made by 23xvx"
echo cyan "Modified by saadelasfur"
sleep 1

echo ""
echo green "Installing dependencies..."
(apt update && apt install proot-distro wget -y) &> /dev/null

echo ""
sleep 2 && clear
cd "$HOME"

# Notice
echo cyan "Your architecture is \"$ARCHITECTURE\""
case "$ARCHITECTURE" in
    aarch64)
        ARCH="arm64"
        ;;
    arm*)
        ARCH="armhf"
        ;;
    x86_64 | amd64)
        ARCH="amd64"
        ;;
    *)
        abort "Unsupported architecture!"
        ;;
esac

echo ""
echo yellow "Please download the rootfs file for \"$ARCH\""
echo yellow "Press enter to continue..."
read enter
sleep 1

# Links
if [[ "$MODE" == "args" ]]; then
    URL="$URL"
    DS_NAME="$NAME"
    echo green "Your URL is \"$URL\""
else
    echo green "Please put in your URL here for downloading rootfs:"
    echo ""
    read URL
    sleep 1
    echo ""
    echo green "Please put in your distro name:"
    echo green "If you put in \"gentoo\", your login script will be"
    echo yellow "\"proot-distro login gentoo\""
    echo ""
    echo red "After proot-distro v3.17.0, these names cannot be used as distro name"
    echo red "kali / parrot / nethunter / blackarch"
    echo ""
    read DS_NAME
    sleep 1
fi

echo ""
echo yellow "Your distro name is \"$DS_NAME\""
sleep 1

if [[ ! -d "$PREFIX/var/lib/proot-distro" ]]; then
    mkdir -p "$PREFIX/var/lib/proot-distro"
    mkdir -p "$PREFIX/var/lib/proot-distro/installed-rootfs"
fi

echo ""
ROOTFS_DIR="$PD/$DS_NAME"
if [[ -d "$ROOTFS_DIR" ]]; then
    if ask "Existing folder found, remove it?"; then
        echo yellow "Deleting existing directory..."
        chmod u+rwx -R "$ROOTFS_DIR"
        rm -rf "$ROOTFS_DIR"
        if [[ -d "$ROOTFS_DIR" ]]; then
            abort "Cannot remove directory"
        fi
    else
        abort "Sorry, we cannot complete the installation"
    fi
fi

sleep 2 && clear

# Download and decompress rootfs
mkdir -p "$ROOTFS_DIR"
ARCHIVE="$(basename "$URL")"
echo green "Downloading $ARCHIVE..."
wget -q --show-progress "$URL" -P "$ROOTFS_DIR/.cache/" || abort "Failed downloading rootfs, exiting..."

echo ""
echo green "Decompressing Rootfs..."
SHA256="$(sha256sum "$ROOTFS_DIR/.cache/$ARCHIVE" | awk '{print $1}')"
proot \
      --link2symlink tar \
      --warning=no-unknown-keyword \
      --delay-directory-restore \
      --preserve-permissions \
      -xpf "$ROOTFS_DIR/.cache/$ARCHIVE" -C "$ROOTFS_DIR/" \
      --exclude="dev"
rm -rf "$ROOTFS_DIR/.cache"

declare -i TARBALL_STRIP_OPT=0
while [[ ! -d "$ROOTFS_DIR/etc" ]]
do
    DIRS="$(ls $ROOTFS_DIR)"
    for dir in $DIRS
    do
        mv "$ROOTFS_DIR/$dir/"* "$ROOTFS_DIR/"
        chmod u+rwx -R "$ROOTFS_DIR/$dir"
        rm -rf "$ROOTFS_DIR/$dir"
    done
    TARBALL_STRIP_OPT="$TARBALL_STRIP_OPT+1"
    [[ -d "$ROOTFS_DIR/etc" ]] && break
    if [[ "$TARBALL_STRIP_OPT" == 3 ]]; then
        abort "Cannot find /etc in archive, exiting..."
    fi
done

# Set up environment
touch "$ROOTFS_DIR/root/.hushlogin"
cat "$ROOTFS_DIR/etc/skel/.bashrc" > "$ROOTFS_DIR/root/.bashrc"
{
    echo ""
    echo "touch .hushlogin"
} >> "$ROOTFS_DIR/root/.bashrc"

rm -f "$ROOTFS_DIR/etc/hostname"
rm -f "$ROOTFS_DIR/etc/resolv.conf"

echo "localhost" >> "$ROOTFS_DIR/etc/hostname"
echo "127.0.0.1 localhost" >> "$ROOTFS_DIR/etc/hosts"
{
    echo "nameserver 8.8.8.8"
    echo "nameserver 8.8.4.4"
} >> "$ROOTFS_DIR/etc/resolv.conf"

cat <<- EOF >> "$ROOTFS_DIR/etc/environment"
EXTERNAL_STORAGE=/sdcard
LANG=en_US.UTF-8
MOZ_FAKE_NO_SANDBOX=1
PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games:/data/data/com.termux/files/usr/bin
PULSE_SERVER=127.0.0.1
TERM=${TERM-xterm-256color}
TMPDIR=/tmp
EOF

# Add the distro in proot-distro list
if [[ ! -f "$PREFIX/etc/proot-distro/$DS_NAME.sh" ]]; then
    echo "
    # This is a default distribution plug-in.
    # Do not modify this file as your changes will be overwritten on the next update.
    # If you want to customize the installation, please make a copy.

    DISTRO_NAME='$DS_NAME'
    DISTRO_COMMENT='Custom distro: $DS_NAME'
    TARBALL_STRIP_OPT=$TARBALL_STRIP_OPT

    TARBALL_URL['$ARCHITECTURE']='$URL'
    TARBALL_SHA256['$ARCHITECTURE']='$SHA256'
    " >> "$SCRIPT/$DS_NAME.sh"
fi

sleep 2 && clear

# Finish
echo green "Installation complete!"
echo green "Now you can login to your distro by:"
echo yellow "proot-distro login $DS_NAME"

echo ""
