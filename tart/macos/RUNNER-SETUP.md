# CI Runner Setup for MAUI Tart VMs

This guide explains how to configure GitHub Actions or Gitea Actions runners to auto-start when the VM boots.

## Quick Start

### GitHub Actions Runner

1. Create a config folder with a `.env` file:

```bash
mkdir -p ~/tart-config
cat > ~/tart-config/.env << 'EOF'
GITHUB_ORG=your-organization
GITHUB_TOKEN=ghp_your_personal_access_token
LABELS=macos,maui,arm64
EOF
```

2. Run the VM with the config folder mounted:

```bash
tart run maui-dev-tahoe-dotnet10.0 --dir config:~/tart-config
```

3. The runner will automatically register and start on boot!

### Gitea Actions Runner

1. Create a config folder with a `.env` file:

```bash
mkdir -p ~/tart-config
cat > ~/tart-config/.env << 'EOF'
GITEA_INSTANCE_URL=https://gitea.example.com
GITEA_RUNNER_TOKEN=your_runner_registration_token
GITEA_RUNNER_LABELS=macos,maui,arm64
EOF
```

2. Run the VM with the config folder mounted:

```bash
tart run maui-dev-tahoe-dotnet10.0 --dir config:~/tart-config
```

## How It Works

When the VM boots:

1. **Bootstrap LaunchAgent** (`com.maui.bootstrap.plist`) starts first
2. Checks for `/Volumes/My Shared Files/config/.env`
3. Loads environment variables and sets them via `launchctl setenv`
4. Runs `/Volumes/My Shared Files/config/init.sh` if present
5. **Runner LaunchAgents** start and use the environment variables
6. Runners register and start accepting jobs

## Configuration Options

### GitHub Actions Runner

See [`.env.example`](scripts/.env.example) for all available options.

**Required:**
- `GITHUB_ORG` - GitHub organization name
- `GITHUB_TOKEN` - GitHub personal access token with `repo` and `admin:org` scopes

**Optional:**
- `GITHUB_REPO` - Repository name (for repo-level runner, omit for org-level)
- `RUNNER_NAME` - Custom runner name
- `RUNNER_NAME_PREFIX` - Prefix for auto-generated names (default: "github-runner")
- `RANDOM_RUNNER_SUFFIX` - Add random suffix (default: "true")
- `LABELS` - Comma-separated labels (default: "default")
- `RUNNER_GROUP` - Runner group (default: "Default")
- `EPHEMERAL` - Ephemeral mode (default: "false")
- `DISABLE_AUTO_UPDATE` - Disable auto-updates (default: "false")

### Gitea Actions Runner

**Required:**
- `GITEA_INSTANCE_URL` - Gitea instance URL (e.g., "https://gitea.example.com")
- `GITEA_RUNNER_TOKEN` - Runner registration token from Gitea

**Optional:**
- `GITEA_RUNNER_NAME` - Custom runner name
- `GITEA_RUNNER_NAME_PREFIX` - Prefix for auto-generated names (default: "gitea-runner")
- `GITEA_RUNNER_LABELS` - Comma-separated labels (default: "macos,maui,arm64")
- `RANDOM_RUNNER_SUFFIX` - Add random suffix (default: "true")

## Custom Initialization Script

You can provide a custom `init.sh` script that runs before the runners start:

```bash
cat > ~/tart-config/init.sh << 'EOF'
#!/bin/bash
echo "Running custom initialization..."

# Clone a repository
git clone https://github.com/myorg/myrepo ~/Development/myrepo

# Install additional tools
brew install your-tool

# Any other setup you need
EOF

chmod +x ~/tart-config/init.sh
```

The bootstrap system will execute this script automatically.

## Logs and Troubleshooting

Logs are written to:
- `/Users/admin/Library/Logs/bootstrap.log` - Bootstrap initialization
- `/Users/admin/Library/Logs/github-runner.log` - GitHub Actions runner
- `/Users/admin/Library/Logs/gitea-runner.log` - Gitea Actions runner

You can also check system logs:
```bash
log show --predicate 'process == "maui-bootstrap"' --last 5m
```

To manually check if environment variables were set:
```bash
launchctl getenv GITHUB_ORG
launchctl getenv GITHUB_TOKEN
```

To manually start a runner (if auto-start isn't working):
```bash
# GitHub
/Users/admin/actions-runner/maui-runner.sh

# Gitea
/Users/admin/gitea-runner/gitea-runner.sh
```

## Multiple Config Folders

You can mount multiple shared folders:

```bash
tart run maui-dev-tahoe-dotnet10.0 \
  --dir config:~/tart-config \
  --dir project:~/my-maui-project
```

## Persistent vs Ephemeral Runners

### Persistent Runners (default)
- Runner stays registered after job completes
- Accepts multiple jobs
- Good for dedicated build machines

### Ephemeral Runners
- Runner is removed after one job
- Must re-register for each job
- Good for security-sensitive environments

To enable ephemeral mode, add to `.env`:
```bash
EPHEMERAL=true
```

## Security Best Practices

1. **Never commit `.env` files** with credentials to version control
2. **Use scoped tokens** with minimum required permissions
3. **Consider ephemeral runners** for untrusted code
4. **Rotate tokens regularly**
5. **Monitor runner activity** in your GitHub/Gitea organization settings

## Comparison with Docker Runner Images

| Feature | Docker | Tart VM |
|---------|--------|---------|
| Set env vars | `docker run -e VAR=value` | Mount `.env` file via `--dir` |
| Init script | `-e INIT_BASH_SCRIPT=/path` | Include `init.sh` in config folder |
| Auto-start | supervisord | LaunchAgents |
| Logs | stdout/stderr | `~/Library/Logs/*.log` |
| Platform | Linux/Windows | macOS only |

The Tart VM approach requires mounting a config folder instead of passing environment variables directly, but provides the same auto-start and initialization capabilities.
