import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/push/push_coordinator.dart';
import '../../../core/push/push_service.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_status_colors.dart';
import '../../../core/theme/theme_mode_controller.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_choice_bar.dart';
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
                    subtitle: 'Nome, e-mail e data de nascimento',
                    onTap: () => context.push('/perfil/dados'),
                  ),
                  AppGroupRow(
                    icon: Icons.lock_outline_rounded,
                    title: 'Alterar senha',
                    subtitle: 'Você precisa da senha atual',
                    onTap: () => context.push('/perfil/senha'),
                  ),
                  const _PushNotificationsRow(),
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

/// O interruptor dos avisos no celular.
///
/// **Diz quando o Android esta bloqueando.** Sem isso o interruptor fica ligado,
/// nada chega, e a culpa parece ser do app -- que e o pior desfecho possivel
/// para uma tela de configuracao.
class _PushNotificationsRow extends ConsumerStatefulWidget {
  const _PushNotificationsRow();

  @override
  ConsumerState<_PushNotificationsRow> createState() =>
      _PushNotificationsRowState();
}

class _PushNotificationsRowState extends ConsumerState<_PushNotificationsRow> {
  bool _saving = false;
  bool _blockedBySystem = false;

  @override
  void initState() {
    super.initState();
    _refreshSystemPermission();
  }

  Future<void> _refreshSystemPermission() async {
    if (!PushService.isSupported) return;
    final permitido = await ref.read(pushServiceProvider).hasPermission();
    if (mounted) setState(() => _blockedBySystem = !permitido);
  }

  Future<void> _toggle(bool value) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(pushEnabled: value);

      if (value) {
        // Religar tem duas metades: a conta volta a aceitar aviso, e o
        // aparelho precisa estar registrado e com permissao. Pedir aqui e o
        // segundo momento legitimo -- a pessoa acabou de dizer que quer.
        final permitido = await ref.read(pushServiceProvider).requestPermission();
        if (mounted) setState(() => _blockedBySystem = !permitido);
        await ref.read(pushCoordinatorProvider).registerDevice();
      }
    } on ApiException catch (error) {
      if (mounted) {
        showAppSnackBar(context, error.message, tone: AppTone.danger);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ligado =
        ref.watch(authControllerProvider).user?.pushEnabled ?? true;

    // Sem push na plataforma (Web e desktop hoje), a linha nao aparece: um
    // interruptor que nao liga nada e pior do que interruptor nenhum.
    if (!PushService.isSupported) return const SizedBox.shrink();

    return AppGroupRow(
      icon: Icons.notifications_active_outlined,
      title: 'Avisos no celular',
      subtitle: ligado && _blockedBySystem
          ? 'Bloqueado nos ajustes do Android'
          : 'Escala publicada, trocas e repertório',
      showChevron: false,
      trailing: Switch(
        value: ligado,
        onChanged: _saving ? null : _toggle,
      ),
    );
  }
}

/// Claro, Escuro e Sistema — no mesmo controle de escolha do resto do app.
///
/// Era um `SegmentedButton`, e num celular estreito ele quebrava: três rótulos
/// com ícone dentro de um cartão com folga de 16px de cada lado não cabem em
/// 320px, e o Material resolvia isso desmanchando o texto em duas linhas
/// dentro do segmento. Quem tem a fonte do sistema aumentada via o mesmo
/// defeito em qualquer largura.
///
/// [AppChoiceBar] em `expanded` é a resposta que o app já tinha: as três
/// opções dividem a largura em partes iguais, cada uma com o mesmo alvo de
/// toque, e quando o rótulo não cabe ao lado do ícone **as três** passam a
/// mostrar o ícone em cima. A folga do cartão encolheu de `lg` para `md` pelo
/// mesmo motivo — são 8px de largura que voltam para os segmentos, e a barra
/// já tem a folga interna dela.
///
/// "Sistema" é o padrão e vem por último, ao lado das duas escolhas manuais:
/// quem já deixou o Android no escuro não precisa mexer aqui.
class _ThemeModeCard extends ConsumerWidget {
  const _ThemeModeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: AppChoiceBar<ThemeMode>(
        expanded: true,
        value: mode,
        onChanged: (option) =>
            ref.read(themeModeProvider.notifier).select(option),
        options: [
          for (final option in [
            ThemeMode.light,
            ThemeMode.dark,
            ThemeMode.system,
          ])
            AppChoice(
              value: option,
              label: themeModeLabel(option),
              icon: _iconFor(option),
            ),
        ],
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
