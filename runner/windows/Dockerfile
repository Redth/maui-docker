# Use .NET SDK base image
FROM mcr.microsoft.com/dotnet/sdk:9.0-windowsservercore-ltsc2022

# Set build arguments
ARG GITHUB_ACTIONS_RUNNER_VERSION=2.323.0
ARG JDK_MAJOR_VERSION=17
ARG ANDROID_SDK_API_LEVEL=35
ARG ANDROID_SDK_BUILD_TOOLS_VERSION=33.0.3
ARG ANDROID_SDK_CMDLINE_TOOLS_VERSION=13.0
ARG DOTNET_VERSION=9.0
ARG DOTNET_WORKLOADS_VERSION=9.0.203

ENV GITHUB_ACTIONS_RUNNER_VERSION=$GITHUB_ACTIONS_RUNNER_VERSION
ENV JDK_MAJOR_VERSION=$JDK_MAJOR_VERSION
ENV ANDROID_SDK_API_LEVEL=$ANDROID_SDK_API_LEVEL
ENV ANDROID_SDK_BUILD_TOOLS_VERSION=$ANDROID_SDK_BUILD_TOOLS_VERSION
ENV ANDROID_SDK_CMDLINE_TOOLS_VERSION=$ANDROID_SDK_CMDLINE_TOOLS_VERSION
ENV DOTNET_VERSION=$DOTNET_VERSION
ENV DOTNET_WORKLOADS_VERSION=$DOTNET_WORKLOADS_VERSION

# Set core environment variables
ENV ANDROID_HOME="C:/androidsdk"
ENV ANDROID_SDK_HOME=$ANDROID_HOME
ENV LOG_PATH="C:\\logs\\"

# Set PowerShell as the default shell
SHELL ["powershell.exe", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

#RUN "%SystemRoot%\system32\WindowsPowerShell\v1.0\powershell.exe" -Command "echo HIELLLLOIOOO"

# Create log directory
RUN New-Item -ItemType Directory -Path $env:LOG_PATH -Force

# Install chocolatey (winget won't install on server core)
RUN Set-ExecutionPolicy Bypass -Scope Process -Force; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); \
    choco install git -y;

# Install openjdk
RUN choco install microsoft-openjdk$($env:JDK_MAJOR_VERSION) -y

# Install the Workloads
RUN dotnet workload install maui --version $env:DOTNET_WORKLOADS_VERSION

# Install Android SDK Tool
RUN dotnet tool install -g AndroidSdk.Tool

# Install and configure Android SDK
RUN android sdk download --home="$env:ANDROID_HOME"

RUN android sdk install --package="platform-tools"
RUN $buildToolsPackage = 'build-tools;' + $env:ANDROID_SDK_BUILD_TOOLS_VERSION; \
    android sdk install --package=$buildToolsPackage
RUN $cmdlineToolsPackage = 'cmdline-tools;' + $env:ANDROID_SDK_CMDLINE_TOOLS_VERSION; \
    android sdk install --package=$cmdlineToolsPackage
RUN $platformsPackage = 'platforms;' + $env:ANDROID_SDK_API_LEVEL; \
    android sdk install --package=$platformsPackage

RUN android sdk info --format=json > $env:LOG_PATH/sdk_info.json
RUN android sdk list --installed --format=json > $env:LOG_PATH/sdk_list.json

# Accept Android Licenses
RUN android sdk accept-licenses --force --home="$env:ANDROID_HOME"


# Create a folder
RUN New-Item -ItemType Directory -Path C:/actions-runner -Force
WORKDIR C:/actions-runner

# Download the latest runner package
RUN $zipUrl = 'https://github.com/actions/runner/releases/download/v' + $env:GITHUB_ACTIONS_RUNNER_VERSION + '/actions-runner-win-x64-' + $env:GITHUB_ACTIONS_RUNNER_VERSION + '.zip' ; \
    Invoke-WebRequest -Uri $zipUrl -OutFile actions-runner-windows.zip
RUN $zipFile = $PWD.Path + '\\actions-runner-windows.zip' ; \
    Add-Type -AssemblyName System.IO.Compression.FileSystem ; [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $PWD) ; \
    Remove-Item -Path $zipFile -Force

# Copy the Supervisor configuration file for running the emulator and Appium
COPY scripts/runner.ps1 C:/actions-runner/runner.ps1


# Default command
CMD ["powershell", "C:\\actions-runner\\runner.ps1"]