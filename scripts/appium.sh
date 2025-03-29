#!/usr/bin/env bash

node appium \
  --session-override \
  --log-level debug \
  --log-timestamp \
  --port 4723 \
  --allow-insecure chromedriver_autodownload