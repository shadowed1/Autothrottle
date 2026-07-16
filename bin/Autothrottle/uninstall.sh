#!/bin/bash
set -e
rm -f /etc/sudoers.d/autothrottle
sleep 2
sudo pmset -a lowpowermode 0
