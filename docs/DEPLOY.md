# Publicação da Pauta

O backend roda no Railway e o app é distribuído diretamente como APK. Os dois
projetos são independentes: publique `backend/` e gere o APK a partir de
`app/`.

## 1. O que precisa ser feito manualmente pelo dono

- criar ou acessar o projeto no Railway e conectar o repositório do backend;
- adicionar o PostgreSQL e o Volume persistente;
- definir os segredos e as URLs no painel;
- criar e guardar o keystore Android fora do repositório;
- criar o projeto no Firebase e gerar a chave das notificações (seção 7);
- hospedar e distribuir cada APK para a equipe.

Essas ações dependem das contas e das senhas do dono e não devem ser
automatizadas por um agente de código.

## 2. Backend no Railway

### Serviço e banco

1. Crie um projeto no Railway e adicione um serviço PostgreSQL.
2. Crie o serviço da API apontando para a raiz de `backend/`.
3. O projeto usa atualmente o Railpack configurado em `railway.toml`:
   - instala também as dependências de build;
   - executa `prisma generate` e `npm run build`;
   - antes do deploy, executa `npx prisma migrate deploy`;
   - inicia com `npm run start:prod`;
   - verifica a saúde em `/health`.
4. Mantenha uma réplica. O Volume acompanha uma única réplica.

O `Dockerfile` também está pronto para uma implantação Docker: o alvo
`production` copia o build e o Prisma e inicia com
`npx prisma migrate deploy && node dist/main.js`. Não configure Railpack e
Docker ao mesmo tempo; `railway.toml` é a opção ativa neste projeto.

### Variáveis

Defina no serviço da API:

| Variável | Valor |
| --- | --- |
| `DATABASE_URL` | referência ao PostgreSQL, preferencialmente `${{Postgres.DATABASE_URL}}` |
| `JWT_SECRET` | segredo aleatório com pelo menos 32 caracteres |
| `CORS_ORIGINS` | origens web permitidas, separadas por vírgula; `*` é recusado em produção |
| `STORAGE_DIR` | `/data` |
| `APP_VERSION` | versão da API, por exemplo `0.2.0` |
| `APP_LATEST_VERSION` | versão publicada do APK, por exemplo `0.2.0+2` |
| `APP_APK_URL` | URL HTTPS direta do APK publicado |
| `FCM_SERVICE_ACCOUNT` | chave da conta de serviço do Firebase, em base64 — ver a seção 7 |

O Railway injeta `PORT`; não fixe esse valor. `INVITE_BASE_URL` é opcional até
existir uma página pública de convite. `SPOTIFY_CLIENT_ID` e
`SPOTIFY_CLIENT_SECRET` habilitam a busca externa de músicas.

Para gerar o `JWT_SECRET` no PowerShell sem reutilizar uma senha humana:

```powershell
[Convert]::ToBase64String(
  [Security.Cryptography.RandomNumberGenerator]::GetBytes(48)
)
```

Se for usada uma URL pública do PostgreSQL em vez da referência interna do
Railway, acrescente `sslmode=require` à query string. Exemplo:

```text
postgresql://usuario:senha@host:porta/banco?schema=public&sslmode=require
```

### Volume das fotos

No serviço da API, crie um Volume com mount path `/data` e mantenha
`STORAGE_DIR=/data`. Sem ele, as fotos somem no próximo deploy. Não monte o
Volume dentro de `/app`, pois essa pasta contém o artefato da aplicação.

### Verificação depois do deploy

```powershell
curl.exe https://SEU-DOMINIO/health
curl.exe https://SEU-DOMINIO/version
```

`/health` deve responder `status: ok` e `database: up`. `/version` deve mostrar
`apiVersion`, `latestAppVersion` e a URL do APK. Faça também login e abra uma
escala no app antes de distribuir uma atualização.

## 3. Assinatura Android

O arquivo `android/key.properties` e qualquer `*.jks` são ignorados pelo Git.
Copie `android/key.properties.example` e preencha os dados reais. Guarde o JKS
fora do projeto e faça ao menos dois backups seguros.

Se ainda não houver uma chave, o dono pode criá-la uma única vez. **O nome do
arquivo e o alias abaixo continuam `louve`, e não `pauta`**: uma chave já
emitida não se renomeia — trocar o alias assina com outra chave, e o Android
recusa instalar a atualização por cima. É identificador de assinatura, não
marca.

```powershell
keytool -genkeypair -v `
  -keystore C:/caminho-seguro/louve-release.jks `
  -alias louve `
  -keyalg RSA -keysize 2048 -validity 10000
```

Perder o keystore ou suas senhas inviabiliza instalar uma atualização sobre o
app existente. Nesse caso, cada pessoa teria de desinstalar o app e perder a
sessão local antes de instalar uma nova assinatura.

## 4. Versão e build do APK

Antes de cada publicação:

1. aumente `version` em `app/pubspec.yaml`; o número depois de `+` precisa ser
   maior que o do APK anterior;
2. configure `APP_LATEST_VERSION` com esse mesmo valor;
3. configure `APP_APK_URL` com o endereço onde o novo arquivo ficará;
4. gere o pacote apontando para a API de produção:

```powershell
cd app
$env:PATH = 'C:\Users\Acer\flutter\bin;' + $env:PATH
flutter analyze
flutter test
flutter build apk --release `
  --dart-define=API_BASE_URL=https://backend-production-b304.up.railway.app
```

