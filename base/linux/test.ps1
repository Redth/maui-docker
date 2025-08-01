
$buildArgs = @{
  DotNetVersion     = "9.0"
  Version           = "16091125574"
  DockerRepository  = "redth/maui-build"
  DockerPlatform    = "linux/amd64"
  Load              = $true
}
if ("refs/heads/main" -eq "refs/heads/main") {
  $buildArgs.Push = $true
}
# Add workload set version if specified

$buildArgs.WorkloadSetVersion = "9.301.1"
./build.ps1 @buildArgs
