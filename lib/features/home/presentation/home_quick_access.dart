import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_header.dart';
import '../../suggestions/data/suggestion_repository.dart';

/// Os três atalhos da Home.
///
/// **Nenhum destino novo.** Repertório, Sugestões e Minha disponibilidade já
/// existem no app — na barra lateral do monitor, e atrás de dois toques no
/// celular. O que a Home acrescenta é o caminho curto: são as telas que a
/// equipe abre entre um domingo e outro, e chegar até elas custava mais do que
/// devia. **Minha disponibilidade** era a mais escondida das três: no celular
/// só se chegava nela pelo Perfil, e é justamente a que tem prazo — avisar que
/// não pode depois da escala montada já é tarde.
///
/// Três, e não seis: a Home não é um painel de controle. Cada atalho a mais
/// aqui rouba peso da manchete, que é a razão de a tela existir.
///
/// **A arrumação muda com a largura, o conteúdo não.** Três ladrilhos lado a
/// lado só cabem quando há largura; num celular de 375px cada um ficaria com
/// 110px, e "Minha disponibilidade" não entra em 110px. Ali os dois primeiros
/// dividem a linha e o terceiro vira uma faixa embaixo — o mesmo cartão,
/// deitado.
class HomeQuickAccess extends ConsumerWidget {
  const HomeQuickAccess({
    super.key,
    required this.teamId,
    required this.canManage,
  });

  final String teamId;

  /// Só quem pode responder uma sugestão vê a contagem delas.
  ///
  /// É a mesma regra do selo na aba Equipe: para quem apenas sugere, um número
  /// que ele não tem como resolver seria enfeite — e a contagem custa uma
  /// requisição que, para essa pessoa, não paga o próprio preço.
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Reaproveita o provider do selo da aba Equipe: mesma chave, mesma
    // resposta. Abrir a lista de sugestões logo depois não custa uma segunda
    // ida ao servidor.
    final pending = canManage
        ? ref.watch(openSuggestionCountProvider(teamId)).valueOrNull ?? 0
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Acessos rápidos',
          padding: EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.md,
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            // O espaço que o bloco recebeu, e não o da janela: dentro da casca
            // com barra lateral aberta a Home tem menos largura do que o
            // monitor sugere, e é a largura daqui que decide se três ladrilhos
            // cabem.
            final tresEmLinha = constraints.maxWidth >= 520;

            final repertorio = _QuickCard(
              icon: Icons.library_music_rounded,
              title: 'Repertório',
              subtitle: 'Cânticos e hinos',
              onTap: () => context.push('/equipe/musicas'),
            );
            final sugestoes = _QuickCard(
              icon: Icons.lightbulb_rounded,
              title: 'Sugestões',
              // Quem responde as sugestões e quem as faz não abrem esta tela
              // pelo mesmo motivo: uma legenda só serviria a metade da equipe.
              subtitle: canManage ? 'Ideias da equipe' : 'Peça uma música',
              badge: pending == 0
                  ? null
                  : AppBadge(
                      label: '$pending',
                      tone: AppTone.primary,
                      emphasis: BadgeEmphasis.solid,
                      semanticsLabel: pending == 1
                          ? '1 sugestão aguardando resposta'
                          : '$pending sugestões aguardando resposta',
                    ),
              onTap: () => context.push('/equipe/sugestoes'),
            );
            final disponibilidade = _QuickCard(
              icon: Icons.event_busy_rounded,
              title: 'Minha disponibilidade',
              subtitle: 'Avise quando não puder',
              banner: !tresEmLinha,
              onTap: () => context.push('/disponibilidade'),
            );

            // `IntrinsicHeight` para os cartões da linha terem a mesma altura:
            // são um conjunto, e um mais alto que o outro por causa do tamanho
            // da legenda lê-se como desalinho, não como diferença. Dentro de
            // uma lista a altura é ilimitada, e `stretch` sozinho num `Row`
            // pede altura infinita.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: repertorio),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: sugestoes),
                      if (tresEmLinha) ...[
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: disponibilidade),
                      ],
                    ],
                  ),
                ),
                if (!tresEmLinha) ...[
                  const SizedBox(height: AppSpacing.md),
                  disponibilidade,
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Um atalho: ícone, nome, uma linha do que há lá dentro.
///
/// O ícone fica no ladrilho tingido — é a exceção que o app se permite fora da
/// manchete, e ela se paga aqui: são dois objetos do mesmo tamanho lado a lado,
/// e é a cor que os distingue antes de o texto ser lido.
class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.banner = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? badge;

  /// Deitado: ícone à esquerda, texto ao lado, ocupando a linha inteira.
  ///
  /// É o mesmo cartão, virado — e não um segundo componente. O ladrilho em pé
  /// existe para caber ao lado de outro; sozinho numa linha de 375px ele
  /// viraria um quadrado com muito ar e duas palavras no canto.
  final bool banner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final marca = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
    );

    final texto = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall,
          maxLines: banner ? 2 : 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: banner
          ? Row(
              children: [
                marca,
                const SizedBox(width: AppSpacing.md),
                Expanded(child: texto),
                if (badge != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  badge!,
                ],
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    marca,
                    const Spacer(),
                    if (badge != null) badge!,
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                texto,
              ],
            ),
    );
  }
}
