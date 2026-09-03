# Sugestões de música — Implementation Plan

> **For agentic workers:** Steps usam checkbox (`- [ ]`) para acompanhamento.
> Backend só via Docker (`docker compose exec api ...`); Flutter nativo no
> Windows com o PATH prefixado.

**Goal:** qualquer integrante pode sugerir uma música — para o repertório em
geral ou para um domingo específico — com uma justificativa assinada; quem
monta a escala vê as sugestões daquela data na hora de montar o repertório.

**Architecture:** uma entidade (`SongSuggestion`) com data **opcional**, e não
duas. O ato no mundo real é o mesmo: alguém quer que a equipe cante uma música.
O que muda é se vem data junto — e o mesmo pedido costuma ser as duas coisas
("podíamos aprender essa; quem sabe domingo que vem"). Duas tabelas obrigariam
a inventar "promover sugestão de repertório para sugestão de data", partiriam a
contagem de repetidas em dois lugares e duplicariam status idênticos.

**Tech Stack:** NestJS 11, Prisma 6, PostgreSQL 16; Flutter + Riverpod +
go_router + Dio.

---

## Decisões de modelo — leia antes de codar

Estas quatro decisões são o plano. O resto é digitação.

### 1. A sugestão aponta para uma DATA, não para a escala

`targetDate` é `@db.Date` — dia civil, como `Unavailability`. **Não** existe
`eventId`.

O motivo é duro: o MEMBER **não enxerga escala em rascunho** (`GET /events/:id`
devolve 404 para ele, seção "Rascunho e publicação"). Na terça, quando ele
pensa "domingo dia 14", ou a escala ainda não foi criada, ou existe como
rascunho e ele não pode vê-la. Guardar `eventId` deixaria o campo impossível de
preencher justamente por quem preenche. A escala também pode ser apagada e
recriada; a data não muda.

O casamento acontece na leitura: a tela de montagem pede as sugestões cuja
`targetDate` bate com o dia civil da escala **no fuso da equipe**
(`civilDateInZone(event.startsAt, team.timezone)`).

`targetDate` nulo tem significado próprio e explícito: **"é para o repertório,
sem data"**. Não é estado indefinido — é a outra metade da funcionalidade.

### 2. Nada é deduzido: o status é dito pelo líder

A dedução tentadora é "a música apareceu no repertório daquele domingo → a
sugestão foi atendida". É a mesma armadilha que o `isNew` já pagou três vezes
(ver `Song.isNew` no schema): o líder pode ter posto a música por conta
própria, ou ter acolhido a ideia e jogado para março. Quem sabe se a sugestão
foi acolhida é o líder, e ele diz isso com um toque.

Pelo mesmo motivo, **aceitar não cria música nem liga `isNew` sozinho**. O
backend registra o acolhimento e o vínculo; quem cria a música é o líder, pela
tela de cadastro que já existe, com `isNew` marcado à mão. Automatizar isso
seria deduzir "a equipe está aprendendo" de "alguém sugeriu".

**A data passar não muda status.** Sugestão de domingo 14 que ninguém tocou
continua `PENDING` — ela só sai da lista ativa, exatamente como a agenda separa
próximas de passadas pelo começo do dia civil. Filtrar por data não é deduzir
julgamento.

### 3. `title` é sempre gravado, mesmo quando há `songId`

Denormalização de propósito, como `Event.startsAt`. Ela compra duas coisas:

- `Song` pode ser **apagada** (`DELETE /songs/:songId` só recusa quando a
  música já foi usada em escala — `SONG_IN_USE`). Com `onDelete: SetNull` no
  vínculo, a sugestão sobrevive com o texto e a justificativa assinada de
  alguém não some junto com um cadastro;
- o MEMBER **não pode criar música** (`POST /songs` é LEADER+, e o formulário
  pede tom, tipo e andamento — decisões da equipe). Sugerir precisa aceitar
  texto livre, senão a funcionalidade morre na primeira tentativa.

A regra de exibição é determinística e não deixa duas verdades: **quando há
`songId`, o título é o da música**; o texto gravado é procedência e reserva,
nunca fonte concorrente de exibição. Se o líder amarrar a música errada, o
texto original continua ali para alguém perceber.

A busca externa ajuda a maioria dos casos a já chegar amarrada: o
`GET /teams/:teamId/songs/search-external` **não tem `@TeamRoles`** (só um
throttle de 30/min), então a tela de sugerir usa a mesma busca do Spotify que o
cadastro usa.

### 4. Repetida não é erro — é o sinal

