$ErrorActionPreference = 'Stop'
$env:JAVA_TOOL_OPTIONS = '-Djdk.net.unixdomain.tmpdir=C:\tmp -Djava.io.tmpdir=C:\tmp'
$env:TEMP = 'C:\tmp'
$env:TMP = 'C:\tmp'
New-Item -ItemType Directory -Force -Path 'C:\tmp' | Out-Null
& 'C:\tools\flutter\bin\flutter.bat' build apk --debug --target lib/main.dart
exit $LASTEXITCODE
