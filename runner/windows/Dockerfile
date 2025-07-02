# Use MAUI base image
ARG BASE_IMAGE_TAG=latest
ARG BASE_DOCKER_REPOSITORY=redth/maui-docker-base
FROM ${BASE_DOCKER_REPOSITORY}:windows-${BASE_IMAGE_TAG}

# Set build arguments for GitHub Actions Runner
ARG GITHUB_ACTIONS_RUNNER_VERSION=2.323.0

ENV GITHUB_ACTIONS_RUNNER_VERSION=$GITHUB_ACTIONS_RUNNER_VERSION

# Define environment variables for GitHub runner registration
# Default to empty values, will be overridden by values from docker-compose
ENV GITHUB_ORG=""
ENV GITHUB_REPO=""
ENV GITHUB_TOKEN=""
ENV RUNNER_NAME_PREFIX="maui-runner"
ENV RANDOM_RUNNER_SUFFIX=""
ENV RUNNER_GROUP=""
ENV RUNNER_WORKDIR=""
ENV LABELS=""
ENV DISABLE_AUTO_UPDATE=""
ENV NO_DEFAULT_LABELS=""
ENV EPHEMERAL=""

# Set PowerShell as the default shell
SHELL ["powershell.exe", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]


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