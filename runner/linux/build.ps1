Param([String]$DotnetVersion="9.0",
    [String]$WorkloadSetVersion="",
    [String]$DockerRepository="redth/maui-docker",
    [String]$Version="latest",
    [Bool]$Load=$false,
    [Bool]$Push=$false) 

# Use a more reliable method to import the common functions module
# This handles paths with spaces better and is more explicit
$buildPath = Join-Path -Path $PSScriptRoot -ChildPath "..\runner-build.ps1" -Resolve -ErrorAction SilentlyContinue
. $buildPath -DotnetVersion $DotnetVersion `
    -WorkloadSetVersion $WorkloadSetVersion `
    -DockerRepository $DockerRepository `
    -DockerPlatform "linux/amd64" `
    -Version $Version `
    -Load $Load `
    -Push $Push

