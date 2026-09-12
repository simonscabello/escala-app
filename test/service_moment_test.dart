import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/events/domain/event_models.dart';
import 'package:louvor_app/features/events/domain/service_moments.dart';

/// O momento do culto: opcional, desta escala, e nunca deduzido.
///
/// A armadilha que estes testes fecham é a mesma do `isNew`: preencher sozinho
/// um campo que é julgamento de quem monta a escala. "Momento de Louvor" seria
/// o palpite fácil — e poria na escala publicada uma decisão de ninguém.
void main() {
  EventSong musica(Map<String, dynamic> extra) => EventSong.fromJson({
        'songId': 's1',
        'serviceId': 'c1',
        'title': 'Estou Seguro',
        ...extra,
      });

  group('vocabulário', () {
    test('os momentos estão na ordem do culto, não na alfabética', () {
      // É a ordem em que eles acontecem no domingo: quem escolhe percorre a
      // lista como percorre o culto, e não como percorre um dicionário.
      expect(serviceMoments.keys.toList(), [
        'PRELUDIO',
        'ABERTURA',
        'DIZIMOS_E_OFERTAS',
        'LOUVOR',
        'ESPECIAL',
        'POSLUDIO',
        'OUTRO',
      ]);
    });

    test('o rótulo é o nome que a igreja usa', () {
      expect(serviceMomentLabel('DIZIMOS_E_OFERTAS'), 'Dízimos e Ofertas');
      expect(serviceMomentLabel('LOUVOR'), 'Momento de Louvor');
    });

    test('sem momento não há rótulo nenhum', () {
      // Nulo, e não "—" nem "Sem momento": a maioria das músicas de uma escala
      // não tem momento, e um marcador de vazio em cada linha seria mais tinta
      // que as próprias músicas.
      expect(serviceMomentLabel(null), isNull);
      expect(serviceMomentLabel(''), isNull);
    });

    test('"Outro" mostra o que a pessoa escreveu', () {
      expect(serviceMomentLabel('OUTRO', 'Santa Ceia'), 'Santa Ceia');
      // Sem texto, o rótulo genérico ainda serve: ela marcou que há um
      // momento, só não o nomeou.
      expect(serviceMomentLabel('OUTRO'), 'Outro');
      expect(serviceMomentLabel('OUTRO', '  '), 'Outro');
    });

    test('momento que esta versão do app não conhece não some da tela', () {
      // O servidor pode ganhar um momento novo antes do próximo APK. O valor
      // cru é feio; sumir com a informação seria pior.
      expect(serviceMomentLabel('CONSAGRACAO'), 'CONSAGRACAO');
    });
  });

  group('a música da escala', () {
    test('lê o momento do servidor', () {
      final song = musica({
        'moment': 'DIZIMOS_E_OFERTAS',
        'hymnals': [
          {
            'hymnalId': 'h-cc',
            'name': 'Cantor Cristão',
            'abbreviation': 'CC',
            'number': 314,
            'isPrimary': true,
          },
        ],
      });

      expect(song.moment, 'DIZIMOS_E_OFERTAS');
      expect(song.momentText, 'Dízimos e Ofertas');
      expect(song.hymnal?.label, '314 CC');
    });

    test('ausente continua ausente', () {
      final song = musica(const {});

      expect(song.moment, isNull);
      expect(song.momentText, isNull);
      // Cache gravado antes desta versão: a lista ausente vale vazia, e a
      // escala continua abrindo.
      expect(song.hymnals, isEmpty);
      expect(song.hymnal, isNull);
    });

    test('"Outro" carrega o nome escrito à mão', () {
      final song = musica({'moment': 'OUTRO', 'momentLabel': 'Batismo'});
      expect(song.momentText, 'Batismo');
    });
  });
}