O arquivo fica em `app/build/app/outputs/flutter-apk/app-release.apk`. Confira
a assinatura antes de enviar:

```powershell
C:\Users\Acer\AppData\Local\Android\sdk\build-tools\VERSAO\apksigner.bat `
  verify --verbose --print-certs `
  build\app\outputs\flutter-apk\app-release.apk
```

O Gradle emite um aviso forte e usa a chave de debug quando
`key.properties` não existe. Esse APK serve apenas para teste e nunca deve ser
distribuído.

## 5. Distribuição e atualização

O APK é publicado como **Release do GitHub** em
`simonscabello/escala-app`, pelo workflow `.github/workflows/release-apk.yml`.
O repositório é público, então a URL do arquivo baixa direto, sem login — que é
o requisito do `APP_APK_URL` e do botão “Atualizar” dentro do app.

Antes do WhatsApp e do Drive, o arquivo saía da máquina de quem desenvolve e o
líder o reenviava a cada versão. Com o Release existe **um endereço estável por
versão**, e é ele que a API anuncia.

### Segredos de assinatura (uma vez só)

O build no CI precisa da **mesma** chave dos APKs anteriores: um APK assinado
com outra chave o Android recusa instalar por cima do app existente. Em
`Settings → Secrets and variables → Actions` do repositório do app:

| Segredo | Valor |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | o `.jks` em base64 (comando abaixo) |
| `ANDROID_KEYSTORE_PASSWORD` | `storePassword` do `android/key.properties` |
| `ANDROID_KEY_ALIAS` | `keyAlias` (hoje `louvor`) |
| `ANDROID_KEY_PASSWORD` | `keyPassword` |

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\Users\Acer\keys\louvor-release.jks")) | Set-Clipboard
```

O workflow **falha de propósito** quando algum deles falta, antes de compilar:
sem os quatro, o Gradle cairia na chave de debug e produziria calado um arquivo
que ninguém consegue instalar por cima do app.

### Publicar uma versão

1. suba o `version` em `app/pubspec.yaml` (o número depois do `+` precisa ser
   maior que o do APK anterior) e faça commit;
2. `git tag v0.2.0 && git push origin v0.2.0` — a tag sem o `v` precisa bater
   com o `version` do pubspec, e o workflow recusa se não bater;
3. o Actions roda `flutter analyze`, `flutter test` e o build, e publica o
   Release com `louve-0.2.0.apk` (universal) mais os três por arquitetura;
4. **no Railway**, no serviço da API, suba **uma** variável:

```
APP_LATEST_VERSION = 0.2.0
```

### O `APP_APK_URL` se configura uma vez, e nunca mais

```
APP_APK_URL = https://github.com/simonscabello/escala-app/releases/latest/download/louve.apk
```

`releases/latest/download/` é um atalho do GitHub que segue sozinho o Release
mais novo, e o workflow publica em toda versão uma cópia de **nome fixo**
(`louve.apk`) justamente para esse endereço encontrar. Sem isso, a URL levaria
o número da versão no nome e teria de ser reescrita a cada publicação — um
campo a mais para errar, e um botão "Atualizar" que baixa 404 quando se erra.

**O nome do arquivo continua `louve`, e não `pauta`, mesmo depois do
rebranding.** Ele não aparece para o usuário: é o identificador que esta
variável já aponta em produção. Renomear no workflow sem reescrever
`APP_APK_URL` no mesmo minuto quebra o botão "Atualizar" de quem já tem o app
instalado. Quando for a hora, as duas coisas mudam juntas — ou o workflow
publica os dois nomes por uma versão, e só então o antigo sai.

O arquivo apontado é **sempre o universal** (~60 MB): uma URL só, que instala em
qualquer aparelho. Os por arquitetura (~20 MB) ficam no Release para quem sabe
qual usar e quer economizar dados — perguntar a alguém da equipe qual é a
arquitetura do próprio celular não é uma pergunta que se faça.

### Por que `APP_LATEST_VERSION` continua manual

Publicar o arquivo e *anunciar* a versão para a equipe são decisões diferentes.
Enquanto essa variável não subir, o Release fica disponível para você instalar e
conferir sem que o app cobre atualização de ninguém. Subiu, e na próxima
abertura da Agenda todo mundo vê "Nova versão disponível".

Se um dia isso incomodar mais do que ajuda, o passo seguinte é a API perguntar
ao GitHub qual é o último Release em vez de ler a variável — aí a publicação
fica sem nenhum passo manual, ao preço de o anúncio sair junto com o arquivo,
sempre.

### Publicar à mão, quando precisar

O caminho do CI não é obrigatório. Com o build local (seção 4), dá para anexar o
arquivo a um Release pela interface do GitHub — `Releases → Draft a new
release` — e apontar o `APP_APK_URL` para ele. Vale para uma correção urgente
com o Actions fora do ar, e é o mesmo resultado.

Para uma instalação nova, envie o link do APK. Para atualizar, a pessoa baixa
o novo arquivo e abre por cima da instalação existente; Android aceita isso
somente quando a assinatura é a mesma e o `versionCode` aumentou.

## 6. Versão Web

O mesmo código Flutter também gera um **site estático**. Não há segundo backend
nem segundo frontend: Android e navegador falam com a mesma API.

```powershell
cd app
flutter build web --release --dart-define=API_BASE_URL=https://backend-production-b304.up.railway.app
```

A saída é `app/build/web`. Publique a pasta inteira em qualquer hospedagem de
site estático (Netlify, Vercel, Cloudflare Pages, GitHub Pages, Nginx).

### O que precisa ser configurado

1. **`CORS_ORIGINS` com o domínio do site.** Sem isso o navegador recusa toda
   chamada à API e o site abre em branco depois do login. Sem barra no fim,
   separado por vírgula se houver mais de uma origem:

   ```text
   CORS_ORIGINS=https://escalas.suaigreja.com
   ```

   Em produção `*` é recusado no boot da API — de propósito.

2. **Nada mais.** As rotas usam hash (`https://site/#/agenda/<id>`), então o
   servidor só vê `/` e recarregar a página em qualquer rota funciona sem
   configuração de *SPA fallback*. Se um dia a URL sem `#` for adotada
   (`PathUrlStrategy` no app), aí sim a hospedagem precisará servir
   `index.html` para toda rota desconhecida — senão um F5 dentro de uma escala
   devolve 404.

   As fotos de perfil (`/uploads/...`) já saem com
   `Access-Control-Allow-Origin: *` próprio, posto no `setHeaders` do
   `useStaticAssets` (`backend/src/main.ts`): o `enableCors` do Nest não cobre
   os arquivos estáticos, e sem esse cabeçalho toda foto quebra no navegador.

