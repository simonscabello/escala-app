/// Em que momento do culto uma música da escala entra.
///
/// **Espelho do enum `ServiceMoment` do servidor**, na ordem em que os
/// momentos acontecem no culto — e não em ordem alfabética. A chave é o valor
/// que viaja no JSON; o valor é o rótulo que aparece na tela, mesma divisão de
/// trabalho de [songThemes].
///
/// Fica aqui, e não numa chamada à API, porque é vocabulário fechado: não há
/// tela que crie momento, a lista é a mesma para toda equipe, e buscá-la pela
/// rede atrasaria a abertura do formulário para entregar um texto que não
/// muda. Hinário é o contrário — aquilo é cadastro, e vem do servidor.
///
/// `OUTRO` é a válvula que impede a lista de crescer a cada denominação nova:
/// o que não cabe aqui entra com o nome escrito à mão.
const Map<String, String> serviceMoments = {
  'PRELUDIO': 'Prelúdio',
  'ABERTURA': 'Abertura',
  'DIZIMOS_E_OFERTAS': 'Dízimos e Ofertas',
  'LOUVOR': 'Momento de Louvor',
  'ESPECIAL': 'Música Especial',
  'POSLUDIO': 'Pós-lúdio',
  'OUTRO': 'Outro',
};

/// O valor de [serviceMoments] que exige um nome escrito à mão.
const String otherServiceMoment = 'OUTRO';

/// Como o momento aparece na tela e na mensagem.
///
/// Em `OUTRO`, o que a pessoa escreveu — "Santa Ceia" diz mais do que "Outro",
/// que não diz nada. Sem texto, o rótulo genérico ainda serve: ela marcou que
/// há um momento, só não o nomeou.
///
/// Nulo quando não há momento nenhum. **Nada de "—" nem de "Sem momento"**: a
/// maioria das músicas de uma escala não tem momento nomeado, e um marcador de
/// campo vazio em cada linha encheria a tela de nada.
String? serviceMomentLabel(String? moment, [String? customLabel]) {
  if (moment == null || moment.isEmpty) return null;

  if (moment == otherServiceMoment) {
    final escrito = customLabel?.trim() ?? '';
    if (escrito.isNotEmpty) return escrito;
  }

  // Momento que o servidor conhece e esta versão do app ainda não: o valor
  // cru é feio, mas é melhor que sumir com a informação até o próximo APK.
  return serviceMoments[moment] ?? moment;
}
