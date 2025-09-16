# Repository Guidelines

## Project Structure & Module Organization
Docker definitions live in three sibling folders. `base/` owns the MAUI development images, split into `linux/` and `windows/` contexts with shared helpers in `base-build.ps1`. `runner/` layers the GitHub Actions runner service onto those images via platform-specific subfolders. `test/` contains the Appium-enabled Android emulator image plus `run.ps1` for local smoke runs. Shared PowerShell helpers sit in `common-functions.ps1`, while `_temp/` holds scratch artifacts generated during builds.

## Build, Test, and Development Commands
Use PowerShell (Core or Windows) to invoke the scripted entry points:
- `pwsh base/base-build.ps1 -DockerPlatform linux/amd64 -Version <tag>` builds the base image and tags it for Linux.
- `pwsh runner/runner-build.ps1 -DockerPlatform windows/amd64 -Version <tag> -Push` emits the runner image and optionally pushes it.
- `pwsh test/build.ps1 -AndroidSdkApiLevel 35 -Load` produces the emulator test image and keeps it locally loaded.
- `pwsh test/run.ps1 -AndroidSdkApiLevel 35` launches the container with Appium, ADB, and emulator ports mapped for manual validation.

## Coding Style & Naming Conventions
PowerShell scripts start with a `Param` block and use PascalCase parameter names, four-space indentation, and splatted arrays for longer command invocations. Guard shared imports with `Join-Path` plus `Test-Path` as in `base/base-build.ps1:18`, and keep helper functions in `common-functions.ps1`. Dockerfiles should keep instructions uppercase, group related `RUN` steps, and expose configurable values via `ARG`/`ENV` pairs so CI callers can override them.

## Testing Guidelines
Container changes should be validated by rebuilding the affected image and exercising a smoke scenario. For Android tooling updates, run `pwsh test/build.ps1` followed by `pwsh test/run.ps1` and confirm the emulator, ADB, and Appium endpoints respond. When altering shared helpers, run at least one Linux and one Windows build path to ensure workload discovery still succeeds. Mirror the existing verb-based naming (`build.ps1`, `run.ps1`) for new test utilities.

## Commit & Pull Request Guidelines
Commits use short, imperative subjects ("Add claude instructions", "Fix version format") and avoid trailing punctuation. Keep related Docker and script changes together and document version bumps in the body when needed. Pull requests should describe the image families touched, note required environment variables (such as `GITHUB_TOKEN` for runners), and include before/after build or runtime logs if behavior changed.

## Security & Configuration Tips
Do not bake personal tokens into Dockerfiles or scripts; rely on runtime environment variables like `GITHUB_TOKEN`, `RUNNER_NAME`, and `INIT_PWSH_SCRIPT`. When testing locally, prefer binding secrets through `--env-file` or volume-mounted config rather than editing tracked files.
