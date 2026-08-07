import 'package:flutter_test/flutter_test.dart';
import 'package:louvor_app/features/songs/domain/song_models.dart';

Map<String, dynamic> songJson({
  String? defaultKey,
  String? kind,
  String? pace,
  String? originalKey,
  String? lyrics,
}) {
  return {
    'id': 's1',
    'title': 'Consagração',
    'artist': 'Aline Barros',
    'composer': 'Anderson Mattos',
    'kind': kind,
    'pace': pace,
    'defaultKey': defaultKey,
    'originalKey': originalKey,
    'bpm': 70,
    'lyrics': lyrics,
    'chordsUrl': 'https://www.cifraclub.com.br/aline-barros/consagracao/',
    'isArchived': false,
  };
}

void main() {
  group('Song', () {
    test('faltando dados enquanto tom, tipo ou andamento estiverem vazios', () {
      expect(Song.fromJson(songJson()).isIncomplete, isTrue);

      // Só o tom preenchido ainda não completa: são três decisões.
      expect(
        Song.fromJson(songJson(defaultKey: 'G')).isIncomplete,
        isTrue,
      );

      final completa = Song.fromJson(
        songJson(defaultKey: 'G', kind: 'SONG', pace: 'CALM'),
      );
      expect(completa.isIncomplete, isFalse);
    });

    test('a lista não traz letra, e isso não é o mesmo que não ter letra', () {
      // Como a listagem responde: sem o campo `lyrics`.
      final daLista = Song.fromJson(songJson());
      expect(daLista.lyrics, isNull);
      expect(daLista.hasLyrics, isFalse);

      final doDetalhe = Song.fromJson(songJson(lyrics: 'Receba a minha vida'));
      expect(doDetalhe.hasLyrics, isTrue);
    });

    test('letra em branco não conta como letra', () {
      expect(Song.fromJson(songJson(lyrics: '   ')).hasLyrics, isFalse);
    });

    test('tom da gravação não vira tom da equipe', () {
      final song = Song.fromJson(songJson(originalKey: 'F#'));
      // O tom lido do CifraClub é sugestão; o campo da equipe segue vazio.
      expect(song.originalKey, 'F#');
      expect(song.defaultKey, isNull);
      expect(song.isIncomplete, isTrue);
    });

    test('sem artista, o subtítulo avisa em vez de ficar em branco', () {
      final json = songJson()
        ..['artist'] = null
        ..['composer'] = null;
      expect(Song.fromJson(json).subtitle, 'Sem artista');
    });
  });

  group('rótulos em português', () {
    test('tipo e andamento', () {
      expect(kindLabel('HYMN'), 'Hino');
      expect(kindLabel('SONG'), 'Cântico');
      expect(paceLabel('CALM'), 'Calma');
      expect(paceLabel('UPBEAT'), 'Agitada');
    });

    test('valor ausente ou desconhecido vira travessão, não erro', () {
      expect(kindLabel(null), '—');
      expect(paceLabel('QUALQUER_COISA'), '—');
    });
  });

  group('CatalogCandidate', () {
    test('lê o que o candidato traz sem receber a letra em si', () {
      final candidate = CatalogCandidate.fromJson({
        'sourceSongId': 'x1',
        'title': 'Consagração',
        'artist': 'Aline Barros',
        'originalKey': 'A',
        'bpm': 70,
        'hasLyrics': true,
        'hasChords': true,
        'hasYoutube': false,
        'hasSpotify': true,
      });

      expect(candidate.hasLyrics, isTrue);
      expect(candidate.hasYoutube, isFalse);
      expect(candidate.originalKey, 'A');
    });

    test('flags ausentes são falsas, nunca nulas', () {
      final candidate = CatalogCandidate.fromJson({
        'sourceSongId': 'x1',
        'title': 'Alguma',
      });
      expect(candidate.hasLyrics, isFalse);
      expect(candidate.artist, isNull);
    });
  });
}
