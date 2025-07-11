# Set build arguments that need to be available before FROM
ARG DOTNET_VERSION=9.0

# Use .NET SDK base image with dynamic version
FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION}-noble

ARG TARGETARCH

# Set build arguments
ARG JDK_MAJOR_VERSION=17
ARG ANDROID_SDK_API_LEVEL=35
ARG ANDROID_SDK_BUILD_TOOLS_VERSION=33.0.3
ARG ANDROID_SDK_CMDLINE_TOOLS_VERSION=13.0
ARG DOTNET_WORKLOADS_VERSION=9.0.203

ENV JDK_MAJOR_VERSION=${JDK_MAJOR_VERSION}
ENV ANDROID_SDK_API_LEVEL=${ANDROID_SDK_API_LEVEL}
ENV ANDROID_SDK_BUILD_TOOLS_VERSION=${ANDROID_SDK_BUILD_TOOLS_VERSION}
ENV ANDROID_SDK_CMDLINE_TOOLS_VERSION=${ANDROID_SDK_CMDLINE_TOOLS_VERSION}
ENV DOTNET_VERSION=${DOTNET_VERSION}
ENV DOTNET_WORKLOADS_VERSION=${DOTNET_WORKLOADS_VERSION}

ENV INIT_PWSH_SCRIPT="/config/init.ps1"
ENV INIT_BASH_SCRIPT="/config/init.sh"

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
RUN dotnet workload install maui-android wasm-tools --version ${DOTNET_WORKLOADS_VERSION}

# Fix permissions on the log directory
RUN chown -R 1400:1401 ${LOG_PATH}

# Switch to mauiusr
USER 1400:1401

# Install Android SDK Tool
RUN dotnet tool install -g AndroidSdk.Tool

ENV PATH="/home/mauiusr/.dotnet/tools:${PATH}"

# Set working directory
WORKDIR /home/mauiusr

# Copy the init script
COPY scripts/init.sh /home/mauiusr/init.sh

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

# Default command - just keep the container running
CMD ["tail", "-f", "/dev/null"]
