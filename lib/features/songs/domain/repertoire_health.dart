/// Uma música numa lista da saúde do repertório.
///
/// Magra de propósito: título para achar, e o histórico para dizer por que ela
/// está na lista. Tocar abre o detalhe, que tem o resto.
class RepertoireHealthSong {
  const RepertoireHealthSong({
    required this.songId,
    required this.title,
    this.artist,
    this.hymnRef,
    this.defaultKey,
    this.isNew = false,
    this.lastPlayedAt,
    this.playCount = 0,
    this.last3Months = 0,
    this.last6Months = 0,
    this.last12Months = 0,
  });

  factory RepertoireHealthSong.fromJson(Map<String, dynamic> json) {
    return RepertoireHealthSong(
      songId: json['songId'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String?,
      hymnRef: json['hymnRef'] as String?,
      defaultKey: json['defaultKey'] as String?,
      isNew: json['isNew'] as bool? ?? false,
      lastPlayedAt: json['lastPlayedAt'] == null
          ? null
          : DateTime.parse(json['lastPlayedAt'] as String).toUtc(),
      playCount: json['playCount'] as int? ?? 0,
      last3Months: json['last3Months'] as int? ?? 0,
      last6Months: json['last6Months'] as int? ?? 0,
      last12Months: json['last12Months'] as int? ?? 0,
    );
  }

  final String songId;
  final String title;
  final String? artist;

  /// "314 CC", já montado pelo servidor.
  final String? hymnRef;
  final String? defaultKey;
  final bool isNew;
  final DateTime? lastPlayedAt;
  final int playCount;
  final int last3Months;
  final int last6Months;
  final int last12Months;

  String get displayTitle => hymnRef == null ? title : '$hymnRef · $title';
}

/// Análise do repertório: resumo e listas em que dá para agir.
///
/// **É aqui que mora o "faltando dados"**, e não na lista do repertório — o
/// filtro já existiu lá e saiu, porque cobrar tom de centenas de músicas no
/// lugar onde a equipe procura a cifra não era o jeito dela trabalhar.
class RepertoireHealth {
  const RepertoireHealth({
    required this.activeCount,
    required this.learningCount,
    required this.neverPlayedCount,
    required this.usedInLast3Months,
    required this.usedInLast6Months,
    required this.usedInLast12Months,
    required this.frequentMinLast3Months,
    required this.idleMonths,
    this.frequent = const [],
    this.idle = const [],
    this.learning = const [],
    this.missingKey = const [],
    this.missingReference = const [],
  });

  factory RepertoireHealth.fromJson(Map<String, dynamic> json) {
    List<RepertoireHealthSong> songs(String key) =>
        (json[key] as List<dynamic>? ?? const [])
            .map(
              (item) =>
                  RepertoireHealthSong.fromJson(item as Map<String, dynamic>),
            )
            .toList();
    final used = json['usedInLast'] as Map<String, dynamic>? ?? const {};
    final rules = json['rules'] as Map<String, dynamic>? ?? const {};

    return RepertoireHealth(
      activeCount: json['activeCount'] as int? ?? 0,
      learningCount: json['learningCount'] as int? ?? 0,
      neverPlayedCount: json['neverPlayedCount'] as int? ?? 0,
      usedInLast3Months: used['months3'] as int? ?? 0,
      usedInLast6Months: used['months6'] as int? ?? 0,
      usedInLast12Months: used['months12'] as int? ?? 0,
      frequentMinLast3Months: rules['frequentMinLast3Months'] as int? ?? 4,
      idleMonths: rules['idleMonths'] as int? ?? 12,
      frequent: songs('frequent'),
      idle: songs('idle'),
      learning: songs('learning'),
      missingKey: songs('missingKey'),
      missingReference: songs('missingReference'),
    );
  }

  final int activeCount;
  final int learningCount;

  /// Um número, e não uma lista: com os hinários importados inteiros, seriam
  /// centenas de linhas mudas.
  final int neverPlayedCount;

  final int usedInLast3Months;
  final int usedInLast6Months;
  final int usedInLast12Months;

  /// Os cortes do servidor, para o texto não repetir os números.
  final int frequentMinLast3Months;
  final int idleMonths;

  final List<RepertoireHealthSong> frequent;
  final List<RepertoireHealthSong> idle;
  final List<RepertoireHealthSong> learning;
  final List<RepertoireHealthSong> missingKey;
  final List<RepertoireHealthSong> missingReference;
}
