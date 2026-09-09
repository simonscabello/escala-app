# Contexto do projeto para assistentes de código

> Este arquivo é lido automaticamente pelo Cursor (e por outros agentes) em toda
> sessão. Ele descreve o que já existe, as convenções e as armadilhas que já
> custaram tempo. **Leia antes de escrever código.**

## O que é

Sistema de escalas para equipes de louvor de igreja. O líder organiza cultos,
quem toca o quê, horário do ensaio e as músicas; os integrantes abrem o app e
veem onde estão escalados.

**O valor do produto está na tela de leitura da escala**, não no CRUD. O membro
precisa ver "Domingo 09h — você, guitarra. Ensaio sábado 19h" em 2 segundos.
Todo o resto existe para viabilizar essa tela.

Documento de arquitetura e decisões: `docs/ARQUITETURA-MVP.md`. Ele é a fonte da
verdade sobre entidades, regras de negócio numeradas e ordem das etapas.

## Estrutura — dois projetos independentes

**Não é monorepo.** Não há workspace npm/pnpm, Melos, Nx nem dependências
compartilhadas de build. `app/` e `backend/` são projetos separados que só se
comunicam por HTTP. No futuro cada um pode virar um repositório Git próprio.

```
sistemas/                  pasta de trabalho (não é um pacote)
├─ docs/                   arquitetura e prompts (produto)
├─ backend/                NestJS 11 + Prisma 6 + PostgreSQL 16 (Docker)
│  ├─ compose.yaml
│  ├─ .env.example
│  └─ ...
└─ app/                    Flutter 3.44 + Riverpod + go_router + Dio
```

## Como rodar

### Backend

Tudo em Docker, a partir de `backend/`:

- `cd backend; docker compose up -d` — sobe api (3000) e db (5432)
- `docker compose logs -f api` — logs
- `docker compose exec api npx prisma migrate dev --name x` — migration
- `docker compose exec api npx tsc --noEmit -p tsconfig.json` — typecheck
- `docker compose exec api npm install <pkg>` — instalar dependência (**dentro** do container, nunca no Windows)

O `.env` vive em `backend/` (copie de `backend/.env.example`).

### App

Flutter roda nativo no Windows, a partir de `app/`. O `flutter` **não está no
PATH global**; prefixe a sessão do PowerShell:

- `$env:PATH = 'C:\Users\Acer\flutter\bin;' + $env:PATH`
- `cd app; flutter analyze` — precisa terminar com "No issues found!"
- `cd app; flutter test`
- versão Web local: `cd app; flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000`
- site estático: `cd app; flutter build web --release --dart-define=API_BASE_URL=https://backend-production-b304.up.railway.app` (saída em `app/build/web`)
- APK para o celular (aponta para produção):
  `cd app; flutter build apk --release --dart-define=API_BASE_URL=https://backend-production-b304.up.railway.app`
- APK contra o backend local (só serve no emulador):
  `cd app; flutter build apk --release --dart-define=API_BASE_URL=http://10.0.2.2:3000`
- instalar no emulador: `C:\Users\Acer\AppData\Local\Android\sdk\platform-tools\adb.exe -s emulator-5554 install -r app\build\app\outputs\flutter-apk\app-release.apk`

**A URL da API em produção é `https://backend-production-b304.up.railway.app`**
— sem barra no fim e sem `/api/v1`, que o `AppConfig` já concatena. Ela não
tem default no código de propósito (`AppConfig.apiBaseUrl` cai em `10.0.2.2`),
então todo build de release precisa passar o `--dart-define`.

## Estado atual

Concluídas: **0 a 8** — fundação, contas, equipe/membros/funções, convites,
cultos, escalação, músicas, acabamento (compartilhar no WhatsApp, duplicar
escala, cache de leitura, design tokens) e distribuição (`docs/DEPLOY.md`,
`GET /version` e aviso de atualização dentro do app).

Depois da etapa 8 o sistema seguiu por um plano de evolução cujo princípio é
**fechar fluxo pela metade antes de acrescentar entidade nova**. O que entrou:

- **Rascunho e publicação** da escala (seção própria abaixo).
- **A escala acaba no último culto, não no primeiro**: um domingo com manhã e
  noite continua em "Próximas" o dia inteiro. O corte usa o começo do dia civil
  no fuso da equipe (`EventsService.list`), e não `now`.
- **Recado individual** por escalado, preservado ao remontar a escalação — o
  formulário mandava só os ids e apagava os recados em silêncio.
- **Cadastro manual de música** quando o catálogo e a busca externa não acham
  nada: antes a mensagem mandava cadastrar à mão sem oferecer o caminho.
- **Duplicar escala** religada (era feature flag desligada).
- **Seletor de equipe ativa** no cabeçalho da agenda, para quem serve em mais
  de uma equipe.
- **Arquivar e restaurar música**, com o arquivo em `/equipe/musicas/arquivadas`.
- **Convite oferecido logo após cadastrar o integrante**, e atalho "Convidar"
  na linha de quem ainda não tem conta.
- **Geração de rascunhos** das próximas semanas a partir da grade de cultos
  (`POST /teams/:id/events/generate`), pulando as datas que já têm escala.
- **Calendário de indisponibilidade da equipe** (seção Indisponibilidade).
- **Rodízio no seletor da escalação**: "Há 3 semanas · 2 escalas em 8 semanas".
- **Relatórios** de participação e de uso do repertório (seção Relatórios).
- **Histórico da escala e trava de edição simultânea** (seção própria).
- **Sugestões de música pela equipe** — qualquer integrante pede uma música,
  para o repertório ou para um domingo, com justificativa assinada; quem monta
  a escala vê as daquela data na tela do repertório (seção Sugestões da
  equipe).

- **Notificações push** (seção própria abaixo): a escala publicada avisa quem
  está nela, e quem lidera fica sabendo da sugestão nova e de quem avisou que
  não pode num domingo em que já está escalado.
- **Lembretes agendados**: repertório para ouvir, ensaio de hoje, véspera do
  culto, convite a sugerir e repertório vazio — com deduplicação em banco.

O que o plano ainda prevê e **não** foi feito: lembretes agendados (ensaio hoje,
culto amanhã, domingo ainda em rascunho), modo culto offline (letra garantida
sem rede), solicitação de troca pelo integrante, link web somente leitura da
escala e sugestão assistida de escalação.


## Versão Web — mesma base, outra arrumação

O app roda no navegador a partir do **mesmo** `lib/`. Não há projeto separado,
não há segundo frontend e não há regra de negócio duplicada: providers,
modelos, repositórios, Dio, tema e rotas são os mesmos do Android.

O que muda é o **formato da tela**, e quem decide isso é a largura da janela —
não a plataforma. Reduzir o Chrome devolve a interface do celular; um tablet
Android ganha a barra lateral pelo mesmo motivo que o monitor ganha. **Não há
`kIsWeb` nas telas.**

