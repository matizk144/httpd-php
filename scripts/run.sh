#!/bin/sh
set -e

# Get uid for the current docroot
[ -z "${DOCUMENT_ROOT}" ] && export DOCUMENT_ROOT=/var/www/html

# Check if docroot or parent exists :
[ -d "${DOCUMENT_ROOT}" ] && export REF_DIR=${DOCUMENT_ROOT}
# Else use its parent
[ -z "${REF_DIR}" ] && export REF_DIR=$(dirname ${DOCUMENT_ROOT})

# Get our command to run
export CMD=$@

[ ! -d /run/php ] && mkdir /run/php
[ ! -d /run/apache2 ] && mkdir /run/apache2


supervisord -nc /etc/supervisor/supervisord.conf
