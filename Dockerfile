# Use .NET SDK base image
FROM mcr.microsoft.com/dotnet/sdk:9.0-noble

# Set environment variables
ENV ANDROID_HOME=/home/mauiusr/.android

# Cmdline-tools version
ENV ANDROID_SDK_VERSION=13.0
# API Level for the Android SDK, Emulator, and AVD
ENV AndroidSdkApiLevel=35

# AVD System Image Type
ENV AndroidSdkAvdSystemImageType=google_apis_playstore

ENV AppiumVersion=2.12.2
ENV AppiumUIAutomator2DriverVersion=3.8.0

# Node Version
ENV NODE_VERSION=22.x
#ENV ProvisionRequiresSudo="False"
ENV DEBIAN_FRONTEND=noninteractive
ENV LOG_PATH=/logs
ENV ANDROID_TOOL_PROCESS_RUNNER_LOG_PATH=/logs/android-tool-process-runner.log
ENV ANDROID_SDK_HOME=${ANDROID_HOME}

# Create log directory
RUN mkdir ${LOG_PATH}

# Install sudo first, installing later fails
RUN apt-get update && apt-get install -y sudo

# Create mauiusr to run things under
ARG USER_PASS=secret
RUN groupadd mauiusr \
         --gid 1401 \
  && groupadd kvm \
         --gid 994 \
  && useradd mauiusr \
         --uid 1400 \
         --gid 1401 \
         --create-home \
         --shell /bin/bash \
  && usermod -aG sudo mauiusr \
  && usermod -aG kvm mauiusr \
  && echo mauiusr:${USER_PASS} | chpasswd \
  && echo 'mauiusr ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# Install git and other necessary dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    gnupg \
    udev \
    tzdata \
    xvfb \
    git \
    lsb-release \
    wget \
    unzip \
    curl \
    cpu-checker \
    ffmpeg \
    xvfb \
    tzdata \
    tree \
    qemu-kvm qemu-utils bridge-utils libvirt-daemon-system libvirt-daemon qemu-system virt-manager virtinst libvirt-clients \
    socat supervisor \
    && apt autoremove -y \
    && apt clean all \
    && rm -rf /var/lib/apt/lists/*

# Install MS OpenJDK
RUN ubuntu_release=$(lsb_release -rs) && \
    wget "https://packages.microsoft.com/config/ubuntu/${ubuntu_release}/packages-microsoft-prod.deb" -O packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y msopenjdk-17

ENV JAVA_HOME="/usr/lib/jvm/msopenjdk-17-amd64"

# Install Node.js and npm
RUN curl -sL https://deb.nodesource.com/setup_${NODE_VERSION} | bash -
RUN apt-get -qqy install nodejs
RUN npm install -g npm

# Install Appium
RUN npm install -g appium@${AppiumVersion}
RUN chown -R 1400:1401 /usr/lib/node_modules/appium

# Fix permissions on the log directory
RUN chown -R 1400:1401 ${LOG_PATH}

# Switch to mauiusr
USER 1400:1401

# Set working directory
WORKDIR /home/mauiusr

# Clone the .NET MAUI repository
RUN git clone https://github.com/dotnet/maui.git

# Set working directory to the MAUI repo
WORKDIR /home/mauiusr/maui

# Specific branch with changes needed for provisioning Android SDK and Emulator
RUN git fetch && git checkout -b temp 93b2484155078acbac8e7325c52ffb0c6ea95568 
# dev/redth/provision-specific-android-apis

# Copy csproj file to the container
COPY scripts/DockerProvision.csproj ./DockerProvision.csproj

# Copy the Supervisor configuration file for running the emulator and Appium
COPY scripts/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY scripts/emulator.sh /home/mauiusr/emulator.sh
COPY scripts/appium.sh /home/mauiusr/appium.sh

# Install appium UIautomator2 driver
RUN appium driver install uiautomator2@${AppiumUIAutomator2DriverVersion}

# Restore global tools
RUN dotnet tool restore

# Show SDK Info for logs
RUN dotnet android sdk info --home="${ANDROID_HOME}"


# Provision all of the parts we need
RUN dotnet build -t:ProvisionJdk ./DockerProvision.csproj -v:detailed
#RUN dotnet build -t:ProvisionAppium -p:AppiumNpmInstallLocation=user ./DockerProvision.csproj -v:detailed
RUN dotnet build -t:InstallAndroidSdk -p:AndroidSdkHome=${ANDROID_HOME} ./DockerProvision.csproj -v:detailed
RUN dotnet build -t:ProvisionAndroidSdkCommonPackages -p:AndroidSdkRequestedApiLevels=${AndroidSdkApiLevel} ./DockerProvision.csproj -v:detailed
RUN dotnet build -t:ProvisionAndroidSdkPlatformApiPackages -p:AndroidSdkRequestedApiLevels=${AndroidSdkApiLevel} ./DockerProvision.csproj -v:detailed
RUN dotnet build -t:ProvisionAndroidSdkEmulatorImagePackages -p:AndroidSdkRequestedApiLevels=${AndroidSdkApiLevel} ./DockerProvision.csproj -v:detailed
RUN dotnet build -t:ProvisionAndroidSdkAvdCreateAvds -p:AndroidSdkRequestedApiLevels=${AndroidSdkApiLevel} ./DockerProvision.csproj -v:detailed

# Move the node_modules directory which would be in the maui repo dir, to the home directory
#RUN mv ./node_modules ../node_modules

# Clean up the git repo, no longer needed
WORKDIR /home/mauiusr
RUN rm -rf maui

RUN dotnet tool install -g AndroidSdk.Tool

# Expose ports for Appium, Android emulator, and ADB
EXPOSE 4723 5554 5555

# Default command (can be overridden)
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]