# Escalas de Louvor — App

App Flutter para a equipe ver e o líder montar escalas. **Um projeto, duas
plataformas**: o aplicativo Android e a versão Web para desktop saem do mesmo
código, com as mesmas regras, os mesmos modelos e a mesma API.

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

### Web

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
```

`http://localhost:3000` e não `10.0.2.2`: o navegador roda no Windows, e
`10.0.2.2` só existe dentro do emulador Android.

O backend precisa aceitar a origem do Chrome. Em desenvolvimento o padrão de
`CORS_ORIGINS` é `*`, e nada precisa ser configurado; em produção veja
[Publicar a versão Web](#publicar-a-versão-web).

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

### Instalar sem cabo USB

1. Baixe ou transfira `app-release.apk` para o celular.
2. Abra o arquivo pelo navegador ou pelo gerenciador de arquivos.
3. Se o Android bloquear, autorize **Instalar apps desconhecidos** apenas para
   o aplicativo que abriu o arquivo (por exemplo, Chrome ou Arquivos).
4. Confirme a instalação e, ao terminar, revogue essa autorização se desejar.

Para atualizar, abra o APK novo sem desinstalar o anterior. O arquivo precisa
ter um número de build maior e a mesma assinatura. Se o Android informar que o
pacote é incompatível, não desinstale antes de confirmar que o APK foi assinado
com o keystore definitivo.

O procedimento completo de Railway, versão, assinatura e publicação está em
[`../docs/DEPLOY.md`](../docs/DEPLOY.md).

### Publicar a versão Web

```powershell
flutter build web --release --dart-define=API_BASE_URL=https://backend-production-b304.up.railway.app
```

A saída fica em `build/web`. É um site estático: sirva a pasta inteira em
qualquer hospedagem (Netlify, Vercel, Cloudflare Pages, GitHub Pages, Nginx).

Três coisas para não esquecer:

1. **CORS no backend.** A API só responde ao navegador se o domínio do site
   estiver em `CORS_ORIGINS`. Em produção `*` é recusado no boot, então some o
   domínio à lista, sem barra no fim:

   ```text
   CORS_ORIGINS=https://escalas.suaigreja.com
   ```

   As fotos de perfil (`/uploads/...`) são servidas fora do `enableCors`, com
   `Access-Control-Allow-Origin: *` próprio — são arquivos públicos, sem cookie
   e sem token. Ver `backend/src/main.ts`.

2. **As rotas usam `#`** (a estratégia padrão do go_router na Web):
   `https://seusite/#/agenda/<id>`. Isso é deliberado — com hash, **nenhuma**
   configuração de servidor é necessária: recarregar a página em qualquer rota
   funciona, porque o servidor só vê `/`. Se um dia a URL sem `#` for desejada,
   troque para `PathUrlStrategy` **e** configure o *SPA fallback* da hospedagem
   (toda rota desconhecida serve `index.html`); sem isso, um F5 em
   `/agenda/<id>` devolve 404.

3. **A URL da API é de build**, como no APK: sem o `--dart-define` o site
   aponta para `10.0.2.2:3000` e não fala com ninguém.

Para servir a pasta localmente e conferir o build:

```powershell
python -m http.server 8080 --directory build\web
```

### Navegador × aplicativo: o que muda

Nada de negócio. O que muda é a **arrumação**, e ela é decidida pela largura da
janela — não pela plataforma. Reduzir o Chrome devolve a interface do celular.

| Largura | Navegação | Conteúdo |
| --- | --- | --- |
| < 600px | barra inferior de três abas | uma coluna |
| 600–1024px | barra lateral recolhida (ícones) | uma coluna, com folga |
| > 1024px | barra lateral aberta | colunas alinhadas, tabelas, painéis |

Os pontos de quebra vivem em `lib/core/responsive/app_breakpoints.dart`.

## Estrutura

```
lib/
├─ main.dart
├─ core/          config, network, router, theme, storage, responsive
├─ features/      auth, team, invites, events, assignments, ...
└─ shared/        widgets reutilizaveis
```

`core/responsive/` guarda os pontos de quebra (`app_breakpoints.dart`), o
`ResponsiveLayout`/`ResponsiveBuilder` e o `showAdaptiveSheet` — folha no
celular, diálogo no monitor. **Não há `kIsWeb` espalhado pelas telas**: quem
decide o formato é a largura da janela.

Stack: Riverpod, go_router, Dio. Modelos à mão (sem freezed/build_runner).
