# Use MAUI base image
ARG BASE_IMAGE_TAG=latest
ARG BASE_DOCKER_REPOSITORY=redth/maui-docker-base
FROM ${BASE_DOCKER_REPOSITORY}:linux-${BASE_IMAGE_TAG}

# Set build arguments for GitHub Actions Runner
ARG GITHUB_ACTIONS_RUNNER_VERSION=2.323.0

ENV GITHUB_ACTIONS_RUNNER_VERSION=${GITHUB_ACTIONS_RUNNER_VERSION}

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

# Switch to root to copy files and install runner
USER root

# Copy the Supervisor configuration file for running the actions runner
COPY scripts/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY scripts/runner.sh /home/mauiusr/runner.sh

# Make runner script executable and fix ownership
RUN chmod +x /home/mauiusr/runner.sh && chown 1400:1401 /home/mauiusr/runner.sh

# Switch back to mauiusr
USER 1400:1401

# Set working directory
WORKDIR /home/mauiusr

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