Três pessoas sugerindo a mesma música é informação que o líder quer. Não
bloqueie; conte. O que se bloqueia é a **mesma pessoa** repetindo a **mesma
música** para a **mesma data**.

Essa trava fica no service, **não** em índice único. `targetDate` e `songId`
são nuláveis, e no Postgres `NULL` é distinto de `NULL` em índice único — a
chave não travaria nada justamente nos casos sem data e sem música cadastrada.
É a mesma armadilha que fez `EventSong.serviceId` ser `NOT NULL`.

---

## Global Constraints

- Domínio e código em **inglês**; mensagens ao usuário em **português**.
  Strings de UI **sem acento**, como o resto do app (dívida conhecida — não
  conserte pontualmente).
- Sem freezed/build_runner; modelos Dart à mão.
- Erros com `{ code, message }`, como o resto do backend.
- Toda a equipe lê e cria; **OWNER/LEADER** resolve. Não-membro → 404.
- **Não criar commits** a menos que o usuário peça.
- `docs/` é copiado em `app/docs` e `backend/docs`. Este plano vive só na raiz.

## Fora do v1 — decidido, não esquecido

- **Votos / curtidas.** Transformam um canal em enquete e criam o problema de
  "a mais votada não foi escolhida". A contagem de quantas pessoas sugeriram já
  dá o sinal.
- **Comentários.** O WhatsApp já existe.
- **Relatório de engajamento.** A sugestão é assinada, então isso sai depois da
  mesma tabela com um `groupBy` e nenhuma migration.
- **Status "conversar sobre"** — o caso em que o motivo certo é uma conversa
  pessoal (teologia, por exemplo). Ideia registrada; acrescentar um valor ao
  enum depois é migration barata.
- **Notificação.** Não há push no projeto (dívida conhecida). O líder acha as
  sugestões pelo badge da Task 9 — sem ele a funcionalidade morre calada.

## File map

| Arquivo | Responsabilidade |
|---|---|
| `backend/prisma/schema.prisma` | `SongSuggestion` + `SuggestionStatus` |
| `backend/src/modules/song-suggestions/dto/song-suggestion.dto.ts` | Create / decline / accept / query |
| `backend/src/modules/song-suggestions/song-suggestions.service.ts` | Regras + Prisma + casamento por data |
| `backend/src/modules/song-suggestions/song-suggestions.controller.ts` | Rotas HTTP |
| `backend/src/modules/song-suggestions/song-suggestions.module.ts` | Wiring |
| `backend/src/app.module.ts` | Import do módulo |
| `backend/test/song-suggestions.spec.ts` | Integração |
| `app/lib/features/suggestions/domain/song_suggestion.dart` | Modelo + fromJson |
| `app/lib/features/suggestions/data/suggestion_repository.dart` | Dio + providers |
| `app/lib/features/suggestions/presentation/suggest_song_sheet.dart` | Formulário de sugerir |
| `app/lib/features/suggestions/presentation/suggestions_screen.dart` | Listagem, duas abas |
| `app/lib/features/songs/presentation/songs_screen.dart` | Entrada "Sugerir" |
| `app/lib/features/events/presentation/setlist_form_screen.dart` | Faixa + aba no seletor |
| `app/lib/features/events/presentation/main_shell.dart` | Badge de sugestões abertas |
| `app/lib/core/router/app_router.dart` | `/equipe/sugestoes` |

---

### Task 1: Schema e migration

**Files:** Modify `backend/prisma/schema.prisma`

- [x] **Step 1: Enum e modelo**

