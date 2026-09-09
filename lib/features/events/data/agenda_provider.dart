import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/read_cache.dart';
import '../domain/event_models.dart';
import 'event_repository.dart';

const agendaQueryLimit = 100;

/// Reaproveita a consulta/cache da Home e as invalidações dos formulários.
/// Só amplia a leitura quando a primeira página pode estar incompleta.
final agendaEventsProvider = FutureProvider.autoDispose
    .family<CachedValue<List<Event>>, EventsQuery>((ref, query) async {
  final initial = await ref.watch(eventsProvider(query).future);
  if (initial.data.length < 20 || initial.fromCache) return initial;
  return ref.watch(eventRepositoryProvider).list(
        query.$1,
        scope: query.$2,
        limit: agendaQueryLimit,
      );
});
