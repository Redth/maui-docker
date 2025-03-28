# Use .NET SDK base image
FROM mcr.microsoft.com/dotnet/sdk:9.0-noble

# Set environment variables
ENV ANDROID_HOME=/home/mauiusr/android-sdk
ENV ANDROID_SDK_VERSION=11076708
ENV NODE_VERSION=22.x
ENV ProvisionRequiresSudo="False"
ENV DEBIAN_FRONTEND=noninteractive
ENV AndroidSdkApiLevel=33
ENV AndroidSdkAvdSystemImageType=google_apis_playstore
ENV LOG_PATH=/logs

RUN mkdir ${LOG_PATH}

# Create a user
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

WORKDIR /home/mauiusr

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
    qemu-kvm bridge-utils libvirt-daemon-system libvirt-daemon qemu-system virt-manager \
    socat supervisor \
    && apt autoremove -y \
    && apt clean all \
    && rm -rf /var/lib/apt/lists/*

# Enable KVM - but skip udevadm commands which don't work in Docker
RUN echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | tee /etc/udev/rules.d/99-kvm4all.rules
# Create KVM device node manually instead of using udevadm
RUN mkdir -p /dev && test ! -e /dev/kvm && mknod /dev/kvm c 10 232 || true
RUN chmod 666 /dev/kvm || true
RUN ls -la /dev/kvm || echo "KVM device not available in container, but continuing build"

# Skip this check if it fails - will be handled by the container runtime
RUN kvm-ok || echo "KVM may not be available in build environment, continuing anyway"
RUN virsh version || echo "virsh may not be fully functional in build environment, continuing anyway"

# MS OpenJDK
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

# Download SDK, extract it, and move the folder to be latest since we expect $ANDROID_HOME/cmdline-tools/latest folder structure
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools/ && cd ${ANDROID_HOME}/cmdline-tools/ && pwd && \
    wget -q "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_VERSION}_latest.zip" && \
    unzip *commandlinetools-linux*.zip && \
    rm *commandlinetools*linux*.zip && \
    mv cmdline-tools latest && \
    ls -al ${ANDROID_HOME}

RUN dotnet tool install -g AndroidSdk.Tool

# Create a directory for supervisor logs
RUN mkdir -p /var/log/supervisor

# Copy the Supervisor configuration file
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf


# Set working directory
WORKDIR /home/mauiusr

# Clone the .NET MAUI repository
RUN git clone https://github.com/dotnet/maui.git

# Set working directory to the MAUI repo
WORKDIR /home/mauiusr/maui

# Copy Android.props file to the container
COPY DockerProvision.csproj ./DockerProvision.csproj

# Restore global tools
RUN dotnet tool restore

# Set the preferred Android SDK location
RUN dotnet android sdk info -p:ANDROID_HOME=${ANDROID_HOME}

# Provision everything
RUN dotnet build -t:ProvisionAll ./DockerProvision.csproj -v:detailed

WORKDIR /home/mauiusr

RUN rm -rf maui

# Fix permissions
#RUN chown -R 1400:1401 /usr/lib/node_modules
RUN chown -R 1400:1401 /home/mauiusr

USER 1400:1401

# Expose ports for Appium, Android emulator, and ADB
EXPOSE 4723 5554 5555

# Default command (can be overridden)
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]