```prisma
enum SuggestionStatus {
  PENDING
  ACCEPTED
  DECLINED
}

/// Alguem da equipe pedindo que a equipe cante uma musica.
///
/// Uma entidade so, com data opcional: o ato e o mesmo, e o mesmo pedido
/// costuma ser as duas coisas ao mesmo tempo. Ver o plano
/// docs/superpowers/plans/2026-09-03-sugestoes-de-musica.md.
model SongSuggestion {
  id     String @id @default(uuid()) @db.Uuid
  teamId String @map("team_id") @db.Uuid

  /// A musica do repertorio, quando a sugestao ja corresponde a uma.
  ///
  /// Nulo enquanto ninguem cadastrou: MEMBER nao cria musica (POST /songs e
  /// LEADER+), entao sugerir precisa aceitar texto livre.
  songId String? @map("song_id") @db.Uuid

  /// O que a pessoa digitou (ou o titulo da musica no momento da sugestao).
  ///
  /// Gravado SEMPRE, inclusive com songId preenchido: a musica pode ser
  /// apagada, e a justificativa assinada de alguem nao pode sumir junto com um
  /// cadastro. Na tela, songId manda -- este texto e procedencia e reserva.
  title  String
  artist String?
  /// Um link so, do jeito que a pessoa mandou (YouTube, Spotify, cifra).
  link   String?

  /// O domingo pedido, em dia civil. NULO = "para o repertorio, sem data".
  ///
  /// Data e nao eventId: quem sugere nao enxerga escala em rascunho, e no dia
  /// em que ele pensa no domingo a escala pode nem existir.
  targetDate DateTime? @map("target_date") @db.Date

  /// Por que valeria a pena. Obrigatorio -- e o que o lider julga, e e o que
  /// torna a recusa uma resposta a um argumento e nao ao gosto de alguem.
  reason String

  status SuggestionStatus @default(PENDING)

  /// Opcional de proposito: as vezes o motivo certo (teologia, por exemplo) e
  /// uma conversa pessoal, e o app nao e o canal. Campo em branco e uso
  /// legitimo, nao esquecimento. Quem sugeriu LE este texto.
  declineReason String? @map("decline_reason")

  /// Quem resolveu. Guardado para auditoria, NAO exibido: recusa com nome do
  /// lider do lado azeda a equipe.
  resolvedById String?   @map("resolved_by") @db.Uuid
  resolvedAt   DateTime? @map("resolved_at") @db.Timestamptz(3)

  createdById String   @map("created_by") @db.Uuid
  createdAt   DateTime @default(now()) @map("created_at") @db.Timestamptz(3)
  updatedAt   DateTime @updatedAt @map("updated_at") @db.Timestamptz(3)

  team       Team        @relation(fields: [teamId], references: [id], onDelete: Cascade)
  song       Song?       @relation(fields: [songId], references: [id], onDelete: SetNull)
  createdBy  Membership  @relation("SuggestionAuthor", fields: [createdById], references: [id], onDelete: Cascade)
  resolvedBy Membership? @relation("SuggestionResolver", fields: [resolvedById], references: [id], onDelete: SetNull)

  @@index([teamId, status, targetDate])
  @@map("song_suggestions")
}
```

- [x] **Step 2: Relações inversas**

Em `Team`: `songSuggestions SongSuggestion[]`.
Em `Song`: `suggestions SongSuggestion[]`.
Em `Membership`: `suggestions SongSuggestion[] @relation("SuggestionAuthor")` e
`resolvedSuggestions SongSuggestion[] @relation("SuggestionResolver")`.

`createdBy` é `Cascade`: integrante removido do banco leva as sugestões dele. O
fluxo normal de saída da equipe é `status: REMOVED`, que não apaga nada.

- [x] **Step 3: Migration**

```
cd backend
docker compose exec api npx prisma migrate dev --name song_suggestions
```
Expected: migration criada, `prisma generate` roda, API sobe sem erro.

---

### Task 2: DTOs

**Files:** Create `backend/src/modules/song-suggestions/dto/song-suggestion.dto.ts`

- [x] **Step 1: Escrever os DTOs**

```typescript
const trim = ({ value }: { value: unknown }) =>
  typeof value === 'string' ? value.trim() : value;

export class CreateSongSuggestionDto {
  @IsOptional() @IsUUID('4')
  songId?: string;

  /// Obrigatorio mesmo com songId: e o texto que sobrevive ao apagar da
  /// musica. A tela preenche sozinha quando a pessoa escolhe do repertorio.
  @Transform(trim) @IsString() @MinLength(2) @MaxLength(160)
  title!: string;

  @Transform(trim) @IsOptional() @IsString() @MaxLength(160)
  artist?: string;

  @Transform(trim) @IsOptional() @IsUrl() @MaxLength(500)
  link?: string;

  @IsOptional() @IsISO8601({ strict: true })
  targetDate?: string;

  /// Minimo curto de proposito: obrigatorio sem minimo vira ".".
  @Transform(trim) @IsString() @MinLength(10) @MaxLength(500)
  reason!: string;
}

export class DeclineSongSuggestionDto {
  @Transform(trim) @IsOptional() @IsString() @MaxLength(500)
  reason?: string;
}

export class AcceptSongSuggestionDto {
  /// A musica que o lider acabou de cadastrar a partir desta sugestao.
  @IsOptional() @IsUUID('4')
  songId?: string;
}

export class ListSongSuggestionsQueryDto {
  @IsOptional() @IsIn(['open', 'closed'])
  scope?: 'open' | 'closed';
}
```

