/// Uma pergunta da Central de Ajuda.
///
/// [answer] aceita um único realce: `**assim**` sai em negrito. Serve para os
/// nomes que a pessoa procura na tela ("**Minha disponibilidade**"), e para
/// nada além disso — resposta que precisa de lista ou link é resposta longa
/// demais para esta tela.
class FaqEntry {
  const FaqEntry({required this.question, required this.answer});

  final String question;
  final String answer;
}

/// As perguntas frequentes, na ordem em que a pessoa costuma precisar delas.
///
/// **Cada resposta descreve o app como ele é hoje**, conferida no código e na
/// tela: nome dos botões, onde ficam, o que acontece. Mudou uma tela, mude a
/// resposta junto — uma ajuda que manda procurar um botão que não existe é
/// pior do que nenhuma. Pergunta nova é uma entrada a mais nesta lista.
const helpFaq = <FaqEntry>[
  FaqEntry(
    question: 'Como vejo minhas próximas escalas?',
    answer: 'Em **Início**, o cartão em destaque mostra a sua próxima escala: '
        'o dia, o horário, a sua função e o ensaio. Toque nele para ver a '
        'escala completa.\n\n'
        'Para ver todas as escalas da equipe, abra a **Agenda**. Em '
        '**Minhas escalas**, aparecem só aquelas em que você está.',
  ),
  FaqEntry(
    question: 'Onde encontro as músicas que preciso preparar?',
    answer: 'Abra a sua escala (pelo cartão de **Início** ou pela **Agenda**) '
        'e desça até **Músicas**. Toque em uma música para ver o tom '
        'combinado para aquela escala, a letra, a cifra e os links de vídeo e '
        'áudio.\n\n'
        'Se a lista estiver vazia, os líderes ainda não definiram as músicas. '
        'Em **Início**, o atalho **Músicas novas** mostra as que a equipe está '
        'aprendendo.',
  ),
  FaqEntry(
    question: 'Onde encontro letras e cifras?',
    answer: 'Toque em uma música, na escala ou no **Repertório**. Ali aparecem '
        '**Cifra**, **Letra**, **YouTube** e **Spotify**. Quando a letra está '
        'guardada no Pauta, ela abre no próprio aplicativo; os outros abrem no '
        'site ou no aplicativo de cada um.\n\n'
        'Se aparecer "Sem link", a equipe ainda não cadastrou aquele material.',
  ),
  FaqEntry(
    question: 'Como informo minha disponibilidade?',
    answer: 'Abra **Minha disponibilidade**: ela fica em **Início**, nos '
        'acessos rápidos, e no **Perfil**. Toque em **Escolher dias**, marque '
        'no calendário os dias em que você não pode servir (podem ser vários), '
        'escreva o motivo se quiser e toque em **Confirmar**.\n\n'
        'Para voltar a ficar disponível, toque no X ao lado do dia. Para mudar '
        'o motivo, toque no próprio dia.\n\n'
        'Os líderes veem esses dias na hora de montar as escalas. Manter tudo '
        'atualizado evita que você seja escalado num dia em que não pode.',
  ),
  FaqEntry(
    question: 'Como acompanho os compromissos da equipe?',
    answer: 'Na **Agenda**. Os dias pintados no calendário têm compromisso: as '
        'escalas, com o horário do ensaio quando houver, e os eventos da '
        'equipe, como reuniões e confraternizações. Toque num dia para ver o '
        'que está marcado; logo abaixo ficam os próximos compromissos.\n\n'
        'Em **Início**, o **Próximo evento** mostra o próximo evento da equipe.',
  ),
  FaqEntry(
    question: 'Como sugiro uma música?',
    answer:
        'Abra **Sugestões** (em **Início** ou na aba **Equipe**) e toque em '
        '**Sugerir**. Procure a música, escolha se ela é para o repertório ou '
        'para uma data e conte por que ela faria bem à equipe — essa parte é '
        'obrigatória. Os links de letra, Spotify e YouTube são opcionais.\n\n'
        'Os líderes respondem, e você acompanha em **Sugestões**, nas abas '
        '**Abertas** e **Encerradas**. Também dá para sugerir pelo '
        '**Repertório**.',
  ),
  FaqEntry(
    question: 'Não estou recebendo notificações. O que faço?',
    answer: 'Os avisos chegam pelo aplicativo do Pauta para Android. A versão '
        'web não recebe notificações.\n\n'
        'No celular, abra o **Perfil** e confira se **Avisos no celular** está '
        'ligado. Se aparecer "Bloqueado nos ajustes do Android", libere as '
        'notificações do Pauta nos ajustes do celular.\n\n'
        'Se ainda assim nada chegar, saia da conta e entre de novo: isso '
        'registra o seu celular outra vez. Lembre que só as escalas já '
        'publicadas pelos líderes geram aviso.',
  ),
  FaqEntry(
    question: 'Posso fazer parte de mais de uma equipe?',
    answer: 'Sim. A mesma conta pode participar de mais de uma equipe. Quando '
        'isso acontece, o nome da equipe aparece no topo de **Início** e da '
        '**Agenda**: toque nele para trocar. No **Perfil**, a linha da equipe '
        'também faz a troca.\n\n'
        'Escalas, músicas e disponibilidade são separadas por equipe. Confira '
        'qual equipe está selecionada antes de marcar seus dias.',
  ),
  FaqEntry(
    question: 'Como altero meus dados ou preferências?',
    answer: 'Tudo fica no **Perfil**:\n\n'
        '**Meus dados**: nome, e-mail, data de nascimento e gênero.\n'
        '**Foto**: toque na sua foto, no alto da tela.\n'
        '**Alterar senha**: você vai precisar da senha atual.\n'
        '**Aparência**: Claro, Escuro ou Sistema (igual ao do aparelho).\n'
        '**Avisos no celular**: só no aplicativo para Android.\n\n'
        'As funções que você exerce e o telefone da equipe são cadastrados '
        'pelos líderes.',
  ),
];
