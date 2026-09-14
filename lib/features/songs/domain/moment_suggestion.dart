import 'song_history.dart';
import 'song_models.dart';
import 'song_themes.dart';

/// Um fato que pesou a favor de uma sugestão.
///
/// O servidor manda **o fato, e não a frase**: "4 meses sem cantar" é escrito
/// aqui pelas mesmas funções que escrevem "Cantada há 12 dias" no seletor, e
/// assim as duas telas nunca dizem a mesma coisa de dois jeitos.
class SuggestionReason {
  const SuggestionReason({
    required this.kind,
    this.theme,
    this.count,
    this.lastPlayedAt,
    this.pace,
  });

  factory SuggestionReason.fromJson(Map<String, dynamic> json) {
    return SuggestionReason(
      kind: json['kind'] as String,
      theme: json['theme'] as String?,
      count: json['count'] as int?,
      lastPlayedAt: json['lastPlayedAt'] == null
          ? null
          : DateTime.parse(json['lastPlayedAt'] as String).toUtc(),
      pace: json['pace'] as String?,
    );
  }

  /// `THEME`, `MOMENT_HISTORY`, `LAST_PLAYED`, `LEARNING` ou `PACE`.
  final String kind;
  final String? theme;
  final int? count;
  final DateTime? lastPlayedAt;
  final String? pace;
}

/// Uma das "Sugestões do Pauta": a música, inteira, e por que ela.
class MomentSuggestion {
  const MomentSuggestion({required this.song, this.reasons = const []});

  factory MomentSuggestion.fromJson(Map<String, dynamic> json) {
    return MomentSuggestion(
      song: Song.fromJson(json['song'] as Map<String, dynamic>),
      reasons: (json['reasons'] as List<dynamic>? ?? const [])
          .map((item) => SuggestionReason.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  /// No formato da lista do repertório: entra no culto como qualquer outra.
  final Song song;
  final List<SuggestionReason> reasons;
}

/// A frase de um motivo. Nulo para o que esta versão do app não conhece — um
/// motivo novo no servidor não pode virar texto cru nem derrubar a folha.
String? suggestionReasonText(SuggestionReason reason, DateTime now) {
  return switch (reason.kind) {
    'THEME' when reason.theme != null => songThemeLabel(reason.theme!),
    'MOMENT_HISTORY' when (reason.count ?? 0) > 1 =>
      'utilizada ${reason.count} vezes neste momento',
    'MOMENT_HISTORY' => 'já utilizada neste momento',
    'LAST_PLAYED' => restPhrase(reason.lastPlayedAt, now),
    'LEARNING' => 'estamos aprendendo',
    'PACE' when reason.pace != null => paceLabel(reason.pace),
    _ => null,
  };
}

/// "Gratidão · já utilizada neste momento · 4 meses sem cantar".
///
/// No máximo três: a linha é uma só, e o quarto motivo empurraria o primeiro
/// para fora dela.
String suggestionReasonsLine(
  List<SuggestionReason> reasons,
  DateTime now, {
  int max = 3,
}) {
  return reasons
      .map((reason) => suggestionReasonText(reason, now))
      .whereType<String>()
      .take(max)
      .join(' · ');
}