`MinLength(10)` no `reason` — a mensagem em português deve explicar, não só
recusar: `'Escreva um pouco mais sobre por que essa musica valeria.'`

---

### Task 3: Service

**Files:** Create `backend/src/modules/song-suggestions/song-suggestions.service.ts`

Reusar `toDateOnly` / `toDateKey` de `unavailabilities.service.ts` (copiar as
duas funções; são cinco linhas e o módulo não deve depender do outro),
`civilDateInZone` de `common/timezone.ts` e `avatarUrl` de
`modules/users/public-user.ts`.

- [x] **Step 1: `list(teamId, scope)`**

Dois escopos, espelhando "próximas/passadas" da agenda:

- `open` (padrão) → `PENDING` **e** (`targetDate >= hoje` **ou**
  `targetDate IS NULL`). Ordem: sem data por último; com data, a mais próxima
  primeiro; empate pelo `createdAt`.
- `closed` → o resto: resolvidas, e as pendentes cuja data já passou.

"Hoje" é o começo do dia civil **no fuso da equipe**, lido de
`team.timezone` — o mesmo corte de `EventsService.list`, e pelo mesmo motivo.

- [x] **Step 2: `toPublic(row, allInTeam)`**

```typescript
{
  id, songId,
  // songId manda; o texto gravado e reserva.
  title: row.song?.title ?? row.title,
  artist: row.song?.artist ?? row.artist,
  link: row.link,
  targetDate: row.targetDate ? toDateKey(row.targetDate) : null,
  reason: row.reason,
  status: row.status,
  declineReason: row.declineReason,
  // Se a musica ja esta no repertorio ativo -- muda o que o lider faz com a
  // sugestao (so programar x cadastrar antes).
  inRepertoire: !!row.song && !row.song.isArchived,
  createdBy: {
    membershipId: row.createdById,
    displayName: row.createdBy.displayName,
    avatarUrl: avatarUrl(row.createdBy.user?.avatarPath),
  },
  createdAt: row.createdAt.toISOString(),
  // Quem MAIS pediu a mesma coisa. Repetida e sinal, nao erro.
  alsoSuggestedBy: string[],
}
```

`alsoSuggestedBy` é agrupado **em memória** sobre as sugestões abertas da
equipe, pela chave `songId ?? title.toLowerCase()`. São dezenas de linhas, não
milhares; um `groupBy` no banco custaria mais código do que resolve. Não
inclui o próprio autor.

- [x] **Step 3: `create(teamId, actor, dto)`**

1. `targetDate` no passado (comparado ao dia civil do fuso da equipe) →
   400 `DATE_IN_THE_PAST`, mensagem `'Escolha uma data que ainda vai chegar.'`
2. Se veio `songId`: a música tem que ser **desta equipe** — senão 400
   `INVALID_SONG` (os ids vêm do cliente, e um id válido de outro lugar passa
   pela validação de formato). Mesma regra do `PUT /events/:id/songs`.
3. Trava de repetição: mesma pessoa (`createdById = actor.id`) + mesma música
   (`songId`, ou `title` insensitive quando não há id) + mesma `targetDate` +
   `status: PENDING` → 409 `SUGGESTION_ALREADY_EXISTS`, mensagem
   `'Voce ja sugeriu essa musica para esta data.'` **No service, não em índice
   único** — ver decisão 4.
4. Grava e devolve a sugestão pública.

- [x] **Step 4: `accept` / `decline` / `reopen`**

Todas carregam a linha por `{ id, teamId }` (404 se não achar) e gravam
`resolvedById = actor.id`, `resolvedAt = now()`.

- `accept(dto)`: se veio `songId`, valida que é da equipe e amarra. `title`
  **não** é reescrito.
- `decline(dto)`: grava `declineReason ?? null`.
- `reopen()`: volta a `PENDING`, limpa `declineReason`, `resolvedById` e
  `resolvedAt`. Existe para o toque errado não virar beco sem saída.

Resolver o que já está resolvido não é erro — grava por cima. O líder muda de
ideia, e um 409 aqui só faria a tela ter que tratar um caso sem consequência.

- [x] **Step 5: `remove(teamId, id, actor)`**

Autor apaga a própria; LEADER+ apaga qualquer uma. MEMBER em sugestão alheia →
403. Espelha `UnavailabilitiesService.remove`.

- [x] **Step 6: `forEvent(eventId)`**

