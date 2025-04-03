# Use .NET SDK base image
FROM mcr.microsoft.com/dotnet/sdk:9.0-noble

# Set build arguments with default value
ARG ANDROID_SDK_API_LEVEL=35
ARG ANDROID_SYSIMG_TYPE=google_apis_playstore
ARG MAUI_REPO_COMMIT=b2b2191462463e5239184b0a47ec0d0fe2d07e7d
ARG JDK_MAJOR_VERSION=17
ARG TARGETARCH

# Node Version
ENV NODE_VERSION=22.x

# Set environment variables
ENV ANDROID_HOME=/home/mauiusr/.android
ENV JdkMajorVersion=${JDK_MAJOR_VERSION}

ENV MAUI_REPO_COMMIT=${MAUI_REPO_COMMIT}
ENV MAUI_VERSION_PROPS_URL=https://raw.githubusercontent.com/dotnet/maui/${MAUI_REPO_COMMIT}/eng/Versions.props

RUN curl -o /mauiversionprops.xml ${MAUI_VERSION_PROPS_URL}  

# Get Versions of things from MAUI version properties
ENV APPIUM_VERSION=2.12.2
RUN APPIUM_VERSION=$(cat /mauiversionprops.xml | grep -oP '(?<=<AppiumVersion>).*(?=</AppiumVersion>)') && \
    echo "APPIUM_VERSION=${APPIUM_VERSION}" >> /etc/environment
ENV APPIUM_UIAUTOMATOR2_VERSION=3.8.0
RUN APPIUM_UIAUTOMATOR2_VERSION=$(cat /mauiversionprops.xml | grep -oP '(?<=<AppiumUIAutomator2DriverVersion>).*(?=</AppiumUIAutomator2DriverVersion>)') && \
    echo "APPIUM_UIAUTOMATOR2_VERSION=${APPIUM_UIAUTOMATOR2_VERSION}" >> /etc/environment
ENV ANDROID_CMDLINE_TOOLS_VERSION=13.0
RUN ANDROID_CMDLINE_TOOLS_VERSION=$(cat /mauiversionprops.xml | grep -oP '(?<=<AndroidSdkCmdLineToolsVersion>).*(?=</AndroidSdkCmdLineToolsVersion>)') && \
    echo "ANDROID_CMDLINE_TOOLS_VERSION=${ANDROID_CMDLINE_TOOLS_VERSION}" >> /etc/environment

# Cmdline-tools version
ENV ANDROID_SDK_VERSION=${ANDROID_CMDLINE_TOOLS_VERSION}

# API Level for the Android SDK, Emulator, and AVD
ENV AndroidSdkApiLevel=${ANDROID_SDK_API_LEVEL}

# AVD System Image Type
ENV AndroidSdkAvdSystemImageType=${ANDROID_SYSIMG_TYPE}

# Use the Appium version from MAUI version properties
ENV AppiumVersion=${APPIUM_VERSION}
ENV AppiumUIAutomator2DriverVersion=${APPIUM_UIAUTOMATOR2_VERSION}

# Set ANDROID_SDK_HOST_ABI based on TARGETARCH
ARG TARGETARCH
ENV TARGETARCH=${TARGETARCH}
ENV ANDROID_SDK_HOST_ABI=$TARGETARCH
RUN if [ "$TARGETARCH" = "amd64" ]; then \
      export ANDROID_SDK_HOST_ABI="x86_64"; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
      export ANDROID_SDK_HOST_ABI="arm64-v8a"; \
    fi

#ENV ProvisionRequiresSudo="False"
ENV DEBIAN_FRONTEND=noninteractive
ENV LOG_PATH=/logs

# Enable this to help debug output of android dotnet global tool
#ENV ANDROID_TOOL_PROCESS_RUNNER_LOG_PATH=/logs/android-tool-process-runner.log

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
    apt-get install -y msopenjdk-${JdkMajorVersion}

ENV JAVA_HOME="/usr/lib/jvm/msopenjdk-${JdkMajorVersion}-amd64"

# Install Node.js and npm
RUN curl -sL https://deb.nodesource.com/setup_${NODE_VERSION} | bash -
RUN apt-get -qqy install nodejs
RUN npm install -g npm

# Install Appium
RUN npm install -g appium@${AppiumVersion}
RUN chown -R 1400:1401 /usr/lib/node_modules/appium

# Clean up
RUN apt autoremove -y \
    && apt clean all \
    && rm -rf /var/lib/apt/lists/*

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
RUN git fetch && git checkout -b temp 49c3e0a3701e7634b08b7ca91afe06ddf0e41465 
# dev/redth/provision-specific-android-apis

# Copy csproj file to the container
COPY scripts/DockerProvision.csproj ./DockerProvision.csproj

# Copy the Supervisor configuration file for running the emulator and Appium
COPY scripts/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY scripts/emulator.sh /home/mauiusr/emulator.sh
COPY scripts/appium.sh /home/mauiusr/appium.sh
COPY scripts/androidportforward.sh /home/mauiusr/androidportforward.sh

# Install appium UIautomator2 driver
RUN appium driver install uiautomator2@${AppiumUIAutomator2DriverVersion}

# Restore global tools
RUN dotnet tool restore

# Show SDK Info for logs
RUN dotnet android sdk info --home="${ANDROID_HOME}"

# We provision JDK and Appium manually above
# These two are tricky to do with the Provisioning.csproj since it's running as user here not root
#RUN dotnet build -t:ProvisionJdk ./DockerProvision.csproj -v:detailed
#RUN dotnet build -t:ProvisionAppium -p:AppiumNpmInstallLocation=user ./DockerProvision.csproj -v:detailed

# Provision the Android SDK and create AVD
RUN dotnet build -t:InstallAndroidSdk -p:AndroidSdkHome=${ANDROID_HOME} ./DockerProvision.csproj -v:detailed
RUN dotnet build -t:ProvisionAndroidSdkCommonPackages -p:AndroidSdkRequestedApiLevels=${AndroidSdkApiLevel} -p:AndroidSdkHostAbi=${ANDROID_SDK_HOST_ABI} ./DockerProvision.csproj -v:detailed
RUN dotnet build -t:ProvisionAndroidSdkPlatformApiPackages -p:AndroidSdkRequestedApiLevels=${AndroidSdkApiLevel} -p:AndroidSdkHostAbi=${ANDROID_SDK_HOST_ABI} ./DockerProvision.csproj -v:detailed
RUN dotnet build -t:ProvisionAndroidSdkEmulatorImagePackages -p:AndroidSdkRequestedApiLevels=${AndroidSdkApiLevel} -p:AndroidSdkHostAbi=${ANDROID_SDK_HOST_ABI} ./DockerProvision.csproj -v:detailed
RUN dotnet build -t:ProvisionAndroidSdkAvdCreateAvds -p:AndroidSdkRequestedApiLevels=${AndroidSdkApiLevel} -p:AndroidSdkHostAbi=${ANDROID_SDK_HOST_ABI} ./DockerProvision.csproj -v:detailed

# Accept android licenses
RUN dotnet android accept-licenses --force --home="${ANDROID_HOME}"

# Log some info
RUN dotnet android sdk info --home="${ANDROID_HOME}"
RUN dotnet android sdk list --installed --home="${ANDROID_HOME}"

# Clean up the git repo, no longer needed
WORKDIR /home/mauiusr
RUN rm -rf maui

# Global install the tool for later use since we deleted the maui repo's copy
RUN dotnet tool install -g AndroidSdk.Tool

# Expose ports for Appium, Android emulator, and ADB
EXPOSE 4723 5554 5555

# Default command (can be overridden)
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]