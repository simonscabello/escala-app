import '../domain/event_datetime.dart';
import '../domain/event_models.dart';

/// Gera o texto da escala para WhatsApp.
///
/// **A mensagem é uma cola, não um relatório.** Quem a recebe quer duas
/// respostas num relance -- quem toca o quê e o que se canta -- e cada linha a
/// mais empurra o repertório para fora da primeira tela do celular. Por isso
/// saíram os horários dos cultos e do ensaio (quem recebe já os sabe, e quem
/// não sabe pergunta), o artista e o tom (o tom cada músico já tem na cifra, e
/// o artista nunca decidiu o que alguém ia tocar).
///
/// **Sem emoji, com negrito.** O WhatsApp formata `*assim*`, e o negrito marca
/// seção sem depender de o emoji renderizar igual em todo aparelho. A regra
/// anterior era "um emoji por seção"; o negrito faz o mesmo trabalho e ainda
/// serve dentro da linha, para destacar o que se procura: a função, quem
/// ministra, a música nova.
String buildScheduleShareText(Event event) {
  final timezone =
      event.timezone.isEmpty ? 'America/Sao_Paulo' : event.timezone;
  final buffer = StringBuffer();

  buffer.writeln(_bold('Escala de Louvor'));
  // O título só existe em culto especial ("Páscoa", "Ceia"), e aí entra entre
  // o cabeçalho e a data: é o que transforma "Domingo, 13 de setembro" numa
  // data com ocasião.
  if (event.hasTitle) {
    buffer.writeln(_bold(event.title!));
  }
  buffer.writeln(_bold(formatEventWeekdayDate(event.startsAt, timezone)));
  if (event.location?.isNotEmpty ?? false) {
    buffer.writeln(event.location!);
  }

  _writeTeam(buffer, event);
  _writeSongs(buffer, event);

  if (event.colorPalette?.isNotEmpty ?? false) {
    buffer.writeln();
    // "Roupas", e não "Paleta": quem lê a mensagem no grupo precisa entender
    // sem tradução que aquilo é o combinado de como se vestir no domingo.
    buffer.writeln('${_bold('Roupas:')} ${event.colorPalette}');
  }

  if (event.notes?.isNotEmpty ?? false) {
    buffer.writeln();
    buffer.writeln(_bold('Observações'));
    buffer.writeln(event.notes);
  }

  return buffer.toString().trimRight();
}

/// A equipe, uma linha por função.
///
/// Uma linha por função, e não uma por pessoa: numa escala de nove as duas
/// formas dizem o mesmo, mas a primeira cabe na tela e deixa o integrante
/// achar o próprio nome correndo o olho pela margem esquerda.
///
/// **Quem ministra mora dentro do Vocal.** Já está escalado ali; a linha
/// separada que existia antes repetia o nome duas vezes na mesma mensagem e
/// fazia parecer que eram duas pessoas.
void _writeTeam(StringBuffer buffer, Event event) {
  buffer.writeln();
  buffer.writeln(_bold('Equipe'));

  if (event.assignments.isEmpty) {
    buffer.writeln('Ninguém escalado ainda.');
    _writeLooseMinister(buffer, event, const {});
    return;
  }

  final curtos = _shortNames(event);
  final ministranteId = event.minister?.membershipId;
  var ministranteEscalado = false;

  for (final group in event.assignments) {
    final pessoas = <String>[];
    for (final member in group.members) {
      final linha = StringBuffer(
        curtos[member.membershipId] ?? member.displayName,
      );
      if (ministranteId != null && member.membershipId == ministranteId) {
        linha.write(' ${_bold('(Ministrante)')}');
        ministranteEscalado = true;
      }
      // O recado que o líder escreveu para aquela pessoa ("chega 8h30"): é
      // dirigido a alguém, e fora da linha dela vira aviso de ninguém.
      if (member.note?.isNotEmpty ?? false) {
        linha.write(' (${member.note})');
      }
      pessoas.add(linha.toString());
    }
    if (pessoas.isEmpty) continue;
    buffer.writeln('${_bold('${group.positionName}:')} ${_joinNames(pessoas)}');
  }

  if (!ministranteEscalado) _writeLooseMinister(buffer, event, curtos);
}