```typescript
// PENDING apenas, em duas listas:
{ date: 'YYYY-MM-DD', forDate: [...], undated: [...] }
```

`date` é `civilDateInZone(event.startsAt, team.timezone)` — `startsAt` já é o
culto mais cedo da escala, mantido pelo service.

Duas listas numa chamada só: a faixa da tela mostra `forDate`, e a aba do
seletor mostra as duas. Uma requisição, duas leituras.

- [x] **Step 7: Typecheck**

Run: `docker compose exec api npx tsc --noEmit -p tsconfig.json` → sem erros.

---

### Task 4: Controller, módulo e wiring

**Files:** Create controller e module; modify `backend/src/app.module.ts`

- [x] **Step 1: Rotas da equipe**

```
@Controller('teams/:teamId/song-suggestions')
@UseGuards(TeamMemberGuard)

GET    /                 list(teamId, query)             toda a equipe
POST   /                 create(teamId, @CurrentMembership, dto)   toda a equipe
DELETE /:id              remove — 204                    autor ou LEADER+
POST   /:id/accept       @TeamRoles('OWNER','LEADER')
POST   /:id/decline      @TeamRoles('OWNER','LEADER')
POST   /:id/reopen       @TeamRoles('OWNER','LEADER')
```

- [x] **Step 2: Rota da escala**

```
@Controller('events/:eventId/song-suggestions')
@UseGuards(TeamMemberGuard)

@TeamRoles('OWNER','LEADER')
GET / → forEvent(eventId)
```

Rota própria, e **não** um campo em `GET /events/:id`: o detalhe da escala é a
tela mais pesada do app e já deixa de carregar letra e músicas na listagem de
propósito (seção "Repertório dentro da escala"). Quem paga por esta consulta é
só quem abriu a montagem do repertório. O `TeamMemberGuard` já resolve o
`teamId` a partir de `:eventId`.

- [x] **Step 3: Registrar `SongSuggestionsModule` em `app.module.ts`**

- [x] **Step 4: `curl` de cada regra, inclusive os erros**

Com `samuel@teste.com` (OWNER) e `maria@teste.com` (MEMBER), conforme AGENTS.md:

- MEMBER cria sugestão sem data e com data → 201
- MEMBER cria com `reason` de 3 letras → 400
- MEMBER cria com `targetDate` de ontem → 400 `DATE_IN_THE_PAST`
- MEMBER repete a mesma → 409 `SUGGESTION_ALREADY_EXISTS`
- OWNER sugere a mesma música → 201, e `alsoSuggestedBy` aparece nas duas
- MEMBER tenta `accept` → 403
- MEMBER apaga sugestão do OWNER → 403; a própria → 204
- OWNER `decline` sem motivo → 200, `declineReason: null`
- OWNER `reopen` → volta a `PENDING`
- `songId` de outra equipe → 400 `INVALID_SONG`
- `GET /events/:id/song-suggestions` com sugestão para a data da escala →
  aparece em `forDate`; sem data → aparece em `undated`
- `scope=closed` traz a de data passada; `open` não

---

### Task 5: Testes de integração

**Files:** Create `backend/test/song-suggestions.spec.ts`

- [x] **Step 1: Cobrir o que quebra calado**

Seguir a forma dos specs existentes (AppModule inteiro, `ctx.tokenFor`, banco
`louvor_test`). Casos: isolamento entre equipes (sugestão de uma equipe não
aparece na outra), os 403 de MEMBER em `accept`/`decline` e em apagar sugestão
alheia, a trava de repetição, `scope=open` excluindo data passada, o casamento
por data em `forEvent` **com fuso não-UTC na equipe** e `alsoSuggestedBy`.

O caso do fuso é o que mais tem chance de estar errado sem ninguém notar: um
domingo às 08:30 em `America/Sao_Paulo` é sábado 11:30 em UTC.

- [x] **Step 2:** `docker compose exec api npm test` → verde.

---

---

## Registro de execução — backend (Tasks 1–5, feitas)

Migration: `20260903181743_song_suggestions`.

**Um desvio do plano:** `accept`, `decline` e `reopen` respondem **200**, não o
201 padrão do `@Post` do Nest. O projeto já reserva 201 para criação e usa
`@HttpCode(HttpStatus.OK)` no `publish`/`unpublish` da escala, que são o mesmo
tipo de rota — ação sobre um recurso que já existe.

Verificado: `tsc` limpo nos dois tsconfig; 7 rotas no log do Nest; 33 checagens
de `curl` (incluindo todos os erros); 14 testes de integração novos; suíte
inteira em 124 testes, 11 arquivos, verde.

