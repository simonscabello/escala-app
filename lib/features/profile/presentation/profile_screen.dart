import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_feedback.dart';
import '../../../shared/widgets/app_group.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_models.dart';
import 'profile_photo.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        top: false,
        child: AppContentWidth.reading(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            children: [
              // O nome sobe para o tamanho de manchete. É a única coisa nesta
              // tela que identifica de quem ela é, e estava no mesmo corpo dos
              // títulos de bloco logo abaixo.
              Row(
                children: [
                  const ProfilePhoto(radius: 34),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: theme.textTheme.headlineSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),

              // "Minha disponibilidade" abre a tela e saiu de "Equipe". Não é
              // uma configuração: é a única coisa que um integrante **faz**
              // neste app além de ler a escala, e estava enterrada abaixo de
              // "Meus dados" e "Alterar senha" — dois itens que se mexe uma
              // vez na vida.
              AppGroup(
                title: 'Minha participação',
                children: [
                  AppGroupRow(
                    icon: Icons.event_busy_outlined,
                    title: 'Minha disponibilidade',
                    subtitle: 'Os dias em que você não pode ser escalado',
                    onTap: () => context.push('/disponibilidade'),
                  ),
                  _TeamRow(teams: auth.teams),
                ],
              ),

              const SizedBox(height: AppSpacing.xxl),
              AppGroup(
                title: 'Conta',
                children: [
                  AppGroupRow(
                    icon: Icons.badge_outlined,
                    title: 'Meus dados',
                    // A foto se troca tocando no avatar aqui em cima, que já
                    // tem o selo de câmera. Repeti-la dentro de "Meus dados"
                    // daria dois caminhos para o mesmo gesto.
                    subtitle: 'Nome e e-mail',
                    onTap: () => context.push('/perfil/dados'),
                  ),
                  AppGroupRow(
                    icon: Icons.lock_outline_rounded,
                    title: 'Alterar senha',
                    subtitle: 'Você precisa da senha atual',
                    onTap: () => context.push('/perfil/senha'),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xxl),
              const SectionHeader(
                title: 'Aparência',
                subtitle: 'Vale só neste aparelho.',
                padding: EdgeInsets.only(
                  left: AppSpacing.xs,
                  bottom: AppSpacing.md,
                ),
              ),
              const _ThemeModeCard(),

              const SizedBox(height: AppSpacing.xxl),
              // Sair e diagnóstico viraram linhas de um grupo, no fim da tela.
              // Como botão vermelho de largura inteira, "Sair" era o elemento
              // mais pesado do Perfil — e ele é a coisa que menos se faz ali. O
              // vermelho fica no texto, que basta para avisar o que é.
              AppGroup(
                dividerIndent: AppGroup.iconIndent,
                children: [
                  AppGroupRow(
                    icon: Icons.wifi_tethering_rounded,
                    title: 'Diagnóstico de conexão',
                    onTap: () => context.push('/diagnostico'),
                  ),
                  AppGroupRow(
                    icon: Icons.logout_rounded,
                    title: 'Sair da conta',
                    tone: AppTone.danger,
                    showChevron: false,
                    onTap: () => _confirmLogout(context, ref),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sair passou a perguntar.
  ///
  /// Era um toque só, num botão que fica logo abaixo de "Tema" — e voltar custa
  /// digitar e-mail e senha, que é justamente o que quem usa o app no meio do
  /// culto não vai querer fazer. A pergunta também lembra que a sessão é do
  /// aparelho, não da equipe.
  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Sair da conta?',
      message: 'Para voltar você vai precisar do e-mail e da senha. As escalas '
          'da equipe continuam onde estão.',
      confirmLabel: 'Sair',
      destructive: true,
    );
    if (!confirmed) return;
    await ref.read(authControllerProvider.notifier).logout();
  }
}

/// Escolha do tema.
///
/// "Sistema" e o padrao e vem primeiro: quem ja deixou o Android no escuro nao
/// precisa configurar nada aqui. As outras duas existem para quem quer o app
/// diferente do resto do aparelho.
class _ThemeModeCard extends ConsumerWidget {
  const _ThemeModeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<ThemeMode>(
          segments: [
            for (final option in ThemeMode.values)
              ButtonSegment(
                value: option,
                icon: Icon(_iconFor(option), size: 18),
                label: Text(themeModeLabel(option)),
              ),
          ],
          selected: {mode},
          showSelectedIcon: false,
          onSelectionChanged: (selection) =>
              ref.read(themeModeProvider.notifier).select(selection.first),
        ),
      ),
    );
  }

  IconData _iconFor(ThemeMode mode) => switch (mode) {
        ThemeMode.system => Icons.brightness_auto_rounded,
        ThemeMode.light => Icons.light_mode_rounded,
        ThemeMode.dark => Icons.dark_mode_rounded,
      };
}

/// A equipe da pessoa, como linha do mesmo grupo.
///
/// Era um cartão só para si, logo abaixo de outro cartão — dois retângulos para
/// duas informações do mesmo assunto.
class _TeamRow extends StatelessWidget {
  const _TeamRow({required this.teams});

  final List<TeamSummary> teams;

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) {
      return const AppGroupRow(
        icon: Icons.groups_outlined,
        title: 'Sem equipe',
        subtitle: 'Você ainda não faz parte de uma equipe.',
        showChevron: false,
      );
    }

    final team = teams.first;
    return AppGroupRow(
      icon: Icons.groups_outlined,
      title: team.name,
      subtitle: 'Sua equipe',
      showChevron: false,
      // O papel virou etiqueta: era uma segunda linha de texto cinza com o
      // mesmo peso do nome da equipe, e "Dono" precisa ser lido como um
      // atributo do vínculo, não como uma informação solta.
      trailing: AppBadge(
        label: roleLabel(team.role),
        tone: team.role == 'MEMBER' ? AppTone.neutral : AppTone.primary,
        semanticsLabel: 'Seu papel na equipe: ${roleLabel(team.role)}',
      ),
    );
  }
}

String roleLabel(String role) => switch (role) {
      'OWNER' => 'Dono',
      'LEADER' => 'Líder',
      _ => 'Membro',
    };
