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

/// As **escalas** de cada dia, e não os horários.
///
/// O calendário pinta um ponto por horário — é assim que a vigília que vira a
/// noite marca os dois dias. A lista abaixo dele fala de escalas: um domingo
/// com manhã e noite é **uma** escala, e mostrá-la duas vezes faria a equipe
/// contar em dobro. A linha ([CompactScheduleTile]) já escreve os dois
/// horários numa frase só.
///
/// A ordem é a das entradas, que vêm ordenadas pelo horário — o primeiro
/// horário do dia é o que decide onde a escala entra.
Map<String, List<Event>> groupAgendaEvents(List<AgendaEntry> entries) {
  final groups = <String, List<Event>>{};
  for (final entry in entries) {
    final escalas = groups[dateKey(entry.day)] ??= [];
    if (!escalas.any((event) => event.id == entry.event.id)) {
      escalas.add(entry.event);
    }
  }
  return groups;
}

/// O recorte da agenda: tudo, ou só onde eu entro.
enum AgendaFilter {
  /// A agenda da equipe inteira.
  all,

  /// Só as escalas em que a pessoa tem alguma responsabilidade.
  mine;

  bool get isMine => this == AgendaFilter.mine;
}

/// As entradas em que a pessoa tem **alguma responsabilidade**.
///
/// Responsabilidade é estar escalado em alguma função. O ministrante entra
/// junto sem uma segunda conferência: o servidor recusa ministrante que não
/// esteja entre os escalados (`assertMinisterIsAssigned`), então quem ministra
/// já aparece em `assignments`. Se um dia isso deixar de valer, é aqui que a
/// segunda fonte entra — e não em cada tela que pergunta "é minha?".
List<AgendaEntry> filterAgendaEntries(
  List<AgendaEntry> entries, {
  required AgendaFilter filter,
  required String membershipId,
}) {
  if (filter == AgendaFilter.all) return entries;
  return [
    for (final entry in entries)
      if (entry.event.positionsForMembership(membershipId).isNotEmpty) entry,
  ];
}
