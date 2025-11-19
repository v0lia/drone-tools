#!/usr/bin/env bash

grep -qxF '[ -f /tmp/log_folder_path.env ] && source /tmp/log_folder_path.env' ~/.bashrc || \
echo '[ -f /tmp/log_folder_path.env ] && source /tmp/log_folder_path.env' >> ~/.bashrc
