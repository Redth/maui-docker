# Use MAUI base image
ARG BASE_IMAGE_TAG=latest
ARG BASE_DOCKER_REPOSITORY=redth/maui-build
FROM ${BASE_DOCKER_REPOSITORY}:windows-${BASE_IMAGE_TAG}

# Define environment variables for Gitea runner registration
# Default to empty values, will be overridden by values from docker-compose
ENV GITEA_INSTANCE_URL=""
ENV GITEA_RUNNER_TOKEN=""
ENV GITEA_RUNNER_NAME=""
ENV GITEA_RUNNER_NAME_PREFIX="gitea-runner"
ENV RANDOM_RUNNER_SUFFIX=""
ENV GITEA_RUNNER_LABELS="maui,windows,amd64"

# Set PowerShell as the default shell
SHELL ["powershell.exe", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Create a folder for Gitea runner
RUN New-Item -ItemType Directory -Path C:/gitea-runner -Force
WORKDIR C:/gitea-runner

# Download the latest Gitea act_runner
RUN $releases = Invoke-RestMethod -Uri 'https://gitea.com/api/v1/repos/gitea/act_runner/releases' ; \
    $latestVersion = $releases[0].tag_name ; \
    $versionNoPrefix = if ($latestVersion.StartsWith('v')) { $latestVersion.Substring(1) } else { $latestVersion } ; \
    Write-Host "Downloading act_runner version: $latestVersion" ; \
    $downloadUrl = "https://gitea.com/gitea/act_runner/releases/download/${latestVersion}/act_runner-${versionNoPrefix}-windows-amd64.exe" ; \
    Invoke-WebRequest -Uri $downloadUrl -OutFile act_runner.exe

# Copy the runner script
COPY scripts/runner.ps1 C:/gitea-runner/runner.ps1

# Default command
CMD ["powershell", "C:\\gitea-runner\\runner.ps1"]
