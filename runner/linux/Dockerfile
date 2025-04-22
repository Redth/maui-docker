# Use .NET SDK base image
FROM mcr.microsoft.com/dotnet/sdk:9.0-noble

ARG TARGETARCH

# Set build arguments
ARG GITHUB_ACTIONS_RUNNER_VERSION=2.323.0
ARG JDK_MAJOR_VERSION=17
ARG ANDROID_SDK_API_LEVEL=35
ARG ANDROID_SDK_BUILD_TOOLS_VERSION=33.0.3
ARG ANDROID_SDK_CMDLINE_TOOLS_VERSION=13.0
ARG DOTNET_VERSION=9.0
ARG DOTNET_WORKLOADS_VERSION=9.0.203

ENV GITHUB_ACTIONS_RUNNER_VERSION=${GITHUB_ACTIONS_RUNNER_VERSION}
ENV JDK_MAJOR_VERSION=${JDK_MAJOR_VERSION}
ENV ANDROID_SDK_API_LEVEL=${ANDROID_SDK_API_LEVEL}
ENV ANDROID_SDK_BUILD_TOOLS_VERSION=${ANDROID_SDK_BUILD_TOOLS_VERSION}
ENV ANDROID_SDK_CMDLINE_TOOLS_VERSION=${ANDROID_SDK_CMDLINE_TOOLS_VERSION}
ENV DOTNET_VERSION=${DOTNET_VERSION}
ENV DOTNET_WORKLOADS_VERSION=${DOTNET_WORKLOADS_VERSION}


ENV GITHUB_ORG=""
ENV GITHUB_REPO=""
ENV GITHUB_TOKEN=""
ENV RUNNER_NAME_PREFIX="maui-runner"
ENV LABELS=""

# Set core environment variables
ENV ANDROID_HOME=/home/mauiusr/.android \
    ANDROID_SDK_HOME=/home/mauiusr/.android \
    DEBIAN_FRONTEND=noninteractive \
    LOG_PATH=/logs \
    JAVA_HOME="/usr/lib/jvm/msopenjdk-${JDK_MAJOR_VERSION}-${TARGETARCH}"

# Create log directory
RUN mkdir ${LOG_PATH}

# Install base packages
RUN apt-get update && apt-get install -y \
    sudo \
    curl \
    ca-certificates \
    gnupg \
    udev \
    tzdata \
    git \
    lsb-release \
    wget \
    apt-transport-https software-properties-common \
    unzip \
    tree \
    socat supervisor \
    jq build-essential libssl-dev libffi-dev python3 python3-venv python3-dev python3-pip \
    libkrb5-3 zlib1g \
    && apt autoremove -y \
    && apt clean all \
    && rm -rf /var/lib/apt/lists/*

# Create mauiusr to run things under
ARG USER_PASS=secret
RUN groupadd mauiusr \
         --gid 1401 \
  && useradd mauiusr \
         --uid 1400 \
         --gid 1401 \
         --create-home \
         --shell /bin/bash \
  && usermod -aG sudo mauiusr \
  && echo mauiusr:${USER_PASS} | chpasswd \
  && echo 'mauiusr ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# Add .NET tools to PATH and fix permissions
#RUN chmod -R +x /home/mauiusr/.dotnet/tools/* && \
#    chown -R 1400:1401 /home/mauiusr/.dotnet

# Install Microsoft Packages: MS OpenJDK and Powershell
RUN ubuntu_release=$(lsb_release -rs) \
    && wget "https://packages.microsoft.com/config/ubuntu/${ubuntu_release}/packages-microsoft-prod.deb" -O packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && rm packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y msopenjdk-${JDK_MAJOR_VERSION} powershell \
    && apt autoremove -y \
    && apt clean all \
    && rm -rf /var/lib/apt/lists/*

# Install the Workloads
RUN dotnet workload install maui-android --version ${DOTNET_WORKLOADS_VERSION}

# Fix permissions on the log directory
RUN chown -R 1400:1401 ${LOG_PATH}

# Switch to mauiusr
USER 1400:1401

# Install Android SDK Tool
RUN dotnet tool install -g AndroidSdk.Tool

ENV PATH="/home/mauiusr/.dotnet/tools:${PATH}"

# Set working directory
WORKDIR /home/mauiusr

# Copy the Supervisor configuration file for running the emulator and Appium
COPY scripts/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY scripts/runner.sh /home/mauiusr/runner.sh

# Install and configure Android SDK
RUN android sdk download --home="${ANDROID_HOME}"

RUN android sdk install \
    --package="platform-tools" \
    --package="build-tools;${ANDROID_SDK_BUILD_TOOLS_VERSION}" \
    --package="cmdline-tools;${ANDROID_SDK_CMDLINE_TOOLS_VERSION}" \
    --package="platforms;android-${ANDROID_SDK_API_LEVEL}"

RUN android sdk info --format=json > /home/mauiusr/sdk_info.json
RUN android sdk list --installed --format=json > /home/mauiusr/sdk_list.json

# Accept Android Licenses
RUN android sdk accept-licenses --force --home="${ANDROID_HOME}"

# Create a folder
RUN mkdir actions-runner

WORKDIR /home/mauiusr/actions-runner

# Download the latest runner package
RUN curl -o actions-runner-linux.tar.gz -L https://github.com/actions/runner/releases/download/v${GITHUB_ACTIONS_RUNNER_VERSION}/actions-runner-linux-x64-${GITHUB_ACTIONS_RUNNER_VERSION}.tar.gz
# Extract the installer
RUN tar xzf ./actions-runner-linux.tar.gz
RUN rm -rf ./actions-runner-linux.tar.gz

# Default command
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]