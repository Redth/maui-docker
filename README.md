# maui-docker
Docker images for MAUI development/building/testing



## Test Images

Test images are designed to help quickly stand up containers that are ready to use for running UI Tests with Appium on the Android Emulator.  They come setup with Appium Server and the Android Emulator (for the given API level) both running and waiting when the container is started.

> NOTE: Only `linux/amd64` is available.

## Usage:

```pwsh
docker run `
    -v C:/MyApp/bin/Debug/net9.0-android35.0/:/app `
    --device /dev/kvm `
    -p 5554:5554 `
    -p 5555:5555 `
    -p 4723:4723 `
    redth/maui-testing:appium-emulator-linux-android35
```

> NOTE: Ports are mapped for the emulator, ADB, and Appium in this example.

> NOTE: Device passthrough of `/dev/kvm` is required for the emulator

### Volumes:
The host folder with the built apk's can be mapped to a folder in the container.  You can then specify the location of the apk to install to appium using the container's path to it (eg: `/app/my.companyname.app-Signed.apk`).

### Environment Variables:
- `INIT_PWSH_SCRIPT` Optionally (linux or windows images) specify a path to a .ps1 script file to run before starting the runner agent (Default path is `/config/init.ps1` on linux and `C:\\config\\init.ps1` on windows - you would need to bind a volume for the script to use)
- `INIT_BASH_SCRIPT` Optionally (linux image only) specify a path to a .ps1 script file to run before starting the runner agent (Default path is `/config/init.sh` on linux - you would need to bind a volume for the script to use)

### Variants

Each Android API Level (23 through latest) has its own image variant.  You can specify different ones to use by the tag name (eg: `test-linux:android23` or `test-linux:android35`).