### Rodar e publicar

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
flutter build web --release --dart-define=API_BASE_URL=https://backend-production-b304.up.railway.app
```

`localhost:3000`, não `10.0.2.2` — o navegador roda no Windows. A saída é
`build/web`, um site estático. A URL da API continua sendo de build, como no
APK, e sem `/api/v1` (o `AppConfig` concatena).

### Os três formatos

Definidos em `lib/core/responsive/app_breakpoints.dart`. **Nenhuma tela escreve
número de largura à mão.**

| Faixa | Largura | Navegação | Conteúdo |
| --- | --- | --- | --- |
| `mobile` | < 600 | barra inferior de três abas | uma coluna, botão flutuante |
| `tablet` | 600–1024 | barra lateral recolhida (só ícones) | uma coluna com folga |
| `desktop` | > 1024 | barra lateral aberta | colunas, tabelas, painel lateral |

As ferramentas:

- `AppBreakpoints.of(context)` / `context.formFactor` — a faixa da **janela**.
  Use quando a decisão é sobre a tela toda (o botão flutuante vira botão de
  cabeçalho, a barra inferior vira lateral).
- `ResponsiveBuilder` — a faixa do **espaço recebido**, via `LayoutBuilder`.
  Use quando a pergunta é "cabem duas colunas aqui?": dentro da casca com a
  barra lateral aberta, um monitor de 1024px deixa só 756px para a tela, e
  medir a janela produziria colunas espremidas. Foi por isso que a tabela de
  integrantes e a montagem da escala olham a largura disponível, não a janela.
- `ResponsiveLayout` — uma árvore por faixa, só quando a diferença é
  estrutural.
- `AppContentWidth`, `AppContentWidth.reading` (até 820) e
  `AppContentWidth.wide` (até 1180) — o teto de largura do conteúdo. O
  construtor comum continua em 640 e é o padrão.
- `showAdaptiveSheet` (`core/responsive/adaptive_dialog.dart`) — folha de baixo
  no celular, diálogo no centro no monitor, **com o mesmo widget dentro**.
- `AppSideNav` (`shared/widgets/app_side_nav.dart`) — a barra lateral. É pura
  apresentação: recebe destinos e callbacks, não conhece Riverpod nem
  go_router. Quem monta os dados é `MainShell`.

### A casca e as rotas

`MainShell` (`features/events/presentation/main_shell.dart`) escolhe entre a
barra inferior e a lateral. A regra do celular não mudou: a barra inferior só
aparece nas abas — hoje `/inicio`, `/agenda`, `/equipe` e `/perfil`.

Para a barra lateral não sumir ao abrir "Repertório" ou "Convites", as telas de
configuração passaram para **dentro** do `ShellRoute`. No celular isso não muda
nada — elas não são uma das abas, então continuam sem barra inferior.

A barra lateral acende a rota **mais específica** que prefixa o caminho atual
(`AppSideNav.selectedRouteFor`). Sem isso `/equipe/musicas` acenderia "Equipe".

## A Home (`/inicio`)

É a porta de entrada depois do login (o redirect de `app_router.dart` manda para
`/inicio`, e `/home` é um apelido antigo que aponta para lá). A Agenda é a aba
seguinte, e responde outra pergunta — ver **A Agenda** logo abaixo.

**A Home existe por uma diferença só:** a manchete da agenda é a próxima escala
**da equipe**, e quem abre o app quer saber da **própria**. Tudo o mais ela pega
emprestado.

- **Nenhum endpoint novo, nenhuma requisição a mais.** Observa o mesmo
  `eventsProvider((teamId, 'upcoming'))` da agenda — mesma chave de família,
  então é a mesma resposta e o mesmo cache — e o `openSuggestionCountProvider`
  que já alimenta o selo da aba Equipe (só para quem gerencia).
- **A leitura mora fora do widget**, em `features/home/domain/home_summary.dart`:
  qual é a minha próxima escala, qual é a **minha** seguinte, quantas músicas a
  escala tem (`scheduleSongCount` cala quando não sabe) e quais avisos nascem.
  `test/home_summary_test.dart` trava isso sem widget nenhum.
- **Ordem fixa:** cabeçalho, minha próxima escala, acessos rápidos, avisos. Um
  bloco pode não existir; nenhum troca de lugar.
- **A Home não lista escalas.** Ela teve um grupo "Próximas escalas" com três
  linhas da equipe, e ele saiu: era a aba Agenda em miniatura ocupando um terço
  da tela, com menos recurso do que a original. Do que ele respondia sobrou uma
  pergunta — "e depois, quando eu toco de novo?" —, e ela cabe numa linha dentro
  da manchete (`HomeSummary.myFollowing`). **É a minha seguinte, não a da
  equipe**: a manchete abriu o fio de "quando eu toco", e continuar esse fio com
  a escala de outra pessoa é o mesmo erro que deu origem à Home.
- **Três acessos rápidos**, e a arrumação muda com a largura: três ladrilhos
  lado a lado só cabem acima de 520px; abaixo disso os dois primeiros dividem a
  linha e **Minha disponibilidade** vira uma faixa deitada — o mesmo cartão,
  virado, e não um segundo componente. Ela entrou porque era o destino mais
  escondido do app no celular (só pelo Perfil) e é o que tem prazo: avisar que
  não pode depois da escala montada já é tarde.
- A manchete usa `AppHeroCard` (`shared/widgets/app_hero_card.dart`), a casca
  violeta. `GreetingHeader` e `TeamOnboarding` saíram de dentro de
  `agenda_screen.dart` quando a Home nasceu, e hoje só a Home usa as três — a
  agenda trocou a manchete pelo calendário.
- **O pedido de permissão de notificação mudou de tela.** Era da agenda; foi
  para a Home, que é onde o app abre. Um integrante que nunca toca na aba
  Agenda jamais veria a pergunta.
- **O que ainda não dá para mostrar:** a contagem de músicas do repertório no
  atalho "Repertório". A única fonte hoje é `GET /teams/:id/songs`, que devolve
  o acervo inteiro (centenas de músicas) — caro demais para um número. Se um dia
  a Home precisar de mais dados agregados, o caminho é um `songCount` em
  `GET /teams/:id` ou um `GET /home`; **não** somar requisições na tela.

## A Agenda (`/agenda`)

**O mês da equipe.** A Home responde "quando eu toco?"; a agenda responde "como
está o mês?" — e é por isso que ela virou um calendário: um ponto por dia com
escala, o dia selecionado embaixo, e as próximas em seguida.

- **A linha da lista é a mesma da Home**: `CompactScheduleTile`
  (`features/events/presentation/agenda_event_tile.dart`), dentro de um
  `AppGroup` chamado **"Próximas escalas"** — o mesmo widget, o mesmo título, o
  mesmo bloco de data, a mesma pílula "VOCÊ". A agenda já teve um cartão próprio
  por horário (`AgendaEntryCard`, removido): duas telas do mesmo app pareciam de
  apps diferentes, e as duas listas divergiriam no primeiro ajuste. **O que a
  agenda tem de seu é o calendário**; escala escrita se escreve de um jeito só.
- **Ponto conta horário; linha conta escala.** `AgendaEntry`
  (`features/events/domain/agenda_entry.dart`) projeta um horário por dia civil
  — é assim que a vigília que atravessa a meia-noite marca os dois dias. A lista
  usa `groupAgendaEvents`, que junta os horários da mesma escala numa linha só:
  um domingo com manhã e noite é **uma** escala, e mostrá-la duas vezes faria a
  equipe achar que toca em dobro. A linha já escreve "Manhã 08:30 · Noite 19:00".
- **Duas listas, nunca a mesma escala nas duas.** O que está no dia selecionado
  sai de "Próximas escalas".
- **O botão de criar é o da Home, no mesmo lugar:** flutuante no celular (onde
  o polegar chega), no cabeçalho no monitor. A agenda chegou a ter só o ícone
  do cabeçalho nas duas larguras — alvo menor para a ação principal, e o botão
  mudando de forma ao trocar de aba é o que faz duas telas parecerem de dois
  apps. A diferença legítima é o que ele leva junto: o dia selecionado
  (`/agenda/novo?data=`).
- **O recorte** (`AgendaFilter`): "Todas" × "Minhas escalas". Governa também os
  **pontos do calendário** — "em que domingos eu toco?" se responde no mês, não
  numa lista. Responsabilidade é estar em `assignments`; o ministrante entra
  junto sem segunda conferência, porque o servidor recusa ministrante fora da
  escalação (`assertMinisterIsAssigned`). Se isso mudar, a segunda fonte entra
  em `filterAgendaEntries` — e não em cada tela que pergunta "é minha?".
- **O dia vazio diz qual vazio é.** Em "Minhas escalas", um domingo cheio de
  escala da equipe não é um dia livre: a frase é "Você não está escalado neste
  dia", e não "Nada marcado". Trocar uma pela outra esconderia uma escala que
  existe, que é o pior defeito que um filtro pode ter. Por isso a tela calcula
  as entradas **duas vezes** — a agenda inteira e o recorte.
- **As datas em aberto somem no recorte pessoal.** Nenhuma data sem escala é
  "sua": não há ninguém escalado nela.
- **A consulta** (`features/events/data/agenda_provider.dart`): a agenda observa
  `upcoming` **e** `past`, porque o calendário navega para trás. Cada escopo
  reusa o `eventsProvider` da Home (20 itens) e só amplia para 100 quando a
  primeira página vem cheia — com chave de cache própria (`upcoming.100`), para
  não substituir o cache de 20 que a Home lê.
- **Vocabulário:** "escala". A tela chegou a dizer "compromisso" em seis lugares
  — ver **Vocabulário: "escala", não "culto"**.

### O que a Web exigiu do código

Foram poucas coisas, e todas valem para as duas plataformas:

1. **Foto de perfil vai por bytes.** `MultipartFile.fromFile` usa `dart:io`; no
   navegador o `path` de um `XFile` é uma URL `blob:`. `AuthRepository.uploadAvatar`
   recebe `bytes` + `filename` e usa `MultipartFile.fromBytes`. O backend nunca
   confiou no nome nem no mimetype (decide pela assinatura do arquivo), então
   nada mudou do lado do servidor.
2. **Compartilhar tem plano B.** `navigator.share` não existe no Firefox nem em
   boa parte dos navegadores de desktop, e o `share_plus` lança. `shareText`
   (`shared/widgets/share_action.dart`) cai na área de transferência e avisa —
   mesmo destino (WhatsApp Web), outro caminho.
3. **Ler a área de transferência pode falhar.** "Colar o código do convite"
   agora trata a exceção em vez de não fazer nada.
4. **CORS das fotos.** Ver a armadilha correspondente abaixo.
5. **Deep link com sessão ainda desconhecida.** Ver a armadilha correspondente.

### URLs, refresh e hospedagem

A estratégia de URL é a **padrão do go_router**: hash
(`https://site/#/agenda/<id>`). Isso é deliberado — com hash o servidor só vê
`/`, e recarregar a página em qualquer rota funciona **sem** configuração de
hospedagem. Trocar para `PathUrlStrategy` exige configurar o *SPA fallback*
(toda rota desconhecida serve `index.html`), senão um F5 em `/agenda/<id>`
devolve 404.

`web/index.html` tem uma abertura própria no violeta profundo da marca,
removida no evento
`flutter-first-frame`. Sem ela, os segundos até o primeiro quadro eram uma
página branca — que parece travamento e, no escuro, é um clarão.

### CORS no backend

`CORS_ORIGINS` já existia e continua sendo a única configuração necessária: em
produção, o domínio do site (sem barra no fim), separado por vírgula se houver
mais de um. `*` é recusado no boot em produção, e isso não mudou.

## Conta do usuário: dados, senha e foto

Cada pessoa cuida da própria conta em `Perfil`. Nada disso tem `:id` na rota —
todas as três agem sobre o dono do token:

- `PATCH /users/me` — nome, e-mail, **data de nascimento e gênero** (o e-mail é
  o login; duplicado dá 409 `EMAIL_ALREADY_USED`). Mudar o nome também acerta o
  `displayName` na equipe, **mas só quando ninguém o personalizou** (o líder
  pode ter trocado "José Carlos da Silva" por "Zeca", e corrigir o nome da conta
  não deve desfazer). Nascimento e gênero aceitam `null` para limpar; campo
  ausente é "não mexi nele" — ver a seção Ficha do integrante.
- `POST /users/me/avatar` — `multipart/form-data`, campo `file`.
- `DELETE /users/me/avatar`.
- Trocar a senha continua em `POST /auth/change-password`, que exige a atual e
  derruba as outras sessões. No app tem dois caminhos para a mesma tela:
  `/trocar-senha` (obrigatória, regra 27) e `/perfil/senha` (voluntária,
  `ChangePasswordScreen(forced: false)`).

### Fotos em disco — o Volume do Railway

As imagens ficam no **disco**, não no banco nem em S3. `STORAGE_DIR` é a raiz;
dentro dela só existe `avatars/`. O banco guarda o caminho relativo
(`users.avatar_path`), e a API devolve `avatarUrl` **relativo ao host**
(`/uploads/avatars/<uuid>.jpg`) — quem monta o endereço final é o `AppAvatar`,
porque o mesmo registro responde em `10.0.2.2` no emulador e no domínio do
Railway.

- **Local:** `STORAGE_DIR=/app/storage` (no compose). Como `backend/` é bind
  mount, os arquivos aparecem em `backend/storage/` no Windows. Está no
  `.gitignore` e no `.dockerignore`.
- **Railway:** o sistema de arquivos do container é descartado a cada deploy.
  Crie um **Volume no serviço da API com mount path `/data`** e defina
  `STORAGE_DIR=/data`. Não monte dentro de `/app` (a raiz do build). O Volume
  só acompanha uma réplica — daí `numReplicas = 1` no `railway.toml`.

Os arquivos são servidos pelo express (`useStaticAssets` em `main.ts`), fora do
`/api/v1` e **sem JWT**: `Image.network` não manda `Authorization`. O que
protege é o nome ser um UUID v4, não enumerável. Validação em
`storage.service.ts`: assinatura do arquivo (JPEG/PNG/WebP — não o `mimetype`
declarado, que é escrito por quem envia) e 5 MB. O app já reduz para 1024px /
qualidade 85 antes de enviar, o que também reencoda HEIC em JPEG.

## Músicas (Etapa 6)

`GET|POST /teams/:teamId/songs`, `GET|PATCH|DELETE .../songs/:songId`.
Qualquer integrante **lê** (o músico precisa achar a cifra e o tom antes do
ensaio); só `OWNER`/`LEADER` escreve.

No app, em `Equipe → Gerenciar → Repertório` (`/equipe/musicas`): lista com
busca e o filtro **"faltando dados"**, detalhe com letra e os quatro links, e
`/equipe/musicas/nova` — **uma caixa de busca, duas fontes**: primeiro o que
outras equipes já cadastraram (instantâneo e com letra), depois o Spotify.
A pessoa escolhe; casar automático erraria calado, porque "Aleluia" existe em
cinco versões.

O que **falta preencher** é o que nenhuma API responde — tom da equipe,
hino/cântico e andamento. Por isso a lista mostra o tom da gravação em cinza
ao lado do campo vazio e a edição tem um "Usar F#": o preenchimento vira um
toque em vez de pesquisa, feito quando a música entra numa escala.

Campos: `title`, `artist`, `composer`, `kind` (`HYMN`/`SONG`), `pace`
(`CALM`/`MODERATE`/`UPBEAT`), `defaultKey` e quatro links — `lyricsUrl`,
`chordsUrl`, `youtubeUrl`, `spotifyUrl`. A letra fica no banco (`lyrics`),
não só o link: site de letra sai do ar e não abre no meio do culto.

- **A lista não devolve `lyrics`** (são centenas de músicas); o `GET` de uma
  música devolve. Os campos que faltam preencher vêm na lista, porque é por
  eles que a tela vai filtrar.
- **`search_text`** é título + artista + compositor em minúsculas e sem
  acento, montado no serviço. É o que a busca compara: sem isso, procurar
  "coracao" não acha "Coração" — que é como o título está gravado e não é
  como as pessoas digitam. A ordenação também usa ele.
- Regra 20 (título+artista único por equipe, ignorando maiúsculas) e regra 21
  (**música usada em escala não se exclui, arquiva-se** — 409 `SONG_IN_USE`).
- **Temas** (`themes`) classificam a música pelo conteúdo: `CEIA`, `NATAL`,
  `REDENCAO`... 82 valores num enum do Postgres, guardados em **coluna de
  array na própria linha** e não em tabela de ligação — a listagem já lê a
  música inteira e passaria a precisar de um join só para desenhar as
  etiquetas. Ver a seção "Temas" abaixo.

### Temas da música

`SongTheme` é um vocabulário **fechado** de 82 temas — o índice temático com
que a igreja escolhe o repertório do culto. Enum e não tabela de catálogo:
ninguém cria tema pela tela, a lista é a mesma para toda equipe e cabe no
código dos dois lados. Tema novo entra por migration, que é o preço certo para
mexer num vocabulário que a API e o app conhecem de cor.

- `GET /teams/:teamId/songs?themes=CEIA,ADORACAO` filtra. **É um OU**
  (`hasSome`), não um E: marcar "Natal" e "Ceia" — duas datas que não caem no
  mesmo culto — devolveria zero com E, e o filtro pareceria quebrado. E ele
  **soma** aos outros filtros: busca por texto e tema valem na mesma consulta.
