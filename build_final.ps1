$ErrorActionPreference = 'Stop'
Write-Host "Copiando projeto para pasta sem caracteres especiais..."
$tempDir = "C:\IsolatedBuildEnv\fithub_agua_app_temp"
if (Test-Path $tempDir) { Remove-Item -Path $tempDir -Recurse -Force }
Copy-Item -Path "$PSScriptRoot\fithub_agua_app" -Destination $tempDir -Recurse -Force

Write-Host "Iniciando compilacao isolada..."
cd $tempDir
$env:JAVA_HOME = "C:\IsolatedBuildEnv\jdk17"
$env:ANDROID_HOME = "C:\IsolatedBuildEnv\android-sdk"
$env:Path = "C:\IsolatedBuildEnv\jdk17\bin;C:\IsolatedBuildEnv\android-sdk\cmdline-tools\latest\bin;" + $env:Path

# Executa clean e pub get para garantir que as dependencias estao atualizadas e sem cache quebrado
C:\src\flutter\bin\flutter.bat clean
C:\src\flutter\bin\flutter.bat pub get
C:\src\flutter\bin\flutter.bat build apk --release

Write-Host "Copiando APK de volta..."
Copy-Item -Path "$tempDir\build\app\outputs\flutter-apk\app-release.apk" -Destination "$PSScriptRoot\fithub_agua_app.apk" -Force

Write-Host "Limpando projeto clonado..."
cd C:\
Remove-Item -Path $tempDir -Recurse -Force
Write-Host "PROCESSO 100% FINALIZADO."
