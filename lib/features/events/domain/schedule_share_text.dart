import '../../team/domain/position_visuals.dart';
import '../domain/event_datetime.dart';
import '../domain/event_models.dart';

/// Gera o texto da escala para WhatsApp (sem markdown).
String buildScheduleShareText(Event event) {
  final timezone =
      event.timezone.isEmpty ? 'America/Sao_Paulo' : event.timezone;
  final buffer = StringBuffer();

  // O título só existe em culto especial ("Páscoa"). Sem ele, a data abre o
  // texto sozinha -- repetir "Domingo" acima de "Domingo, 9 de agosto" não
  // dizia nada a quem recebe.
  if (event.hasTitle) {
    buffer.writeln('🎵 ${event.title}');
  }
  buffer.writeln(
    '📅 ${formatEventWeekdayDate(event.startsAt, timezone)}',
  );
  // Uma linha por culto. Com dois, quem recebe precisa ver os dois horários --
  // é a mesma equipe servindo de manhã e à noite.
  for (final service in event.displayServices) {
    buffer.writeln(
      '⏰ ${service.label} às ${formatEventTime(service.startsAt, timezone)}',
    );
  }

  if (event.rehearsalAt != null) {
    buffer.writeln(
      '🎤 Ensaio: ${formatEventWeekdayDate(event.rehearsalAt!, timezone)} '
      'às ${formatEventTime(event.rehearsalAt!, timezone)}',
    );
  } else {
    // Dito explicitamente: o convidado que recebe este texto não tem o app
    // para conferir, e a ausência da linha seria ambígua.
    buffer.writeln('🎤 Sem ensaio');
  }

  if (event.location?.isNotEmpty ?? false) {
    buffer.writeln('📍 ${event.location}');
  }

  buffer.writeln();
  // Antes da equipe: quem recebe o texto precisa saber a quem se reportar
  // antes de procurar o próprio nome na lista.
  if (event.minister != null) {
    buffer.writeln('🎙️ Ministrante: ${event.minister!.displayName}');
    buffer.writeln();
  }
  buffer.writeln('👥 Equipe');

  if (event.assignments.isEmpty) {
    buffer.writeln('Ninguém escalado ainda.');
  } else {
    for (final group in event.assignments) {
      buffer.writeln();
      // Emoji e nao icone: quem recebe le no WhatsApp, fora do app. E o mesmo
      // vocabulario que o resto deste texto ja usa (🎵 📅 ⏰).
      buffer.writeln(
        '${PositionVisuals.emoji(group.positionName)} ${group.positionName}:',
      );
      for (final member in group.members) {
        final note =
            (member.note?.isNotEmpty ?? false) ? ' (${member.note})' : '';
        buffer.writeln('• ${member.displayName}$note');
      }
    }
  }

  final songLines = _songLines(event.songs);
  if (songLines.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('🎶 Músicas');
    for (var i = 0; i < songLines.length; i++) {
      buffer.writeln('${i + 1}. ${songLines[i]}');
    }
  }

  if (event.colorPalette?.isNotEmpty ?? false) {
    buffer.writeln();
    buffer.writeln('🎨 Paleta: ${event.colorPalette}');
  }

  if (event.notes?.isNotEmpty ?? false) {
    buffer.writeln();
    buffer.writeln('📝 Observações');
    buffer.writeln(event.notes);
  }

  return buffer.toString().trimRight();
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
