import 'package:flutter/material.dart';

/// Tokens de cor da identidade Pauta (claro e escuro).
///
/// **A marca é violeta/índigo**, e os três valores que a definem aparecem aqui
/// literalmente, cada um no papel em que faz trabalho:
///
/// | `#4F46E5` | índigo   | `primary` no claro, `inversePrimary` no escuro |
/// | `#312E81` | violeta profundo | texto sobre a tinta clara; tinta no escuro |
/// | `#EDE9FE` | lavanda  | texto sobre o violeta profundo, no escuro |
/// | `#22C55E` | verde    | `success` do tema escuro |
///
/// **Os neutros carregam um traço do violeta da marca** (matiz 246, saturação
/// baixa) em vez de serem cinzas puros. É o que faz a tela parecer de um
/// produto e não de um painel administrativo: sem nomear nenhuma cor, tudo
/// pertence à mesma família. Cinza neutro ao lado de um violeta saturado sempre
/// lê como "tema padrão com a cor trocada". A matiz 246 fica entre o índigo
/// (243) e a lavanda (251) — os neutros são a média da marca, não um quarto
/// tom.
///
/// **A troca de azul para violeta foi feita a luminância constante.** Cada
/// neutro é o antigo com a matiz girada e a claridade reajustada até a
/// luminância relativa (WCAG) bater com a de antes. Não é preciosismo: violeta
/// tem menos verde que azul-ardósia, e o verde pesa 0,72 na fórmula de
/// luminância — girar a matiz mantendo a claridade HSL teria escurecido a
/// paleta inteira e derrubado os contrastes que `test/theme_contrast_test.dart`
/// cobra. Com a luminância presa, **toda a arquitetura tonal abaixo sobrevive
/// intacta à mudança de marca**, e o que muda é só a cor.
///
/// O `#F8FAFC` do enunciado da marca ("background neutral") não é o fundo da
/// página aqui, e a razão está na regra 3: um fundo tão claro não sustenta o
/// cartão branco sem sombra. Ele descreve a *família* do neutro claro, que é o
/// que os tokens de superfície seguem.
///
/// **A página é um passo mais funda que o cartão** porque o cartão não tem
/// sombra. Não é gosto: com a sombra removida, é a diferença de cor que passa a
/// sustentar sozinha a forma do cartão. Cor e elevação são o mesmo orçamento —
/// gastar menos numa exige gastar mais na outra.
///
/// Três regras sustentam a paleta, e cada uma existe porque uma versão anterior
/// falhava nela:
///
/// 1. **O cartão fica um passo acima da página, nos dois temas.** No escuro
///    isso inverte a ordem do Material 3 (lá `surfaceContainerLowest` é mais
///    escuro que `surface`), e a inversão é deliberada: o app usa esse token
///    como "a superfície do cartão", e seguir o M3 fazia o cartão ficar mais
///    escuro que a página — lido como buraco, não como cartão.
/// 2. **Borda de controle tem 3:1** contra o que está atrás dela (WCAG 1.4.11,
///    "non-text contrast"). O `outline` antigo dava 1,45:1 sobre o campo: a
///    borda existia no código e não na tela.
/// 3. **Fundo e cartão precisam se distinguir sem depender só da borda.** O par
///    antigo (#F7F9FC / #FFFFFF) era 1,055:1 — praticamente a mesma cor.
class AppColors {
  const AppColors._();

  // --- A marca, antes de virar papel de tema ---
  //
  // Os três valores da identidade, nomeados pela cor e não pela função. Todo
  // token abaixo que for exatamente um deles aponta para cá: assim a pergunta
  // "onde está o violeta da Pauta?" tem uma resposta, e não seis ocorrências
  // do mesmo hexadecimal espalhadas pelo arquivo.

  /// Índigo. A cor que o app é.
  static const Color brandIndigo = Color(0xFF4F46E5);

  /// Violeta profundo. A superfície de abertura — splash do Android, boot da
  /// Web, splash do Flutter — e a tinta do primário no tema escuro.
  static const Color brandDeepViolet = Color(0xFF312E81);

  /// Lavanda. O claro da marca: texto sobre o violeta profundo.
  static const Color brandLavender = Color(0xFFEDE9FE);

  // --- Light ---

  static const Color lightPrimary = brandIndigo;
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightPrimaryContainer = Color(0xFFE5E3FE);