/// Quem ministra sem estar escalado em função nenhuma.
///
/// Acontece com quem só conduz: aí a linha separada volta, porque a
/// alternativa é a mensagem não dizer a quem a equipe se reporta. A regra é
/// não **repetir** o nome, não escondê-lo.
void _writeLooseMinister(
  StringBuffer buffer,
  Event event,
  Map<String, String> curtos,
) {
  final minister = event.minister;
  if (minister == null) return;
  buffer.writeln(
    '${_bold('Ministrante:')} '
    '${curtos[minister.membershipId] ?? minister.displayName}',
  );
}

/// O repertório, com uma seção por culto quando há mais de um.
///
/// Com um culto só o rótulo é "Músicas"; com dois, é o nome de cada um -- é o
/// que impede o vocalista da noite de ensaiar o repertório da manhã. O horário
/// não entra em nenhum dos dois casos: "Manhã" e "Noite" já separam as listas,
/// e a hora do culto ninguém veio procurar aqui.
///
/// **Repertório que falta é dito, e não omitido** -- quem recebe este texto
/// não tem o app para conferir, e a seção que some deixa "esqueceram de
/// mandar" e "ainda não escolheram" com a mesma cara.
///
/// **"Falta" e "é assim que fazemos" são coisas diferentes**, e é o modo de
/// repertório da escala que as separa: no culto em que as músicas saem na hora
/// a lista vazia é o combinado, e anunciá-la como pendência manda a equipe
/// esperar uma mensagem que nunca vem.
void _writeSongs(StringBuffer buffer, Event event) {
  final grupos = [
    for (final grupo in event.songsByService)
      (service: grupo.service, linhas: _songLines(grupo.songs)),
  ];
  if (grupos.isEmpty) return;

  final naHora = event.isRepertoireOnTheFly;
  final semNenhuma = grupos.every((grupo) => grupo.linhas.isEmpty);

  // Nada escolhido em culto nenhum: uma seção só. Nomear "Manhã" e "Noite"
  // aqui para dizer o mesmo dos dois lados gastaria quatro linhas com uma
  // informação só.
  if (semNenhuma) {
    buffer.writeln();
    buffer.writeln(_bold('Músicas'));
    buffer.writeln(_semRepertorio(naHora));
    return;
  }

  // Escala de repertório na hora com alguma música já escolhida acontece: o
  // ministrante deixa uma ou duas encaminhadas e resolve o resto no culto. A
  // linha diz isso antes da lista, para ninguém a receber como definitiva.
  if (naHora) {
    buffer.writeln();
    buffer.writeln('Definidas na hora. Por enquanto:');
  }

  // Daqui para baixo pelo menos um culto tem repertório, e aí o culto vazio
  // **precisa** ser nomeado: sem isso, quem canta à noite lê a lista da manhã
  // como o repertório do dia inteiro.
  final separar = grupos.length > 1;
  for (final grupo in grupos) {
    buffer.writeln();
    buffer.writeln(_bold(separar ? grupo.service.label : 'Músicas'));
    buffer.writeln();
    if (grupo.linhas.isEmpty) {
      buffer.writeln(_semRepertorio(naHora));
      continue;
    }
    // A numeração recomeça em cada culto: "a 3ª da noite" é como a equipe
    // fala, e continuar contando de 4 a 6 obrigaria a subtrair de cabeça.
    for (var i = 0; i < grupo.linhas.length; i++) {
      buffer.writeln('${i + 1}. ${grupo.linhas[i]}');
    }
  }
}

String _semRepertorio(bool naHora) =>
    naHora ? 'Definidas na hora, no culto.' : 'Ainda não escolhidas.';