### Verificação depois de publicar

Abra o site e confira, com o console do navegador aberto:

- login e logout;
- **F5 dentro de uma escala** (`.../#/agenda/<id>`) — tem de voltar para a
  mesma escala, não para a agenda;
- uma foto de perfil carregando (é o teste de CORS dos `/uploads`);
- a janela reduzida até ~500px — a barra lateral vira a barra inferior de três
  abas, sem nada cortado.

## 7. Notificações push (Firebase)

Sem esta seção o app funciona inteiro — só não avisa ninguém. `FCM_SERVICE_ACCOUNT`
é opcional de propósito: faltando a variável, o módulo sobe desligado e a API
não muda em nada.

### O que já está feito

O `app/android/app/google-services.json` está no repositório e aponta para o
projeto `pauta-app-1f31b`, pacote `br.com.escalas.louvor_app`. Ele **não é
segredo** — vai dentro do APK de qualquer jeito.

### A chave do servidor

1. Firebase Console → engrenagem → **Project settings** → aba **Service
   accounts** → **Generate new private key**. Baixa um JSON.
2. **Esse arquivo é segredo de verdade**: quem o tem manda notificação em nome
   do projeto para qualquer aparelho. Nunca no repositório.
3. Converta para uma linha, em base64:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\caminho\para\chave.json"))
```

4. Serviço da API no Railway → Settings → Variables → `FCM_SERVICE_ACCOUNT`.

Chave inválida **não derruba o boot**: a API sobe, registra o erro no log e
segue sem notificar. Confira o log do deploy — a linha esperada é
`Notificacoes push ligadas.`

### O que NÃO é preciso

- **Conta Apple / certificado APNs**: não há pasta `ios/` neste projeto.
- **VAPID key ou service worker**: push na Web ficou fora do v1.
- **Publicar na Play Store**: o FCM funciona em APK instalado à mão, desde que o
  aparelho tenha Google Play Services.
- **Cartão de crédito**: o plano gratuito do Firebase cobre o FCM, sem cobrança
  por mensagem.

### Conferir sem Firebase

`NOTIFICATIONS_DEBUG=true` registra no log o aviso que **seria** enviado, com
destinatário e texto, e não envia nada. É como se confere um gatilho novo no
ambiente local.

## Checklist de publicação

- [ ] migrations aplicadas pelo pre-deploy;
- [ ] `/health` saudável e `/version` com os valores da publicação;
- [ ] Volume `/data` montado e `STORAGE_DIR=/data`;
- [ ] `CORS_ORIGINS` restrito e `JWT_SECRET` exclusivo;
- [ ] versão e build incrementados no `pubspec.yaml`;
- [ ] APK release assinado com o keystore definitivo;
- [ ] login, Agenda, detalhe, escalação e repertório verificados;
- [ ] APK hospedado e link testado em um celular;
- [ ] site Web publicado, com o domínio em `CORS_ORIGINS` e F5 dentro de uma escala testado;
- [ ] keystore e senhas com backup seguro.
