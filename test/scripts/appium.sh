#!/usr/bin/bash

appium \
  --session-override \
  --log-level debug \
  --log-timestamp \
  --port 4723 \
  --allow-insecure *:chromedriver_autodownload