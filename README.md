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