- Tema desconhecido no filtro é **ignorado**, não vira 400: isto é leitura, e a
  resposta honesta é a lista sem aquele critério. No `PATCH`, ao contrário, ele
  é recusado — ali o valor inválido acabaria gravado.
- Teto de **8 temas** por música (`MAX_SONG_THEMES`, em `song-themes.ts` e não
  no DTO: o script de classificação importa daí e o DTO puxaria junto os
  decoradores do `class-validator`). Quinze temas não é classificar, é indexar
  — e o filtro devolveria a música em toda pergunta.
- `PATCH` com `themes: []` **limpa**; omitir o campo não mexe.
- `from-catalog` traz os temas da origem e **soma** os que a tela mandou: eles
  descrevem a letra, e a letra é a mesma. `from-external` só tem os da tela —
  nenhum serviço externo lê letra.
- A **escala não carrega temas** (`event-songs.service.ts`): ali a pergunta é
  quem toca o quê, e a tela já é a mais pesada do app.

No app: `song_themes.dart` espelha o enum com os rótulos (mesma divisão de
`kindLabel`/`paceLabel`), e `song_theme_picker.dart` é **o** seletor das três
telas que precisam dele — filtro do repertório, edição e cadastro. Folha com
busca sem acento, etiquetas em vez de linhas, escolhidos no topo; fechar por
qualquer caminho (botão, voltar, arrastar) **aplica** o que foi marcado.

### Classificar o acervo existente

```
docker compose exec api npm run classify:songs -- --team=<uuid> [--dry-run] [--replace]
```

A lista vem de `prisma/data/song-themes.json`, revista à mão: onde a letra está
no banco (286 das 1.210) ela é a fonte; nas outras, o título mais o que a
canção é. Cada entrada registra `source` (`lyrics`/`title`) para que essa
diferença continue visível.

**Não há detecção por palavra-chave, e a ausência é proposital**: "sangue" no
verso de uma canção de entrega não a torna um cântico sobre a expiação, e casar
tema por regex produziria etiqueta errada em silêncio.

- Casa por **número do hino** ou por **título+artista** normalizados — nenhum
  id. Por isso o arquivo serve a qualquer equipe: a igreja que importar o
  Cantor Cristão amanhã recebe a classificação dos 581 hinos rodando o script.
- Sem `--replace`, os temas do arquivo **se somam** aos que a música já tem: o
  que a equipe marcou na tela vale mais que o palpite do arquivo.
- Repetível — rodar de novo devolve "0 classificadas".
- 20 músicas ficaram **de fora de propósito**: os três hinos cívicos (575-577)
  e títulos que não dizem o conteúdo ("Colina", "Cativar", "Deep Deep"). O
  script lista todas no fim; classificar no escuro seria pior que o vazio.

### Busca externa (Spotify + CifraClub)

- `GET /teams/:teamId/songs/search-external?search=` — busca no Spotify.
- `POST /teams/:teamId/songs/from-external` — cria a música escolhida,
  resolvendo cifra, letra, tom e andamento no CifraClub (LEADER+).

**Duas etapas de propósito.** A busca é uma chamada só e responde rápido,
porque a pessoa está com o teclado na mão; resolver a cifra custa até oito
requisições ao CifraClub e só acontece para a música escolhida. Fazer isso
para os oito resultados deixaria a busca inutilizável.

- O cliente devolve no POST o que a busca entregou — assim o servidor não
  guarda estado entre a busca e a escolha.
