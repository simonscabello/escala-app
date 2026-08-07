/// Uma música do repertório da equipe.
///
/// O mesmo modelo serve à lista e ao detalhe: a lista não traz `lyrics` (são
/// centenas de músicas e a letra só importa na tela de uma delas), então o
/// campo fica nulo lá. `hasLyrics` diferencia "não tem letra" de "a lista não
/// carregou a letra".
class Song {
  const Song({
    required this.id,
    required this.title,
    this.artist,
    this.composer,
    this.kind,
    this.pace,
    this.defaultKey,
    this.originalKey,
    this.bpm,
    this.lyrics,
    this.lyricsUrl,
    this.chordsUrl,
    this.youtubeUrl,
    this.spotifyUrl,
    this.isArchived = false,
  });

  final String id;
  final String title;
  final String? artist;
  final String? composer;

  /// 'HYMN' ou 'SONG'.
  final String? kind;

  /// 'CALM', 'MODERATE' ou 'UPBEAT'.
  final String? pace;

  /// O tom em que a equipe canta. Só a equipe preenche.
  final String? defaultKey;

  /// O tom da gravação, lido do CifraClub. Sugestão, não decisão.
  final String? originalKey;
  final int? bpm;

  final String? lyrics;
  final String? lyricsUrl;
  final String? chordsUrl;
  final String? youtubeUrl;
  final String? spotifyUrl;
  final bool isArchived;

  bool get hasLyrics => lyrics != null && lyrics!.trim().isNotEmpty;

  /// O que ainda falta a equipe decidir. É o que a tela cobra: nenhum serviço
  /// externo responde essas três.
  bool get isIncomplete => defaultKey == null || kind == null || pace == null;

  String get subtitle {
    final parts = [artist, composer].where((p) => p != null && p.isNotEmpty);
    return parts.isEmpty ? 'Sem artista' : parts.first!;
  }

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String?,
      composer: json['composer'] as String?,
      kind: json['kind'] as String?,
      pace: json['pace'] as String?,
      defaultKey: json['defaultKey'] as String?,
      originalKey: json['originalKey'] as String?,
      bpm: json['bpm'] as int?,
      lyrics: json['lyrics'] as String?,
      lyricsUrl: json['lyricsUrl'] as String?,
      chordsUrl: json['chordsUrl'] as String?,
      youtubeUrl: json['youtubeUrl'] as String?,
      spotifyUrl: json['spotifyUrl'] as String?,
      isArchived: json['isArchived'] as bool? ?? false,
    );
  }
}

String kindLabel(String? kind) => switch (kind) {
      'HYMN' => 'Hino',
      'SONG' => 'Cântico',
      _ => '—',
    };

String paceLabel(String? pace) => switch (pace) {
      'CALM' => 'Calma',
      'MODERATE' => 'Moderada',
      'UPBEAT' => 'Agitada',
      _ => '—',
    };

/// Música que outra equipe já cadastrou.
///
/// É o único caminho para a letra numa igreja que chega agora: nenhuma API
/// devolve letra, e a maioria das igrejas não tem como exportar acervo de
/// lugar nenhum.
class CatalogCandidate {
  const CatalogCandidate({
    required this.sourceSongId,
    required this.title,
    this.artist,
    this.composer,
    this.originalKey,
    this.bpm,
    this.hasLyrics = false,
    this.hasChords = false,
    this.hasYoutube = false,
    this.hasSpotify = false,
  });

  final String sourceSongId;
  final String title;
  final String? artist;
  final String? composer;
  final String? originalKey;
  final int? bpm;
  final bool hasLyrics;
  final bool hasChords;
  final bool hasYoutube;
  final bool hasSpotify;

  factory CatalogCandidate.fromJson(Map<String, dynamic> json) {
    return CatalogCandidate(
      sourceSongId: json['sourceSongId'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String?,
      composer: json['composer'] as String?,
      originalKey: json['originalKey'] as String?,
      bpm: json['bpm'] as int?,
      hasLyrics: json['hasLyrics'] as bool? ?? false,
      hasChords: json['hasChords'] as bool? ?? false,
      hasYoutube: json['hasYoutube'] as bool? ?? false,
      hasSpotify: json['hasSpotify'] as bool? ?? false,
    );
  }
}

/// Resultado da busca no Spotify.
class ExternalCandidate {
  const ExternalCandidate({
    required this.title,
    required this.artist,
    required this.spotifyUrl,
    this.album,
    this.year,
  });

  final String title;
  final String artist;
  final String spotifyUrl;
  final String? album;
  final String? year;

  factory ExternalCandidate.fromJson(Map<String, dynamic> json) {
    return ExternalCandidate(
      title: json['title'] as String,
      artist: json['artist'] as String? ?? '',
      spotifyUrl: json['spotifyUrl'] as String? ?? '',
      album: json['album'] as String?,
      year: json['year'] as String?,
    );
  }
}
