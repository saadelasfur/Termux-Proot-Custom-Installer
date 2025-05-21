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
Errors may occur during installation."

echo ""
echo cyan "Script made by 23xvx"
echo cyan "Modified by saadelasfur"
sleep 1

echo ""
echo green "Installing dependencies..."
(apt update && apt install proot pulseaudio wget -y) &> /dev/null

cd "$HOME"
if [[ ! -d "storage" ]]; then
    echo ""
    echo green "Please allow storage permissions" && sleep 1
    termux-setup-storage
    sleep 2 && clear
fi

# Notice
echo ""
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
    echo cyan "Please put in your distro name:"
    echo cyan "If you put in \"kali\", your login script will be"
    echo yellow "\"bash kali.sh\""
    echo ""
    read DS_NAME
    sleep 1
fi

echo ""
echo yellow "Your distro name is \"$DS_NAME\""
sleep 1 && cd "$HOME"

echo ""
ROOTFS_DIR="$DS_NAME-fs"
if [[ -d "$ROOTFS_DIR" ]]; then
    if ask "Existing folder found, remove it?"; then
        echo yellow "Deleting existing directory..."
        chmod u+rwx -R "$HOME/$ROOTFS_DIR"
        rm -rf "$HOME/$ROOTFS_DIR"
        rm -rf "$HOME/.config"
        rm -f "$HOME/$DS_NAME.sh"
        rm -f "$HOME/.hushlogin"
        if [[ -d "$ROOTFS_DIR" ]]; then
            abort "Cannot remove directory"
        fi
    else
        abort "Sorry, we cannot complete the installation"
    fi
else
    mkdir -p "$HOME/$ROOTFS_DIR"
fi
mkdir -p "$HOME/$ROOTFS_DIR/.cache"

sleep 2 && clear

# Download and decompress rootfs
ARCHIVE="$(basename "$URL")"
echo green "Downloading $ARCHIVE..."
wget -q --show-progress "$URL" -P "$HOME/$ROOTFS_DIR/.cache/" || abort "Failed downloading rootfs, exiting..."

echo ""
echo green "Decompressing Rootfs..."
proot --link2symlink tar -xpf "$HOME/$ROOTFS_DIR/.cache/$ARCHIVE" -C "$HOME/$ROOTFS_DIR/" --exclude="dev"
rm -rf "$HOME/$ROOTFS_DIR/.cache"
if [[ ! -d "$ROOTFS_DIR/etc" ]]; then
    DIRS="$(ls $ROOTFS_DIR)"
    for dir in $DIRS
    do
        mv "$ROOTFS_DIR/$dir/"* "$ROOTFS_DIR/"
        chmod u+rwx -R "$ROOTFS_DIR/$dir"
        rm -rf "$ROOTFS_DIR/$dir"
    done
    if [[ ! -d "$ROOTFS_DIR/etc" ]]; then
        abort "Failed decompressing rootfs"
    fi
fi

# Set up environment
mkdir -p "$HOME/$ROOTFS_DIR/tmp"
mkdir -p "$HOME/$ROOTFS_DIR/dev/shm"
mkdir -p "$HOME/$ROOTFS_DIR/binds"

rm -f "$HOME/$ROOTFS_DIR/etc/hostname"
rm -f "$HOME/$ROOTFS_DIR/etc/resolv.conf"

echo "localhost" >> "$HOME/$ROOTFS_DIR/etc/hostname"
echo "127.0.0.1 localhost" >> "$HOME/$ROOTFS_DIR/etc/hosts"
{
    echo "nameserver 8.8.8.8"
    echo "nameserver 8.8.4.4"
} >> "$HOME/$ROOTFS_DIR/etc/resolv.conf"

stubs=()
stubs+=("$HOME/$ROOTFS_DIR/usr/bin/groups")
for f in "${stubs[@]}"
do
    {
        echo "#!/bin/sh"
        echo "exit"
    } > "$f"
done

cat <<- EOF >> "$ROOTFS_DIR/etc/environment"
EXTERNAL_STORAGE=/sdcard
LANG=en_US.UTF-8
MOZ_FAKE_NO_SANDBOX=1
PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games
PULSE_SERVER=127.0.0.1
TERM=${TERM-xterm-256color}
TMPDIR=/tmp
EOF

# Sound fix
cat "$HOME/$ROOTFS_DIR/etc/skel/.bashrc" > "$HOME/$ROOTFS_DIR/root/.bashrc"
{
    echo ""
    echo "export PULSE_SERVER=127.0.0.1"
} >> "$HOME/$ROOTFS_DIR/root/.bashrc"

## Script
echo ""
echo green "Writing launch script..."
sleep 1
BIN="$DS_NAME.sh"

cat <<- EOM >> "$BIN"
#!/bin/bash
cd \$(dirname \$0)

## Start PulseAudio
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1

## Set login shell for different distributions
login_shell=\$(grep "^root:" "$ROOTFS_DIR/etc/passwd" | cut -d ':' -f 7)

## unset LD_PRELOAD in case termux-exec is installed
unset LD_PRELOAD

## Proot command
command=""
command+="proot"
command+=" -k 6.8.0-1021-azure"
command+=" --link2symlink"
command+=" --kill-on-exit"
command+=" -0"
command+=" -r $ROOTFS_DIR"
if [[ -n "\$(ls -A $ROOTFS_DIR/binds)" ]]; then
    for f in $ROOTFS_DIR/binds/*
    do
      . \$f
    done
fi
command+=" -b /dev"
command+=" -b /dev/null:/proc/sys/kernel/cap_last_cap"
command+=" -b /dev/null:/proc/stat"
command+=" -b /dev/urandom:/dev/random"
command+=" -b /proc"
command+=" -b /proc/self/fd:/dev/fd"
command+=" -b /proc/self/fd/0:/dev/stdin"
command+=" -b /proc/self/fd/1:/dev/stdout"
command+=" -b /proc/self/fd/2:/dev/stderr"
command+=" -b /sys"
command+=" -b /data/data/com.termux/files/usr/tmp:/tmp"
command+=" -b $ROOTFS_DIR/tmp:/dev/shm"
command+=" -b /data/data/com.termux"
command+=" -b /:/host-rootfs"
command+=" -b /sdcard"
command+=" -b /storage"
command+=" -b /mnt"
command+=" -w /root"
command+=" /usr/bin/env -i"
command+=" HOME=/root"
command+=" PATH=/usr/local/sbin:/usr/local/bin:/bin:/usr/bin:/sbin:/usr/sbin:/usr/games:/usr/local/games"
command+=" TERM=\$TERM"
command+=" LANG=C.UTF-8"
command+=" \$login_shell"
if [[ -z "\$1" ]]; then
    \$command
else
    if [[ "\$1" == "--remove" ]]; then
        echo "Removing rootfs directory..."
        chmod u+rwx "$ROOTFS_DIR"
        rm -f ".hushlogin"
        rm -f "$BIN"
        rm -rf ".config"
        rm -rf "$ROOTFS_DIR"
        echo "Done!"
    else
        \$command -c "\$@"
    fi
fi
EOM

termux-fix-shebang "$BIN"
bash "$BIN" "touch $HOME/.hushlogin ; exit"
sleep 2 && clear

echo red "If you find problems, try to restart Termux!"
echo green "You can now start your distro with \"$DS_NAME.sh\" script"
echo yellow "Command: bash $DS_NAME.sh [Options]"

echo ""
echo "Options:"
echo "     --remove           : delete rootfs directory"
echo "     *command*    : any comamnd to execute in proot and exit"

echo ""