- **Título do Spotify vem com subtítulo entre parênteses** ("Consagração
  (Ao Vivo)") e o CifraClub usa o título curto. As URLs candidatas incluem a
  versão sem parênteses: verificado, `consagracao-ao-vivo` dá 404 e
  `consagracao` dá 200.
- Não achou cifra? Cria só com o que tem. **Nunca inventa link.**
- `defaultKey` e `pace` nascem vazios: nenhum serviço externo sabe respondê-los.
- Sem `SPOTIFY_CLIENT_ID`/`SECRET` a busca devolve `[]` e a API sobe normal.
  **Em produção, definir no Railway** ou a tela de cadastro nasce cega.

O código vive em `src/modules/songs/external/` e é o mesmo que o
`prisma/enrich-songs.ts` usa — o script importa de lá, não o contrário.

### Repertório de outra equipe (catálogo)

- `GET /teams/:teamId/songs/catalog?search=` — procura a mesma música no
  repertório das **outras** equipes. Devolve `sourceSongId` e o que cada
  candidato traz (`hasLyrics`, `hasChords`...), **nunca a letra em si**.
- `POST /teams/:teamId/songs/from-catalog` — copia para esta equipe (LEADER+).

Existe porque **a maioria das igrejas não tem como exportar acervo de lugar
nenhum e nenhuma API devolve letra**: quem chega depois só tem letra se alguém
antes já tiver cadastrado aquela música. Não é tabela nova nem catálogo curado
— é a própria tabela consultada de lado.

- **Copia, não compartilha.** A partir daí as duas linhas seguem separadas.
- Copia só o universal. `defaultKey`, `pace` e `isArchived` nascem vazios: são
  a decisão desta equipe.
- `externalSource`/`externalId` viajam junto — é o que faz a identidade se
  propagar e a 10ª igreja reconhecer a música da 1ª.
- Busca com menos de 2 caracteres devolve vazio: isto lê repertório de
  terceiros, e despejar a tabela não é o propósito.
- **`@Get('catalog')` precisa vir antes de `@Get(':songId')`** no controller,
  senão o Nest casa "catalog" como id e o `ParseUUIDPipe` rejeita com 400.

### Levar o repertório para outro banco

```
docker compose exec api npm run export:songs -- --team=<uuid> --file=tmp/songs.json
docker compose exec -e DATABASE_URL="<url do Railway>" api npm run import:songs -- --team=<uuid de producao> --file=tmp/songs.json
```

Vai **direto ao banco, sem passar pela API**. O arquivo sai sem `id` e sem
`teamId` — quem decide a equipe de destino é o import, que casa por
`(equipe, origem, id externo)` e atualiza em vez de duplicar.

`--only-universal` deixa de fora `defaultKey`, `pace` e `isArchived`: use ao
dar repertório de partida para **outra igreja**; omita ao mover a base da
mesma igreja para produção.

Trocar o `team_id` das músicas por `UPDATE` também funciona — nada além da
própria linha guarda o vínculo. Mas **move em vez de copiar**, e depois de
existir escala com repertório deixa músicas ligadas a eventos de outra equipe.

### Import do Holyrics

```
docker compose exec api npm run import:holyrics -- --file=tmp/holyrics.js --team=<uuid> [--dry-run]
```

O arquivo é o backup "cleaned" do Holyrics (`window.CLEANED_SONGS = [...]`) —
`.js`, não `.json`, por isso o script recorta do primeiro `[` ao último `]` e
faz `JSON.parse` (nada é avaliado como código). Ele vai em `backend/tmp/`, que
é gitignored: são dados da igreja, não código.

**É repetível.** A chave é `(team, "holyrics", id do backup)`, então rodar de
novo atualiza em vez de duplicar — e a atualização **não toca em `defaultKey`,
`pace` nem `isArchived`**, que são o trabalho manual da equipe.

O que o backup de 288 músicas rendeu: 286 gravadas (2 títulos repetidos), 195
links de letra, 53 de cifra, 52 do YouTube, 42 do Spotify e 10 marcadas como
hino (o hinário vem escrito no campo de artista: "Cantor Cristão - 148").
Tom, andamento e hino/cântico do resto ficam vazios — chutar seria pior.

**Nenhuma API preenche esses campos.** O `audio-features` do Spotify, que dava
tom e energia, foi descontinuado em 27/11/2024 e devolve 403 para aplicativos
novos; o `bpm` do Deezer vem 0 para boa parte do gospel brasileiro. E o tom
que importa é o que a equipe canta, não o da gravação.

### Enriquecimento dos links

```
docker compose exec api npm run enrich:songs -- --team=<uuid> --dry-run
```

Completa `spotifyUrl` e `youtubeUrl` das músicas que estão sem eles. Cada
provedor só roda se a chave dele existir no `.env` (`SPOTIFY_CLIENT_ID`/
`SECRET`, `YOUTUBE_API_KEY`); sem chave ele é pulado e o outro segue. **A API
não precisa de nenhuma delas.**

**Letra não entra, e não é omissão:** 285 das 286 músicas já têm a letra
completa no banco e nenhuma está sem letra *e* sem link. Texto guardado é
melhor que link, que depende de rede e do site continuar no ar. A API do
Vagalume, que faria isso, responde **503 em qualquer caminho desde 08/2026** —
o `www` continua no ar, o `api.` não. Foi verificado; não suponha que voltou
sem testar.

- **Só grava com casamento forte**: o título tem que bater e as palavras do
  nome do artista têm que ser subconjunto das do outro, ignorando acento,
  maiúscula e conectivos (`de`, `da`, `e`...). O `e` importa — o Spotify lista
  "Aline Barros e Fernandinho" como dois artistas, e sem ignorá-lo o
  casamento falhava.
- **Música sem artista não é tentada** pelos provedores de link. Antes deles
  roda a **recuperação de artista**: 75 das 108 sem artista carregam o nome
  dele na própria URL que já têm (o Vagalume e o Letras.mus.br no primeiro
  trecho do caminho, o `*.lyrics.com.br` no subdomínio). O palpite sai do
  endereço sem gastar requisição, mas **só é gravado depois de confirmado** —
  ou o Spotify acha a música com aquele artista, ou a página do CifraClub
  existe. Sem confirmação, fica vazio.
- Quando o Spotify confirma, grava a **grafia dele** ("Rebanhão", não o
  "Rebanhao" que sai do slug), e refaz o `searchText`.
- Nunca sobrescreve link existente nem toca em tom/andamento/hino.
- O YouTube tem cota de ~100 músicas/dia (busca custa 100 de 10.000 unidades).
  **Só `quotaExceeded`/`dailyLimitExceeded` derruba o provedor**; os outros 403
  pulam a música e seguem — chave recém-criada no Google Cloud leva alguns
  minutos para propagar e responde 403 nesse meio-tempo. Já aconteceu aqui: a
  mesma busca que falhou voltou 200 minutos depois, sem mudar nada.

**Cifra funciona sem API e sem chave, por montagem de URL + verificação.** O
CifraClub não tem API pública, mas devolve **404 de verdade** para slug que não
existe (sem Cloudflare, sem página falsa de "não encontrado") — foi testado. O
provedor monta `cifraclub.com.br/<artista>/<música>/`, tenta as variações com e
sem artigos (o site derruba artigos: `eu-vejo-gloria`, `trazendo-arca`) e **só
grava a que responder 200**. É o 404 que torna o chute seguro: sem ele seria
adivinhação, com ele é verificação.

Medido contra os links reais do backup: das 29 que tinham cifra **e** artista,
achou **22 e errou 0** — três apontaram para a mesma música por outro caminho
(`trazendo-a-arca` × `trazendo-arca`, `cifras.com.br`, `cifraclub.com` sem
`.br`). A tentativa anterior, sem variações e sem conferir o 404, acertava 17.
As 7 falhas são cadastro ruim: artista preenchido com número de hinário
("Cantor Cristão - 439") ou abreviado ("Min. Koinonya de Louvor").

Não vale usar `github.com/code4music/cifraclub-api` para isso: ele recebe
`/artists/:artist/songs/:song`, ou seja **exige como entrada o slug que é
justamente o problema**, sobe um Selenium por requisição e devolve o conteúdo
da cifra (obra licenciada) — quando o que se quer é só a URL.

### Repertório dentro da escala — **um por culto**

`PUT /events/:eventId/songs` (LEADER+) substitui a lista inteira, na ordem
recebida, e **responde com a escala completa** — a tela do culto se atualiza
sem uma segunda chamada. Mesma forma do `PUT` de escalação, e pelo mesmo
motivo: a pessoa arrasta, tira, acrescenta e salva de uma vez; item a item
deixaria a escala pela metade se a rede caísse no meio.

**Cada item traz `serviceId`, e ele é obrigatório.** A manhã e a noite têm
repertórios próprios — é o caso real da igreja. `EventSong.serviceId` é
`NOT NULL`: toda escala tem pelo menos um culto, então não existe música de
escala que não seja de algum culto, e um nulo criaria um estado "sem culto
definido" para carregar na tela, nas consultas e no texto compartilhado.
Nulável também deixaria a chave única sem trava, porque no Postgres `NULL` é
distinto de `NULL` em índice único.

- **A mesma música nos dois cultos são duas linhas**, e isso é o certo: à noite
  pode ser outro tom, outra ordem, outro recado. A chave é
  `(eventId, serviceId, songId)`.
- **A posição é normalizada por culto**, em `0..n-1` dentro de cada um. O
  cliente manda ordem, não índice. Numerar a escala inteira faria o repertório
  da noite começar em 4 — e "3ª música da noite" é como a equipe fala.
- Música repetida **no mesmo culto** → 400 `DUPLICATE_SONG`. Culto de outra
  escala → 400 `INVALID_SERVICE`. Música de outra equipe → 400 `INVALID_SONG`
  (os ids vêm do cliente, e um id válido de outro lugar passaria pela
  validação de formato).
- Lista vazia limpa o repertório. É como se tira tudo.
- `duplicate` remapeia os cultos: cada música cai no culto correspondente da
  cópia, casado **pelo horário** (todos andaram o mesmo tanto), e não pela
  ordem do `create`, que o Prisma não promete.

#### O `update` da escala faz upsert dos cultos, e isso é obrigatório

`EventServiceDto` aceita `id`. Presente = "é o mesmo culto, só mudou o rótulo
ou o horário" → `update`; ausente = culto novo → `create`; o que sumiu da
lista é apagado.

Isto **não é refinamento**: a FK do repertório é `onDelete: Cascade`. Enquanto
o `update` fazia `deleteMany` + `createMany`, cada edição dava um `id` novo a
cada culto — e **mudar o horário da noite apagaria as músicas da noite**. O app
devolve o `id` em `_servicePayload`; note que `Event.displayServices` inventa
um culto com o **id da escala** quando não há culto gravado (fallback de cache
antigo), e devolver esse id dá 400 `INVALID_SERVICE`.

Apagar um culto de propósito continua levando o repertório dele — é o que
"tirei a noite desta semana" significa.
- `keyOverride` é o tom **desta escala**, sem alterar a música: a mesma canção
  sobe ou desce conforme quem canta. O servidor devolve `key` já resolvido
  (o da escala quando existe, senão o da equipe) — nem a tela nem o texto do
  WhatsApp repetem essa decisão.
- A escala **não** carrega a letra das músicas: são centenas de caracteres por
  música e essa já é a tela mais pesada. Título, artista, tom e links bastam.
- **A listagem da agenda devolve `songs: []`** de propósito: nenhum card mostra
  músicas, e carregá-las multiplicaria a resposta por evento. O compartilhar
  sai do detalhe, que tem tudo.

No app: `/agenda/:eventId/repertorio`, com um `ReorderableListView` **por
culto** (`shrinkWrap`, sem física própria, dentro da rolagem da tela). Use
**`onReorderItem`**, não `onReorder` — ele já entrega o índice de destino
corrigido, e compensar à mão erra por um ao arrastar para baixo. A `Key` de
cada linha é `culto:musica`, não só a música: a mesma canção pode estar nos
dois cultos.

- O **cabeçalho do culto aparece sempre**, mesmo com um culto só: some a dúvida
  de "para qual culto estou escolhendo" antes de ela existir.
- No **texto do WhatsApp** o cabeçalho só entra com 2+ cultos — a linha
  `⏰ Culto às 09:00` já está no topo, e repeti-la sobre a única lista seria
  ruído. A numeração recomeça em cada culto. Culto **sem** música entra nomeado,
  com "Ainda não escolhidas.", desde que algum outro tenha repertório; sem
  nenhum em lugar nenhum, a frase aparece uma vez só, sem os rótulos.
- `Event.songsByService` agrupa e é o que a tela, o texto e os testes usam.
  Culto sem música **continua na lista** (a tela mostra o que falta montar), e
  música sem `serviceId` — cache gravado antes desta versão — cai no primeiro
  culto, que é onde ela estava.

### Criar uma escala emenda em escalação e repertório

Criar não é o fim da tarefa: a escala nasce sem ninguém escalado e sem
repertório. Por isso o formulário de criação **não volta para a agenda** — ele
emenda em escalação e, dali, em repertório.

**Uma única chamada de navegação por passo**, sempre `pushReplacement`:

```
[agenda, novo]  →  [agenda, escalar]  →  [agenda, repertorio]  →  [agenda, detalhe]
```

- `?novo=1` é o que faz cada tela emendar em vez de voltar. Na escalação o
  botão também vira "Salvar e escolher músicas", para o passo seguinte não
  ser surpresa.
- `pushReplacement` e não `push` porque cada passo **já foi salvo**: voltar
  para ele só ofereceria salvá-lo de novo. Voltar em qualquer ponto cai na
  agenda, onde a escala nova já aparece.
- **Editar continua com `pop`.** O encadeamento é só da criação; quem foi
  editar o horário não quer ser levado para a escalação.
- A bandeira vai na **query**, não em `extra`: assim o encadeamento sobrevive a
  um recarregamento da rota, e a tela do repertório sabe buscar a escala
  sozinha quando chega por URL, sem o `extra`.

Por que não é `go` + `push`: ver a armadilha 11.

### Abrir a música de dentro da escala

Tocar numa música da escala abre `showEventSongSheet` (folha), **para MEMBER
também** — é justamente quem toca que precisa da cifra.

Folha e não navegação para `/equipe/musicas/:songId` por dois motivos: o tom
que vale ali é o **desta escala** (`keyOverride`), e aquela tela mostra o tom
da equipe; e ela usa a **equipe ativa**, não a equipe da escala (armadilha 10).
A folha recebe `event.teamId` e busca a letra por ele.

A escala não carrega `lyrics` (continua não carregando). A folha busca a música
inteira só quando alguém a abre, e falhar ali não esconde tom, recado nem
links, que já vieram com a escala.

### Edição da música: o que a equipe decide × o que veio de fora

`song_form_screen.dart` edita tudo, em duas camadas. Aberto: nome, nosso tom,
tipo e andamento — o que nenhuma API responde. **Recolhido**: artista,
compositor, tom da gravação, os quatro links e a letra, que vêm do import e do
enriquecimento. Fechado, o grupo resume o que já tem ("Tem cifra, letra,
YouTube") em vez de dizer "mais campos".

A letra **só é enviada quando muda** — são até 20 mil caracteres, e reenviá-los
a cada ajuste de tom é peso puro na rede da igreja.

Mudar artista ou título refaz `searchText` e passa pela regra 20 no servidor,
que responde 409 `SONG_ALREADY_EXISTS` — agora é possível esbarrar nela pela
tela, o que antes não acontecia.

### Cadastrar música durante a montagem da escala

O seletor do repertório tem "Cadastrar", que abre o `AddSongScreen` por
`Navigator.push` **sobre** a tela da escala — a escala em montagem continua
viva embaixo e volta intacta. `AddSongScreen` ganhou `onCreated`: nulo mantém o
caminho normal (vai para o detalhe da música); preenchido devolve a música para
quem pediu, que a põe no culto e reabre o seletor.

## Sugestões da equipe

O único canal em que quem canta fala com quem monta a escala **sobre
repertório**. Antes disso o fluxo era de mão única: o líder publicava, a equipe
lia. A única coisa que voltava era indisponibilidade.

Qualquer integrante sugere uma música — para o repertório em geral, ou para um
domingo específico. Quem monta a escala vê as sugestões daquela data **na hora
de montar o repertório**, que é onde a funcionalidade existe para chegar.

### Uma entidade, duas leituras — não duas funcionalidades

`SongSuggestion` tem `targetDate` **opcional**. O ato no mundo real é o mesmo
("quero que a equipe cante isso"); o que muda é se vem data junto — e o mesmo
pedido costuma ser as duas coisas ao mesmo tempo ("podíamos aprender essa; quem
sabe domingo que vem"). Duas tabelas obrigariam a inventar "promover sugestão
de repertório para sugestão de data", partiriam a contagem de repetidas em dois
lugares e duplicariam status idênticos.

`targetDate` nulo significa **"para o repertório, sem data"**. É a outra metade
da funcionalidade, e não um campo que faltou preencher.

### A sugestão aponta para uma DATA, não para a escala

Dia civil (`@db.Date`), como `Unavailability`. **Não existe `eventId`.**

O motivo é duro: o MEMBER **não enxerga escala em rascunho** (`GET /events/:id`
devolve 404 para ele). Na terça, quando ele pensa "domingo dia 14", ou a escala
ainda não foi criada, ou existe como rascunho e ele não pode vê-la. Guardar o id
deixaria o campo impossível de preencher justamente por quem preenche. A escala
também pode ser apagada e recriada; a data não muda.

O casamento acontece na leitura, pelo dia civil **no fuso da equipe**
(`civilDateInZone(event.startsAt, team.timezone)`). Um culto das 21h em São
Paulo cai na **segunda** em UTC — comparar sem o fuso deixaria a faixa da tela
vazia justamente no culto da noite. Há teste para isso.

### Nada é deduzido: quem resolve é o líder

A dedução tentadora é "a música apareceu no repertório daquele domingo → a
sugestão foi atendida". É a mesma armadilha que o `isNew` já pagou três vezes: o
líder pode ter posto a música por conta própria, ou ter acolhido a ideia e
jogado para março.

- **Acolher não cria música nem liga `isNew`.** O backend registra o
  acolhimento e o vínculo; quem cria a música é o líder, na tela de cadastro,
  com `isNew` marcado à mão (ela já nasce marcada ali).
- **Pôr no culto não acolhe a sugestão.** São dois botões na faixa, de
  propósito: o líder pode estar experimentando, e a escala ainda é rascunho.
- **A data passar não muda status.** A sugestão continua `PENDING`; ela só sai
  da lista aberta, como a agenda separa próximas de passadas. Filtrar por data
  não é deduzir julgamento — dizer que foi recusada seria.

### `title` é sempre gravado, mesmo com `songId`

Denormalização de propósito. Compra duas coisas:

- a música pode ser **apagada** (`DELETE /songs/:id` só recusa depois de usada
  em escala). Com `onDelete: SetNull`, a sugestão sobrevive com o texto — a
  justificativa assinada de alguém não some junto com um cadastro;
- o MEMBER **não cria música** (`POST /songs` é LEADER+, e o formulário pede
  tom, tipo e andamento — decisões da equipe). Sugerir precisa aceitar texto
  livre, ou a funcionalidade morre na primeira tentativa.

A exibição não fica com duas verdades: **havendo `songId`, o título é o da
música**; o texto gravado é procedência e reserva — é o que permite notar que o
líder amarrou a música errada.

A busca externa faz a maioria já chegar amarrada: o `GET .../songs/search-external`
**não tem `@TeamRoles`** (só um throttle de 30/min), então a folha de sugerir usa
a mesma busca do Spotify que o cadastro usa.

### A justificativa é obrigatória, e a pergunta muda com a data

`reason` é `NOT NULL`, com mínimo de 10 caracteres — obrigatório sem mínimo
vira ".". Ela filtra sugestão de impulso e, principalmente, **é o que torna a
recusa possível sem virar pessoal**: o líder responde a um argumento, não ao
gosto de alguém.

O rótulo na tela depende da data, e isso não é enfeite: se a música **já é** do
repertório e alguém a pede para o domingo 14, "por que entrar no repertório"
não faz sentido — ela já entrou.

- sem data → "Por que vale a pena a equipe aprender essa música?"
- com data → "Por que essa música nesse domingo?"

### Recusar é "Por enquanto não", e o motivo é opcional

`declineReason` é nulável **de propósito**: às vezes o motivo certo (teologia,
por exemplo) é uma conversa pessoal, e o app não é o canal. Campo em branco é
uso legítimo, não esquecimento — a tela não empurra ninguém a escrever, e a
recusa sem motivo aparece só como o estado, sem rótulo "Motivo:" pendurado no
vazio.

O campo avisa, ali mesmo, que **quem sugeriu vai ler**. Sem isso um líder
escreve "letra com teologia duvidosa" achando que é nota interna, e o app
entrega na cara da pessoa — estrago que não dá para desfazer.

**Quem resolveu não aparece em tela nenhuma.** `resolvedById` é gravado para
auditoria; recusa com o nome do líder do lado azeda a equipe.

`reopen` desfaz a resolução, para o toque errado não virar beco sem saída.

### Repetida não é erro — é o sinal

Três pessoas pedindo a mesma música é o que o líder quer saber. Não bloqueia;
conta (`alsoSuggestedBy`, agrupado em memória sobre as pendentes da equipe pela
chave `songId ?? título normalizado`). O que se bloqueia é a **mesma pessoa**
repetindo a **mesma música** para a **mesma data**.

Essa trava fica no **service, não em índice único**: `targetDate` e `songId` são
nuláveis, e no Postgres `NULL` é distinto de `NULL` em índice único — a chave
não travaria nada justamente nos casos sem data e sem cadastro. Mesma armadilha
que fez `EventSong.serviceId` ser `NOT NULL`.

### Rotas

```
GET    /teams/:teamId/song-suggestions?scope=open|closed   toda a equipe
POST   /teams/:teamId/song-suggestions                     toda a equipe
DELETE /teams/:teamId/song-suggestions/:id                 autor, ou LEADER+
POST   /teams/:teamId/song-suggestions/:id/accept          LEADER+  { songId? }
POST   /teams/:teamId/song-suggestions/:id/decline         LEADER+  { reason? }
POST   /teams/:teamId/song-suggestions/:id/reopen          LEADER+
GET    /events/:eventId/song-suggestions                   LEADER+
```

- `scope=open` (padrão) = pendentes que ainda valem: sem data, ou com data que
  não passou. `closed` = resolvidas + pendentes cujo domingo já foi.
- **`accept`/`decline`/`reopen` respondem 200, não 201.** Agem sobre recurso
  que já existe, como o `publish`/`unpublish` da escala.
- `GET /events/:eventId/song-suggestions` devolve `{ date, forDate[], undated[] }`
  — uma chamada, duas leituras. É **rota própria, e não um campo em
  `GET /events/:id`**: aquele é o retorno mais pesado do app e já deixa de
  carregar letra de propósito; quem paga esta consulta é só quem abriu a
  montagem do repertório.

### No app

**A entrada fica na aba Equipe, ao lado do Repertório — e não em "Gerenciar
equipe".** Pelo mesmo motivo que tirou o Repertório de lá: aquela tela só se
alcança pela engrenagem que aparece para líderes, e quem sugeriu é justamente
quem precisa ver o que aconteceu com a sugestão dele, inclusive o "por enquanto
não". O selo de contagem na linha é só para quem pode responder — para o
integrante, um número que ele não resolve seria enfeite.

Sem push no projeto, **é esse selo que faz o líder descobrir que alguém
sugeriu**. Sugestão que ninguém vê é sugestão que ninguém faz duas vezes.

- `/equipe/sugestoes` — duas abas, "Abertas" e "Encerradas". O cartão mostra a
  justificativa **inteira**, sem cortar: ela é o conteúdo, não um detalhe.
- No **Repertório**, um botão por papel: para quem lidera o flutuante continua
  "Adicionar" e "Sugerir" vai para o cabeçalho; para o integrante — que não
  tinha ação nenhuma naquela tela — o flutuante é "Sugerir".
- Na **montagem do repertório** (`/agenda/:eventId/repertorio`), a
  `EventSuggestionsBand` no topo: as do dia daquela escala, mais um grupo com
  as sem data que já têm cadastro. Recolhida quando a escala já tem música,
  aberta quando está vazia, e some inteira quando não há sugestão. Falha ou
  carregamento **não desenham nada** — a montagem funciona sem a faixa.
- `AddSongScreen` ganhou `initialSearch`: acolher uma sugestão sem cadastro abre
  a busca já preenchida, em vez de o líder redigitar o que quem sugeriu digitou.

**Fora do v1, decidido e não esquecido:** votos/curtidas (transformam um canal
em enquete e criam o problema de "a mais votada não foi escolhida"),
comentários (o WhatsApp já existe), relatório de engajamento (sai depois da
mesma tabela com um `groupBy`, sem migration) e um status "conversar sobre",
para o caso em que o motivo certo é uma conversa pessoal.

Plano e registro de execução: `docs/superpowers/plans/2026-09-03-sugestoes-de-musica.md`.

## Notificações

O que faltava para o app ser o **primeiro** lugar onde a equipe descobre as
coisas — e não o segundo, depois do grupo do WhatsApp. O texto compartilhado
continua existindo: ele é como o convidado, que não tem o app, recebe a escala.

Transporte: FCM (Firebase Cloud Messaging), só Android. Domínio em
`backend/src/modules/notifications/`. **Sem fila**: os gatilhos são os pontos de
gravação que já existiam e que já calculavam o que mudou.

### Sete regras, e cada uma tem um motivo

1. **A notificação não sai do histórico — sai do mesmo gatilho.** O histórico
   fala em terceira pessoa para a equipe ("Pedro entrou em Baixo"); o aviso fala
   em segunda pessoa com uma pessoa ("Você entrou em Baixo"). Derivar um do
   outro obrigaria a procurar o próprio nome dentro de um texto já formatado.
   `diffAssignments` foi extraída de `describeAssignmentChange` justamente para
   servir aos dois sem que um dependa do outro.
2. **Rascunho não avisa ninguém.** `GET /events/:id` devolve 404 de rascunho
   para MEMBER; um push levaria a pessoa a uma tela de erro. Todos os gatilhos
   de escala checam `status === 'PUBLISHED'`.
3. **O token é do aparelho, não da pessoa.** `device_tokens.token` é `@unique`:
   registrar um token conhecido **move** a linha para o novo dono. E sair da
   conta apaga o registro **antes** de descartar o access token — senão o
   próximo a entrar naquele celular recebe a escala de quem saiu.
4. **Falhar em notificar nunca derruba a gravação.** Mesma regra do
   `EventChangesService.record`. Toda chamada é `void this.notifications...`,
   depois da transação, e o `PushService.send` nunca lança.
5. **Só quem tem conta recebe.** Um filtro (`userId` não nulo) resolve
   convidado e placeholder de uma vez. Quem está `onLeave` mas foi escalado
   recebe — é quem mais precisa saber.
6. **Quem fez a ação não é notificado.** Inclusive quando é um dos escalados.
7. **Sem agrupamento.** O diff já filtra: salvar sem mudar nada produz lista
   vazia. O que sobra é publicar e corrigir o horário em seguida — dois avisos
   em minutos, aceito.

### Duas famílias

- **Notificação** — *aconteceu alguma coisa*. Nasce de uma gravação, no mesmo
  instante em que ela acontece. Escala: `SCHEDULE_PUBLISHED`,
  `ASSIGNMENT_ADDED`, `ASSIGNMENT_REMOVED`, `ASSIGNMENT_MOVED`,
  `SCHEDULE_DETAILS`, `SETLIST_READY`, `SETLIST_CHANGED`, `SCHEDULE_CANCELLED`,
  `SCHEDULE_UNPUBLISHED`. Equipe: `SUGGESTION_CREATED`, `SUGGESTION_ACCEPTED`,
  `SUGGESTION_DECLINED`, `UNAVAILABLE_ASSIGNED`, `INVITE_ACCEPTED`.
- **Lembrete** — *há algo útil que você pode fazer agora*. Nasce do relógio:
  `SETLIST_REMINDER`, `REHEARSAL_REMINDER`, `SERVICE_REMINDER`,
  `SUGGESTION_NUDGE`, `SETLIST_EMPTY_NUDGE`. Seção própria abaixo.

### Como se escreve um aviso

O texto é lido na tela de bloqueio, por gente de idades e familiaridades muito
diferentes com aplicativo. Daí três regras que valem para todo texto novo:

- **Dia da semana sempre por extenso.** "domingo", nunca "dom" — `qui` e `qua`
  se confundem numa olhada rápida, e o custo de escrever inteiro são alguns
  caracteres. `weekdayLong` é o único caminho; **não existe `weekdayShort` no
  projeto**, e isso é de propósito.
- **Hora do jeito que se fala.** "9h", "19h30" — não "09:00". `naturalHour`.
  O formato de tabela (`wallClock`) sobrevive **só no histórico**, que é uma
  tabela mesmo.
- **`em`, nunca `na`/`no`, para funções.** Os nomes são cadastrados pela equipe
  ("Ministração", "Data show"), e adivinhar o gênero produziria "no
  Ministração". Com dias da semana é o contrário: o gênero é fixo em português,
  então `onScheduleDay` concorda certo ("no domingo", "na segunda-feira").

Vocabulário: **servir, equipe, preparar, repertório, ensaiar, com a gente**.
Situação positiva pode ter alegria (`Pedro agora faz parte da equipe!`);
situação operacional é clara; situação negativa é respeitosa e **sem frase
motivacional** — cancelamento não se enfeita.

Quatro detalhes que são regra e não acabamento:

- **`SCHEDULE_DETAILS` só olha ensaio, horário e local.** `notes`, `title` e
  `colorPalette` mudam sem que ninguém precise remarcar o sábado — o filtro é o
  `detailLinesForPush`. Sem linha sobrando, não notifica.
- **`ASSIGNMENT_MOVED` existe porque trocar de instrumento cai nas duas listas
  do diff.** Dois avisos contariam a mesma mudança duas vezes, e o segundo
  chegaria como se a pessoa tivesse sido tirada da escala.
- **`SUGGESTION_DECLINED` não diz quem recusou.** `resolvedById` é auditoria e
  não exibição — recusa com o nome do líder do lado azeda a equipe.
- **`UNAVAILABLE_ASSIGNED` é o aviso mais valioso do lado de quem lidera.** O
  modelo é "avisar antes", mas quem marca **depois** da publicação sumia do
  radar: o líder só descobriria reabrindo aquele domingo. Abre direto em
  `/agenda/:eventId/escalar`, e entrega boa parte da "solicitação de troca" sem
  criar entidade nenhuma.

### Lembretes

Saem às **9h no fuso da equipe** — de manhã, para dar tempo de a pessoa fazer
alguma coisa com o aviso. O cron acorda de hora em hora e só trabalha nas
equipes cuja hora local bateu; Manaus e São Paulo não recebem no mesmo instante.

Os prazos estão em `reminder-settings.ts`, **num lugar só**: mudar "três dias"
para "quatro" é conversa de produto, não caça a literais.

| Lembrete | Quando | Para quem | Só se |
|---|---|---|---|
| `SUGGESTION_NUDGE` | 5 dias antes | escalados | repertório vazio |
| `SETLIST_EMPTY_NUDGE` | 4 dias antes | OWNER/LEADER | repertório vazio |
| `SETLIST_REMINDER` | 3 dias antes | escalados | há repertório |
| `SERVICE_REMINDER` | véspera | escalados | — |
| `REHEARSAL_REMINDER` | dia do ensaio | escalados | ensaio ainda por vir |

Três coisas que sustentam isso e não são detalhe:

- **`notification_logs` é a deduplicação**, com chave única
  `(userId, kind, eventId)`. Sem ela o cron mandaria o mesmo lembrete 24 vezes
  por dia. Timer em memória não serviria: o container reinicia a cada deploy.
- **Grava primeiro, envia depois.** Morrendo o processo entre as duas coisas,
  perde-se um lembrete — muito melhor do que repetir. O produto suporta um
  aviso a menos; não suporta virar máquina de spam.
- **Um lembrete por escala por pessoa por dia.** Com o ensaio no sábado e o
  culto no domingo, "hoje tem ensaio" e "amanhã é dia de servir" cairiam no
  mesmo sábado. O ensaio de hoje ganha.

O cron em processo é seguro porque `numReplicas = 1`. Com duas réplicas, quem
impediria o aviso dobrado seria a chave única — não o cron.

### Configuração

`FCM_SERVICE_ACCOUNT` (o JSON da conta de serviço em base64) é **opcional**,
como as chaves do Spotify: sem ela o módulo sobe desligado e a API funciona
igual. Ninguém precisa de conta do Firebase para rodar o projeto local.

`NOTIFICATIONS_DEBUG=true` **loga o aviso em vez de enviar** — é como se confere
texto e destinatário sem Firebase nenhum:

```
[debug] SCHEDULE_PUBLISHED -> 1 usuario(s), 2 aparelho(s) | Escala publicada:
dom, 4 de outubro | Você em Guitarra · Manhã 09:00 · Ensaio sáb 22:00 | rota
/agenda/<id>
```

O `android.notification.channelId` que o backend manda (`escalas`) **precisa ser
idêntico** ao canal criado em `push_service.dart`: id diferente faz a mensagem
chegar e não aparecer, sem erro em lugar nenhum.

### No app

- `core/push/push_service.dart` — aparelho: permissão, canal, token, mensagens.
  **Com o app aberto o FCM não desenha nada**; quem desenha é o
  `flutter_local_notifications`. Sem isso o aviso some justamente para quem está
  com o app na mão.
- `core/push/push_coordinator.dart` — produto: registra o aparelho ao entrar na
  conta, escuta `onTokenRefresh` e, no toque, **troca a equipe ativa antes de
  navegar** (quem serve em duas equipes cairia na agenda errada) e invalida o
  cache daquela escala (o aviso existe porque algo mudou).
- A **permissão do Android 13+** é pedida depois que a agenda mostra conteúdo,
  não no primeiro boot: quem ainda não viu uma escala não tem como decidir, e o
  sistema só volta a perguntar uma vez.
- O interruptor "Avisos no celular" fica em `Perfil → Conta` e diz quando o
  Android está bloqueando — senão ele fica ligado, nada chega, e a culpa parece
  ser do app.
- `isCoreLibraryDesugaringEnabled` no `android/app/build.gradle.kts` é exigência
  do `flutter_local_notifications`. Sem ela o build falha em
  `checkReleaseAarMetadata`, e a mensagem não diz qual dependência pediu.

Fora do v1, decidido: push na Web (VAPID + service worker), preferências por
categoria, central de notificações dentro do app e confirmação de leitura.

Plano e registro de execução:
`docs/superpowers/plans/2026-09-08-notificacoes.md`.

## Vocabulário: "escala", não "culto"

Na interface, a entidade que o líder cria chama-se **escala**. No código e no
banco ela continua sendo `Event` / `events` — renomear a tabela e o modelo não
traria benefício nenhum ao usuário e quebraria migrations. Ao escrever textos
novos, use "escala"; "culto" só sobrevive como rótulo do **horário** dentro da
escala (`Culto 09:00` × `Ensaio 19:00`), que é o sentido correto ali.

## Identidade visual e acessibilidade

Índigo (`#4F46E5`) é a marca da Pauta, e os neutros carregam um traço dele
(matiz 246). Âmbar (`tertiary`) é o papel de **atenção**: algo a
resolver, sem o susto do vermelho, que significa erro. Hoje marca a música sem
tom na lista do repertório — das 286 importadas a maioria chegou assim, e em
cinza o buraco lia-se como "está tudo certo".

Três regras sustentam `app_colors.dart`, e cada uma existe porque a versão
anterior falhava nela:

1. **O cartão fica um passo acima da página, nos dois temas.** No escuro isto
   inverte o Material 3 de propósito (lá `surfaceContainerLowest` é mais escuro
   que `surface`): o app usa esse token como "a superfície do cartão", e seguir
   o M3 fazia o cartão ficar **mais escuro** que a página — lido como buraco.
2. **Borda de controle tem 3:1** (WCAG 1.4.11). O `outline` antigo dava 1,45:1
   sobre o campo: existia no código e não na tela. `outline` é para o que se
   toca (campo, chip, botão contornado); `outlineVariant` é o fio decorativo
   entre blocos, que não precisa dos 3:1.
3. **Fundo e cartão se distinguem sem depender da borda.** O par antigo era
   1,055:1 no claro e 1,034:1 no escuro — a mesma cor.

**`test/theme_contrast_test.dart` mede tudo isso a cada `flutter test`.** Foi
verificado que ele falha ao restaurar o `outline` antigo. Se mexer na paleta e
ele reclamar, o número está certo e a cor está errada — olho não mede razão de
luminância.

Outros pontos do tema (`app_theme.dart`):

- **Foco visível** (`focusColor`) para teclado externo e controle adaptativo. O
  padrão do Flutter é um preto translúcido que some no tema escuro.
- **48dp de alvo de toque** em `IconButton` e em linha de lista
  (`minTileHeight`): uma `ListTile` `dense` chegava a ~40 e escapava do dedo de
  quem está com o instrumento na mão.
- **Um raio por papel**: `radiusMd` (12) para controles, `radiusLg` (16) para
  cartões, `radiusPill` para etiquetas. `radiusXl` e `radiusHero` saíram — o
  segundo nunca foi usado e o primeiro dava ao app três raios de cartão
  diferentes conforme a tela.
- A **sombra do `AppCard` não é o que faz o cartão existir**; é a cor. A sombra
  só arredonda a transição, e por isso o cartão continua legível com "reduzir
  animações" ligado.

## Os horários da escala na tela

`EventTimesList` (`features/events/presentation/event_times.dart`) desenha os
horários no cartão do detalhe **e** no cartão destacado da agenda: uma linha por
culto mais o ensaio, com o rótulo à esquerda e a hora à direita. Abrir a escala
não deve reapresentar a mesma informação num formato diferente.

- **Não volte às etiquetas coloridas.** Eram um `Wrap` de pílulas com
  `primaryContainer` de fundo, e saíram por dois motivos: o texto do ensaio
  estourava a largura, e aquele violeta é **a mesma cor** da faixa de "alguém
  avisou que não pode" logo abaixo — três linhas de informação corriqueira com
  o peso visual de um alerta. A cor sobrou só no ícone do culto.
- Em coluna as horas caem na mesma vertical e ficam comparáveis de relance, que
  é a pergunta de quem abre a escala. Por isso `FontFeature.tabularFigures()`:
  sem ele os dois-pontos de "08:30" e "19:00" desalinham.
- **O ensaio usa `formatRehearsalTime`**, que dá `19:00` no mesmo dia da escala
  e `sáb 19:00` em outro. A data por extenso ("Ensaio Segunda-feira, 10 de
  agosto 00:30") era o que quebrava o layout. Há teste travando o formato.
- Esse rótulo já esteve duplicado em três lugares com formatos diferentes, e a
  listagem tinha um bug por isso: mostrava só a hora, então ensaio de sábado
  parecia ser no dia do culto. **Um formatador só, os três chamam.**
- No **item** da lista os horários seguem em linha corrida
  (`Manhã 08:30 · Noite 19:00 · Ensaio sáb 19:00`): ali a pergunta é "qual
  escala é esta?", e a coluna alinhada gastaria três linhas por item.

## Regras de escalação

Duas regras vêm da prática do culto e são validadas **no backend** (o app só
impede antes, para o líder não descobrir o erro ao salvar):

1. **Um instrumento por pessoa por escala.** Vocal acumula com um instrumento
   (canta e toca violão); dois instrumentos, nunca.
2. **Multimídia e som ficam fora da banda.** Quem está em função `TECH` não
   pode estar em `VOCAL` nem `INSTRUMENT` na mesma escala.

A categoria da `Position` é o que sustenta isso: `VOCAL`, `INSTRUMENT`, `TECH`
e `OTHER`. Multimídia e Som são semeadas como `TECH` em toda equipe nova.
Códigos de erro: `MULTIPLE_INSTRUMENTS` e `TECH_WITH_BAND`.

## Quem lidera junto: promover a LEADER

`LEADER` e `OWNER` fazem **exatamente as mesmas coisas**. A única diferença que
existia — só o dono redefinia a senha de um integrante — foi removida de
propósito: quem lidera junto precisa resolver "esqueci a senha" no sábado à
noite sem depender do dono.

O que sobra em `OWNER` é ser quem criou a equipe: o papel dele não se altera
(`CANNOT_DEMOTE_OWNER`) e ele não pode ser removido (`CANNOT_REMOVE_OWNER`).

- **Não existe segundo dono**, e a dívida de transferência de posse continua
  aberta. O índice parcial `memberships_one_active_owner_per_team` segue de pé,
  e `UpdateMemberDto` só aceita `LEADER`/`MEMBER`.
- **Um líder não redefine a senha do dono** → 403 `CANNOT_RESET_OWNER_PASSWORD`.
  Isto não é zelo: a rota **devolve a senha temporária a quem chamou**, então um
  líder que pudesse chamá-la sairia dali com acesso à conta do dono. Papel
  nenhum se toma por assalto. Líder redefinir a de outro líder é permitido — é
  o mesmo nível de confiança, e foi decisão de quem os promoveu.
- **Ninguém muda o próprio papel** → 409 `CANNOT_CHANGE_OWN_ROLE`.

No app, em `Equipe → Integrantes → (pessoa)`, no fim do formulário. A tela
**explica em vez de deixar tentar**: para o dono, para você mesmo e para
convidado ela mostra o papel atual e o motivo, sem seletor — um seletor
desabilitado convidaria a insistir.

**Redefinir a senha** fica no menu da linha do integrante (`Redefinir senha`,
`reset_password_action.dart`), e só aparece para quem já tem conta — pela mesma
razão, ela some quando um líder olha a linha do dono, em vez de deixar tentar e
levar 403. O diálogo mostra a senha temporária **uma vez**, com copiar e
"WhatsApp"; ela nunca é gravada em claro, e perder a tela significa redefinir de
novo.

**Até onde vai a derrubada de sessão.** `revokeAllForUser` revoga os *refresh
tokens*: nenhum aparelho renova a sessão, e a senha antiga não entra mais em
lugar nenhum. O *access token* que já estava na mão continua valendo até
expirar (`JWT_ACCESS_TTL_SECONDS`, uma hora) — o `JwtAuthGuard` verifica o JWT
sem ir ao banco, e o `mustChangePassword` que ele lê é o do payload antigo. Um
app aberto responde nessa janela. O texto do diálogo diz isso; fechar a janela
exigiria uma coluna de versão do token conferida a cada requisição, e essa
decisão não foi tomada.

## Ficha do integrante: o que é da pessoa e o que é da equipe

A ficha está partida em dois lugares, e a divisão não é arrumação — é quem
responde pelo dado.

**Na conta (`users`), porque é da pessoa:** `birth_date` e `gender`. Não mudam
de equipe para equipe, e quem os conhece é o dono da conta. Preenchidos em
`Perfil → Meus dados`, por `PATCH /users/me`.

- **O preço está assumido:** integrante cadastrado pelo líder e ainda sem conta
  vem com `birthDate: null`, e o líder **não** preenche por ele. A tela diz isso
  ("aparece quando Fulano criar a conta"), em vez de mostrar um campo vazio que
  parece cadastro esquecido. Se um dia a decisão mudar, o campo desce para
  `memberships` — é uma migration pequena.
- `birth_date` é `@db.Date`, dia civil, nunca timestamp. Mesma armadilha já paga
  em `Unavailability`: guardar com hora faz quem nasceu no dia 1º virar dia 30.
  O par `toDateOnly`/`toDateKey` mora em `src/common/date-only.ts` (backend) e
  `lib/core/date/civil_date.dart` (app).
- 400 `BIRTH_DATE_IN_FUTURE` e `BIRTH_DATE_TOO_OLD` (ano < 1900): o
  `class-validator` garante o formato, mas não sabe que ninguém nasceu amanhã.
- `Gender` é `MALE | FEMALE | OTHER`, e `null` é "não informou" — estado padrão
  e legítimo. Nada no sistema decide nada por ele.

**No vínculo (`memberships`), porque é da equipe:** `notes`, `on_leave`,
`leave_until` e `leave_reason`, junto de `phone`, que já morava ali.

- `notes` é a anotação de quem lidera ("chega depois das 9h"). **O corte é no
  servidor:** `MembershipsService.list` recebe `canSeeNotes` e devolve `null`
  para quem é `MEMBER` — campo que não pode ser lido não sai da API.
- **Afastamento liga e desliga à mão.** `leave_until` é *previsão* de retorno, e
  não gatilho: quem sabe que a pessoa voltou é a liderança, não o calendário.
  Voltar antes do previsto é comum, e um retorno automático na data recolocaria
  na escala alguém que ninguém conferiu. Quando a previsão vence, a API devolve
  `leaveOverdue: true` e a tela cobra a decisão em vez de tomá-la.
- **Desligar o afastamento limpa a previsão e o motivo** (`leaveFields`, no
  serviço). Sem isso, quem se afasta de novo em setembro reapareceria com
  "previsão: 12 de março" — texto que ninguém escreveu, dito com a autoridade de
  um campo preenchido.
- O afastamento **não impede escalar**: aparece como etiqueta âmbar na lista,
  na ficha e no seletor da escalação, ao lado da de indisponibilidade. Uma é o
  aviso de longo prazo, a outra é a do dia; quem está nos dois estados vê os
  dois selos. O rótulo é **"Em afastamento"**, e não "Afastado": o app sabe o
  gênero de quem preencheu e não sabe o de quem não preencheu, e um adjetivo
  erraria o nome de metade da equipe toda vez que aparecesse.

**Onde os campos aparecem:** os aniversários dos próximos 60 dias abrem a aba
Equipe ("Hoje", "Amanhã", "em 12 dias"), sem o ano — quem lê quer saber quando
parabenizar, e anunciar a idade de todo mundo é decisão que ninguém tomou. O
`phone` finalmente tem uso: WhatsApp e ligação no menu do integrante, para a
equipe inteira e não só para quem lidera.

## Convidados

Músico de fora chamado para uma ocasião: `Membership` com `isGuest = true`,
sem conta e sem convite. **Não aparece na lista de integrantes** — a listagem
só o inclui com `?includeGuests=true`, usada pela tela de escalação. Ele entra
na escala e no texto compartilhado, que é como recebe as informações, já que
não tem o app.

## Indisponibilidade

O modelo é **avisar antes**, não confirmar depois. Não existe aceitar/recusar
escala: o integrante marca em `Perfil → Minha disponibilidade` os dias em que
não pode, e quem monta a escala vê a etiqueta na hora de escalar.

- Tabela `unavailabilities` guarda **dia civil** (`@db.Date`), não timestamp.
- `GET /events/:id` devolve `unavailable[]` (quem não pode naquele dia) e
  `warnings.unavailableAssigned[]` (quem foi escalado mesmo assim).
- **Indisponível não bloqueia escalar** — o líder às vezes já combinou a troca
  por fora. A tela sinaliza em vermelho e o aviso reaparece depois de salvar.
- LEADER+ pode marcar indisponibilidade por outra pessoa; MEMBER, só a própria.
- `GET /teams/:id/unavailabilities?from&to` alimenta o **calendário da equipe**
  (`Gerenciar equipe → Quem não pode`): um mês civil por vez, contagem por dia,
  filtro por pessoa e atalho "criar escala neste dia", que abre a escala nova
  já na data (`/agenda/novo?data=AAAA-MM-DD`). Antes disso o líder só descobria
  a ausência ao abrir a escala de um domingo específico — depois de escalar.

## Rascunho e publicação

Toda escala nasce `DRAFT` — inclusive a cópia de "duplicar" e os rascunhos
gerados pela grade. Antes ela nascia publicada, e a equipe via a montagem pela
metade: nome entrando e saindo, repertório vazio, e alguém perguntando no grupo
se aquilo já valia.

Enquanto está em rascunho:

- **só quem administra enxerga.** `GET /teams/:id/events` filtra por papel e
  `GET /events/:id` devolve 404 da escala em rascunho para quem é MEMBER;
- a agenda mostra a etiqueta "Rascunho" e o que ainda falta;
- `POST /events/:id/publish` recusa com `INCOMPLETE_SCHEDULE` só enquanto não
  houver **equipe escalada**. A mensagem lista o que falta;
- `POST /events/:id/unpublish` devolve a escala ao rascunho.

### Repertório em aberto não segura a publicação

A regra antiga também exigia música em todos os cultos, e estava errada para o
caso mais comum da igreja: **no culto de quinta as músicas não são escolhidas
antes**. Segurar a escala até o repertório sair segura justamente o que urge —
saber que você está escalado daqui a um mês. O repertório chega depois; a
escalação, não.

O que **não** mudou é dizer o que falta. Faltando música, a escala continua
avisando — em rascunho e publicada:

- `Event.publicationBlockers` é o que impede publicar (hoje só `['equipe']`);
  `Event.servicesWithoutSongs` é o que ainda está em aberto, e vale nos dois
  status. Eram uma lista só — juntar as duas fazia "falta música" parecer
  impedimento, que é exatamente o que ele deixou de ser;
- na agenda, `_ScheduleStatusLines` dá até duas linhas: âmbar para o que trava a
  publicação, ardósia (`info`) para "Músicas a definir", que é notícia e não
  pendência de ninguém;
- no **texto do WhatsApp** a seção 🎶 entra mesmo vazia, com "Ainda não
  escolhidas." — mesma razão do "Sem ensaio": quem recebe não tem o app, e
  seção que some confunde "esqueceram de mandar" com "ainda não escolheram";
- no detalhe, o vazio do repertório oferece **"Sugerir uma música"** a quem não
  administra, com a data do culto já preenchida. É o momento em que a sugestão
  ainda tem chance de ser acolhida — com o repertório montado, ela chega tarde;
- o histórico grava `Publicada sem o repertório definido` (ou os cultos sem
  música, quando só parte deles está em aberto). Depois, nenhuma consulta
  distingue "publicaram sem música" de "a música veio depois".

## Histórico da escala e edição simultânea

O `updatedAt` da escala é o **número de versão dela inteira**. A escalação e o
repertório tocam a linha da escala de propósito (`event.update` com `data: {}`)
só para que trocar a equipe também conte como alteração.

- Quem edita devolve o `expectedUpdatedAt` que recebeu ao abrir a tela.
  Diferente do banco = **409 `SCHEDULE_CHANGED`**, e o app oferece "ver como
  está agora" ou "salvar assim mesmo". Sem isso, dois líderes montando o mesmo
  domingo se sobrescreviam **em silêncio**.
- O campo é **opcional**: app antigo, que ainda não o manda, continua gravando
  como antes em vez de quebrar na atualização.
- `event_changes` guarda quem mexeu, quando e as frases do que mudou.
  `GET /events/:id/history` é liberado para a equipe inteira: "quem me tirou da
  escala?" é pergunta de quem foi tirado.
- **O texto é gravado pronto, não derivado depois.** Um resumo montado hoje a
  partir dos ids leria "Fulano entrou no Baixo" com o nome e a função de hoje;
  o histórico precisa dizer o que era verdade naquele dia.
- **Registrar nunca derruba a gravação.** `EventChangesService.record` engole o
  próprio erro: a escala é o produto, o histórico é o benefício.
- Salvar sem mudar nada **não** vira linha. O app manda o formulário inteiro a
  cada gravação; sem a comparação, o histórico diria que tudo mudou toda vez.

As funções que montam as frases são puras e exportadas —
`describeAssignmentChange`, `describeDetailsChange` e `describeSetlistChange` —
justamente para serem testáveis sem banco quando houver teste no backend.

## Relatórios

Todos em `/teams/:teamId/reports`, restritos a OWNER/LEADER:

- `GET .../workload?weeks=` — participação por integrante: escalas, funções e
  última vez. Tela: `Gerenciar equipe → Participação`.
- `GET .../rotation?weeks=` — o mesmo olhar, magro e indexado por
  `membershipId`, para a **linha do seletor da escalação**. Conta escalas e não
  escalações: quem tocou baixo e cantou no mesmo domingo serviu uma vez. Não
  bloqueia nem sugere nada — só evita que a escala repita quem vem à cabeça
  primeiro.
- `GET .../songs?months=` — uso do repertório: quantas vezes, quando e em que
  tons. Só escala **publicada e já passada**: rascunho é plano, e plano não é
  histórico. As não cantadas viram um número (`neverPlayedCount`), não uma
  lista — com os 581 hinos do Cantor Cristão importados de uma vez, a lista
  seria ruído. Tela: `Gerenciar equipe → Uso do repertório`.

## Feature flags

`app/lib/core/config/feature_flags.dart` esconde funcionalidades prontas em vez
de removê-las: o endpoint, o diálogo e o teste continuam funcionando; só a
entrada no menu some.

Hoje **nenhuma está desligada**. `duplicateSchedule` voltou a `true` depois da
revisão do fluxo — a cópia nasce como rascunho, e cultos, escalação,
ministrante, recados e repertório caem nos horários correspondentes.

**O schema Prisma já contém TODAS as tabelas do MVP**, incluindo `events`,
`assignments`, `songs` e `event_songs`. As etapas 4 a 6 normalmente **não
precisam de migration nova** — só se você acrescentar campos.

Contas de teste no banco local, ambas da equipe "Ministerio de Louvor":
`samuel@teste.com` / `senhaFinal789` (OWNER) e `maria@teste.com` /
`mariaTeste2026` (MEMBER — serve para conferir os 403 sem depender de ler o
código do guard).

## Testes do backend

Integração de verdade: sobem o `AppModule` inteiro contra um Postgres, com os
mesmos `ValidationPipe`, filtro de exceção e prefixo do `main.ts`. É onde moram
as coisas que quebram caladas — isolamento entre equipes, papéis, transações,
regras de escalação — e nenhuma delas aparece num teste com o Prisma dublado.

```
cd backend
docker compose exec api npm test              # a suíte inteira
docker compose exec api npx jest test/x.spec.ts   # um arquivo
docker compose exec api npx tsc --noEmit -p tsconfig.spec.json
```

- **Banco separado.** A suíte usa `louvor_test`, no mesmo Postgres do compose:
  `test/setup/env.ts` troca a `DATABASE_URL` **antes** de qualquer import (o
  `src/config/env.ts` valida o ambiente no import), e `global-setup` cria o
  banco e roda `prisma migrate deploy`. Cada teste começa truncando todas as
  tabelas — apontar isso para o banco de trabalho apagaria a equipe de verdade.
- **`maxWorkers: 1`.** Um banco só, limpo entre testes. Paralelizar exigiria um
  schema por worker, e a suíte inteira roda em menos de um minuto.
- **Token assinado direto** (`ctx.tokenFor`), sem passar pelo login: o argon2 é
  caro de propósito. O login de verdade tem teste próprio em `auth.spec.ts`.
- **O rate limit é neutralizado trocando o `ThrottlerStorage`**, e não o guard:
  `overrideGuard` não alcança um guard registrado como `APP_GUARD`, porque o
  token do provider é `APP_GUARD` e não a classe.
- **Não use `isolatedModules` no ts-jest.** Sem checagem de tipo, a primeira
  versão desta suíte passava `SeededMember` onde a ajuda esperava `{ id }`,
  assinava um token com `sub: undefined` e o teste de isolamento entre equipes
  passava *pelo motivo errado* — filtro do Prisma com `undefined` deixa de
  filtrar.

O que a suíte cobre hoje: autenticação, isolamento entre equipes e papéis,
rascunho/publicação, o corte da agenda pelo dia civil, regras de escalação,
recado individual, trava de edição simultânea, histórico, repertório por culto,
geração pela grade, duplicação, indisponibilidade, convites, os três
relatórios e as sugestões de música — inclusive o casamento por dia civil num
fuso não-UTC, que é o que quebraria calado. **Ainda sem teste**: cadastro de músicas, catálogo e busca externa,
fotos de perfil e o CRUD de funções e integrantes.

## Convenções do backend

- Módulos por feature em `src/modules/<nome>/` com `*.controller.ts`,
  `*.service.ts`, `*.module.ts` e `dto/`. Três camadas: controller → service →
  Prisma. **Sem** CQRS, event bus, repositório genérico ou DDD tático.
- Rotas de negócio sob `/api/v1`. `/health` fica fora do prefixo.
- Domínio e código em **inglês**; mensagens ao usuário em **português**.
- Tabelas e colunas em `snake_case` via `@map`; modelos em `PascalCase`.

### Autenticação e autorização

- `JwtAuthGuard` é global. Rota aberta precisa de `@Public()`.
- `@SkipPasswordChangeCheck()` libera a rota para quem está com
  `mustChangePassword` (só `/auth/me` e `/auth/change-password` usam).
- `@UseGuards(TeamMemberGuard)` no controller carrega o `Membership` ativo em
  `req.membership` e devolve **404** (não 403) para quem não é da equipe.
  **O guard exige um parâmetro `:teamId` na rota.**
- `@TeamRoles('OWNER', 'LEADER')` restringe por papel.
- `@CurrentUser()` e `@CurrentMembership()` injetam nos handlers.

### Erros

Filtro global em `src/common/filters/http-exception.filter.ts` normaliza tudo
para `{ statusCode, code, message, path, timestamp }`. Para um erro com código
próprio, lance com objeto:

`throw new ConflictException({ code: 'CANNOT_REMOVE_OWNER', message: 'O dono da equipe nao pode ser removido.' })`

O app usa `code` para reagir e `message` para exibir.

### Validação

`ValidationPipe` global com `whitelist: true` e `forbidNonWhitelisted: true` —
campo desconhecido no corpo vira 400. DTOs com `class-validator`, mensagens em
português, `@Transform` para `trim`/lowercase. Use `ParseUUIDPipe` nos params.

## Convenções do app

- Feature-first: `lib/features/<nome>/{data,domain,presentation}`, mais
  `application/` quando há controller de estado.
- Riverpod: `Provider` para repositórios, `FutureProvider.autoDispose.family`
  para listas por `teamId`, `StateNotifierProvider` para sessão.
- **Modelos escritos à mão** com `fromJson`. Não use freezed/build_runner — o
  passo de codegen não paga o próprio custo neste MVP.
- Repositórios envolvem chamadas em `_guard` e lançam `ApiException`
  (`core/network/api_exception.dart`). Telas capturam e exibem.
- Formulários usam `FormScaffold` e `FormErrorBanner`
  (`shared/widgets/form_scaffold.dart`).
- Navegação em `core/router/app_router.dart`, com `redirect` por estado de auth.
  Telas que dependem da equipe usam o helper `_withActiveTeam`.
- Equipe ativa: `activeTeamIdProvider` (`features/team/data/team_repository.dart`).
- Responsividade: `core/responsive/`. Pontos de quebra em `AppBreakpoints`,
  **nunca** número de largura solto numa tela. `AppBreakpoints.of(context)`
  para decisões sobre a janela; `ResponsiveBuilder` para decisões sobre o
  espaço recebido. Diálogo x folha por `showAdaptiveSheet`.

## Armadilhas já pagas — não repita

1. **Android release não fala HTTP em texto claro.** Resolvido em
   `app/android/app/src/main/res/xml/network_security_config.xml`. Para testar em
   celular físico, adicione o IP da máquina lá.
2. **Não coloque timeout curto na leitura do armazenamento seguro.** Um
   `timeout(5s)` no bootstrap deslogava quem tinha sessão válida em aparelho
   lento. Falha real vira exceção e é tratada.
3. **`TokenStorage` mantém cache em memória.** No Android o plugin trabalha na
   thread principal; ler o Keystore a cada requisição causou ANR.
4. **`enableShutdownHooks()` só em produção** — em dev quebra o hot reload.
5. **Hot reload do Nest depende de polling** configurado em
   `backend/tsconfig.json` (`watchOptions`) e `backend/nodemon.json`
   (`legacyWatch` + `signal: SIGKILL`). Não mexa sem entender o porquê:
   `CHOKIDAR_USEPOLLING` **não** resolve, e o engine do Prisma faz o processo
   ignorar SIGTERM.
5b. **`rootDir` é fixo em `./src`, e `prisma/` está fora do `include`.** Isto
   custou uma hora: o `include` trazia `prisma/**/*`, e bastou existir um `.ts`
   ali importando de `../src/` para o TypeScript recalcular a raiz — a saída
   migrou de `dist/main.js` para `dist/src/main.js` enquanto o nodemon seguia
   rodando o `dist/main.js` antigo. **A API ficou congelada num build velho
   sem um único erro aparecer**: `tsc` dizia "0 errors", o log do Nest mostrava
   as rotas antigas e a rota nova respondia 404. Se isso voltar a acontecer,
   compare a data de `dist/main.js` com a do fonte antes de procurar bug no
   código. **Mas compare com `main.ts`, não com o arquivo que você editou**: o
   build é incremental, e `dist/main.js` só é reemitido quando `main.ts` muda —
   editar um service deixa `dist/main.js` legitimamente mais velho que o fonte,
   o que parece o congelamento sem ser. O teste honesto é olhar o `.js`
   correspondente ao arquivo editado (`dist/modules/.../x.service.js`) e, se
   quiser certeza, `grep` nele por um identificador que você acabou de
   escrever. E apague o `tsconfig.tsbuildinfo` **da raiz do projeto** (não só o
   de `dist/`): o cache incremental sobrevive à troca de layout e faz o build
   se declarar atualizado sem emitir nada. Os scripts de `prisma/` rodam por
   `ts-node`, que já os typecheca ao executar.
6. **String vazia não passa em `z.string().url().optional()`.** O compose sempre
   define a variável; use `z.preprocess` para tratar `''` como ausente.
7. **O emulador Android desta máquina é muito lento** (1–2 min para abrir em
   debug). Automação de UI por `adb input` é pouco confiável — os toques caem
   antes da tela renderizar. Prefira validar por `curl` (backend) e
   `flutter test` (app), e peça verificação visual ao usuário.
8. **Datas em `timestamptz` (UTC) no banco.** A exibição usa `team.timezone`
   (`America/Sao_Paulo`). Nunca guarde horário local.
9. **A fonte é empacotada, não baixada.** O pacote `google_fonts` foi removido:
   ele buscava a Plus Jakarta Sans em `fonts.gstatic.com` na primeira execução,
   o que fazia o app depender de um segundo servidor além da API e degradar
   para a fonte do sistema em rede ruim. Os `.ttf` estão em `app/assets/fonts`
   e declarados no `pubspec.yaml` como família `PlusJakartaSans`. **Não
   reintroduza `google_fonts`.**
10. **Permissão e identidade vêm da equipe do recurso**, não de `teams.first`.
    O app assume uma equipe por usuário em vários pontos, mas onde há um
    `teamId` no objeto (evento, por exemplo), use-o para achar o
    `Membership` correto — senão quem participa de duas equipes vê o menu de
    líder onde é apenas membro.
11. **Não encadeie `go` e `push` no mesmo frame.** Foi a primeira tentativa do
    fluxo "criar escala → escalar → músicas": `go('/agenda/:id')` para montar
    agenda → detalhe e `push` da escalação por cima. **Não funciona.** As duas
    disparam análises de rota assíncronas, e o `push` toma como base a
    configuração de **antes** do `go`; a pilha sai indeterminada. O sintoma
    engana: a tela empilhada aparece normalmente, e o que falha é o passo
    seguinte, que parece não responder ao botão. Compila, passa no `analyze` e
    no `flutter test` — só aparece no aparelho. **Um passo, uma chamada de
    navegação.**

12. **`MultipartFile.fromFile` não existe no navegador.** Ele usa `dart:io`, e
    no Flutter Web o `path` de um `XFile` é uma URL `blob:`. Envio de arquivo
    em código compartilhado vai por `MultipartFile.fromBytes`.
13. **O `enableCors` do Nest não cobre os arquivos estáticos.** O
    `useStaticAssets` é registrado antes do middleware de CORS e responde sem
    passar por ele. No Android isso nunca apareceu (não há origem a conferir);
    na Web, o `Image.network` busca os bytes por XHR e **toda foto de perfil
    quebrava**. O cabeçalho é posto à mão no `setHeaders` de `/uploads`
    (`backend/src/main.ts`).
14. **Deep link chega antes de o app saber se há sessão.** No celular o app
    sempre abre em `/`; na Web, colar `#/agenda/<id>` ou apertar F5 dentro de
    uma escala entra direto por aquela rota, com o `AuthController` ainda em
    `unknown`. O redirect precisa mandar para a splash, e por isso guarda o
    destino (`_PendingLocation` em `app_router.dart`) e volta a ele quando a
    sessão resolve. Sem isso o link compartilhado sempre caía na agenda.
15. **`Align` com `heightFactor` e largura adaptativa.** `AppContentWidth`
    ganhou variantes (`.reading`, `.wide`) que leem `MediaQuery`. O
    `heightFactor: 1` continua sendo obrigatório pelo motivo de sempre — ver o
    comentário do widget e `test/app_content_width_test.dart`.


## Definição de pronto

Uma etapa só está pronta quando:

- `cd backend; docker compose exec api npx tsc --noEmit -p tsconfig.json` não acusa nada;
- as rotas novas aparecem no log do Nest;
- **cada regra de negócio foi exercitada por `curl`**, inclusive os casos de
  erro (não basta o caminho feliz);
- `cd app; flutter analyze` termina com "No issues found!";
- `cd app; flutter test` passa;
- `cd app; flutter build web --release --dart-define=API_BASE_URL=https://backend-production-b304.up.railway.app` compila;
- o APK release compila.

Relate o que **não** foi verificado. Não afirme que algo funciona sem ter
executado.

## Dívidas conhecidas

- **A agenda custa duas consultas, e pode custar quatro.** Ela precisa de
  `upcoming` e `past` para o calendário navegar para trás, e cada escopo amplia
  para 100 itens quando a página de 20 vem cheia. A saída não é cortar o
  passado, é a API ganhar recorte por mês (`GET /teams/:id/events?from=&to=`) —
  aí o calendário pede o mês que está mostrando, e só ele.

- **Sem build WebAssembly.** `flutter build web --wasm` não passa: o
  `flutter_secure_storage_web` ainda usa `dart:html`/`package:js`. O build JS
  padrão funciona normalmente; o `--wasm` fica esperando o pacote migrar para
  `dart:js_interop`.
- **Sessão na Web depende de contexto seguro.** O `flutter_secure_storage_web`
  guarda o token cifrado com WebCrypto, que só existe em `https` ou
  `localhost`. Servir o site em `http://` num IP de rede local deixa a sessão
  sem onde ser salva.

- **Strings sem acento.** As mensagens de UI e os comentários estão sem acentos
  ("Voce", "Funcoes") por causa de problemas de encoding no shell do Windows
  durante o desenvolvimento inicial. Flutter e Postgres lidam com UTF-8 sem
  problema — vale uma passada acertando os acentos das strings visíveis ao
  usuário. Faça isso de uma vez só, não etapa por etapa.
- **Transferência de posse de equipe** não existe. `PATCH` de membro só aceita
  `LEADER`/`MEMBER`; promover a `OWNER` exigiria operação atômica própria por
  causa do índice único parcial `memberships_one_active_owner_per_team`.
- **Sem página pública de convite.** `INVITE_BASE_URL` é opcional; sem ela a API
  devolve `url: null` e o app compartilha só o código.
- **Sem cache offline real.** Planejado para a Etapa 7: guardar o último JSON e
  exibir com selo "atualizado às HH:mm".
- **Sem confirmação de presença** ("aceito/não posso"). Fora do MVP por decisão;
  o modelo suporta com uma coluna `status` em `assignments`.
- **Cobertura parcial no backend.** A suíte de integração cobre o núcleo (ver
  a seção Testes do backend), mas cadastro de músicas, catálogo, busca externa,
  fotos de perfil e o CRUD de funções e integrantes continuam verificados só
  por `curl`, à mão.
- **Sem CI.** Nada roda a suíte sozinho: `npm test`, `tsc` e `flutter test`
  dependem de alguém lembrar antes de publicar.
- **Sem modo culto offline.** O cache guarda agenda e detalhe, mas não garante
  a letra quando a conexão cai durante o ensaio ou o culto.
- **Sem link web da escala.** Convidado e quem não tem o APK dependem do texto
  compartilhado.
- **Sessão aberta sobrevive à redefinição de senha por até uma hora.** O refresh
  token é revogado na hora, mas o access token em mãos vale até expirar e o
  `JwtAuthGuard` não vai ao banco. Fechar isso exige versão de token (ou
  `password_changed_at`) conferida por requisição — custo de uma leitura a cada
  chamada. Ver a seção "Quem lidera junto".
