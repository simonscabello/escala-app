import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../data/hymnal_repository.dart';
import '../domain/hymnal_models.dart';

/// A seção "Hinários" do cadastro de uma música.
///
/// ```
/// Hinários
/// Cantor Cristão 314
/// [ + Adicionar referência ]
/// ```
///
/// **Nenhuma música é obrigada a ter hinário** — a maioria do repertório é
/// cântico, e a seção vazia é só o botão. O que a tela oferece é o que a
/// estrutura anterior não sabia fazer: mais de uma referência na mesma música,
/// desde que em livros diferentes.
///
/// A lista de hinários vem do servidor ([hymnalsProvider]) e não de uma
/// constante em Dart. É a promessa desta estrutura: o quarto hinário entra por
/// uma linha no banco, sem release do APK.
class HymnalRefsField extends ConsumerWidget {
  const HymnalRefsField({
    super.key,
    required this.refs,
    required this.enabled,
    required this.onChanged,
  });

  final List<HymnalRef> refs;
  final bool enabled;
  final ValueChanged<List<HymnalRef>> onChanged;

  /// Grava a referência mantendo **exatamente uma principal**, como o servidor
  /// faz. A tela precisa da mesma regra porque ela desenha o resultado antes
  /// de salvar: sem isto, tirar a principal deixaria a lista sem nenhuma até a
  /// próxima ida à rede.
  void _aplicar(List<HymnalRef> novas) {
    if (novas.isEmpty) {
      onChanged(const []);
      return;
    }

    final marcada = novas.indexWhere((ref) => ref.isPrimary);
    final principal = marcada == -1 ? 0 : marcada;

    onChanged([
      for (var i = 0; i < novas.length; i++)
        HymnalRef(
          hymnalId: novas[i].hymnalId,
          slug: novas[i].slug,
          name: novas[i].name,
          abbreviation: novas[i].abbreviation,
          number: novas[i].number,
          isPrimary: i == principal,
        ),
    ]);
  }

  Future<void> _editar(
    BuildContext context,
    List<Hymnal> hymnals, {
    HymnalRef? atual,
  }) async {
    // Livro que a música já tem não volta ao seletor: o mesmo hinário duas
    // vezes é erro (o hino não tem dois números no mesmo livro), e o servidor
    // recusaria. Só que o que está sendo editado continua disponível, senão o
    // seletor abriria sem a própria escolha.
    final ocupados = refs
        .where((ref) => ref.hymnalId != atual?.hymnalId)
        .map((ref) => ref.hymnalId)
        .toSet();

    final escolha = await showDialog<HymnalRef>(
      context: context,
      builder: (_) => _HymnalRefDialog(
        hymnals: hymnals.where((h) => !ocupados.contains(h.id)).toList(),
        atual: atual,
      ),
    );

    if (escolha == null) return;

    final novas = [...refs];
    final posicao = novas.indexWhere((ref) => ref.hymnalId == atual?.hymnalId);
    posicao == -1 ? novas.add(escolha) : novas[posicao] = escolha;
    _aplicar(novas);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hymnals = ref.watch(hymnalsProvider);
    final disponiveis = hymnals.valueOrNull ?? const <Hymnal>[];

    // Todos os livros já estão na música: não há o que acrescentar.
    final podeAdicionar =
        enabled && disponiveis.length > refs.length && disponiveis.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hinários', style: theme.textTheme.titleSmall),
        Text(
          'O número com que a igreja pede a música. A primeira é a que aparece '
          'na escala.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final item in refs)
          _RefRow(
            item: item,
            enabled: enabled,
            // A principal só se escolhe quando há mais de uma: com uma
            // referência só, a estrela seria um botão que não muda nada.
            showPrimary: refs.length > 1,
            onEdit: () => _editar(context, disponiveis, atual: item),
            onRemove: () => _aplicar(
              refs.where((r) => r.hymnalId != item.hymnalId).toList(),
            ),
            onMakePrimary: () => _aplicar([
              for (final r in refs)
                HymnalRef(
                  hymnalId: r.hymnalId,
                  slug: r.slug,
                  name: r.name,
                  abbreviation: r.abbreviation,
                  number: r.number,
                  isPrimary: r.hymnalId == item.hymnalId,
                ),
            ]),
          ),
        // O erro da lista de hinários não pode travar o formulário: quem abriu
        // para corrigir o tom continua salvando, e o que já está gravado
        // continua na tela (as referências vêm com a música, não daqui).
        if (hymnals.hasError)
          Text(
            'Não foi possível carregar a lista de hinários agora.',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: podeAdicionar
                  ? () => _editar(context, disponiveis)
                  : null,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Adicionar referência'),
            ),
          ),
      ],
    );
  }
}