  /// O violeta profundo da marca, como texto sobre a tinta clara.
  static const Color lightOnPrimaryContainer = brandDeepViolet;

  static const Color lightSecondary = Color(0xFF535076);
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightSecondaryContainer = Color(0xFFE8E6F2);
  static const Color lightOnSecondaryContainer = Color(0xFF282448);

  /// Âmbar: o papel de **atenção**, que não é erro.
  ///
  /// "Falta o tom desta música", "ninguém escalado ainda", "esta pessoa avisou
  /// que não pode" são coisas para notar, não para se assustar — e usar o
  /// vermelho nelas gastava o alarme em situações comuns. O violeta não serve:
  /// ele é a cor do que está certo e do que se toca.
  ///
  /// **Não mudou com a marca**, e é de propósito: âmbar é um papel semântico,
  /// não um tom derivado do primário. Girá-lo junto com os neutros só teria
  /// tirado dele a distância que o faz ser lido como aviso.
  static const Color lightTertiary = Color(0xFF9A4E06);
  static const Color lightOnTertiary = Color(0xFFFFFFFF);
  static const Color lightTertiaryContainer = Color(0xFFFDECD3);
  static const Color lightOnTertiaryContainer = Color(0xFF7A3E00);

  static const Color lightError = Color(0xFFB3261E);
  static const Color lightOnError = Color(0xFFFFFFFF);
  static const Color lightErrorContainer = Color(0xFFF9DEDC);
  static const Color lightOnErrorContainer = Color(0xFF410E0B);

  /// Verde: o papel de **deu certo**, e só isso.
  ///
  /// Era o buraco da paleta. "Escala salva", "convite copiado" e "senha
  /// alterada" saíam no cinza-escuro do snackbar padrão, com exatamente o mesmo
  /// peso de "não foi possível carregar" — quem confirmava uma ação tinha de
  /// ler a frase para saber se tinha dado certo. O verde responde antes da
  /// leitura.
  ///
  /// **Não é uma cor de destaque.** Nada nasce verde; ele só aparece depois de
  /// uma ação que terminou bem, e some sozinho. Usar verde para enfeitar
  /// gastaria o sinal.
  ///
  /// O `#22C55E` da marca é claro demais para virar texto sobre o cartão branco
  /// (2,28:1, contra os 4,5:1 exigidos). Ele é o verde do tema **escuro**, onde
  /// a mesma cor entrega 7,5:1; aqui fica a versão escura da mesma matiz.
  static const Color lightSuccess = Color(0xFF0E7B36);
  static const Color lightOnSuccess = Color(0xFFFFFFFF);
  static const Color lightSuccessContainer = Color(0xFFD6F2E1);
  static const Color lightOnSuccessContainer = Color(0xFF0A5224);

  /// A página. Funda o bastante para o cartão branco existir sem sombra.
  static const Color lightSurface = Color(0xFFEEECF7);
  static const Color lightOnSurface = Color(0xFF161236);
  static const Color lightOnSurfaceVariant = Color(0xFF59547F);

  /// A superfície do cartão.
  static const Color lightSurfaceContainerLowest = Color(0xFFFFFFFF);

  /// Preenchimento de campo e cartão discreto.
  static const Color lightSurfaceContainerLow = Color(0xFFF6F5FC);
  static const Color lightSurfaceContainer = Color(0xFFE5E4F3);
  static const Color lightSurfaceContainerHigh = Color(0xFFDCD9EE);
  static const Color lightSurfaceContainerHighest = Color(0xFFD1CEE9);

  /// Borda de controle: campo, botão contornado, o que se toca. 3:1.
  static const Color lightOutline = Color(0xFF807DA3);

  /// Fio de divisão entre blocos, e a borda de cabelo do cartão sem sombra.
  /// Decorativo — separa, não delimita um controle, então não precisa dos 3:1.
  static const Color lightOutlineVariant = Color(0xFFE2E1F0);

  static const Color lightInverseSurface = Color(0xFF1E1C3A);
  static const Color lightOnInverseSurface = Color(0xFFF4F4FB);
  static const Color lightInversePrimary = Color(0xFFB4ABFF);
  static const Color lightScrim = Color(0xFF000000);
  static const Color lightShadow = Color(0xFF000000);

  // --- Dark ---
  static const Color darkPrimary = Color(0xFFB4ABFF);
  static const Color darkOnPrimary = Color(0xFF1E1B4B);

