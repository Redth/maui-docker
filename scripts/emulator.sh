#!/usr/bin/env bash

# First argument is API level, fallback to environment variable if not provided
API_LEVEL=${1:-$AndroidSdkApiLevel}

sudo chown 1400:1401 /dev/kvm
#sudo sed -i '1d' /etc/passwd

/home/mauiusr/.dotnet/tools/android avd start --home="${ANDROID_HOME}" --name=Emulator_${API_LEVEL} --wait-boot --wait-exit --gpu="swiftshader_indirect" --accel="on" --no-window --no-audio --no-boot-anim