/// Uma linha por música: `Nome - 314 CC (Dízimos e Ofertas)`.
///
/// Nem artista nem tom. O tom está na cifra que cada um já abre e o artista
/// nunca decidiu nada -- juntos custavam meia linha por música, e é a lista de
/// músicas que precisa caber inteira na tela.
///
/// O que entra é o que a pessoa **procura na mensagem**:
///
/// - **O hinário**, quando existe: ninguém pede "Pão da Vida", pede "142".
///   Número e sigla, porque a mesma igreja canta de mais de um livro e "208"
///   sozinho não diz qual.
/// - **O momento**, quando existe: é o que diz ao instrumentista que aquela
///   entra na oferta, e à multimídia em que ponto do culto preparar a letra.
/// - **"Nova"**, quando existe: o único recado que muda o que a pessoa faz
///   antes do domingo, que é ouvir a música durante a semana.
///
/// **Nada aparece vazio.** Sem hinário e sem momento sai só o nome, que é a
/// esmagadora maioria das linhas -- um "( )" ou um "—" em cada uma delas faria
/// a mensagem parecer um formulário por preencher.
List<String> _songLines(List<EventSong> songs) {
  final lines = <String>[];
  for (final song in songs) {
    if (song.title.isEmpty) continue;

    final linha = StringBuffer(song.title);

    // Separado por travessão curto, e não por vírgula: "314 CC" é um
    // identificador, não mais um item de uma lista de atributos.
    final hinario = song.hymnal;
    if (hinario != null) linha.write(' - ${hinario.label}');

    final momento = song.momentText;
    if (momento != null) linha.write(' ($momento)');

    if (song.isNew) linha.write(' — ${_bold('Nova')}');

    lines.add(linha.toString());
  }
  return lines;
}

/// Como a equipe chama cada um: só o primeiro nome.
///
/// É como as pessoas se tratam no grupo, e o nome completo de nove integrantes
/// enche a mensagem de sobrenome que ninguém usa. Mais partes entram **só**
/// quando dois escalados desta escala começam igual -- aí "Simon" viraria
/// adivinhação, e "Simon Lopes"/"Simon Pedro" resolvem. Esgotadas as partes
/// (dois "João Silva" existem), vai o nome como está: nada mais aqui os
/// separa.
Map<String, String> _shortNames(Event event) {
  final completos = <String, String>{};
  for (final group in event.assignments) {
    for (final member in group.members) {
      completos[member.membershipId] = member.displayName.trim();
    }
  }
  final minister = event.minister;
  if (minister != null) {
    completos.putIfAbsent(
      minister.membershipId,
      () => minister.displayName.trim(),
    );
  }

  final porPrimeiroNome = <String, List<String>>{};
  completos.forEach((id, nome) {
    porPrimeiroNome
        .putIfAbsent(_nameKey(_nameParts(nome).first), () => [])
        .add(id);
  });

  final curtos = <String, String>{};
  completos.forEach((id, nome) {
    final partes = _nameParts(nome);
    final homonimos = porPrimeiroNome[_nameKey(partes.first)]!;
    if (homonimos.length == 1) {
      curtos[id] = partes.first;
      return;
    }
    for (var n = 2; n <= partes.length; n++) {
      final prefixo = partes.take(n).toList();
      final unico = homonimos.every(
        (outro) => outro == id || !_startsWithParts(completos[outro]!, prefixo),
      );
      if (unico) {
        curtos[id] = prefixo.join(' ');
        return;
      }
    }
    curtos[id] = nome;
  });
  return curtos;
}

List<String> _nameParts(String name) {
  final partes =
      name.split(RegExp(r'\s+')).where((parte) => parte.isNotEmpty).toList();
  return partes.isEmpty ? [name] : partes;
}

bool _startsWithParts(String name, List<String> prefixo) {
  final partes = _nameParts(name);
  if (partes.length < prefixo.length) return false;
  for (var i = 0; i < prefixo.length; i++) {
    if (_nameKey(partes[i]) != _nameKey(prefixo[i])) return false;
  }
  return true;
}

String _nameKey(String value) => value.toLowerCase();

/// "Gisely, Joseane e Simon" -- vírgula até o penúltimo, "e" no último.
String _joinNames(List<String> nomes) {
  if (nomes.length < 2) return nomes.join();
  return '${nomes.sublist(0, nomes.length - 1).join(', ')} e ${nomes.last}';
}

/// Negrito do WhatsApp.
String _bold(String value) => '*$value*';
