#!/usr/bin/env bash

# Permissions for KVM
sudo chown 1400:1401 /dev/kvm

# Seems that stopping/starting adb causes adb key to generate
/home/mauiusr/.android/platform-tools/adb kill-server
/home/mauiusr/.android/platform-tools/adb start-server

# Start our emulator
android avd start --home="${ANDROID_HOME}" --name=Emulator_${ANDROID_SDK_API_LEVEL} --wait-boot --wait-exit --gpu="swiftshader_indirect" --accel="on" --wipe-data --no-window --no-audio --no-boot-anim --grpc=8554