  /// O violeta profundo da marca, como tinta de container no escuro.
  static const Color darkPrimaryContainer = brandDeepViolet;

  /// A lavanda da marca, no valor exato, sobre o violeta profundo.
  static const Color darkOnPrimaryContainer = brandLavender;

  static const Color darkSecondary = Color(0xFFB5B2D2);
  static const Color darkOnSecondary = Color(0xFF282448);
  static const Color darkSecondaryContainer = Color(0xFF353154);
  static const Color darkOnSecondaryContainer = Color(0xFFE8E6F2);

  static const Color darkTertiary = Color(0xFFF0B357);
  static const Color darkOnTertiary = Color(0xFF412402);
  static const Color darkTertiaryContainer = Color(0xFF5A3405);
  static const Color darkOnTertiaryContainer = Color(0xFFFDECD3);

  static const Color darkError = Color(0xFFF2B8B5);
  static const Color darkOnError = Color(0xFF601410);
  static const Color darkErrorContainer = Color(0xFF8C1D18);
  static const Color darkOnErrorContainer = Color(0xFFF9DEDC);

  /// O verde da marca, no valor exato. Ver a nota em [lightSuccess].
  static const Color darkSuccess = Color(0xFF22C55E);
  static const Color darkOnSuccess = Color(0xFF043215);
  static const Color darkSuccessContainer = Color(0xFF124926);
  static const Color darkOnSuccessContainer = Color(0xFFCAF2D9);

  /// A página, e o ponto mais escuro do tema.
  ///
  /// Quase preto, mas **violeta, nunca cinza** — no escuro é onde o traço de
  /// matiz mais aparece, e um cinza puro faria o violeta da marca parecer um
  /// adesivo colado por cima.
  static const Color darkSurface = Color(0xFF0B0916);
  static const Color darkOnSurface = Color(0xFFEDEBF8);
  static const Color darkOnSurfaceVariant = Color(0xFFAFACCB);

  /// A superfície do cartão — **mais clara** que a página, ao contrário do que
  /// o nome do Material 3 sugere. Ver a regra 1 no topo do arquivo.
  static const Color darkSurfaceContainerLowest = Color(0xFF1B1930);

  /// Preenchimento de campo e cartão discreto: acima da página, abaixo do
  /// cartão.
  static const Color darkSurfaceContainerLow = Color(0xFF121122);
  static const Color darkSurfaceContainer = Color(0xFF22203C);
  static const Color darkSurfaceContainerHigh = Color(0xFF2E2A4B);
  static const Color darkSurfaceContainerHighest = Color(0xFF373457);

  static const Color darkOutline = Color(0xFF6B6793);
  static const Color darkOutlineVariant = Color(0xFF302D4C);

  static const Color darkInverseSurface = Color(0xFFECEAF7);
  static const Color darkOnInverseSurface = Color(0xFF1C1A2F);
  static const Color darkInversePrimary = brandIndigo;
  static const Color darkScrim = Color(0xFF000000);
  static const Color darkShadow = Color(0xFF000000);

  // --- A manchete ---
  //
  // **A única superfície do app que é escura nos dois temas.** A próxima
  // escala é a razão de a agenda existir, e ela precisava de um degrau de
  // hierarquia acima do cartão comum — que no tema claro já é branco, o ponto
  // mais alto da escala de superfícies. Não havia para onde subir clareando.
  //
  // Subiu escurecendo: o violeta profundo da marca vira o chão da manchete, e
  // o texto passa a ser branco. É o mesmo movimento do `inverseSurface` do
  // Material (a superfície que se destaca invertendo, e não somando tinta),
  // com a diferença de que aqui ela carrega a cor da marca em vez do neutro.
  //
  // **O gradiente é curto de propósito** — dois passos da mesma matiz, não um
  // arco-íris. O que ele faz é dar profundidade ao bloco sem que nenhuma parte
  // da área fique com contraste diferente da outra: os dois extremos foram
  // escolhidos para que branco e [onHeroVariant] passem o mínimo do WCAG sobre
  // **qualquer** ponto da rampa, e não só sobre a média. `theme_contrast_test`
  // cobra os dois extremos separadamente.
  //
  // No escuro a rampa desce um pouco mais: sobre a página quase preta, o
  // violeta do tema claro brilharia como um anúncio.

