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
    buffer.writeln('Paleta: ${event.colorPalette}');
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
void _writeSongs(StringBuffer buffer, Event event, String timezone) {
  final grupos = event.songsByService
      .where((grupo) => _songLines(grupo.songs).isNotEmpty)
      .toList();
  if (grupos.isEmpty) return;

  buffer.writeln();
  buffer.writeln('🎶 Músicas');

  final separar = grupos.length > 1;
  for (final grupo in grupos) {
    if (separar) {
      buffer.writeln();
      buffer.writeln(
        '${grupo.service.label} '
        '${formatEventTime(grupo.service.startsAt, timezone)}',
      );
    }
    // A numeração recomeça em cada culto: "a 3ª da noite" é como a equipe
    // fala, e continuar contando de 4 a 6 obrigaria a subtrair de cabeça.
    final linhas = _songLines(grupo.songs);
    for (var i = 0; i < linhas.length; i++) {
      buffer.writeln('${i + 1}. ${linhas[i]}');
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
    lines.add(parts.join(' '));
  }
  return lines;
}
