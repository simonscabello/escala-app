import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/app_avatar_stack.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/you_highlight.dart';
import '../domain/event_datetime.dart';
import '../domain/event_models.dart';
import 'duplicate_event_dialog.dart';
import 'event_schedule_facts.dart';

/// A próxima escala: a manchete da agenda.
///
/// Esta é a razão de o app existir — quem abre quer saber quando é e onde entra
/// em dois segundos —, e por isso ela leva a tipografia de manchete: a data em
/// 32px com espacejamento apertado, muito acima do corpo das escalas seguintes.
///
/// **Ela é escura nos dois temas, e isso é o degrau novo da hierarquia.** Antes
/// a manchete era um cartão branco com texto maior, dentro de uma página de
/// cartões brancos: a diferença ficava toda por conta do tamanho da fonte. No
/// tema claro não havia como subir mais um passo clareando — branco já é o topo
/// da escala de superfícies. Subiu escurecendo, no violeta da marca (ver
/// `AppColors.heroGradient`), e o bloco passou a se destacar antes de qualquer
/// texto ser lido.
///
/// Já esteve **sem** cartão, solta na página, para levar a hierarquia ao
/// limite: uma coisa grande, uma lista quieta. Em aparelho real não funcionou.
/// Sem fundo, o bloco parava de se ler como um objeto e virava texto derramado
/// entre o cumprimento acima e a lista abaixo — e, pior, um objeto tocável sem
/// nada delimitando onde ele começa e termina. A lição continua valendo: **a
/// hierarquia se faz pelo tamanho do texto, pela folga e pela superfície, nunca
/// pela ausência de moldura.**
///
/// **Dois alvos de toque, de propósito.** O cartão inteiro continua abrindo a
/// escala, como sempre abriu; o botão "Ver detalhes" existe porque um cartão
/// tocável sem botão nenhum não se anuncia como tocável para quem nunca tentou.
/// Não há conflito: o botão é filho, e o toque para no filho antes de chegar ao
/// cartão.
class ScheduleHeroCard extends ConsumerWidget {
  const ScheduleHeroCard({
    super.key,
    required this.event,
    required this.canManage,
    required this.membershipId,
  });

  final Event event;
  final bool canManage;
  final String membershipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final timezone =
        event.timezone.isEmpty ? 'America/Sao_Paulo' : event.timezone;
    final youPositions = event.positionsForMembership(membershipId);
    final facts = ScheduleFacts.of(event, timezone);
    final people = event.scheduledPeople;

    return AppCard(
      onTap: () => context.push('/agenda/${event.id}'),
      gradient: AppColors.heroGradient(theme.colorScheme),
      child: Stack(
        children: [
          // Duas manchas de luz, e nada mais. O recorte do cartão corta o que
          // passa da borda, então elas leem como um brilho vindo de fora e não
          // como dois círculos desenhados dentro do bloco. 5% e 4%: abaixo
          // disso não se percebe, acima vira textura de papel de parede.
          const Positioned(
            right: -70,
            top: -90,
            child: _Glow(size: 210, alpha: 0.05),
          ),
          const Positioned(
            right: 20,
            bottom: -120,
            child: _Glow(size: 190, alpha: 0.04),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroTopRow(
                  event: event,
                  canManage: canManage,
                  youPositions: youPositions,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  heroDateText(
                    context,
                    formatEventWeekdayDate(event.startsAt, timezone),
                  ),
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: AppColors.onHero,
                  ),
                  // Quatro linhas: "Quinta-feira, 10 de setembro de 2027" com
                  // a fonte do sistema no dobro do tamanho precisa de todas
                  // elas, e cortar a data é cortar a identidade da escala.
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                // A data é a identidade da escala e fica sempre na mesma
                // posição; o título só existe em culto especial e entra abaixo,
                // para se ler como exceção.
                if (event.hasTitle) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    event.title!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.onHeroVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                _HeroFacts(facts: facts),
                const SizedBox(height: AppSpacing.xl),
                _HeroFooter(event: event, people: people),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sobrancelha, destaque pessoal e menu, na mesma linha.
///
/// A pílula "VOCÊ: ..." fica **aqui em cima**, e não no rodapé como nas linhas
/// da lista: na manchete ela responde a pergunta que faz a pessoa abrir o app,
/// e responder isso depois dos horários é responder tarde.
class _HeroTopRow extends ConsumerWidget {
  const _HeroTopRow({
    required this.event,
    required this.canManage,
    required this.youPositions,
  });

  final Event event;
  final bool canManage;
  final List<String> youPositions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showMenu = canManage && FeatureFlags.duplicateSchedule;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          // `Wrap` e não `Row`: a pílula carrega os nomes das funções, e
          // "VOCÊ: Vocal, Baixo, Violão" não cabe ao lado da sobrancelha num
          // celular estreito. Lado a lado quando cabe, empilhado quando não —
          // em vez de espremer a pílula até virar reticências.
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                event.isDraft ? 'RASCUNHO' : 'PRÓXIMA ESCALA',
                style: AppTypography.eyebrow(context).copyWith(
                  color: AppColors.onHeroVariant,
                ),
              ),
              if (youPositions.isNotEmpty)
                YouHighlight(
                  positionNames: youPositions,
                  // Claro sobre escuro: o `primaryContainer` do tema claro é
                  // lavanda, e lavanda sobre o violeta da manchete seria a
                  // mesma mancha duas vezes.
                  background: AppColors.onHero.withValues(alpha: 0.16),
                  foreground: AppColors.onHero,
                ),
            ],
          ),
        ),
        if (showMenu)
          _HeroMenu(event: event)
        else
          // Sem menu, a linha continua alta o bastante para a sobrancelha não
          // encostar na data. Sem isto o bloco "pula" ao trocar de papel.
          const SizedBox(height: AppSpacing.touchTarget),
      ],
    );
  }
}

