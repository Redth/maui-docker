# Use .NET SDK base image
FROM mcr.microsoft.com/dotnet/sdk:9.0-noble

# Set environment variables
ENV ANDROID_HOME=/work/.android
ENV ANDROID_SDK_VERSION=13.0
ENV NODE_VERSION=22.x
ENV ProvisionRequiresSudo="False"
ENV DEBIAN_FRONTEND=noninteractive
ENV AndroidSdkApiLevel=33
ENV AndroidSdkAvdSystemImageType=google_apis_playstore
ENV LOG_PATH=/logs
ENV ANDROID_TOOL_PROCESS_RUNNER_LOG_PATH=/logs/android-tool-process-runner.log

RUN mkdir ${LOG_PATH}
RUN mkdir /work

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
    qemu-kvm qemu-utils bridge-utils libvirt-daemon-system libvirt-daemon qemu-system virt-manager virtinst libvirt-clients \
    socat supervisor \
    && apt autoremove -y \
    && apt clean all \
    && rm -rf /var/lib/apt/lists/*

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
# RUN mkdir -p ${ANDROID_HOME}/cmdline-tools/ && cd ${ANDROID_HOME}/cmdline-tools/ && pwd && \
#     wget -q "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_VERSION}_latest.zip" && \
#     unzip *commandlinetools-linux*.zip && \
#     rm *commandlinetools*linux*.zip && \
#     mv cmdline-tools latest && \
#     ls -al ${ANDROID_HOME}

# Create a directory for supervisor logs
RUN mkdir -p /var/log/supervisor

# Copy the Supervisor configuration file
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

RUN mkdir -p /work

# Set working directory
WORKDIR /work

RUN dotnet tool install --tool-path /work/androidsdktool AndroidSdk.Tool
#RUN export PATH="$PATH:/root/.dotnet/tools"

RUN /work/androidsdktool/android sdk download --home="${ANDROID_HOME}" --version="${ANDROID_SDK_VERSION}"
RUN rm -rf ${ANDROID_HOME}/androidsdk.zip
RUN rm -rf ${ANDROID_HOME}/.temp


# Clone the .NET MAUI repository
RUN git clone https://github.com/dotnet/maui.git

# Set working directory to the MAUI repo
WORKDIR /work/maui

RUN git checkout dev/redth/provision-specific-android-apis

# Copy Android.props file to the container
COPY DockerProvision.csproj ./DockerProvision.csproj

# Restore global tools
RUN dotnet tool restore

# Show SDK Info for logs
RUN dotnet android sdk info -p:ANDROID_HOME=${ANDROID_HOME}

RUN dotnet build -t:ProvisionJdk ./DockerProvision.csproj -v:detailed
RUN dotnet build -t:ProvisionAppium ./DockerProvision.csproj -v:detailed
RUN dotnet build -t:ProvisionAndroidSdk -p:AndroidSdkRequestedApiLevels=${AndroidSdkApiLevel} ./DockerProvision.csproj -v:detailed



WORKDIR /work
RUN rm -rf maui

# Fix permissions
#RUN chown -R 1400:1401 /usr/lib/node_modules
RUN chown -R 1400:1401 /work
RUN chown -R 1400:1401 ${LOG_PATH}

# Switch to mauiusr
USER 1400:1401


# Expose ports for Appium, Android emulator, and ADB
EXPOSE 4723 5554 5555

# Default command (can be overridden)
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]