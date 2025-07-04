Param([String]$AndroidSdkApiLevel=35,
    [String]$AdbKeyFolder="$env:USERPROFILE/.android",
    [Int]$AdbPortMapping=5555,
    [Int]$EmulatorPortMapping=5554,
    [Int]$GrpcPortMapping=8554,
    [Int]$AppiumPortMapping=4723,
    [bool]$BindAdbKeys=$true)


$runArgs = @(
    "run", "-d",
    "--device", "/dev/kvm",
    "-p", "${AdbPortMapping}:5555/tcp",
    "-p", "${EmulatorPortMapping}:5554/tcp",
    "-p", "${GrpcPortMapping}:8554/tcp",
    "-p", "${AppiumPortMapping}:4723/tcp"
)

if ($bindAdbKeys) {
    $runArgs += "--mount", "type=bind,src=${AdbKeyFolder}/adbkey,dst=/home/mauiusr/.android/adbkey,readonly"
    $runArgs += "--mount", "type=bind,src=${AdbKeyFolder}/adbkey.pub,dst=/home/mauiusr/.android/adbkey.pub,readonly"
}


$runArgs += "redth/maui-testing:appium-emulator-linux-android$AndroidSdkApiLevel"

& docker $runArgs