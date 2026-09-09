# Notificações push — Implementation Plan

> **For agentic workers:** Steps usam checkbox (`- [ ]`) para acompanhamento.
> Backend só via Docker (`docker compose exec api ...`); Flutter nativo no
> Windows com o PATH prefixado.

**Goal:** o integrante descobre pelo app — e não pelo grupo do WhatsApp — que
foi escalado, que saiu da escala, que o ensaio mudou de hora e que o repertório
saiu; quem lidera descobre que alguém sugeriu uma música e que um escalado
avisou que não pode.

**Architecture:** FCM (Firebase Cloud Messaging) como transporte, um módulo
`notifications/` como domínio e **nenhuma fila**. Os gatilhos são os pontos de
gravação que já existem e que já calculam o que mudou: `publish`, a troca de
escalação, o `PATCH` de detalhes, a gravação do repertório, as sugestões e a
indisponibilidade. O diff já está pronto nesses três lugares — o que falta é um
segundo leitor para ele.

**Tech Stack:** NestJS 11, Prisma 6, PostgreSQL 16, `firebase-admin`; Flutter +
Riverpod + go_router, `firebase_core` + `firebase_messaging` +
`flutter_local_notifications`.

---

## Decisões — leia antes de codar

Estas sete decisões são o plano. O resto é digitação.

### 1. A notificação não sai do histórico — sai do mesmo gatilho

Tentação: ler `event_changes` e mandar as frases que já estão lá. Não.

O histórico fala da escala em terceira pessoa e para a equipe inteira — "Pedro
entrou em Baixo". A notificação fala com **uma** pessoa, em segunda pessoa, e
só sobre a parte que é dela — "Você entrou em Baixo". Derivar uma da outra
obrigaria a reconhecer o próprio nome dentro de um texto já formatado, que é
exatamente o tipo de dedução que este projeto evita.

Além disso o histórico grava **rascunho também** (ver decisão 2), e uma leitura
posterior não teria como distinguir.

Então: mesmo ponto de gravação, dois leitores. `describeAssignmentChange`
continua servindo ao histórico; a notificação usa as listas `entered` / `left`
que a mesma comparação já separa em `assignments.service.ts`.

### 2. Nada de rascunho. Nunca.

`GET /events/:id` devolve **404** de escala em rascunho para quem é MEMBER
(seção "Rascunho e publicação" do `AGENTS.md`). Um push sobre rascunho levaria
a pessoa a bater numa tela de erro.

Isso vale para todos os gatilhos de escala: escalação, detalhes e repertório só
notificam quando `event.status === 'PUBLISHED'`. Rascunho é bancada de
trabalho, e o valor de ter separado rascunho de publicado é justamente esse:
existe um momento em que a equipe passa a ser avisada, e ele tem nome.

O corolário é que **publicar é a notificação mais importante do sistema**, e as
outras são correções sobre algo que a pessoa já leu.

### 3. O token é do aparelho, não da pessoa

O FCM entrega para uma *instalação*, não para uma conta. Um token pode passar
de dono: o celular é emprestado, a pessoa sai da conta e outra entra.

Daí duas regras que não são opcionais:

- **`POST /me/devices` grava o token no usuário autenticado.** Se o token já
  existir apontando para outro usuário, ele é **movido**, não duplicado — daí o
  `@unique` na coluna.
- **Sair da conta apaga o token no servidor**, e não só no aparelho. Sem isso o
  próximo a entrar naquele celular recebe a escala de outra pessoa. O hook é o
  `logout` / `_signOutLocally` do `auth_controller.dart`.

Token que o FCM devolver como `registration-token-not-registered` é apagado na
hora. Sem essa poda a tabela vira depósito de aparelhos formatados.

### 4. Falhar em notificar nunca derruba a gravação

Mesma regra — e mesmo motivo — do `EventChangesService.record`, que engole o
próprio erro: **a escala é o produto, o aviso é o benefício**. Se o FCM estiver
fora do ar, a escala foi salva e o pedido é um sucesso.

Na prática: toda chamada ao `NotificationsService` acontece **depois** da
transação, sem `await` que possa propagar, e o `PushService` tem try/catch
interno.

Corolário operacional: `FCM_SERVICE_ACCOUNT` é **opcional**. Sem ela a API sobe
normalmente e o módulo fica desligado — igual ao `SPOTIFY_CLIENT_ID`. Ninguém
precisa de conta do Firebase para rodar o projeto local.

### 5. Convidado não recebe, e quem não tem conta também não

`Membership.userId` é nulo enquanto a pessoa é placeholder, e `isGuest = true`
não tem conta por decisão (seção "Convidados"). O filtro é um só e resolve os
dois casos: **só entra na lista de destinatários quem tem `userId`**. Convidado
continua recebendo pelo texto do WhatsApp, que é como ele sempre recebeu.

Membro em `onLeave` que estiver escalado **recebe**. Afastado que foi escalado
mesmo assim é justamente quem mais precisa saber.

### 6. Quem fez a ação não é notificado

O líder que acabou de publicar está olhando para a tela. O ator sai da lista de
destinatários em todos os gatilhos — inclusive quando ele é um dos escalados.

O caso interessante é o líder que se escala: ele publica, todo mundo recebe,
ele não. Correto — ele acabou de digitar o próprio nome.