  static const Color lightHeroTop = Color(0xFF3F3AA8);
  static const Color lightHeroBottom = brandDeepViolet;
  static const Color darkHeroTop = Color(0xFF3A3596);
  static const Color darkHeroBottom = Color(0xFF241F5C);

  /// Texto sobre a manchete: o que se lê primeiro.
  static const Color onHero = Color(0xFFFFFFFF);

  /// Texto de apoio sobre a manchete.
  ///
  /// Lavanda acinzentada, e não branco com alfa: sobre um gradiente, o alfa
  /// entrega um contraste diferente em cada ponto da rampa — o que passa em
  /// cima reprova embaixo. Uma cor opaca tem uma razão só, e ela é medida.
  static const Color onHeroVariant = Color(0xFFC7C3F0);

  /// A rampa da manchete, do topo para a base.
  static LinearGradient heroGradient(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? const [darkHeroTop, darkHeroBottom]
          : const [lightHeroTop, lightHeroBottom],
    );
  }

  /// Os dois extremos da rampa, para quem precisa medir contraste contra ela.
  static List<Color> heroRamp(Brightness brightness) {
    return brightness == Brightness.dark
        ? const [darkHeroTop, darkHeroBottom]
        : const [lightHeroTop, lightHeroBottom];
  }

  static ColorScheme lightScheme() {
    return const ColorScheme(
      brightness: Brightness.light,
      primary: lightPrimary,
      onPrimary: lightOnPrimary,
      primaryContainer: lightPrimaryContainer,
      onPrimaryContainer: lightOnPrimaryContainer,
      secondary: lightSecondary,
      onSecondary: lightOnSecondary,
      secondaryContainer: lightSecondaryContainer,
      onSecondaryContainer: lightOnSecondaryContainer,
      tertiary: lightTertiary,
      onTertiary: lightOnTertiary,
      tertiaryContainer: lightTertiaryContainer,
      onTertiaryContainer: lightOnTertiaryContainer,
      error: lightError,
      onError: lightOnError,
      errorContainer: lightErrorContainer,
      onErrorContainer: lightOnErrorContainer,
      surface: lightSurface,
      onSurface: lightOnSurface,
      onSurfaceVariant: lightOnSurfaceVariant,
      surfaceContainerLowest: lightSurfaceContainerLowest,
      surfaceContainerLow: lightSurfaceContainerLow,
      surfaceContainer: lightSurfaceContainer,
      surfaceContainerHigh: lightSurfaceContainerHigh,
      surfaceContainerHighest: lightSurfaceContainerHighest,
      outline: lightOutline,
      outlineVariant: lightOutlineVariant,
      inverseSurface: lightInverseSurface,
      onInverseSurface: lightOnInverseSurface,
      inversePrimary: lightInversePrimary,
      scrim: lightScrim,
      shadow: lightShadow,
    );
  }

  static ColorScheme darkScheme() {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: darkPrimary,
      onPrimary: darkOnPrimary,
      primaryContainer: darkPrimaryContainer,
      onPrimaryContainer: darkOnPrimaryContainer,
      secondary: darkSecondary,
      onSecondary: darkOnSecondary,
      secondaryContainer: darkSecondaryContainer,
      onSecondaryContainer: darkOnSecondaryContainer,
      tertiary: darkTertiary,
      onTertiary: darkOnTertiary,
      tertiaryContainer: darkTertiaryContainer,
      onTertiaryContainer: darkOnTertiaryContainer,
      error: darkError,
      onError: darkOnError,
      errorContainer: darkErrorContainer,
      onErrorContainer: darkOnErrorContainer,
      surface: darkSurface,
      onSurface: darkOnSurface,
      onSurfaceVariant: darkOnSurfaceVariant,
      surfaceContainerLowest: darkSurfaceContainerLowest,
      surfaceContainerLow: darkSurfaceContainerLow,
      surfaceContainer: darkSurfaceContainer,
      surfaceContainerHigh: darkSurfaceContainerHigh,
      surfaceContainerHighest: darkSurfaceContainerHighest,
      outline: darkOutline,
      outlineVariant: darkOutlineVariant,
      inverseSurface: darkInverseSurface,
      onInverseSurface: darkOnInverseSurface,
      inversePrimary: darkInversePrimary,
      scrim: darkScrim,
      shadow: darkShadow,
    );
  }
}
