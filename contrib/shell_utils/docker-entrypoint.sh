#!/bin/sh

# Entry point script for netatalk docker container.
# Copyright (C) 2023  Eric Harmon
# Copyright (C) 2024  Daniel Markstedt
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

set -e

echo "*** Setting up users and groups"

if [ -z "$AFP_USER" ]; then
    echo "ERROR: AFP_USER needs to be set to use this Docker container."
    exit 1
fi
if [ -z "$AFP_PASS" ]; then
    echo "ERROR: AFP_PASS needs to be set to use this Docker container."
    exit 1
fi
if [ -z "$AFP_GROUP" ]; then
    echo "ERROR: AFP_GROUP needs to be set to use this Docker container."
    exit 1
fi

uidcmd=""
gidcmd=""
if [ -n "$AFP_UID" ]; then
    uidcmd="-u $AFP_UID"
fi
if [ -n "$AFP_GID" ]; then
    gidcmd="-g $AFP_GID"
fi

adduser $uidcmd --no-create-home --disabled-password "$AFP_USER" 2>/dev/null || true
addgroup $gidcmd "$AFP_GROUP" 2>/dev/null || true
addgroup "$AFP_USER" "$AFP_GROUP"

echo "$AFP_USER:$AFP_PASS" | chpasswd

# Creating credentials for the RandNum UAM
if [ -f "/usr/local/etc/netatalk/afppasswd" ]; then
    rm -f /usr/local/etc/netatalk/afppasswd
fi
afppasswd -c
if ! afppasswd -a -f -w "$AFP_PASS" "$AFP_USER"; then
    echo "NOTE: Use a password of 8 chars or less to authenticate with Mac OS 8 or earlier clients"
fi

# Optional second user
if [ -n "$AFP_USER2" ]; then
    adduser --no-create-home --disabled-password "$AFP_USER2" 2>/dev/null || true
    addgroup "$AFP_USER2" "$AFP_GROUP"
    echo "$AFP_USER2:$AFP_PASS2" | chpasswd
    if ! afppasswd -a -f -w "$AFP_PASS2" "$AFP_USER2"; then
        echo "NOTE: Use a password of 8 chars or less to authenticate with Mac OS 8 or earlier clients"
    fi
fi

echo "*** Configuring shared volume"
[ -d /mnt/afpshare ] || mkdir /mnt/afpshare
[ -d /mnt/afpbackup ] || mkdir /mnt/afpbackup

echo "*** Fixing permissions"
chmod 2775 /mnt/afpshare /mnt/afpbackup
if [ -n "$AFP_UID" ] && [ -n "$AFP_GID" ]; then
    chown "$AFP_UID:$AFP_GID" /mnt/afpshare /mnt/afpbackup
else
    chown "$AFP_USER:$AFP_GROUP" /mnt/afpshare /mnt/afpbackup
fi

echo "*** Removing residual lock files"
mkdir -p /run/lock
rm -f /run/lock/netatalk /run/lock/atalkd /run/lock/papd

echo "*** Configuring Netatalk"
UAMS="uams_dhx.so uams_dhx2.so uams_randnum.so"

[ -n "$VERBOSE" ] && TEST_FLAGS=-v
[ -n "$INSECURE_AUTH" ] && UAMS="$UAMS uams_clrtxt.so uams_guest.so"
[ -n "$DISABLE_TIMEMACHINE" ] && TIMEMACHINE="no" || TIMEMACHINE="yes"
ATALK_NAME="${SERVER_NAME:-$(hostname | cut -d. -f1)}"

if [ -n "$AFP_READONLY" ]; then
    AFP_RWRO="rolist"
else
    AFP_RWRO="rwlist"
fi

if [ -z "$MANUAL_CONFIG" ]; then
    cat <<EOF > /usr/local/etc/afp.conf
[Global]
appletalk = yes
log file = /var/log/afpd.log
log level = default:${AFP_LOGLEVEL:-info}
spotlight = yes
uam list = $UAMS
zeroconf name = ${SERVER_NAME:-Netatalk File Server}
[${SHARE_NAME:-File Sharing}]
appledouble = ea
path = /mnt/afpshare
valid users = $AFP_USER $AFP_USER2
$AFP_RWRO = $AFP_USER $AFP_USER2
[${SHARE2_NAME:-Time Machine}]
appledouble = ea
path = /mnt/afpbackup
time machine = $TIMEMACHINE
valid users = $AFP_USER $AFP_USER2
$AFP_RWRO = $AFP_USER $AFP_USER2
EOF
fi

# Configuring AppleTalk if enabled
if [ -n "$ATALKD_INTERFACE" ]; then
    echo "*** Configuring DDP"
    echo "$ATALKD_INTERFACE $ATALKD_OPTIONS" > /usr/local/etc/atalkd.conf
    echo "cupsautoadd:op=root:" > /usr/local/etc/papd.conf
    echo "*** Starting DDP services"
    cupsd
    atalkd
    nbprgstr -p 4 "$ATALK_NAME:Workstation"
    nbprgstr -p 4 "$ATALK_NAME:netatalk"
    papd
    timelord -l
    a2boot
else
    echo "Set the \`ATALKD_INTERFACE' environment variable to start DDP services."
fi

echo "*** Starting AFP server"
if [ -z "$TESTSUITE" ]; then
    if [ -z "$AFP_DRYRUN" ]; then
        netatalk -d
    else
        netatalk -V
    fi
else
    if [ "$TESTSUITE" = "spectest" ]; then
    cat <<EXT > /usr/local/etc/extmap.conf
.         "????"  "????"      Unix Binary                    Unix                      application/octet-stream
.doc      "WDBN"  "MSWD"      Word Document                  Microsoft Word            application/msword
.pdf      "PDF "  "CARO"      Portable Document Format       Acrobat Reader            application/pdf
EXT
    fi
    netatalk
    sleep 2
    case "$TESTSUITE" in
        spectest)
            afp_spectest "$TEST_FLAGS" -"$AFP_VERSION" -h 127.0.0.1 -p 548 -u "$AFP_USER" -d "$AFP_USER2" -w "$AFP_PASS" -s "$SHARE_NAME" -S "$SHARE2_NAME" -c /mnt/afpshare
            ;;
        readonly)
            echo "testfile uno" > /mnt/afpshare/first.txt
            echo "testfile dos" > /mnt/afpshare/second.txt
            mkdir /mnt/afpshare/third
            afp_spectest "$TEST_FLAGS" -"$AFP_VERSION" -h 127.0.0.1 -p 548 -u "$AFP_USER" -w "$AFP_PASS" -s "$SHARE_NAME" -f Readonly_test
            ;;
        login)
            afp_logintest "$TEST_FLAGS" -"$AFP_VERSION" -h 127.0.0.1 -p 548 -u "$AFP_USER" -w "$AFP_PASS"
            ;;
        lan)
            afp_lantest "$TEST_FLAGS" -"$AFP_VERSION" -h 127.0.0.1 -p 548 -u "$AFP_USER" -w "$AFP_PASS" -s "$SHARE_NAME"
            ;;
        speed)
            afp_speedtest "$TEST_FLAGS" -"$AFP_VERSION" -h 127.0.0.1 -p 548 -u "$AFP_USER" -w "$AFP_PASS" -s "$SHARE_NAME"
            ;;
        *)
            echo "Unknown testsuite: $TESTSUITE"
            exit 1
            ;;
    esac
fi