### 7. Sem agrupamento no v1 — porque o diff já filtra

A preocupação óbvia é o líder que salva a escalação três vezes em cinco minutos
e dispara três avisos. Ela não se concretiza: a comparação antes/depois já
existe, então **salvar sem mudar nada produz lista vazia** e não notifica
ninguém. A segunda gravação só alcança quem mudou de verdade na segunda
gravação.

O caso que sobra é publicar e, logo depois, corrigir o horário: duas
notificações em minutos. Aceito no v1. Se incomodar, o conserto é uma tabela
`notification_log (userId, eventId, kind, sentAt)` com janela de dez minutos —
que também responderia "por que fulano não recebeu?". Está fora do v1 por não
ter ainda o problema que ela resolve.

---

## O catálogo

`ator` = quem fez a ação, sempre excluído. "escalados" = quem tem `Assignment`
na escala **e** `userId` preenchido.

| Chave | Gatilho | Destinatários | Título / corpo |
|---|---|---|---|
| `SCHEDULE_PUBLISHED` | `POST /events/:id/publish` | escalados | "Escala de dom, 14 de setembro" / "Você em Guitarra · culto 09:00 · ensaio sáb 19:00" |
| `ASSIGNMENT_ADDED` | `PUT /events/:id/assignments`, escala publicada | quem entrou | "Você entrou na escala de dom, 14 de setembro" / "Guitarra · culto 09:00" |
| `ASSIGNMENT_REMOVED` | idem | quem saiu | "Você saiu da escala de dom, 14 de setembro" / "Você estava em Guitarra" |
| `ASSIGNMENT_MOVED` | idem, quando a pessoa cai nas **duas** listas | quem trocou | "Você mudou de função em dom, 14 de setembro" / "Agora em Vocal · antes Guitarra" |
| `SCHEDULE_DETAILS` | `PATCH /events/:id`, publicada, **só** ensaio/horário/local | escalados | "Mudou a escala de dom, 14 de setembro" / as frases filtradas |
| `SETLIST_READY` | `PUT /events/:id/setlist`, publicada, repertório estava vazio | escalados | "O repertório de dom, 14 de setembro saiu" / "5 músicas" |
| `SETLIST_CHANGED` | idem, já havia repertório | escalados | "O repertório de dom, 14 de setembro mudou" |
| `SCHEDULE_CANCELLED` | `DELETE /events/:id`, publicada | escalados | "A escala de dom, 14 de setembro foi cancelada" |
| `SCHEDULE_UNPUBLISHED` | `POST /events/:id/unpublish`, estava publicada | escalados | "A escala de dom, 14 de setembro saiu do ar" / "A equipe vai remontar" |
| `SUGGESTION_CREATED` | `POST /teams/:id/song-suggestions` | OWNER/LEADER | "Maria sugeriu uma música" / "Bondade de Deus — para 14 de setembro" |
| `SUGGESTION_ACCEPTED` | `.../accept` | autor | "Sua sugestão entrou" / "Bondade de Deus" |
| `SUGGESTION_DECLINED` | `.../decline` | autor | "Por enquanto não: Bondade de Deus" / o motivo, **sem o nome de quem recusou** |
| `UNAVAILABLE_ASSIGNED` | `POST /unavailabilities` em dia com escala publicada onde a pessoa está escalada | OWNER/LEADER | "João não pode no dia 14" / "Ele está escalado em Bateria" |
| `INVITE_ACCEPTED` | `POST /invites/accept` | OWNER/LEADER | "Pedro entrou na equipe" / "Falta definir as funções dele" |

Três observações que são regra e não detalhe:

- **`SCHEDULE_DETAILS` só olha ensaio, horário e local.** `notes`, `title` e
  `colorPalette` mudam sem que ninguém precise remarcar o sábado. O
  `describeDetailsChange` devolve tudo; a notificação filtra as linhas que
  começam com `Ensaio`, `Horário`, `Saiu do horário` e `Local`. Se nada sobrar
  depois do filtro, não notifica.
- **`SUGGESTION_DECLINED` não diz quem recusou.** O schema é explícito:
  `resolvedById` é "guardado para auditoria e **não exibido**: recusa com o nome
  do líder do lado azeda a equipe". A notificação obedece.
- **`ASSIGNMENT_MOVED` não estava previsto e apareceu ao escrever o serviço.**
  Trocar alguém de instrumento cai nas duas listas do diff: sem ele, a pessoa
  recebia "entrou" e "saiu" pela mesma mudança, e o segundo chegava como se ela
  tivesse sido tirada da escala.
- **`UNAVAILABLE_ASSIGNED` é a mais valiosa do lado do líder** e a menos óbvia.
  O modelo é "avisar antes", mas quando a pessoa marca **depois** da publicação,
  hoje o líder só descobre reabrindo aquele evento e vendo
  `warnings.unavailableAssigned`. Ela abre direto em `/agenda/:eventId/escalar`,
  e entrega boa parte da "solicitação de troca" que o plano prevê sem criar
  entidade nenhuma.

## Global Constraints

- Domínio e código em **inglês**; mensagens ao usuário em **português**.
  Strings de UI **sem acento**, como o resto do app (dívida conhecida — não
  conserte pontualmente). **Exceção:** o corpo da notificação é texto de
  produto lido fora do app, e é gerado no **backend**, onde as mensagens já são
  acentuadas (`'Escala não encontrada.'`). Ele vai com acento.
