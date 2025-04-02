#!/usr/bin/env bash

# First argument is API level, fallback to environment variable if not provided
API_LEVEL=${1:-$AndroidSdkApiLevel}

# Permissions for KVM
sudo chown 1400:1401 /dev/kvm

# Seems that stopping/starting adb causes adb key to generate
/home/mauiusr/.android/platform-tools/adb kill-server
/home/mauiusr/.android/platform-tools/adb start-server

# Start our emulator
/home/mauiusr/.dotnet/tools/android avd start --home="${ANDROID_HOME}" --name=Emulator_${API_LEVEL} --wait-boot --wait-exit --gpu="swiftshader_indirect" --accel="on" --wipe-data --no-window --no-audio --no-boot-anim
