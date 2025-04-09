# maui-docker
Docker images for MAUI dev/testing

## Building

```sh
docker build --pull --rm -f 'Dockerfile' -t 'redth/maui-docker:android_appium_emulator_35' '.' 
```

## Running

```sh
docker run -d --device /dev/kvm -p 5554:5554 -p 5555:5555 -p 4723:4723 redth/maui-docker:android_appium_emulator_35
```

### Docker and Nested Virtualization
The emulator on this image requires nested virtualization to work correctly.  This is done by passing the `--device /dev/kvm` from the host device to the docker container.

#### Windows
Windows may have mixed results with Docker running in Hyper-V mode.  It seems recent Windows and/or Docker updates makes this less reliable.  Instead it's recommended to have [Docker run in WSL2](https://docs.docker.com/desktop/features/wsl/) mode and launch the docker image from WSL2 in order to pass through the KVM device.

#### macOS
Apple Silicon based Macs will require an M3 or newer to use nested virtualization with Docker.

#### Linux
Linux should work fine as long as you have [kvm virtualization support](https://docs.docker.com/desktop/setup/install/linux/#kvm-virtualization-support) enabled.


## Variants
- redth/maui-docker:android_appium_emulator_23
- redth/maui-docker:android_appium_emulator_24
- redth/maui-docker:android_appium_emulator_25
- redth/maui-docker:android_appium_emulator_26
- redth/maui-docker:android_appium_emulator_28
- redth/maui-docker:android_appium_emulator_29
- redth/maui-docker:android_appium_emulator_30
- redth/maui-docker:android_appium_emulator_31
- redth/maui-docker:android_appium_emulator_32
- redth/maui-docker:android_appium_emulator_33
- redth/maui-docker:android_appium_emulator_34
- redth/maui-docker:android_appium_emulator_35 