- Sem freezed/build_runner; modelos Dart à mão.
- Erros com `{ code, message }`, como o resto do backend.
- **Não criar commits** a menos que o usuário peça.
- `docs/` é copiado em `app/docs` e `backend/docs`. Este plano vive só na raiz.

## Fora do v1 — decidido, não esquecido

- ~~**Lembretes agendados**~~ — **feitos**, ver a seção abaixo.
- **Push na Web.** Exige VAPID key, um `firebase-messaging-sw.js` em `app/web/`
  e HTTPS. A versão Web se usa sentado na mesa, onde a agenda já está aberta —
  o valor do push está no celular.
- **Preferências por categoria.** O v1 sai com **um interruptor só**
  (`User.pushEnabled`). Escolher categorias antes de alguém ter sentido o volume
  é chutar; virar categorias depois é uma migration barata.
- **Central de notificações dentro do app.** Uma segunda superfície para manter
  em sincronia com as telas que já existem (agenda, sugestões, histórico).
- **`notification_log`.** Ver decisão 7. (Uma tabela com esse papel acabou
  entrando pelos lembretes, e não pelas notificações: `notification_logs` é a
  deduplicação do agendador. As notificações de gravação continuam sem ela --
  elas já são únicas por definição.)
- **Confirmação de leitura** ("Fulano ainda não abriu a escala"). Vira
  vigilância, e vai contra a mesma linha que escondeu o nome de quem recusa uma
  sugestão.
- **Aniversários.** `User.birthDate` existe e é tentador. É outro produto.

## File map

| Arquivo | Responsabilidade |
|---|---|
| `backend/prisma/schema.prisma` | `DeviceToken` + `User.pushEnabled` |
| `backend/src/config/env.ts` | `FCM_SERVICE_ACCOUNT` (opcional), `NOTIFICATIONS_DEBUG` |
| `backend/src/modules/notifications/push.service.ts` | Transporte: firebase-admin, envio em lote, poda de token |
| `backend/src/modules/notifications/notifications.service.ts` | Domínio: quem recebe o quê, e com que texto |
| `backend/src/modules/notifications/notification-text.ts` | Funções puras que montam título/corpo |
| `backend/src/modules/notifications/devices.controller.ts` | `POST` / `DELETE /me/devices` |
| `backend/src/modules/notifications/notifications.module.ts` | Wiring, `@Global()` |
| `backend/src/modules/events/events.service.ts` | Gatilhos: publish, unpublish, delete, details |
| `backend/src/modules/assignments/assignments.service.ts` | Gatilho: entrou/saiu |
| `backend/src/modules/songs/event-songs.service.ts` | Gatilho: repertório |
| `backend/src/modules/song-suggestions/song-suggestions.service.ts` | Gatilhos: criada, aceita, recusada |
| `backend/src/modules/unavailabilities/unavailabilities.service.ts` | Gatilho: conflito com escala publicada |
| `backend/src/modules/invites/invites.service.ts` | Gatilho: convite aceito |
| `backend/src/modules/users/users.service.ts` | `pushEnabled` no `PATCH /me` |
| `backend/test/notifications.spec.ts` | Integração: destinatários, não o FCM |
| `app/android/app/google-services.json` | **Manual.** Vem do Firebase Console |
| `app/lib/core/push/push_service.dart` | Inicialização, permissão, token, canal |
| `app/lib/core/push/push_router.dart` | Toque na notificação → troca de equipe → rota |
| `app/lib/features/auth/application/auth_controller.dart` | Registrar no login, apagar no logout |
| `app/lib/features/profile/presentation/profile_screen.dart` | Interruptor "Avisos no celular" |
| `app/lib/main.dart` | `Firebase.initializeApp` + handler de background |

---

## Task 0: O que só o dono do projeto faz

**Nenhum agente executa esta task.** Ela depende de contas e senhas. As demais
tasks podem ser escritas antes — o backend sobe sem a chave (decisão 4) e o app
compila sem o `google-services.json` só depois que ele existir, então esta task
precisa estar pronta antes da Task 8.

- [x] **Step 1: Projeto no Firebase**

console.firebase.google.com → **Add project** → nome livre (ex.: `pauta`).
Pode **desligar o Google Analytics** — não é usado aqui e só acrescenta consentimento.

O plano gratuito (Spark) cobre o FCM. **Não há cobrança por mensagem.**

- [x] **Step 2: Registrar o app Android**

No projeto → ícone do Android → **Android package name**:

```
br.com.escalas.louvor_app
```

Precisa bater **exatamente** com o `applicationId` de
`app/android/app/build.gradle.kts:31`. Apelido e SHA-1 são opcionais (o SHA-1 só
serve para Google Sign-In, que não existe aqui).

Baixe o `google-services.json` e coloque em `app/android/app/`.
Ele **não é segredo** (vai dentro do APK), mas também não precisa ir para o Git.

- [x] **Step 3: Chave de serviço do backend**

Firebase Console → engrenagem → **Project settings** → aba **Service accounts**
→ **Generate new private key**. Baixa um JSON.