class _HeroMenu extends ConsumerWidget {
  const _HeroMenu({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Mais opções desta escala',
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.onHeroVariant),
      onSelected: (value) async {
        if (value == 'duplicate') {
          await showDuplicateEventDialog(
            context: context,
            ref: ref,
            source: event,
          );
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'duplicate', child: Text('Duplicar escala')),
      ],
    );
  }
}

/// Horários, ensaio e repertório — os três fatos da escala, com ícone.
///
/// Em `Wrap` e não em `Row`: com a fonte do sistema aumentada, ou num culto com
/// três horários, os dois blocos não cabem lado a lado e precisam empilhar em
/// vez de espremer.
class _HeroFacts extends StatelessWidget {
  const _HeroFacts({required this.facts});

  final ScheduleFacts facts;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xl,
      runSpacing: AppSpacing.md,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        _HeroFact(
          icon: Icons.schedule_rounded,
          label: facts.times,
          detail: facts.rehearsal,
        ),
        if (facts.songs != null)
          _HeroFact(icon: Icons.music_note_rounded, label: facts.songs!),
      ],
    );
  }
}

class _HeroFact extends StatelessWidget {
  const _HeroFact({required this.icon, required this.label, this.detail});

  final IconData icon;
  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      // Teto de largura para o `Wrap` ter onde quebrar: sem ele, um bloco com
      // três horários ocupa a linha inteira e empurra o repertório para baixo
      // mesmo num monitor.
      constraints: const BoxConstraints(maxWidth: 320),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: AppColors.onHeroVariant),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.onHero,
                    fontFeatures: AppTypography.tabular,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (detail != null)
                  Text(
                    detail!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.onHeroVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Quem está na escala, e o caminho para dentro dela.
class _HeroFooter extends StatelessWidget {
  const _HeroFooter({required this.event, required this.people});

  final Event event;
  final List<({String name, String? imageUrl})> people;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final count = people.length;

    final crowd = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (people.isNotEmpty) ...[
          AppAvatarStack(
            people: people,
            max: 4,
            radius: 14,
            // O anel tem a cor do fundo da manchete; a rampa é escura o
            // bastante para uma só das duas pontas servir aos dois extremos.
            ringColor: AppColors.heroRamp(theme.brightness).last,
            // Sobre a manchete os rostos também invertem: o `primaryContainer`
            // do tema claro é lavanda, e uma pilha de lavanda sobre o violeta
            // sumia. Branco translúcido funciona nos dois temas porque o fundo
            // é escuro nos dois.
            background: AppColors.onHero.withValues(alpha: 0.18),
            foreground: AppColors.onHero,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Flexible(
          child: Text(
            switch (count) {
              // Rascunho sem ninguém escalado é o estado mais comum de uma
              // escala recém-criada, e é o que o líder precisa ver.
              0 => 'Ninguém escalado ainda',
              1 => '1 pessoa na escala',
              _ => '$count pessoas na escala',
            },
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.onHeroVariant,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    final button = _HeroDetailButton(eventId: event.id);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Numa tela de celular a contagem e o botão não cabem na mesma linha
        // sem que um dos dois vire reticências. Empilhar custa 40px de altura e
        // não custa informação nenhuma — o botão continua encostado à direita,
        // que é onde o polegar o procura.
        if (constraints.maxWidth < 380) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(alignment: Alignment.centerLeft, child: crowd),
              const SizedBox(height: AppSpacing.md),
              Align(alignment: Alignment.centerRight, child: button),
            ],
          );
        }

        return Row(
          children: [
            // `Expanded`, e não `Flexible`: é ele que empurra o botão para a
            // borda direita do cartão em vez de deixá-lo colado na contagem.
            Expanded(child: crowd),
            const SizedBox(width: AppSpacing.md),
            button,
          ],
        );
      },
    );
  }
}

/// "Ver detalhes →".
///
/// Contido e à direita, e não largo na base do cartão: um botão que atravessa a
/// manchete inteira compete com a data pelo primeiro olhar, e a data é que
/// identifica a escala. À direita ele fica no fim natural da leitura e no
/// alcance do polegar.
class _HeroDetailButton extends StatelessWidget {
  const _HeroDetailButton({required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return FilledButton.icon(
      onPressed: () => context.push('/agenda/$eventId'),
      style: FilledButton.styleFrom(
        // A tinta clara da marca sobre o violeta escuro: o mesmo par do botão
        // primário do tema escuro, que é o contexto em que este botão vive
        // mesmo quando o app está no tema claro.
        backgroundColor: AppColors.brandLavender,
        foregroundColor: AppColors.brandDeepViolet,
        // Menor que o botão principal de um formulário (52): aqui ele é a ação
        // de um cartão, não a ação da tela.
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        textStyle: Theme.of(context).textTheme.labelLarge,
        // A seta segue o texto; `iconAlignment` é o que evita montar uma `Row`
        // à mão só para inverter a ordem.
      ).copyWith(
        overlayColor: WidgetStatePropertyAll(
          scheme.shadow.withValues(alpha: 0.08),
        ),
      ),
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
      label: const Text('Ver detalhes'),
    );
  }
}

/// Uma mancha de luz atrás do conteúdo da manchete.
class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.onHero.withValues(alpha: alpha),
        ),
      ),
    );
  }
}
