# Use .NET SDK base image
FROM mcr.microsoft.com/dotnet/sdk:9.0-noble AS env-builder

# Set build arguments with default value
ARG ANDROID_SDK_API_LEVEL=35
ARG TARGETARCH
ARG MAUI_REPO_COMMIT=b2b2191462463e5239184b0a47ec0d0fe2d07e7d

# Install required tools for environment setup
RUN apt-get update && apt-get install -y curl xmlstarlet gettext-base

# Install Android SDK Tool
RUN dotnet tool install -g AndroidSdk.Tool

# Get MAUI version props
ENV MAUI_VERSION_PROPS_URL=https://raw.githubusercontent.com/dotnet/maui/${MAUI_REPO_COMMIT}/eng/Versions.props
RUN curl -o /tmp/mauiversion.props ${MAUI_VERSION_PROPS_URL}

# Generate environment variables
RUN if [ "$TARGETARCH" = "arm64" ]; then \
        echo 'export MAUI_AndroidAvdHostAbi="arm64-v8a"' > /tmp/maui_versions_env; \
    else \
        echo 'export MAUI_AndroidAvdHostAbi="x86_64"' > /tmp/maui_versions_env; \
    fi && \
    echo 'export MAUI_AndroidSdkApiLevel="${ANDROID_SDK_API_LEVEL}"' >> /tmp/maui_versions_env && \
    xmlstarlet sel -t \
        -m "//Project/PropertyGroup/*[contains(name(),'Appium')]" -v "concat('export MAUI_', name(), '=\"', ., '\"')" -n \
        -m "//Project/PropertyGroup/*[contains(name(),'Android')]" -v "concat('export MAUI_', name(), '=\"', ., '\"')" -n \
        -m "//Project/PropertyGroup/*[contains(name(),'Java')]" -v "concat('export MAUI_', name(), '=\"', ., '\"')" -n \
        -m "//Project/ItemGroup/AndroidSdkApiLevels[@Include='${ANDROID_SDK_API_LEVEL}']/@SystemImageType" -v "concat('export MAUI_AndroidAvdSystemImageType=\"', ., '\"')" -n \
        /tmp/mauiversion.props >> /tmp/maui_versions_env

# Process environment file
RUN envsubst < /tmp/maui_versions_env > /tmp/maui_versions_env.processed && \
    sed 's/^export /ENV /' /tmp/maui_versions_env.processed > /tmp/env_instructions

# Start the main image
FROM mcr.microsoft.com/dotnet/sdk:9.0-noble

# Set build arguments
ARG ANDROID_SDK_API_LEVEL=35
ARG ANDROID_AVD_DEVICE_TYPE="Nexus 5X"
ARG TARGETARCH
ARG MAUI_REPO_COMMIT=b2b2191462463e5239184b0a47ec0d0fe2d07e7d
ARG JDK_MAJOR_VERSION=17

# Set core environment variables
ENV NODE_VERSION=22.x \
    ANDROID_HOME=/home/mauiusr/.android \
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
    xvfb \
    git \
    lsb-release \
    wget \
    unzip \
    cpu-checker \
    ffmpeg \
    tree \
    qemu-kvm qemu-utils bridge-utils libvirt-daemon-system libvirt-daemon qemu-system virt-manager virtinst libvirt-clients \
    socat supervisor \
    && apt autoremove -y \
    && apt clean all \
    && rm -rf /var/lib/apt/lists/*

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

# Copy .NET tools and environment variables
RUN mkdir -p /home/mauiusr/.dotnet/tools && \
    chown -R 1400:1401 /home/mauiusr/.dotnet
COPY --from=env-builder /root/.dotnet/tools/ /home/mauiusr/.dotnet/tools/
COPY --from=env-builder /tmp/env_instructions /tmp/
COPY --from=env-builder /tmp/maui_versions_env.source /tmp/

# Add .NET tools to PATH and fix permissions
RUN chmod -R +x /home/mauiusr/.dotnet/tools/* && \
    chown -R 1400:1401 /home/mauiusr/.dotnet
ENV PATH="/home/mauiusr/.dotnet/tools:${PATH}"

RUN cat /tmp/env_instructions >> /Dockerfile && \
    set -a && . /tmp/maui_versions_env.source && set +a

# Install MS OpenJDK
RUN ubuntu_release=$(lsb_release -rs) && \
    wget "https://packages.microsoft.com/config/ubuntu/${ubuntu_release}/packages-microsoft-prod.deb" -O packages-microsoft-prod.deb && \
    dpkg -i packages-microsoft-prod.deb && \
    rm packages-microsoft-prod.deb && \
    apt-get update && \
    apt-get install -y msopenjdk-${JDK_MAJOR_VERSION}

# Install Node.js and npm
RUN curl -sL https://deb.nodesource.com/setup_${NODE_VERSION} | bash -
RUN apt-get -qqy install nodejs
RUN npm install -g npm

# Install Appium
RUN npm install -g appium@${MAUI_AppiumVersion}
RUN chown -R 1400:1401 /usr/lib/node_modules/appium

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

# Install and configure Android SDK
RUN dotnet tool install -g AndroidSdk.Tool && \
    android sdk download --home="${ANDROID_HOME}" && \
    android sdk install --home="${ANDROID_HOME}" \
    --package="platform-tools" \
    --package="build-tools;${MAUI_AndroidSdkBuildToolsVersion}" \
    --package="cmdline-tools;${MAUI_AndroidSdkCmdLineToolsVersion}" \
    --package="emulator" \
    --package="platforms;android-${MAUI_AndroidSdkApiLevel}" \
    --package="system-images;android-${MAUI_AndroidSdkApiLevel};${MAUI_AndroidAvdSystemImageType};${MAUI_AndroidAvdHostAbi}"

# Accept Android Licenses
RUN android accept-licenses --force --home="${ANDROID_HOME}"

# Create Android Virtual Device
RUN android avd create \
    --name="Emulator_${MAUI_AndroidSdkApiLevel}" \
    --sdk="system-images;android-${MAUI_AndroidSdkApiLevel};${MAUI_AndroidAvdSystemImageType};${MAUI_AndroidAvdHostAbi}" \
    --device="${ANDROID_AVD_DEVICE_TYPE}" \
    --force

# Expose ports for Appium, Android emulator, and ADB
EXPOSE 4723 5554 5555

# Default command
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]