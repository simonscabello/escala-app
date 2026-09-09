import '../domain/event_datetime.dart';
import '../domain/event_models.dart';

/// Gera o texto da escala para WhatsApp (sem markdown).
///
/// **Emoji marca seção, nunca linha.** A versão anterior punha um em cada
/// horário, no ensaio, no local, no ministrante e em cada função — numa escala
/// com seis funções davam quinze numa mensagem só, e o que deveria guiar o
/// olho virava ruído. Sobraram três, um por bloco que se procura: a equipe, as
/// músicas e as observações. O cabeçalho não precisa de nenhum, porque é a
/// primeira coisa que se lê.
String buildScheduleShareText(Event event) {
  final timezone =
      event.timezone.isEmpty ? 'America/Sao_Paulo' : event.timezone;
  final buffer = StringBuffer();

  // O título só existe em culto especial ("Páscoa"). Sem ele, a data abre o
  // texto sozinha -- repetir "Domingo" acima de "Domingo, 9 de agosto" não
  // dizia nada a quem recebe.
  if (event.hasTitle) {
    buffer.writeln(event.title);
  }
  buffer.writeln(formatEventWeekdayDate(event.startsAt, timezone));
  // Uma linha por culto. Com dois, quem recebe precisa ver os dois horários --
  // é a mesma equipe servindo de manhã e à noite.
  for (final service in event.displayServices) {
    buffer.writeln(
      '${service.label} às ${formatEventTime(service.startsAt, timezone)}',
    );
  }

  if (event.rehearsalAt != null) {
    buffer.writeln(
      'Ensaio: ${formatEventWeekdayDate(event.rehearsalAt!, timezone)} '
      'às ${formatEventTime(event.rehearsalAt!, timezone)}',
    );
  } else {
    // Dito explicitamente: o convidado que recebe este texto não tem o app
    // para conferir, e a ausência da linha seria ambígua.
    buffer.writeln('Sem ensaio');
  }

  if (event.location?.isNotEmpty ?? false) {
    buffer.writeln(event.location);
  }

  buffer.writeln();
  // Antes da equipe: quem recebe o texto precisa saber a quem se reportar
  // antes de procurar o próprio nome na lista.
  if (event.minister != null) {
    buffer.writeln('Ministrante: ${event.minister!.displayName}');
    buffer.writeln();
  }
  buffer.writeln('👥 Equipe');

  if (event.assignments.isEmpty) {
    buffer.writeln('Ninguém escalado ainda.');
  } else {
    for (final group in event.assignments) {
      buffer.writeln();
      buffer.writeln('${group.positionName}:');
      for (final member in group.members) {
        final note =
            (member.note?.isNotEmpty ?? false) ? ' (${member.note})' : '';
        buffer.writeln('• ${member.displayName}$note');
      }
    }
  }

  _writeSongs(buffer, event, timezone);

  if (event.colorPalette?.isNotEmpty ?? false) {
    buffer.writeln();
    // "Roupas", e não "Paleta": quem lê a mensagem no grupo precisa entender
    // sem tradução que aquilo é o combinado de como se vestir no domingo.
    buffer.writeln('Roupas: ${event.colorPalette}');
  }

  if (event.notes?.isNotEmpty ?? false) {
    buffer.writeln();
    buffer.writeln('📝 Observações');
    buffer.writeln(event.notes);
  }

  return buffer.toString().trimRight();
}

