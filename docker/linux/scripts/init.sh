#!/usr/bin/bash

# Base initialization script for MAUI development environment
echo "MAUI Base Image - Linux"
echo "=======================" 

echo "Base initialization complete."
echo "This is a MAUI development base image with .NET $DOTNET_VERSION, Android SDK, and Java $JDK_MAJOR_VERSION"
echo "You can now run your MAUI Android development tasks."
echo ""
echo "This image includes GitHub Actions and Gitea Actions runner capabilities."
echo "To enable runners, set the appropriate environment variables:"
echo "  - GitHub: GITHUB_ORG and GITHUB_TOKEN"
echo "  - Gitea: GITEA_INSTANCE_URL and GITEA_RUNNER_TOKEN"
echo ""

# Start the runner script which handles both GitHub and Gitea runners
# The runner script will also execute any custom initialization scripts
exec /usr/bin/bash /home/mauiusr/runner.sh
