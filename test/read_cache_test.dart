import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/core/storage/read_cache.dart';
import 'package:louvor_app/shared/widgets/cache_stamp_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    tzdata.initializeTimeZones();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('cache da agenda salva e lê o JSON com timestamp', () async {
    final prefs = await SharedPreferences.getInstance();
    final cache = ReadCache(prefs);

    await cache.saveAgenda('team-1', 'upcoming', [
      {
        'id': 'e1',
        'teamId': 'team-1',
        'title': 'Culto',
        'startsAt': '2026-08-16T12:00:00.000Z',
        'status': 'PUBLISHED',
        'timezone': 'America/Sao_Paulo',
        'assignments': [],
        'songs': [],
      },
    ]);

    final cached = cache.readAgenda('team-1', 'upcoming');
    expect(cached, isNotNull);
    expect(cached!.data.single['title'], 'Culto');
    expect(cached.cachedAt.isUtc, isTrue);
  });

  test('fallback de cache marca fromCache e gera selo legível', () async {
    final prefs = await SharedPreferences.getInstance();
    final cache = ReadCache(prefs);
    await cache.saveEvent('e1', {
      'id': 'e1',
      'teamId': 't1',
      'title': 'Culto',
      'startsAt': '2026-08-16T12:00:00.000Z',
      'status': 'PUBLISHED',
      'timezone': 'America/Sao_Paulo',
      'assignments': [],
      'songs': [],
    });

    final payload = cache.readEvent('e1')!;
    final value = CachedValue(
      data: payload.data,
      fromCache: true,
      cachedAt: payload.cachedAt,
    );

    expect(value.fromCache, isTrue);
    expect(value.stampLabel, startsWith('atualizado às '));
  });
}
