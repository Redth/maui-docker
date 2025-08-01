# Set build arguments that need to be available before FROM
ARG DOTNET_VERSION=9.0

# Use .NET SDK base image with dynamic version
FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION}-windowsservercore-ltsc2022

# Set build arguments
ARG JDK_MAJOR_VERSION=17
ARG ANDROID_SDK_API_LEVEL=35
ARG ANDROID_SDK_BUILD_TOOLS_VERSION=33.0.3
ARG ANDROID_SDK_CMDLINE_TOOLS_VERSION=13.0
ARG DOTNET_WORKLOADS_VERSION=9.0.203

ENV JDK_MAJOR_VERSION=$JDK_MAJOR_VERSION
ENV ANDROID_SDK_API_LEVEL=$ANDROID_SDK_API_LEVEL
ENV ANDROID_SDK_BUILD_TOOLS_VERSION=$ANDROID_SDK_BUILD_TOOLS_VERSION
ENV ANDROID_SDK_CMDLINE_TOOLS_VERSION=$ANDROID_SDK_CMDLINE_TOOLS_VERSION
ENV DOTNET_VERSION=$DOTNET_VERSION
ENV DOTNET_WORKLOADS_VERSION=$DOTNET_WORKLOADS_VERSION

ENV INIT_PWSH_SCRIPT="C:/config/init.ps1"

# Set core environment variables
ENV ANDROID_HOME="C:/androidsdk"
ENV ANDROID_SDK_HOME=$ANDROID_HOME
ENV LOG_PATH="C:\\logs\\"

# Set PowerShell as the default shell
SHELL ["powershell.exe", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

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

# Install Android SDK Tool & AppleDev Tool
RUN dotnet tool install -g AndroidSdk.Tool
RUN dotnet tool install -g AppleDev.Tools

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

# Copy the init script
COPY scripts/init.ps1 C:/init.ps1

# Default command - just keep the container running
CMD ["powershell", "while ($true) { Start-Sleep -Seconds 30 }"]
