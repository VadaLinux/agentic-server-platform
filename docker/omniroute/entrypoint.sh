#!/bin/bash
set -e

# Proxy internal loopback (127.0.0.1:20129) to container-wide interface (0.0.0.0:20128)
socat TCP-LISTEN:20128,fork,reuseaddr TCP:127.0.0.1:20129 &

exec omniroute serve --port 20129 --no-open
