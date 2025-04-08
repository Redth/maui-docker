Param([String]$AndroidSdkApiLevel=35,
    [Int]$AdbPortMapping=5555,
    [Int]$EmulatorPortMapping=5554,
    [Int]$GrpcPortMapping=8554,
    [Int]$AppiumPortMapping=4723)


$runArgs = @(
    "run", "-d",
    "--device", "/dev/kvm",
    "-p", "${AdbPortMapping}:5555/tcp",
    "-p", "${EmulatorPortMapping}:5554/tcp",
    "-p", "${GrpcPortMapping}:8554/tcp",
    "-p", "${AppiumPortMapping}:4723/tcp",
    "redth/maui-docker:android_appium_emulator_$AndroidSdkApiLevel"
)

& docker $runArgs