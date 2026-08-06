import '../domain/event_datetime.dart';
import '../domain/event_models.dart';

/// Gera o texto da escala para WhatsApp (sem markdown).
String buildScheduleShareText(Event event) {
  final timezone =
      event.timezone.isEmpty ? 'America/Sao_Paulo' : event.timezone;
  final buffer = StringBuffer();

  buffer.writeln('🎵 ${event.title}');
  buffer.writeln(
    '📅 ${formatEventWeekdayDate(event.startsAt, timezone)}',
  );
  buffer.writeln('⏰ Culto às ${formatEventTime(event.startsAt, timezone)}');

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

List<String> _songLines(List<Object?> songs) {
  final lines = <String>[];
  for (final raw in songs) {
    if (raw is! Map) continue;
    final title = raw['title']?.toString() ?? raw['songTitle']?.toString();
    if (title == null || title.isEmpty) continue;
    final artist = raw['artist']?.toString();
    final key = raw['keyOverride']?.toString() ?? raw['defaultKey']?.toString();
    final parts = <String>[title];
    if (artist != null && artist.isNotEmpty) {
      parts.add('— $artist');
    }
    if (key != null && key.isNotEmpty) {
      parts.add('($key)');
    }
    lines.add(parts.join(' '));
  }
  return lines;
}
