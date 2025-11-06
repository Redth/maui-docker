# Repository Guidelines

## Project Structure & Module Organization
- `base/` hosts MAUI development images; use `linux/` and `windows/` subfolders plus shared helpers in `base/base-build.ps1`.
- `runner/` layers GitHub Actions runners on top of the base images with platform-specific contexts.
- `test/` builds the Appium-enabled Android emulator image; `run.ps1` performs local smoke runs.
- Shared PowerShell utilities sit in `common-functions.ps1`; transient build artifacts land in `_temp/`.

## Build, Test, and Development Commands
- `pwsh base/base-build.ps1 -DockerPlatform linux/amd64 -Version <tag>` builds and tags the Linux base image.
- `pwsh runner/runner-build.ps1 -DockerPlatform windows/amd64 -Version <tag> [-Push]` produces the runner image and optionally pushes it.
- `pwsh test/build.ps1 -AndroidSdkApiLevel 35 [-Load]` prepares the Android emulator image; add `-Load` to keep it locally.
- `pwsh test/run.ps1 -AndroidSdkApiLevel 35` starts the emulator container with Appium and ADB ports exposed.

## Coding Style & Naming Conventions
- PowerShell scripts begin with `Param` blocks, use PascalCase parameter names, and four-space indentation.
- Prefer splatted hashtables for longer command invocations and guard shared imports with `Join-Path` + `Test-Path`.
- Dockerfiles keep uppercase instructions, group related `RUN` steps, and expose overrides through paired `ARG` and `ENV` values.

## Testing Guidelines
- Rebuild the affected image before merging; follow with `test/run.ps1` to verify emulator, ADB, and Appium endpoints.
- When editing shared helpers, execute at least one Linux and one Windows build path to confirm tool discovery.
- Keep test utilities in verb-form (`build.ps1`, `run.ps1`) and mirror existing naming when adding scripts.

## Commit & Pull Request Guidelines
- Write imperative commit subjects without trailing punctuation (e.g., "Update Android SDK cache").
- Group related Dockerfile and script updates in the same commit and explain version bumps in the body.
- Pull requests must list touched image families, required env vars (e.g., `GITHUB_TOKEN`, `RUNNER_NAME`), and include relevant build or runtime logs.

## Security & Configuration Tips
- Do not bake credentials into images; supply secrets at runtime via `--env-file` or mounted configuration.
- Prefer environment variables such as `INIT_PWSH_SCRIPT` for runtime customization and keep `_temp/` out of version control.
