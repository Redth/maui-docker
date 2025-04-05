#!/bin/bash

export ANDROID_TOOL_PROCESS_RUNNER_LOG_PATH=/logs/androidsdktool.log

# Permissions for KVM
sudo chown 1400:1401 /dev/kvm

# Seems that stopping/starting adb causes adb key to generate
/home/mauiusr/.android/platform-tools/adb kill-server
/home/mauiusr/.android/platform-tools/adb start-server

# Start our emulator
#android avd start --home="${ANDROID_HOME}" --name=Emulator_${ANDROID_SDK_API_LEVEL} --wait-boot --wait-exit --gpu="swiftshader_indirect" --accel="on" --wipe-data --no-window --no-audio --no-boot-anim --grpc=8554
/home/mauiusr/.android/emulator/emulator -avd Emulator_${ANDROID_SDK_API_LEVEL} -no-snapshot-load -grpc 8554 -wipe-data -gpu swiftshader_indirect -accel on -no-window -no-audio -no-boot-anim