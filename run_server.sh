#!/bin/bash
cd /home/toor/DeVulStrike-ai || exit 1
source hexstrike-env/bin/activate
exec python DeVulStrike_server.py