**Esse arquivo é segredo de verdade** — quem o tem manda notificação em nome do
projeto. Nunca no repositório. Converta para uma linha só, em base64:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\caminho\para\chave.json"))
```

- [x] **Step 4: Variável no Railway**

Serviço da API → Settings → Variables:

| Variável | Valor |
| --- | --- |
| `FCM_SERVICE_ACCOUNT` | o base64 do passo 3 |

Localmente é opcional: sem ela a API sobe e o módulo fica desligado. Para testar
push no ambiente local, ponha a mesma variável no `backend/.env`.

- [x] **Step 5: Confirmar que não precisa de mais nada**

- **Sem conta Apple / APNs** — este projeto não tem pasta `ios/`.
- **Sem VAPID key** — push na Web está fora do v1.
- **Sem publicar na Play Store** — FCM funciona em APK instalado à mão, desde
  que o aparelho tenha Google Play Services (o caso de praticamente todo Android
  vendido no Brasil).

---

## Task 1: Schema e migration

**Files:** Modify `backend/prisma/schema.prisma`

- [x] **Step 1: Modelo `DeviceToken`**

```prisma
/// Um aparelho que aceita receber aviso. **Do aparelho, nao da pessoa**: o
/// FCM entrega para uma instalacao, e a instalacao troca de dono quando
/// alguem sai da conta e outro entra. Por isso `token` e unico no banco
/// inteiro -- registrar um token que ja existe MOVE a linha para o novo dono,
/// em vez de criar uma segunda.
model DeviceToken {
  id     String @id @default(uuid()) @db.Uuid
  userId String @map("user_id") @db.Uuid

  /// O registration token do FCM.
  token String @unique

  /// "android" hoje. "web" quando o push do navegador entrar.
  platform String

  /// Ultima vez que o app confirmou este token. Serve para faxina futura --
  /// o FCM tambem expira token parado ha mais de ~270 dias.
  lastSeenAt DateTime @default(now()) @map("last_seen_at") @db.Timestamptz(3)
  createdAt  DateTime @default(now()) @map("created_at") @db.Timestamptz(3)

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId])
  @@map("device_tokens")
}
```

- [x] **Step 2: Interruptor no `User`**

```prisma
  /// Avisos no celular. **Explicito e ligado a mao**, nao deduzido de "tem
  /// token registrado": desligar no Android some com a notificacao mas nao
  /// avisa o servidor, que continuaria mandando para o vazio.
  ///
  /// Mora no `User` e nao no `Membership` porque "nao me acorde" e da pessoa,
  /// e nao da equipe. O preco esta assumido: quem serve em duas equipes tem um
  /// interruptor so.
  pushEnabled  Boolean       @default(true) @map("push_enabled")

  deviceTokens DeviceToken[]
```

- [x] **Step 3: Migration**

```
cd backend
docker compose exec api npx prisma migrate dev --name device_tokens
```

Expected: migration criada, `prisma generate` roda, API sobe sem erro.

---

## Task 2: Configuração e transporte

**Files:** Modify `backend/src/config/env.ts`, `backend/.env.example`,
`backend/package.json`; Create `backend/src/modules/notifications/push.service.ts`

- [x] **Step 1: Dependência**

```
cd backend
docker compose exec api npm install firebase-admin
```

Dentro do container, nunca no Windows.

- [x] **Step 2: Variáveis**

Em `env.ts`, seguindo o padrão do `SPOTIFY_CLIENT_ID` (opcional, e o
`vazioComoAusente` porque o compose sempre define a variável):

```typescript
  /// Chave de conta de servico do Firebase, em base64 do JSON inteiro.
  /// **Opcional de proposito**: sem ela o modulo de notificacao sobe
  /// desligado e a API funciona normalmente -- ninguem precisa de conta do
  /// Firebase para rodar o projeto local. Ver Task 0 do plano.
  FCM_SERVICE_ACCOUNT: z.preprocess(vazioComoAusente, z.string().optional()),

  /// Loga o payload que SERIA enviado, sem enviar. Serve para conferir texto
  /// e destinatario sem configurar Firebase.
  NOTIFICATIONS_DEBUG: z.coerce.boolean().default(false),
```

Documente as duas em `.env.example` e na tabela de variáveis de `docs/DEPLOY.md`.

- [x] **Step 3: `PushService`**

Responsabilidade única: pegar `userIds` + payload e entregar. **Não sabe nada de
escala.**

```typescript
@Injectable()
export class PushService implements OnModuleInit {
  private app: App | null = null;

  onModuleInit() {
    if (!env.FCM_SERVICE_ACCOUNT) {
      this.logger.log('FCM_SERVICE_ACCOUNT ausente -- notificacoes desligadas.');
      return;
    }
    // JSON.parse do base64 -> initializeApp({ credential: cert(...) })
  }

