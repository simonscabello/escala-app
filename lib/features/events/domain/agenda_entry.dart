import '../../../core/date/civil_date.dart';
import 'event_datetime.dart';
import 'event_models.dart';

/// Projeção de leitura: cada horário ocupa seu dia no calendário. Mantém a
/// escala como destino, sem transformar cultos em novas entidades de domínio.
class AgendaEntry {
  const AgendaEntry({required this.event, required this.service});

  final Event event;
  final EventService service;

  String get id => '${event.id}/${service.id}';
  DateTime get startsAt => service.startsAt;
  String get timezone =>
      event.timezone.isEmpty ? 'America/Sao_Paulo' : event.timezone;
  DateTime get day {
    final local = eventLocalTime(startsAt, timezone);
    return DateTime(local.year, local.month, local.day);
  }

  String get title => event.hasTitle ? event.title! : service.label;
}

List<AgendaEntry> agendaEntries(Iterable<Event> events) {
  final unique = {for (final event in events) event.id: event};
  return [
    for (final event in unique.values)
      for (final service in event.displayServices)
        AgendaEntry(event: event, service: service),
  ]..sort((a, b) {
      final time = a.startsAt.compareTo(b.startsAt);
      return time == 0 ? a.id.compareTo(b.id) : time;
    });
}

Map<String, List<AgendaEntry>> groupAgendaEntries(List<AgendaEntry> entries) {
  final groups = <String, List<AgendaEntry>>{};
  for (final entry in entries) {
    (groups[dateKey(entry.day)] ??= []).add(entry);
  }
  return groups;
}