Sobraram no banco de trabalho 3 sugestões realistas de propósito, para as telas
das Tasks 6–10 terem o que mostrar: uma aceita e amarrada, e duas pessoas
pedindo a mesma música para o mesmo domingo (exercita `alsoSuggestedBy`).

### Task 6: App — modelo, repositório e providers

**Files:** Create `app/lib/features/suggestions/domain/song_suggestion.dart`,
`app/lib/features/suggestions/data/suggestion_repository.dart`

- [x] **Step 1: Modelo à mão** — `SongSuggestion` com `fromJson`, e um enum
  `SuggestionStatus` com `fromJson` tolerante (valor desconhecido → `pending`,
  para app antigo não quebrar quando o enum crescer).

- [x] **Step 2: Repositório** no padrão de `song_repository.dart`: `Dio`,
  `_guard`, e providers Riverpod —
  `suggestionsProvider(SuggestionQuery(teamId, scope))`,
  `eventSuggestionsProvider(eventId)`.

---

### Task 7: App — tela de sugerir

**Files:** Create `app/lib/features/suggestions/presentation/suggest_song_sheet.dart`

Folha (`showModalBottomSheet` + `DraggableScrollableSheet`), como o seletor de
músicas. Três passos numa tela só:

- [x] **Step 1: Qual música**

Busca no repertório (`songsProvider`) e, abaixo, busca externa
(`GET .../songs/search-external`, liberada para a equipe inteira). Escolher do
repertório preenche `songId` **e** `title`/`artist`. Terceiro caminho:
"Nao achei — digitar" abre título, artista e link à mão.

- [x] **Step 2: Data (opcional)**

Um `SwitchListTile` "E para um domingo especifico?" e, ligado, um date picker.
Desligado é o padrão — a maioria das sugestões é para o repertório.

- [x] **Step 3: Justificativa (obrigatória), com o rótulo variando pela data**

```dart
final label = _data == null
    ? 'Por que vale a pena a equipe aprender essa musica?'
    : 'Por que essa musica nesse domingo?';
```

Custa um `if` e evita a pergunta errada: se a música **já é** do repertório e
alguém a pede para o domingo 14, "por que entrar no repertório" não faz
sentido — ela já entrou. Validação local espelhando o `MinLength(10)`, para o
erro não precisar de ida ao servidor.

- [x] **Step 4:** Ao salvar, `ref.invalidate` dos providers de sugestão e
  snackbar `'Sugestao enviada.'`.

---

### Task 8: App — listagem

**Files:** Create `app/lib/features/suggestions/presentation/suggestions_screen.dart`;
modify `app/lib/core/router/app_router.dart`

- [x] **Step 1: Rota** `/equipe/sugestoes` dentro da casca, com
  `_withActiveTeam`, ao lado de `/equipe/musicas`.

- [x] **Step 2: `AppChoiceBar` com duas abas** — "Abertas" (`open`) e
  "Encerradas" (`closed`), na forma que o Repertório já usa.

- [x] **Step 3: O card de cada sugestão**

Título e artista; nome e foto de quem sugeriu; a justificativa inteira (não
truncada — ela é o conteúdo); a data pedida como etiqueta, ou "Para o
repertorio" quando não há; `alsoSuggestedBy` como "Maria e Joao tambem
sugeriram"; e "Ja esta no repertorio" quando `inRepertoire`.

- [x] **Step 4: Ações do LEADER+ no card**

`Aceitar` / `Por enquanto nao` / `Excluir`. MEMBER vê só `Excluir` na própria.

**"Por enquanto nao", nunca "Recusar"** — e o campo de motivo abre **opcional**,
sem texto empurrando o líder a escrever, com o rótulo dizendo em quem ele cai:

```
Motivo (opcional) — quem sugeriu vai ler
```

Esse rótulo não é enfeite: sem ele um líder escreve "letra com teologia
duvidosa" achando que é nota interna, e o app entrega na cara da pessoa. É um
estrago que não dá para desfazer.

Recusa sem motivo aparece **só como o estado**, sem rótulo "Motivo:" pendurado
no vazio. Quem recusou **não** aparece em lugar nenhum da tela.

- [x] **Step 5: Aceitar, quando a música ainda não existe**

Sugestão com `songId == null`: `Aceitar` abre o `AddSongScreen` por
`Navigator.push` (o mesmo caminho da montagem da escala, com `onCreated`),
pré-preenchido com título, artista e link, **e com `isNew` marcado por
padrão** — mas marcado na tela, para o líder confirmar ou desmarcar. Voltando,
chama `accept({ songId })`.