  /// Nunca lanca. Ver decisao 4 do plano.
  async send(userIds: string[], message: PushMessage): Promise<void> { ... }
}
```

Pontos que não são negociáveis:

- **`sendEachForMulticast` aceita 500 tokens por chamada.** Fatiar.
- **Podar token morto:** resposta com
  `messaging/registration-token-not-registered` ou
  `messaging/invalid-argument` → `deleteMany({ where: { token } })`.
- **Filtrar `pushEnabled: false`** na consulta dos tokens, não no chamador.
- **try/catch em volta de tudo**, com `logger.warn`. Nunca relança.
- Payload Android:

```typescript
{
  notification: { title, body },
  data: { kind, route, teamId },      // strings; o FCM nao aceita outra coisa
  android: {
    priority: 'high',
    notification: { channelId: 'escalas' },  // igual ao canal criado no app
  },
}
```

---

## Task 3: O domínio

**Files:** Create `backend/src/modules/notifications/notification-text.ts`,
`backend/src/modules/notifications/notifications.service.ts`,
`backend/src/modules/notifications/notifications.module.ts`;
Modify `backend/src/app.module.ts`

- [x] **Step 1: Textos puros**

Um arquivo de funções puras — exportadas e sem Prisma, pelo mesmo motivo que
`describeAssignmentChange` é pura: dá para testar sem banco.

```typescript
/// "dom, 14 de setembro" no fuso da equipe. Reaproveita a mesma ideia de
/// `civilDay`, com o dia da semana, que e o que a pessoa procura primeiro.
export function scheduleLabel(startsAt: Date, timeZone: string): string
export function publishedBody(positions: string[], services: ..., rehearsalAt: Date | null, tz: string): string
export function detailLinesForPush(lines: string[]): string[]   // filtra ensaio/horario/local
```

- [x] **Step 2: `NotificationsService`**

Um método por linha do catálogo. Cada um: carrega o que precisa, monta a lista
de destinatários, monta o texto, chama `PushService.send`.

Dois helpers privados fazem o trabalho repetido:

```typescript
/// Escalados com conta, menos o ator. Ver decisoes 5 e 6.
private async assignedUserIds(eventId: string, actorMembershipId?: string)

