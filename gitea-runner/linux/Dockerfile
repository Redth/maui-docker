# Use MAUI base image
ARG BASE_IMAGE_TAG=latest
ARG BASE_DOCKER_REPOSITORY=redth/maui-build
FROM ${BASE_DOCKER_REPOSITORY}:linux-${BASE_IMAGE_TAG}

# Define environment variables for Gitea runner registration
# Default to empty values, will be overridden by values from docker-compose
ENV GITEA_INSTANCE_URL=""
ENV GITEA_RUNNER_TOKEN=""
ENV GITEA_RUNNER_NAME=""
ENV GITEA_RUNNER_NAME_PREFIX="gitea-runner"
ENV RANDOM_RUNNER_SUFFIX=""
ENV GITEA_RUNNER_LABELS="maui,linux,amd64"

# Switch to root to install runner
USER root

# Copy the Supervisor configuration file for running the Gitea runner
COPY scripts/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY scripts/runner.sh /home/mauiusr/runner.sh

# Make runner script executable and fix ownership
RUN chmod +x /home/mauiusr/runner.sh && chown 1400:1401 /home/mauiusr/runner.sh

# Switch back to mauiusr
USER 1400:1401

# Set working directory
WORKDIR /home/mauiusr

# Create a folder for Gitea runner
RUN mkdir gitea-runner

WORKDIR /home/mauiusr/gitea-runner

# Download the latest Gitea act_runner
RUN LATEST_VERSION=$(curl -fsSL https://gitea.com/api/v1/repos/gitea/act_runner/releases | jq -r '.[0].tag_name') && \
    echo "Downloading act_runner version: $LATEST_VERSION" && \
    curl -fsSL "https://dl.gitea.com/act_runner/${LATEST_VERSION}/act_runner-${LATEST_VERSION}-linux-amd64" -o act_runner && \
    chmod +x act_runner

# Default command
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