/// O repertório, com uma seção por culto quando há mais de um.
///
/// Com um culto só, o rótulo não entra: a linha "Culto às 09:00" já está lá
/// em cima e repeti-la sobre a única lista de músicas seria ruído numa
/// mensagem que se lê no celular. Com dois, o rótulo é o que impede o
/// vocalista da noite de ensaiar o repertório da manhã.
///
/// **Repertório que falta é dito, e não omitido** -- pela mesma razão do
/// "Sem ensaio" lá em cima: quem recebe este texto não tem o app para
/// conferir, e a seção que some deixa "esqueceram de mandar" e "ainda não
/// escolheram" com a mesma cara. Antes isso não aparecia porque a escala só
/// era publicada com todos os cultos montados; agora ela vai para a equipe com
/// as músicas em aberto de propósito, e este virou o caso normal.
///
/// **"Falta" e "é assim que fazemos" são coisas diferentes**, e é o modo de
/// repertório da escala que as separa: no culto em que as músicas saem na hora
/// a lista vazia é o combinado, e anunciá-la como pendência manda a equipe
/// esperar uma mensagem que nunca vem.
void _writeSongs(StringBuffer buffer, Event event, String timezone) {
  final grupos = [
    for (final grupo in event.songsByService)
      (service: grupo.service, linhas: _songLines(grupo.songs)),
  ];
  if (grupos.isEmpty) return;

  buffer.writeln();
  buffer.writeln('🎶 Músicas');

  // Repertório definido na hora: a lista vazia é o combinado, e "ainda não
  // escolhidas" diria que falta alguma coisa. A frase é a mesma que a equipe
  // usa ("as músicas a gente define na hora"), e é o que quem recebe precisa
  // ler para não ficar esperando uma segunda mensagem.
  final naHora = event.isRepertoireOnTheFly;
  final semNenhuma = grupos.every((grupo) => grupo.linhas.isEmpty);

  // Nada escolhido em culto nenhum: uma linha só. Repetir "Manhã" e "Noite"
  // aqui para dizer o mesmo dos dois lados devolveria os horários que já
  // estão no topo da mensagem.
  if (semNenhuma) {
    buffer.writeln(
      naHora ? 'Definidas na hora, no culto.' : 'Ainda não escolhidas.',
    );
    return;
  }

  // Escala de repertório na hora com alguma música já escolhida acontece: o
  // ministrante deixa uma ou duas encaminhadas e resolve o resto no culto. A
  // linha diz isso antes da lista, para ninguém a receber como definitiva.
  if (naHora) {
    buffer.writeln('Definidas na hora. Por enquanto:');
  }

  // Daqui para baixo pelo menos um culto tem repertório, e aí o culto vazio
  // **precisa** ser nomeado: sem isso, quem canta à noite lê a lista da manhã
  // como o repertório do dia inteiro.
  final separar = grupos.length > 1;
  for (final grupo in grupos) {
    if (separar) {
      buffer.writeln();
      buffer.writeln(
        '${grupo.service.label} '
        '${formatEventTime(grupo.service.startsAt, timezone)}',
      );
    }
    if (grupo.linhas.isEmpty) {
      buffer.writeln(
        naHora ? 'Definidas na hora, no culto.' : 'Ainda não escolhidas.',
      );
      continue;
    }
    // A numeração recomeça em cada culto: "a 3ª da noite" é como a equipe
    // fala, e continuar contando de 4 a 6 obrigaria a subtrair de cabeça.
    for (var i = 0; i < grupo.linhas.length; i++) {
      buffer.writeln('${i + 1}. ${grupo.linhas[i]}');
    }
  }
}

List<String> _songLines(List<EventSong> songs) {
  final lines = <String>[];
  for (final song in songs) {
    if (song.title.isEmpty) continue;

    final parts = <String>[song.title];
    if (song.artist != null && song.artist!.isNotEmpty) {
      parts.add('— ${song.artist}');
    }
    // O tom já vem resolvido: o desta escala quando existe, senão o da
    // equipe. É a informação que o músico procura no grupo do WhatsApp.
    if (song.key != null && song.key!.isNotEmpty) {
      parts.add('(${song.key})');
    }
    // No fim da linha e em palavra, não em emoji: a regra desta mensagem é um
    // emoji por seção, e um "🆕" por música devolveria o ruído que o cabeçalho
    // 🎶 existe para evitar. Depois do tom porque é o tom que o músico procura
    // primeiro; "nova" é recado, e recado se lê no fim.
    if (song.isNew) {
      parts.add('(nova)');
    }
    lines.add(parts.join(' '));
  }
  return lines;
}