/// OWNER/LEADER com conta, menos o ator.
private async leaderUserIds(teamId: string, actorMembershipId?: string)
```

A rota do `data` sai daqui: `/agenda/<eventId>`, `/agenda/<eventId>/escalar`
(para `UNAVAILABLE_ASSIGNED`), `/equipe/sugestoes`, `/equipe/gerenciar`.

- [x] **Step 3: Módulo `@Global()`**

Sete módulos vão injetar o `NotificationsService`. `@Global()` evita sete
imports e uma discussão sobre dependência circular com `EventsModule`.

---

## Task 4: A espinha — publicar e entrar/sair

**Files:** Modify `backend/src/modules/events/events.service.ts`,
`backend/src/modules/assignments/assignments.service.ts`

Esta task sozinha prova o caminho ponta a ponta. **Verifique-a antes da Task 5.**

- [x] **Step 1: `publish`**

Depois do `changes.record`, em `events.service.ts:316`:

```typescript
void this.notifications.schedulePublished(eventId, actor?.id);
```

- [x] **Step 2: entrou / saiu**

Em `assignments.service.ts`, o `before` já é lido antes da transação
(`assignments.service.ts:125`) e o `describeAssignmentChange` já separa
`entered` e `left`. Extraia essa separação para uma função que devolve as duas
listas, use-a nos dois lugares, e:

```typescript
// Escala em rascunho nao avisa ninguem -- ver decisao 2 do plano.
if (event.status === 'PUBLISHED') {
  void this.notifications.assignmentsChanged(eventId, entered, left, actor?.id);
}
```

`replace` hoje não carrega o `status` do evento; acrescente ao `select` que já
existe.

- [x] **Step 3: Verificar**

```
docker compose exec api npx tsc --noEmit -p tsconfig.json
```

Com `NOTIFICATIONS_DEBUG=true`, publicar uma escala pelo app deve imprimir um
payload por destinatário, com o nome da função certa e **sem o ator na lista**.

---

## Task 5: Os demais gatilhos

**Files:** Modify `events.service.ts`, `event-songs.service.ts`,
`song-suggestions.service.ts`, `unavailabilities.service.ts`,
`invites.service.ts`

Cada um é ~10 linhas depois da Task 4.

- [x] **Step 1: Detalhes, cancelamento e despublicação** (`events.service.ts`)

O `describeDetailsChange` já roda; passe as linhas por `detailLinesForPush` e
notifique só se sobrar alguma. `DELETE` e `unpublish` precisam ler os escalados
**antes** de apagar/mudar.

- [x] **Step 2: Repertório** (`event-songs.service.ts:219`)

`SETLIST_READY` quando estava vazio, `SETLIST_CHANGED` quando não. A distinção
importa: publicar sem repertório é caminho normal e previsto, e "o repertório
saiu" é a notícia que fecha aquele ciclo.

- [x] **Step 3: Sugestões** (`song-suggestions.service.ts`)

Criada → líderes. Aceita/recusada → autor. **`declineReason` vai no corpo; o
nome de quem recusou não vai.**

- [x] **Step 4: Indisponibilidade** (`unavailabilities.service.ts`)

Depois de gravar, procure escala **publicada** da equipe naquele dia civil
(mesmo casamento de fuso que as sugestões usam) em que aquele membership tenha
`Assignment`. Achando, notifique os líderes com a função em que a pessoa está
escalada. Não achando, silêncio — é o caso comum e correto.

- [x] **Step 5: Convite aceito** (`invites.service.ts`)

---

## Task 6: Rotas de dispositivo e preferência

**Files:** Create `backend/src/modules/notifications/devices.controller.ts`;
Modify `backend/src/modules/users/users.service.ts` e o DTO do `PATCH /me`

- [x] **Step 1: Controller**

```
POST   /me/devices   { token, platform }   -> 204
DELETE /me/devices   { token }             -> 204
```

`POST` é `upsert` por `token` **trocando o `userId`** — decisão 3. Responde 204
porque não devolve recurso.

- [x] **Step 2: `pushEnabled` no `PATCH /me`**

Booleano opcional, junto dos campos que já existem.

---

## Task 7: Testes de integração

**Files:** Create `backend/test/notifications.spec.ts`

- [x] **Step 1: Substituir o `PushService` por um espião**

O teste **não** fala com o FCM. `overrideProvider(PushService)` com um duplo que
guarda as chamadas. O que se verifica é **quem receberia**, que é onde moram os
erros caros.

- [x] **Step 2: Os casos que quebram calados**

- publicar avisa os escalados e **não** avisa o ator;
- convidado (`isGuest`) e placeholder (`userId` nulo) **não** entram na lista;
- trocar escalação em **rascunho** não avisa ninguém;
- salvar a escalação sem mudar nada não avisa ninguém;
- `pushEnabled: false` não recebe;
- recusar sugestão manda o motivo e **não** manda o nome de quem recusou;
- registrar um token já existente de outro usuário **move** a linha;
- vazamento entre equipes: líder da equipe B não recebe sugestão da equipe A.

---

## Task 8: App — inicialização, permissão e token

**Files:** Modify `app/pubspec.yaml`, `app/android/app/build.gradle.kts`,
`app/android/build.gradle.kts`, `app/lib/main.dart`;
Create `app/lib/core/push/push_service.dart`

**Depende da Task 0.**

- [x] **Step 1: Dependências e plugin Gradle**

`firebase_core`, `firebase_messaging`, `flutter_local_notifications`. O
`google-services` entra como plugin do Gradle Android.

- [x] **Step 2: Canal de notificação**

Android 8+ exige canal. Crie `escalas` com importância alta, **com o mesmo id
que o `PushService` do backend manda em `channelId`**. Id diferente = a
notificação chega e não aparece.

- [x] **Step 3: Permissão no momento certo**

Android 13+ exige `POST_NOTIFICATIONS` em runtime. **Não peça no primeiro
boot**, quando a pessoa ainda não sabe o que o app faz — peça depois que ela vê
a primeira escala, com uma frase dizendo para quê. Negada, o app segue
funcionando; não insista.

- [x] **Step 4: Ciclo de vida do token**

- em `_applySession` (login e bootstrap) → `POST /me/devices`;
- em `onTokenRefresh` → `POST /me/devices` de novo;
- em `logout` / `_signOutLocally` → `DELETE /me/devices` **antes** de descartar
  o access token, senão a chamada sai sem autenticação (decisão 3).

---

## Task 9: App — receber e abrir

**Files:** Create `app/lib/core/push/push_router.dart`; Modify `main.dart`

- [x] **Step 1: App aberto**

Com o app em primeiro plano o FCM **não** desenha nada — quem desenha é o
`flutter_local_notifications`. Sem este passo o aviso simplesmente não aparece
para quem está com o app na mão, que é o caso mais fácil de testar e o mais
fácil de dar como quebrado.

- [x] **Step 2: Toque → rota, com a equipe certa**

`getInitialMessage` (app fechado) e `onMessageOpenedApp` (app em segundo plano).
O `data` traz `route` e `teamId`.

**Antes de navegar, trocar a equipe ativa** via `ActiveTeamController.select`
(`team_repository.dart:347`). Quem serve em duas equipes tem uma equipe ativa
guardada no aparelho; abrir a escala da outra sem trocar mostraria a agenda
errada, ou uma tela vazia.

Depois de navegar, **invalidar o cache de leitura** daquela escala: a
notificação existe porque algo mudou, e mostrar a versão em cache seria mostrar
exatamente o que mudou de errado.

- [x] **Step 3: Handler de background**

Função de topo com `@pragma('vm:entry-point')`, registrada em `main.dart`. Ela
não desenha nada (o Android já desenha) — existe para o plugin não reclamar.

---

## Task 10: App — o interruptor

**Files:** Modify `app/lib/features/profile/presentation/profile_screen.dart`

- [x] **Step 1: "Avisos no celular"**

Um `SwitchListTile` no perfil, ligado ao `pushEnabled` do `PATCH /me`. Quando a
permissão do Android estiver negada, mostrar isso na linha e oferecer abrir os
ajustes do sistema — senão o interruptor fica ligado e nada chega, e a culpa
parece ser do app.

---

## Task 11: Verificação final

- [x] **Step 1: Backend**

```
docker compose exec api npx tsc --noEmit -p tsconfig.json
docker compose exec api npm test
```

- [x] **Step 2: App**

```
$env:PATH = 'C:\Users\Acer\flutter\bin;' + $env:PATH
cd app; flutter analyze     # precisa terminar com "No issues found!"
cd app; flutter test
```

- [x] **Step 3: Teste de ponta a ponta, em dois aparelhos**

Com duas contas (`samuel@teste.com` OWNER, `maria@teste.com` MEMBER):

1. escalar Maria numa escala em rascunho → **nada chega**;
2. publicar → chega no aparelho da Maria e **não** no do Samuel;
3. app fechado → toque abre `/agenda/<id>` com os dados atualizados;
4. tirar Maria da escala → "Você saiu da escala de ...";
5. Maria sugere música → chega no Samuel;
6. Samuel recusa com motivo → chega na Maria **sem o nome dele**;
7. Maria marca indisponibilidade num domingo em que está escalada → chega no
   Samuel, e o toque abre a escalação daquele dia;
8. Maria sai da conta → escalar de novo **não** manda nada para aquele aparelho.

- [x] **Step 4: Documentação**

- `AGENTS.md`: seção nova "Notificações", e **retirar** de "Dívidas conhecidas"
  a linha "Sem notificação" (AGENTS.md:1353), ajustando o parágrafo do "Estado
  atual" que lista o que o plano ainda prevê;
- `docs/DEPLOY.md`: `FCM_SERVICE_ACCOUNT` na tabela de variáveis e a Task 0 como
  passo manual do dono;
- `backend/.env.example`: as duas variáveis, comentadas como opcionais;
- copiar `docs/` para `app/docs` e `backend/docs`.

---

## Registro de execução

Tudo feito e verificado em 08/09/2026. `npm test` verde (164 testes, 13 suítes),
`tsc --noEmit` limpo, `flutter analyze` com "No issues found!", `flutter test`
verde (249) e o APK de release construído com o Firebase dentro (61,1 MB).

### O que o plano não previa e apareceu na execução

- **`ASSIGNMENT_MOVED`.** Ver a observação no catálogo.
- **`wallClock` e `civilDay` saíram de `event-changes.service.ts`** para
  `src/common/human-time.ts`, junto de `weekdayShort` e
  `civilDayFromDateOnly`. As notificações viraram o segundo leitor, e a segunda
  cópia é que estraga — mesma razão que criou o `date-only.ts`. Um importador
  só foi tocado (`events.service.ts`).
- **`civilDayFromDateOnly` formata em UTC, e isso não é detalhe.** A
  `targetDate` da sugestão é `@db.Date` (meia-noite UTC); formatá-la no fuso da
  equipe faria "domingo dia 14" virar "13 de setembro" no aviso. É a armadilha
  que a `Unavailability` já tinha pago.
- **`positionsByMember` ordena por `sortOrder` e depois por nome.** Sem isso o
  corpo saía "Você em Vocal e Guitarra" conforme o banco devolvesse as linhas —
  e a ordem da equipe é a que a tela da escala usa.
- **`isCoreLibraryDesugaringEnabled` no Gradle.** Exigência do
  `flutter_local_notifications`. O build falha em `checkReleaseAarMetadata`, e a
  mensagem não diz qual dependência pediu.
- **`z.coerce.boolean()` não serve para flag de ambiente**: transforma qualquer
  string não vazia em `true`, inclusive `"false"` — que é exatamente o que
  alguém escreveria para desligar. `NOTIFICATIONS_DEBUG` usa um `preprocess`
  que só aceita `"true"`.
- **O `PushSpy` entrou em `createTestApp`, e não só no spec novo.** Sem a troca,
  todo teste que publica uma escala dispararia a inicialização do
  `firebase-admin` e consultas de token que não têm nada a ver com o que ele
  verifica.
- **As asserções negativas precisam de `settle()`.** Os gatilhos são
  `void this.notifications...` de propósito (decisão 4), então a resposta HTTP
  volta antes de o aviso ser montado. `waitFor` resolve as positivas.

### Verificação de ponta a ponta (com `NOTIFICATIONS_DEBUG=true`)

Contra o banco de desenvolvimento, com Samuel (OWNER) e Maria (MEMBER),
exercitando cada gatilho e conferindo o texto real:

```
SCHEDULE_PUBLISHED  -> Escala publicada: dom, 4 de outubro
                       Você em Guitarra · Manhã 09:00, Noite 19:00 · Ensaio sáb 22:00