/// "Cantor Cristão 314", com a estrela de principal, o lápis e o X.
class _RefRow extends StatelessWidget {
  const _RefRow({
    required this.item,
    required this.enabled,
    required this.showPrimary,
    required this.onEdit,
    required this.onRemove,
    required this.onMakePrimary,
  });

  final HymnalRef item;
  final bool enabled;
  final bool showPrimary;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onMakePrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: enabled ? onEdit : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Text(
                  '${item.name} ${item.number}',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
          ),
          if (showPrimary)
            IconButton(
              tooltip: item.isPrimary
                  ? 'Aparece na escala'
                  : 'Usar esta na escala',
              icon: Icon(
                item.isPrimary ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 20,
                color: item.isPrimary ? scheme.primary : scheme.onSurfaceVariant,
              ),
              onPressed: enabled && !item.isPrimary ? onMakePrimary : null,
            ),
          IconButton(
            tooltip: 'Tirar ${item.name}',
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: enabled ? onRemove : null,
          ),
        ],
      ),
    );
  }
}

/// Qual hinário e que número.
///
/// Uma folha só para dois campos porque eles andam juntos: "314" sem o livro
/// não identifica nada, e escolher o livro sem o número não grava referência
/// nenhuma.
class _HymnalRefDialog extends StatefulWidget {
  const _HymnalRefDialog({required this.hymnals, this.atual});

  final List<Hymnal> hymnals;

  /// A referência sendo corrigida, ou nulo quando é uma nova.
  final HymnalRef? atual;

  @override
  State<_HymnalRefDialog> createState() => _HymnalRefDialogState();
}

class _HymnalRefDialogState extends State<_HymnalRefDialog> {
  late final TextEditingController _number = TextEditingController(
    text: widget.atual?.number.toString() ?? '',
  );

  late Hymnal? _hymnal = widget.hymnals.firstWhere(
    (h) => h.id == widget.atual?.hymnalId,
    // Referência nova: o primeiro da lista já vem escolhido. É o hinário que a
    // igreja mais usa (o servidor ordena por isso), e um seletor vazio custaria
    // um toque a mais no caso comum.
    orElse: () => widget.hymnals.first,
  );

  String? _erro;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  void _confirmar() {
    final hymnal = _hymnal;
    if (hymnal == null) return;

    final numero = int.tryParse(_number.text.trim());
    if (numero == null || numero < 1) {
      setState(() => _erro = 'Informe o número do hino.');
      return;
    }

    // O teto é do hinário, e não um 581 escrito no app: era exatamente isso
    // que amarrava tudo ao Cantor Cristão. Hinário sem fim conferido
    // (`maxNumber` nulo) aceita qualquer número — o servidor faz igual.
    final teto = hymnal.maxNumber;
    if (teto != null && numero > teto) {
      setState(() => _erro = '${hymnal.name} vai até $teto.');
      return;
    }

    Navigator.pop(
      context,
      HymnalRef(
        hymnalId: hymnal.id,
        slug: hymnal.slug,
        name: hymnal.name,
        abbreviation: hymnal.abbreviation,
        number: numero,
        isPrimary: widget.atual?.isPrimary ?? false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.atual == null ? 'Adicionar referência' : 'Editar referência',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<Hymnal>(
            initialValue: _hymnal,
            decoration: const InputDecoration(labelText: 'Hinário'),
            items: [
              for (final hymnal in widget.hymnals)
                DropdownMenuItem(value: hymnal, child: Text(hymnal.name)),
            ],
            onChanged: (value) => setState(() {
              _hymnal = value;
              _erro = null;
            }),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _number,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Número',
              errorText: _erro,
              helperText: _hymnal?.maxNumber != null
                  ? 'De 1 a ${_hymnal!.maxNumber}'
                  : null,
            ),
            onSubmitted: (_) => _confirmar(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _confirmar, child: const Text('Aplicar')),
      ],
    );
  }
}
