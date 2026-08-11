import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_avatar.dart';
import '../../auth/application/auth_controller.dart';

/// Casca com a navegação principal.
///
/// Três abas: Agenda (o que a pessoa abre o app para ver), Equipe e Perfil.
/// O perfil virou aba porque leva para "Minha disponibilidade", que deixou de
/// ser um canto de configuração e passou a ser algo que o integrante usa com
/// frequência.
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _tabs = ['/agenda', '/equipe', '/perfil'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    final index = _tabs.indexOf(path);
    // A barra só aparece nas telas de topo; em formulários e detalhes ela
    // atrapalharia o caminho de volta.
    final showNav = index != -1;
    final user = ref.watch(authControllerProvider).user;
    final name = user?.firstName ?? '?';

    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: child,
      // Fio em cima da barra, como no cabeçalho. Sem ele a barra tem a cor do
      // cartão e o conteúdo passa por baixo sem fronteira nenhuma — e agora que
      // os cartões não projetam sombra, não sobrou nada separando os dois.
      bottomNavigationBar: showNav
          ? DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: NavigationBar(
                selectedIndex: index,
                onDestinationSelected: (selected) =>
                    context.go(_tabs[selected]),
                // O rótulo fica sempre visível. Com `onlyShowSelected` os dois
                // ícones não escolhidos viram desenhos mudos, e "grupo de
                // pessoas" versus "calendário" é justamente o par que quem não
                // tem intimidade com aplicativo não decifra sozinho.
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  const NavigationDestination(
                    icon: Icon(Icons.calendar_today_outlined),
                    selectedIcon: Icon(Icons.calendar_today_rounded),
                    label: 'Agenda',
                  ),
                  const NavigationDestination(
                    icon: Icon(Icons.groups_outlined),
                    selectedIcon: Icon(Icons.groups_rounded),
                    label: 'Equipe',
                  ),
                  NavigationDestination(
                    // O avatar como ícone: a aba é sobre a própria pessoa, e
                    // isso identifica melhor que um boneco genérico.
                    icon: AppAvatar(
                      name: name,
                      imageUrl: user?.avatarUrl,
                      radius: 13,
                    ),
                    label: 'Perfil',
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
