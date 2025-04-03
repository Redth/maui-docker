# Use .NET SDK base image
FROM mcr.microsoft.com/dotnet/sdk:9.0-noble

# Set build arguments with default value
ARG ANDROID_SDK_API_LEVEL=35
ARG ANDROID_SYSIMG_TYPE=google_apis_playstore
ARG ANDROID_AVD_DEVICE_TYPE=Nexus 5X
ARG TARGETARCH=x86_64
ARG MAUI_REPO_COMMIT=b2b2191462463e5239184b0a47ec0d0fe2d07e7d
ARG JDK_MAJOR_VERSION=17

# Node Version
ENV NODE_VERSION=22.x

# Set environment variables
ENV ANDROID_HOME=/home/mauiusr/.android
ENV ANDROID_SDK_HOME=${ANDROID_HOME}
ENV MAUI_REPO_COMMIT=${MAUI_REPO_COMMIT}
ENV MAUI_VERSION_PROPS_URL=https://raw.githubusercontent.com/dotnet/maui/${MAUI_REPO_COMMIT}/eng/Versions.props

# Enable this to help debug output of android dotnet global tool
#ENV ANDROID_TOOL_PROCESS_RUNNER_LOG_PATH=/logs/android-tool-process-runner.log

# Install sudo first, installing later fails, need curl too
RUN apt-get update && apt-get install -y sudo curl xmlstarlet

RUN curl -o /tmp/mauiversion.props ${MAUI_VERSION_PROPS_URL}  

# First add the env for ABI based on TARGETARCH
RUN if [ "$TARGETARCH" = "arm64" ]; then \
        echo "MAUI_AndroidAvdHostAbi=arm64-v8a" > /tmp/maui_versions_env.sh ; \
    else \
        echo "MAUI_AndroidAvdHostAbi=x86_64" > /tmp/maui_versions_env.sh ; \
    fi

# Next add the env vars from the mauiversion.props file for values we're interested in
RUN echo "MAUI_AndroidSdkApiLevel=${ANDROID_SDK_API_LEVEL}" >> /tmp/maui_versions_env.sh && \
    echo "MAUI_AndroidAvdHostAbi=${ANDROID_HOST_ABI}" >> /tmp/maui_versions_env.sh && \
    xmlstarlet sel -t -m "//Project/PropertyGroup/*[contains(name(),'Appium')]" -v "concat('export MAUI_', name(), '=\"', ., '\"')" -n /tmp/mauiversion.props >> /tmp/maui_versions_env.sh && \
    xmlstarlet sel -t -m "//Project/PropertyGroup/*[contains(name(),'Android')]" -v "concat('export MAUI_', name(), '=\"', ., '\"')" -n /tmp/mauiversion.props >> /tmp/maui_versions_env.sh && \
    xmlstarlet sel -t -m "//Project/PropertyGroup/*[contains(name(),'Java')]" -v "concat('export MAUI_', name(), '=\"', ., '\"')" -n /tmp/mauiversion.props >> /tmp/maui_versions_env.sh && \
    xmlstarlet sel -t -m "//Project/ItemGroup/AndroidSdkApiLevels[@Include='${ANDROID_SDK_API_LEVEL}']/@SystemImageType" -v "concat('export MAUI_AndroidAvdSystemImageType=\"', ., '\"')" -n /tmp/mauiversion.props >> /tmp/maui_versions_env.sh && \
    chmod +x /tmp/maui_versions_env.sh

# Source the script during image build (this only sets ENV at build time)
RUN . /tmp/maui_versions_env.sh && \
    env | grep MAUI_ >> /tmp/env_exported

# Extract the env vars and use ENV instruction to persist
RUN set -a && . /tmp/maui_versions_env.sh && set +a && \
    env | grep MAUI_ >> /tmp/version_env && \
    while IFS= read -r line; do echo "ENV $line"; done < /tmp/version_env >> /tmp/Dockerfile.env

# Apply ENV instructions to Dockerfile
#COPY /tmp/Dockerfile.env /tmp/Dockerfile.env
#RUN cat /tmp/Dockerfile.env >> /Dockerfile

ENV DEBIAN_FRONTEND=noninteractive
ENV LOG_PATH=/logs

# Create log directory
RUN mkdir ${LOG_PATH}

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
    apt-get install -y msopenjdk-${JDK_MAJOR_VERSION}

ENV JAVA_HOME="/usr/lib/jvm/msopenjdk-${JDK_MAJOR_VERSION}-${TARGETARCH}}"

# Install Node.js and npm
RUN curl -sL https://deb.nodesource.com/setup_${NODE_VERSION} | bash -
RUN apt-get -qqy install nodejs
RUN npm install -g npm

# Install Appium
RUN npm install -g appium@${MAUI_AppiumVersion}
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

# Copy the Supervisor configuration file for running the emulator and Appium
COPY scripts/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY scripts/emulator.sh /home/mauiusr/emulator.sh
COPY scripts/appium.sh /home/mauiusr/appium.sh
COPY scripts/androidportforward.sh /home/mauiusr/androidportforward.sh

# Install appium UIautomator2 driver
RUN appium driver install uiautomator2@${MAUI_AppiumUIAutomator2DriverVersion}

# Global install the tool for later use since we deleted the maui repo's copy
RUN dotnet tool install -g AndroidSdk.Tool

RUN /home/mauiusr/.dotnet/tools/android sdk download --home="${ANDROID_HOME}"
RUN /home/mauiusr/.dotnet/tools/android sdk install --home="${ANDROID_HOME}" \
    --package="platform-tools" \
    --package="build-tools;${MAUI_AndroidSdkBuildToolsVersion}}" \
    --package="cmdline-tools;${MAUI_AndroidSdkCmdLineToolsVersion}" \
    --package="emulator" \
    --package="platforms;android-${MAUI_AndroidSdkApiLevel}"

# Download/Install the Android SDK
RUN /home/mauiusr/.dotnet/tools/android sdk install --home="${ANDROID_HOME}" \
    --package="system-images;android-${MAUI_AndroidSdkApiLevel};${MAUI_AndroidAvdSystemImageType};${MAUI_AndroidAvdHostAbi}"

# Accept Android Licenses
RUN /home/mauiusr/.dotnet/tools/android accept-licenses --force --home="${ANDROID_HOME}"

# Log some info
RUN /home/mauiusr/.dotnet/tools/android sdk info --home="${ANDROID_HOME}"
RUN /home/mauiusr/.dotnet/tools/android sdk list --installed --home="${ANDROID_HOME}"

RUN /home/mauiusr/.dotnet/tools/android avd create \
    --name="Emulator_${MAUI_AndroidSdkApiLevel}" \
    --sdk="system-images;android-${MAUI_AndroidSdkApiLevel};${MAUI_AndroidAvdSystemImageType};${MAUI_AndroidAvdHostAbi}" \
    --device="${MAUI_AndroidSdkAvdDeviceType}" \
    --force

# Expose ports for Appium, Android emulator, and ADB
EXPOSE 4723 5554 5555

# Default command (can be overridden)
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]