Ligar `isNew` no servidor seria deduzir "a equipe está aprendendo" de "alguém
sugeriu". A marca é julgamento humano e mora na música — ver `Song.isNew`.

Com `songId` já preenchido, `Aceitar` chama a rota direto.

---

### Task 9: App — entradas e badge

**Files:** Modify `songs_screen.dart`, `main_shell.dart`

- [x] **Step 1:** Botão "Sugerir musica" no Repertório, visível para **toda a
  equipe** — é a tela onde se pensa em música. Abre a folha da Task 7.

- [x] **Step 2:** Item "Sugestoes da equipe" em `Gerenciar equipe`, ao lado de
  "Uso do repertorio".

- [x] **Step 3:** Badge com a contagem de abertas no item de menu, para
  LEADER+. Sem push no projeto, **é isto que faz o líder descobrir que há
  sugestão** — sugestão que ninguém vê é sugestão que ninguém faz duas vezes.
  Usar o `suggestionsProvider(open)` que a listagem já busca.

---

### Task 10: App — sugestões dentro da montagem do repertório

**Files:** Modify `app/lib/features/events/presentation/setlist_form_screen.dart`

Esta é a razão da funcionalidade existir. As outras telas alimentam esta.

- [x] **Step 1: A faixa**

No topo da tela de repertório, acima dos cultos: "3 sugestoes da equipe para
este domingo", de `eventSuggestionsProvider(eventId).forDate`. Recolhida por
padrão quando a escala já tem repertório; aberta quando está vazia. Some
quando não há sugestão — sem estado vazio ocupando o topo da tela.

Cada linha: título, quem sugeriu, a justificativa, e um botão que **põe a
música no culto** (o mesmo `_novoItem`). Com mais de um culto, o botão pergunta
em qual — a tela já sabe fazer isso.

- [x] **Step 2: Sugestão de música que ainda não existe**

Botão "Cadastrar" na linha, que abre o `_cadastrarMusica()` que já existe,
pré-preenchido. Voltando, entra no culto **e** chama `accept({ songId })`.

- [x] **Step 3: A aba no seletor**

Quarta opção no `AppChoiceBar` do `_SongPicker`: `Canticos | Hinos | Novas |
Sugeridas`. "Sugeridas" lista `forDate` + `undated` que já tenham `songId`
(as sem cadastro não têm o que selecionar; elas ficam na faixa).

- [x] **Step 4: Pôr no culto NÃO aceita a sugestão**

De propósito. O líder pode estar experimentando, e a escala ainda é rascunho.
Quem diz que a sugestão foi acolhida é o botão `Aceitar` — e é por isso que ele
também está na faixa, ao lado. Deduzir o acolhimento de "a música entrou" é
exatamente a armadilha da decisão 2.

---


## Registro de execução — app (Tasks 6–10, feitas)

Verificado: `flutter analyze` sem nada; **202 testes** verdes (196 que já
existiam, mais 6 novos do modelo da sugestão); build web e APK release
compilam; app servido em `build/web` contra o backend local carrega sem
nenhum erro de console.

**Quatro desvios do plano, todos deliberados:**

1. **A entrada não foi para "Gerenciar equipe".** O plano mandava pôr
   "Sugestões" ao lado de "Uso do repertório", mas o comentário de
   `manage_team_screen.dart` registra que **o Repertório foi tirado dali**
   justamente porque aquela tela só se alcança pela engrenagem de líder — e o
   integrante ficava sem caminho. Sugerir é da equipe inteira, então a entrada
   foi para a **aba Equipe**, ao lado do Repertório, e para a barra lateral da
   Web. O selo de contagem continua só para quem pode responder.

2. **A aba "Sugeridas" no seletor virou uma seção da faixa.** O
   `_SongPicker` carrega uma armadilha documentada (a versão que escondia os
   581 hinos por construir a `SongQuery` sem `filter`), e um quarto chip pedia
   remexer no estado dele. As sugestões **sem data** entraram como um segundo
   grupo dentro da própria faixa — mesma capacidade, no mesmo lugar, sem tocar
   no seletor.

3. **Strings de UI com acento.** A restrição do plano veio da dívida "strings
   sem acento" do `AGENTS.md`, que está **desatualizada**: o código novo
   (`songs_screen`, `setlist_form_screen`, `song_models`) usa acento em tudo
   que o usuário lê. Segui o código, não a nota.

