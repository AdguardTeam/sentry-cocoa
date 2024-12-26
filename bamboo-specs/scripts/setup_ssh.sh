#!/bin/bash
set -e
printf "%b\n" "${bamboo_sshSecretKey}" | ssh-add -
