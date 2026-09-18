import 'package:flutter/widgets.dart';

/// Marca um pedaço da tela que o tour sabe destacar.
///
/// **Não muda nada no desenho.** Só se inscreve pelo [id] enquanto está na
/// tela, para o tour achar onde ele está sem que cada tela precise conhecer o
/// tour. Os nomes estão em `TourTargetIds`.
///
/// Se o mesmo [id] estiver duas vezes na árvore (a página que sai e a que
/// entra, durante a transição), vale o último a entrar — e sair não apaga a
/// inscrição de quem chegou depois.
class TourTarget extends StatefulWidget {
  const TourTarget({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  /// Onde o alvo está agora, ou nulo se ele não está na tela.
  static BuildContext? contextOf(String id) {
    final state = _registry[id];
    if (state == null || !state.mounted) return null;
    return state.context;
  }

  static final Map<String, _TourTargetState> _registry = {};

  @override
  State<TourTarget> createState() => _TourTargetState();
}

class _TourTargetState extends State<TourTarget> {
  @override
  void initState() {
    super.initState();
    TourTarget._registry[widget.id] = this;
  }

  @override
  void didUpdateWidget(TourTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      _unregister(oldWidget.id);
      TourTarget._registry[widget.id] = this;
    }
  }

  @override
  void dispose() {
    _unregister(widget.id);
    super.dispose();
  }

  void _unregister(String id) {
    if (identical(TourTarget._registry[id], this)) {
      TourTarget._registry.remove(id);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