4. **Um botão por papel no Repertório**, em vez de acrescentar mais um. Para
   quem lidera a ação principal continua "Adicionar" e "Sugerir" vai para o
   cabeçalho; para o integrante — que não tinha ação nenhuma naquela tela — o
   botão flutuante é "Sugerir".

**Duas mudanças fora dos arquivos previstos:**

- `AddSongScreen` ganhou `initialSearch`: aceitar uma sugestão sem cadastro
  abre o cadastro com o nome já buscado, em vez de fazer o líder digitar de
  novo o que quem sugeriu já digitou. O `isNew` daquela tela já nascia marcado,
  então "pré-marcado mas confirmável" saiu de graça.
- `test/setlist_new_song_test.dart` precisou de um `override` de
  `eventSuggestionsProvider`: a tela agora vai à rede pela faixa, e sem o dublê
  o teste falhava por timer pendente — por um motivo que nada tem a ver com a
  etiqueta "Nova" que ele verifica.

**Não verificado:** as telas novas com olho humano. O APK release compila e o
site local sobe sem erro, mas ninguém abriu Sugestões, a folha de sugerir nem a
faixa dentro da montagem do repertório numa sessão autenticada.

### Task 11: Verificação final

- [x] **Step 1: Backend**

```
cd backend
docker compose exec api npx tsc --noEmit -p tsconfig.json
docker compose exec api npm test
```

- [x] **Step 2: App**

```
$env:PATH = 'C:\Users\Acer\flutter\bin;' + $env:PATH
cd app
flutter analyze          # "No issues found!"
flutter test
flutter build web --release --dart-define=API_BASE_URL=https://backend-production-b304.up.railway.app
flutter build apk --release --dart-define=API_BASE_URL=https://backend-production-b304.up.railway.app
```

- [x] **Step 3: `AGENTS.md`**

Seção nova "Sugestões da equipe", depois de "Repertório dentro da escala", com
as quatro decisões de modelo. Atualizar "Estado atual" e tirar o item
correspondente das dívidas se couber. Copiar para `app/AGENTS.md` e
`backend/AGENTS.md`.

- [x] **Step 4: Relatório**

Listar o que passou e **o que não foi verificado** — em especial a UI no
emulador, que é lento e não confiável para toque automatizado.

---


## Registro de execução — documentação (Task 11, feita)

Seção `## Sugestões da equipe` inserida antes de "Vocabulário" nos **três**
`AGENTS.md`. Atenção: `backend/AGENTS.md` era cópia byte a byte da raiz (e foi
recopiado), mas **`app/AGENTS.md` divergiu** — tem 129 linhas próprias, entre
elas a direção visual "programa impresso" e o detalhamento do `isNew`. Ele foi
editado no lugar, e não sobrescrito; copiar a raiz por cima apagaria essas
seções.

Duas correções de conteúdo velho, feitas na frase que eu já estava editando:

- "Estado atual" listava **testes automatizados do backend** como não feitos.
  A suíte existe há tempo (11 arquivos, 124 testes) e tem seção própria no
  mesmo documento. Saiu da lista.
- A frase de cobertura da suíte ganhou as sugestões, com o caso do fuso
  nomeado.

Portões finais, todos verdes: `tsc` nos dois tsconfig; 124 testes de backend;
`flutter analyze` sem nada; 202 testes de app; build web e APK release.

`build/web` foi **rebuildado apontando para o Railway** ao final: durante a
verificação visual ele estava apontando para `localhost:3000`, e deixar isso no
lugar do artefato de publicação seria uma armadilha silenciosa. Conferido no
bundle: zero ocorrências de `localhost:3000`.

## Self-review (decisões vs tasks)

| Decisão | Task |
|---|---|
| Uma entidade, data opcional | 1 |
| Data civil e não `eventId` | 1, 3 (Step 6) |
| Justificativa obrigatória, rótulo pela data | 2, 7 |
| Motivo de recusa opcional, autor lê, líder oculto | 1, 3, 8 |
| Assinada, sem relatório | 3 (Step 2), 8 |
| Repetida conta, não bloqueia; trava no service | 3 (Steps 2–3) |
| `title` sempre gravado | 1, 3 |
| Aceitar não liga `isNew` sozinho | 8 (Step 5), 10 (Step 4) |
| Pôr no culto não aceita | 10 (Step 4) |
| Líder encontra as sugestões | 9 (Step 3), 10 (Step 1) |

Sem placeholders TBD. O único ponto deixado em aberto de propósito é o status
"conversar sobre", registrado em "Fora do v1".
