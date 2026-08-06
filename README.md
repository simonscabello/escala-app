# Escalas de Louvor — App

App Flutter (Android no MVP) para a equipe ver e o líder montar escalas.

Projeto **independente** do backend: só se comunicam por HTTP. Arquitetura e
convenções: [`AGENTS.md`](AGENTS.md) e [`docs/`](docs/).

## Pré-requisitos

- Flutter instalado (nesta máquina: `C:\Users\Acer\flutter`)
- Android SDK / emulador (ou Chrome para web)
- API rodando se precisar de dados reais (`../backend` — ver README do backend)

O `flutter` **não está no PATH global**. Em cada sessão PowerShell:

```powershell
$env:PATH = 'C:\Users\Acer\flutter\bin;' + $env:PATH
```

Permanente (User PATH):

```powershell
[Environment]::SetEnvironmentVariable('Path', 'C:\Users\Acer\flutter\bin;' + [Environment]::GetEnvironmentVariable('Path','User'), 'User')
```

## Rodar

Na pasta deste projeto:

```powershell
flutter pub get
flutter run
```

Emulador Android usa `10.0.2.2:3000` por padrão (localhost do Windows).

Celular físico — IP da máquina + firewall na porta 3000:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.0.10:3000
```

Web:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
```

## Análise e testes

```powershell
flutter analyze
flutter test
```

## Build release

APK para instalar no celular — aponta para a API em produção (Railway):

```powershell
flutter build apk --release --dart-define=API_BASE_URL=https://backend-production-b304.up.railway.app
```

A URL vai **sem** barra no fim e **sem** `/api/v1`: o `AppConfig` já concatena o
prefixo (`apiUrl = '$apiBaseUrl/api/v1'`). Com `/api/v1` na variável, o app
chama `/api/v1/api/v1` e tudo responde 404.

Build apontando para o backend local, para testar no emulador:

```powershell
flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

HTTP em texto claro no release: `android/app/src/main/res/xml/network_security_config.xml`.
Para celular físico contra o backend local, adicione o IP da máquina nesse
arquivo. Produção é HTTPS e não precisa de nada lá.

Instalar no aparelho conectado:

```powershell
C:\Users\Acer\AppData\Local\Android\sdk\platform-tools\adb.exe install -r build\app\outputs\flutter-apk\app-release.apk
```

## Estrutura

```
lib/
├─ main.dart
├─ core/          config, network, router, theme, storage
├─ features/      auth, team, invites, events, assignments, ...
└─ shared/        widgets reutilizaveis
```

Stack: Riverpod, go_router, Dio. Modelos à mão (sem freezed/build_runner).