![Docker Image Version (tag)](https://img.shields.io/docker/v/redth/maui-testing/appium-emulator-linux-android35?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fredth%2Fmaui-testing%2Ftags)

<details>

<summary>Show All Variants...</summary>

- ![Docker Image Version (tag)](https://img.shields.io/docker/v/redth/maui-testing/appium-emulator-linux-android23?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fredth%2Fmaui-testing%2Ftags)
- ![Docker Image Version (tag)](https://img.shields.io/docker/v/redth/maui-testing/appium-emulator-linux-android24?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fredth%2Fmaui-testing%2Ftags)
- ![Docker Image Version (tag)](https://img.shields.io/docker/v/redth/maui-testing/appium-emulator-linux-android25?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fredth%2Fmaui-testing%2Ftags)
- ![Docker Image Version (tag)](https://img.shields.io/docker/v/redth/maui-testing/appium-emulator-linux-android26?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fredth%2Fmaui-testing%2Ftags)
- ![Docker Image Version (tag)](https://img.shields.io/docker/v/redth/maui-testing/appium-emulator-linux-android28?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fredth%2Fmaui-testing%2Ftags)
- ![Docker Image Version (tag)](https://img.shields.io/docker/v/redth/maui-testing/appium-emulator-linux-android29?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fredth%2Fmaui-testing%2Ftags)
- ![Docker Image Version (tag)](https://img.shields.io/docker/v/redth/maui-testing/appium-emulator-linux-android30?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fredth%2Fmaui-testing%2Ftags)
- ![Docker Image Version (tag)](https://img.shields.io/docker/v/redth/maui-testing/appium-emulator-linux-android31?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fredth%2Fmaui-testing%2Ftags)
- ![Docker Image Version (tag)](https://img.shields.io/docker/v/redth/maui-testing/appium-emulator-linux-android32?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fredth%2Fmaui-testing%2Ftags)
- ![Docker Image Version (tag)](https://img.shields.io/docker/v/redth/maui-testing/appium-emulator-linux-android33?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fredth%2Fmaui-testing%2Ftags)
- ![Docker Image Version (tag)](https://img.shields.io/docker/v/redth/maui-testing/appium-emulator-linux-android34?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fredth%2Fmaui-testing%2Ftags)
- ![Docker Image Version (tag)](https://img.shields.io/docker/v/redth/maui-testing/appium-emulator-linux-android35?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fredth%2Fmaui-testing%2Ftags)
 
</details>

### Docker and Nested Virtualization
The emulator on this image requires nested virtualization to work correctly.  This is done by passing the `--device /dev/kvm` from the host device to the docker container.

#### Windows
Windows may have mixed results with Docker running in Hyper-V mode.  It seems recent Windows and/or Docker updates makes this less reliable.  Instead it's recommended to have [Docker run in WSL2](https://docs.docker.com/desktop/features/wsl/) mode and launch the docker image from WSL2 in order to pass through the KVM device.

#### macOS
Apple Silicon based Macs will require an M3 or newer to use nested virtualization with Docker.

#### Linux
Linux should work fine as long as you have [kvm virtualization support](https://docs.docker.com/desktop/setup/install/linux/#kvm-virtualization-support) enabled.

--------------------

## GitHub Action Runner Images

- Linux: ![Docker Image Version (tag)](https://img.shields.io/docker/v/redth/maui-actions-runner/linux-dotnet9.0?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fredth%2Fmaui-actions-runner%2Ftags)
- Windows: ![Docker Image Version (tag)](https://img.shields.io/docker/v/redth/maui-actions-runner/windows-dotnet9.0?link=https%3A%2F%2Fhub.docker.com%2Fr%2Fredth%2Fmaui-actions-runner%2Ftags)


Runner images are intended to make it really easy to stand up self-hosted build agents with some .NET / MAUI SDK prerequisites installed.  They have the latest workload set installed for the given .NET SDK version.  They also install, configure (including self registration), and run the GitHub Action Runner service when the container starts.

## Usage:

```pwsh
docker run `
    -e GITHUB_ORG=myorg `
    -e GITHUB_REPO=myrepo `
    -e GITHUB_TOKEN=myaccesstoken `
    redth/maui-actions-runner:windows-dotnet9.0
```

> NOTE: You can omit the `GITHUB_REPO` to install the runner at the organization level, but make sure you have an access token (PAT) with the correct access at this level to do so.

### Environment Variables:
- `GITHUB_TOKEN` Required github access token with Action Runner Read/Write permissons in order to self register the runner.
- `GITHUB_ORG` Required github organization to attach the runner to.
- `GITHUB_REPO` Optional repository name to attach the runner to (otherwise attaches at the org level).
- `RUNNER_NAME` Optionally sets an explicit runner name.  Default is calculated based on a suffix, and random suffix.
- `RUNNER_NAME_PREFIX` Optional prefix to be used for the runner name.
- `RANDOM_RUNNER_SUFFIX` Default is `true`.  If true, adds a random suffix to the RUNNER_NAME.
- `LABELS` Overrides the default set of labels to apply to the runner.
- `RUNNER_GROUP` Overrides the default runner group.
- `RUNNER_WORKDIR` Overrides the default runner work directory.
- `INIT_PWSH_SCRIPT` Optionally (linux or windows images) specify a path to a .ps1 script file to run before starting the runner agent (Default path is `/config/init.ps1` on linux and `C:\\config\\init.ps1` on windows - you would need to bind a volume for the script to use)
- `INIT_BASH_SCRIPT` Optionally (linux image only) specify a path to a .ps1 script file to run before starting the runner agent (Default path is `/config/init.sh` on linux - you would need to bind a volume for the script to use)

### Installed Software
- Chocolatey
- Microsoft OpenJDK
- Android SDK
- .NET SDK
- .NET Workloads

> NOTE: The .NET Workloads are installed with the latest Workload set version for the given .NET SDK major version (eg: 9.0 SDK could have 9.0.203 as the latest workload set version).

> NOTE: Versions for things like OpenJDK and Android SDK (including the individual SDK packages/components) are inferred from the Workloads' `data/WorkloadDependencies.json` files (in their Manifest nuget packages), which specify recommended versions and components to be installed for each workload.

------------------


## Building

The images can be built with their respective `build.ps1` files.  See the GitHub workflow yml files for examples.


-------------------


## Roadmap

- Windows container for Test images
