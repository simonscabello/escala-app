import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_choice_bar.dart';
import '../../../shared/widgets/app_content_width.dart';
import 'repertoire_health_screen.dart';
import 'song_usage_screen.dart';

/// As duas leituras do repertório.
enum RepertoireReport { health, usage }

/// Relatórios do repertório: **Análise** e **Uso**, numa tela com duas abas.
///
/// Eram duas telas vizinhas respondendo perguntas vizinhas — "o que se repete,
/// o que sumiu" e "o que foi cantado, quando e em que tom" —, cada uma com a
/// sua linha em Gerenciar equipe. Quem abria uma quase sempre queria a outra
/// logo depois. As rotas continuam as duas (`/equipe/musicas/saude` e
/// `/equipe/musicas/uso`), e cada uma abre na sua aba.
class RepertoireReportsScreen extends StatefulWidget {
  const RepertoireReportsScreen({
    super.key,
    required this.teamId,
    this.initial = RepertoireReport.health,
  });

  final String teamId;
  final RepertoireReport initial;

  @override
  State<RepertoireReportsScreen> createState() =>
      _RepertoireReportsScreenState();
}

class _RepertoireReportsScreenState extends State<RepertoireReportsScreen> {
  late RepertoireReport _report = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios do repertório')),
      body: SafeArea(
        top: false,
        child: AppContentWidth.reading(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                  AppSpacing.screenPadding,
                  0,
                ),
                child: AppChoiceBar<RepertoireReport>(
                  expanded: true,
                  value: _report,
                  onChanged: (value) => setState(() => _report = value),
                  options: const [
                    AppChoice(
                      value: RepertoireReport.health,
                      label: 'Análise',
                      icon: Icons.insights_rounded,
                    ),
                    AppChoice(
                      value: RepertoireReport.usage,
                      label: 'Uso',
                      icon: Icons.history_rounded,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: switch (_report) {
                  RepertoireReport.health =>
                    RepertoireHealthView(teamId: widget.teamId),
                  RepertoireReport.usage =>
                    SongUsageView(teamId: widget.teamId),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
