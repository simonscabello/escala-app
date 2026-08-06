import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Etiqueta de "avisou que não pode neste dia".
///
/// Vive em `shared/` porque aparece nos dois lados da mesma informação: para
/// quem monta a escala (ao escolher) e para quem lê a escala pronta.
class UnavailableBadge extends StatelessWidget {
  const UnavailableBadge({super.key, this.reason, this.compact = true});

  final String? reason;

  /// Versão só com a palavra, para linhas apertadas.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showReason = !compact && (reason?.isNotEmpty ?? false);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_busy_rounded,
            size: 13,
            color: scheme.onErrorContainer,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              showReason ? 'Indisponível · $reason' : 'Indisponível',
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Junta nomes como se fala: "João", "João e Maria", "João, Maria e Pedro".
String joinNames(Iterable<String> names) {
  final list = names.toList();
  if (list.isEmpty) return '';
  if (list.length == 1) return list.first;
  return '${list.sublist(0, list.length - 1).join(', ')} e ${list.last}';
}