ASSIGNMENT_REMOVED  -> Você saiu da escala de dom, 4 de outubro | Você estava em Baixo
ASSIGNMENT_MOVED    -> Você mudou de função em dom, 4 de outubro
                       Agora em Vocal · antes Guitarra
SCHEDULE_DETAILS    -> Mudou a escala de dom, 4 de outubro | Local: "Templo novo"
SETLIST_READY       -> O repertório de dom, 4 de outubro saiu | 1 música
UNAVAILABLE_ASSIGNED-> Maria avisou que não pode | dom, 4 de outubro · Vocal
                       rota /agenda/<id>/escalar
SUGGESTION_CREATED  -> Maria sugeriu uma música | Bondade de Deus   (2 líderes)
SUGGESTION_DECLINED -> Por enquanto não: Bondade de Deus | <motivo>  (sem o nome do líder)
SCHEDULE_CANCELLED  -> A escala de dom, 4 de outubro foi cancelada | rota /agenda
```

Confirmado no mesmo roteiro: quem publicou **não** recebe; mudar só a observação
não avisa; e a escala de teste foi apagada do banco de trabalho ao final.

### Verificação em dois aparelhos — feita

Publicado como **v0.5.0** (`8a3d928`) pelo workflow do CI, e testado em duas
instâncias do BlueStacks (Android 9, x86_64, Google Play Services 26.28.33),
uma por conta, contra o backend de produção — onde o log do deploy confirma
`Notificacoes push ligadas.`

Os dez passos do roteiro passaram: rascunho não avisa, a publicação chega só
para quem não publicou, o toque abre a escala recarregada, trocar de função é um
aviso só, mudar a observação não avisa e mudar o local avisa, o repertório
distingue "saiu" de "mudou", a sugestão chega para quem lidera e a recusa volta
com o motivo e sem o nome, a indisponibilidade abre a escalação daquele dia --
e, o que mais importava, **sair da conta faz o aparelho parar de receber**.

Duas coisas que esse ambiente não cobre, e continuam sem verificação:

- **O pedido de permissão do Android 13+.** `POST_NOTIFICATIONS` só existe a
  partir da API 33; no Android 9 do BlueStacks o aviso aparece sem diálogo
  nenhum, então o caminho "pede depois que a agenda carrega" nunca roda.
- **Doze e otimização de bateria de aparelho real.** O emulador não dorme como
  um celular no bolso.

Ambas só se verificam num Android 13+ físico, com o app horas em segundo plano.

---

## Segunda rodada: linguagem humana e lembretes (08/09/2026)

A implementação estava correta e os textos, mecânicos -- tinham cara de sistema
administrativo, não de uma equipe que se prepara para servir junta.

### O que mudou nos textos

Os 14 avisos foram reescritos. Três regras passaram a valer para todo texto
novo, e as três estão no `AGENTS.md`:

- **Dia da semana sempre por extenso.** "domingo", nunca "dom". A equipe tem
  gente de idades e familiaridades muito diferentes com aplicativo, e `qui` e
  `qua` se confundem numa olhada rápida na tela de bloqueio -- que é exatamente
  onde o aviso é lido. `weekdayShort` foi **deletado**, não desativado: deixá-lo
  vivo era convidar o próximo a usá-lo.
- **Hora do jeito que se fala:** `9h`, `19h30`, nunca `09:00`. O formato de
  tabela (`wallClock`) sobrevive só no histórico, que é uma tabela mesmo.
- **`em`, nunca `na`/`no`, para funções.** Os nomes são cadastrados pela equipe
  ("Ministração", "Data show"), e adivinhar o gênero produziria "no
  Ministração". Com dia da semana é o contrário -- o gênero é fixo em português
  --, então `onScheduleDay` concorda certo: "no domingo", "na segunda-feira".

`servicesLabel` passou a dizer "Cultos às 9h e 19h" em vez de "Manhã 09:00,
Noite 19:00". **O rótulo do culto se perdeu no aviso**, e isso é uma troca
consciente: numa linha só ele dobrava o tamanho para repetir o que a hora já
diz. A tela da escala continua mostrando o rótulo, que é onde ele importa.

### `SCHEDULE_DETAILS` deixou de ler o histórico

Ele filtrava as frases de `describeDetailsChange` por prefixo de string. Era
frágil de um jeito silencioso: renomear "Local" no histórico calaria a
notificação, sem erro em lugar nenhum. E contrariava a decisão 1 deste plano,
que a própria implementação tinha violado.

Agora recebe o **antes/depois estruturado** e monta a própria frase. O
histórico ficou intocado.

### Lembretes

Cinco novos, de uma família diferente: notificação é *aconteceu alguma coisa*,
lembrete é *há algo útil que você pode fazer agora*. Regras, prazos e a tabela
de deduplicação estão na seção "Notificações" do `AGENTS.md`.

Três decisões que sustentam o resto:

- **`@nestjs/schedule` fixado na linha 5.x.** A 12 é ESM e quebra o Jest
  CommonJS do projeto. Preferi a versão CJS a mexer no `transformIgnorePatterns`
  de toda a suíte por causa de uma dependência.
- **Grava primeiro, envia depois.** Morrendo o processo entre as duas coisas,
  perde-se um lembrete -- muito melhor do que repetir. O produto suporta um
  aviso a menos; não suporta virar máquina de spam.
- **Um lembrete por escala por pessoa por dia.** Com o ensaio no sábado e o
  culto no domingo, "hoje tem ensaio" e "amanhã é dia de servir" cairiam no
  mesmo sábado. O ensaio de hoje ganha.

`assignedUserIds`, `leaderUserIds` e `positionsByMember` saíram do
`NotificationsService` para `audience.ts`: os lembretes precisavam exatamente
das mesmas regras, e a segunda cópia é que teria esquecido o filtro de conta
um dia.

### Um bug pré-existente, encontrado por acaso

`song-suggestions.spec.ts` calculava "ontem" em UTC e comparava com o dia civil
da equipe. Ele falha na janela entre a meia-noite de Greenwich e a de São Paulo
-- que era exatamente o horário em que a suíte rodou (UTC 00:01, SP 21:01).
Veio com o commit das sugestões, não com este trabalho. Corrigido; o teste da
divergência de fuso no mesmo arquivo dependia do comportamento antigo, e as
duas leituras foram separadas em vez de misturadas.

### Verificação

Backend: `tsc --noEmit` limpo, **205 testes em 15 suítes** (41 novos, em
`notification-text.spec.ts` -- puro, sem banco -- e `reminders.spec.ts`).
App: `flutter analyze` sem issues, **267 testes**.

**Nenhum arquivo do Flutter mudou.** O app trata `kind` como string e nunca
decide por ele: renderiza título e corpo do FCM e navega pelo `route`. Os cinco
tipos novos não exigiram nada lá, o que é a propriedade "o backend é a fonte da
verdade" se sustentando sozinha.
