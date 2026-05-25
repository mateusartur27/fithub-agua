$ErrorActionPreference = 'Stop'
Write-Host "Criando diretorio C:\IsolatedBuildEnv..."
New-Item -ItemType Directory -Force -Path C:\IsolatedBuildEnv | Out-Null
New-Item -ItemType Directory -Force -Path C:\IsolatedBuildEnv\android-sdk\cmdline-tools | Out-Null

Write-Host "Baixando Java 17..."
curl.exe -L -o C:\IsolatedBuildEnv\jdk.zip "https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse"

Write-Host "Baixando Android SDK Cmdline Tools..."
curl.exe -L -o C:\IsolatedBuildEnv\cmdline.zip "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"

Write-Host "Extraindo Java 17..."
tar.exe -xf C:\IsolatedBuildEnv\jdk.zip -C C:\IsolatedBuildEnv
$jdkFolder = Get-ChildItem -Path C:\IsolatedBuildEnv -Directory -Filter "jdk-17*" | Select-Object -First 1
Rename-Item -Path $jdkFolder.FullName -NewName "jdk17" -Force

Write-Host "Extraindo Android SDK..."
tar.exe -xf C:\IsolatedBuildEnv\cmdline.zip -C C:\IsolatedBuildEnv\android-sdk\cmdline-tools
Rename-Item -Path C:\IsolatedBuildEnv\android-sdk\cmdline-tools\cmdline-tools -NewName "latest" -Force

Write-Host "Configurando Variaveis de Ambiente Temporarias..."
$env:JAVA_HOME = "C:\IsolatedBuildEnv\jdk17"
$env:ANDROID_HOME = "C:\IsolatedBuildEnv\android-sdk"
$env:Path = "C:\IsolatedBuildEnv\jdk17\bin;C:\IsolatedBuildEnv\android-sdk\cmdline-tools\latest\bin;" + $env:Path

Write-Host "Aceitando licencas e instalando pacotes..."
$yes = "y`n" * 50
$yes | sdkmanager.bat "platform-tools" "build-tools;34.0.0" "platforms;android-34"
$yes | sdkmanager.bat --licenses

Write-Host "Fazendo o Build do Flutter..."
cd "C:\Users\Mateus\OneDrive\Desktop\app hidratação\fithub_agua_app"
flutter build apk --release

Write-Host "SUCESSO! Build finalizado."
