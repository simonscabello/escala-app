"""Deriva os assets de plataforma a partir dos masters oficiais da marca Pauta.

Execute da raiz de app/:

    python tools/generate_brand_assets.py
    dart run flutter_launcher_icons

O segundo comando gera os recursos Android a partir das fontes em
assets/branding. Os arquivos web são escritos aqui porque o pacote usa a mesma
imagem para ícones normais e maskable, embora eles precisem de bordas distintas.

**Este script não desenha nada.** Antes ele reconstruía a marca a partir de
coordenadas; agora a marca é um arquivo entregue pelo design, e o que sobrou
aqui é recorte, escala e composição — as três coisas que cada plataforma pede
de um jeito diferente e que ninguém quer refazer à mão.

Os masters (não mexer, são a entrega do design):

    pauta_logo.png         símbolo + palavra, horizontal
    pauta_foreground.png   só o símbolo, colorido — para fundo claro
    pauta_monochrome.png   só o símbolo, branco — para fundo escuro
    pauta_icon.png         o ícone completo, símbolo claro sobre violeta

Os derivados (gerados por este script, não editar à mão):

    pauta_adaptive_foreground.png   o símbolo branco recentrado e reduzido
                                    até caber na máscara do Android
    pauta_symbol_on_dark.png        o símbolo branco, recentrado, no tamanho
    pauta_symbol_on_light.png       o colorido — os dois para dentro do app
    web/icons/*, web/favicon.png

Os dois `symbol_*` existem por três motivos que o master sozinho não resolve:
o desenho vem alguns por cento fora do centro da tela, o que num quadrado de
40px aparece como peça torta; vem em 1254², vinte vezes maior do que o app
jamais desenha; e vem com uma margem que não é a que o ladrilho da marca pede.
"""

from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
BRANDING = ROOT / "assets/branding"

# O violeta profundo da marca (AppColors.brandDeepViolet). É o fundo do adaptive
# icon, da splash e do ícone maskable — os três lugares em que o símbolo branco
# precisa de um fundo próprio.
DEEP_VIOLET = (0x31, 0x2E, 0x81)

# Quanto do raio o símbolo pode ocupar em cada máscara, medido do centro da tela
# até o ponto mais distante do desenho.
#
# O Android recorta o ícone adaptativo num círculo de 72dp dentro dos 108dp da
# tela (raio 33,3%) e garante só os 66dp de dentro dele (raio 30,6%). O valor
# aqui é o círculo garantido com uma folga: em 33,3% o P não era cortado, mas
# encostava na borda da máscara, que é o mesmo defeito visto de perto.
#
# O maskable da Web tem a safe zone maior — círculo de 80% do lado, raio 40% —
# e 36% deixa a peça respirando em vez de encostar.
#
# O símbolo entregue ocupa 42,2% de raio: sem esta redução, as pontas do P saem
# cortadas em qualquer lançador que use máscara redonda.
RAIO_ADAPTIVE = 0.29
RAIO_MASKABLE = 0.36

# Dentro do app o símbolo mora num quadrado de canto arredondado, que não
# recorta nada — aqui a folga é só respiro, e a peça pode ser maior do que nas
# máscaras. 0,40 põe o desenho ocupando cerca de dois terços do ladrilho, que é
# onde ele para de parecer um selo colado e ainda não encosta no canto.
RAIO_NO_APP = 0.40
LADO_NO_APP = 512


def _recortar_fundo_preto(caminho: Path) -> Image.Image:
    """Torna transparente o preto que sobra fora do squircle do ícone.

    O master veio achatado sobre preto, e os quatro cantos ficariam pretos no
    favicon e no ícone normal da Web, que esperam canto transparente.

    O recorte é por preenchimento a partir dos cantos, e não por uma máscara
    de retângulo arredondado: o interior do ícone tem regiões quase pretas
    (a soma RGB mais escura ali é 44, contra os 30 do limiar), e um limiar
    global abriria buracos no meio do desenho. Preenchimento só alcança o
    preto que está ligado à borda.

    **Roda uma vez só.** Depois do primeiro corte o arquivo em disco já tem
    canto transparente, e este passo devolve a imagem intacta — repetir o
    desfoque da borda a cada execução comeria um fio do desenho por vez.
    """
    im = Image.open(caminho).convert("RGBA")
    w, h = im.size
    if im.getchannel("A").getpixel((0, 0)) == 0:
        return im
    rgb = im.convert("RGB").load()

    limiar = 30
    visto = bytearray(w * h)
    fila: deque[tuple[int, int]] = deque()
    for x, y in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        if sum(rgb[x, y]) <= limiar and not visto[y * w + x]:
            visto[y * w + x] = 1
            fila.append((x, y))

    while fila:
        x, y = fila.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not visto[ny * w + nx]:
                if sum(rgb[nx, ny]) <= limiar:
                    visto[ny * w + nx] = 1
                    fila.append((nx, ny))

    alfa = Image.frombytes("L", (w, h), bytes(255 if not v else 0 for v in visto))
    # Um fio de suavização na borda: o master é antisserrilhado contra preto, e
    # sem isto o recorte devolve um degrau duro de um pixel.
    alfa = alfa.filter(ImageFilter.GaussianBlur(1.0))
    im.putalpha(alfa)
    return im


def _caixa_visivel(im: Image.Image, limiar: int = 40) -> tuple[int, int, int, int]:
    alfa = im.getchannel("A").point(lambda v: 255 if v > limiar else 0)
    caixa = alfa.getbbox()
    if caixa is None:
        raise ValueError("imagem sem pixels opacos")
    return caixa


def _raio_maximo(im: Image.Image, cx: float, cy: float, limiar: int = 40) -> float:
    """Distância do ponto (cx, cy) até o pixel opaco mais distante."""
    alfa = im.getchannel("A").load()
    w, h = im.size
    maior = 0.0
    for y in range(h):
        for x in range(w):
            if alfa[x, y] > limiar:
                d = (x - cx) ** 2 + (y - cy) ** 2
                if d > maior:
                    maior = d
    return maior**0.5


def simbolo_na_safe_zone(master: Path, lado: int, raio: float) -> Image.Image:
    """O símbolo recentrado e reduzido até caber num círculo de `raio` do lado.

    Recentra pela caixa do desenho, e não pela tela: o master vem alguns por
    cento fora do centro, e num ícone isso aparece como peça torta.
    """
    im = Image.open(master).convert("RGBA")
    x0, y0, x1, y1 = _caixa_visivel(im)
    desenho = im.crop((x0, y0, x1, y1))

    dw, dh = desenho.size
    r_atual = _raio_maximo(desenho, dw / 2, dh / 2)
    fator = (raio * lado) / r_atual

    novo = (max(1, round(dw * fator)), max(1, round(dh * fator)))
    desenho = desenho.resize(novo, Image.Resampling.LANCZOS)

    tela = Image.new("RGBA", (lado, lado), (0, 0, 0, 0))
    tela.alpha_composite(
        desenho,
        ((lado - novo[0]) // 2, (lado - novo[1]) // 2),
    )
    return tela


def icone_maskable(lado: int) -> Image.Image:
    """Fundo cheio da marca com o símbolo branco dentro da safe zone.

    O master do ícone é um squircle: usado como maskable ele apareceria
    recortado dentro do recorte, com os cantos do próprio desenho à mostra. O
    maskable precisa sangrar até a borda, então o fundo é reconstruído na cor
    da marca e o símbolo oficial vai por cima.
    """
    fundo = Image.new("RGBA", (lado, lado), DEEP_VIOLET + (255,))
    fundo.alpha_composite(
        simbolo_na_safe_zone(BRANDING / "pauta_monochrome.png", lado, RAIO_MASKABLE)
    )
    return fundo


def salvar(imagem: Image.Image, caminho: Path) -> None:
    caminho.parent.mkdir(parents=True, exist_ok=True)
    imagem.save(caminho, optimize=True)
    print(f"{caminho.relative_to(ROOT)}  {imagem.size[0]}x{imagem.size[1]}")


def main() -> None:
    icone = _recortar_fundo_preto(BRANDING / "pauta_icon.png")
    salvar(icone, BRANDING / "pauta_icon.png")

    salvar(
        simbolo_na_safe_zone(BRANDING / "pauta_monochrome.png", 1024, RAIO_ADAPTIVE),
        BRANDING / "pauta_adaptive_foreground.png",
    )

    for master, destino in (
        ("pauta_monochrome.png", "pauta_symbol_on_dark.png"),
        ("pauta_foreground.png", "pauta_symbol_on_light.png"),
    ):
        salvar(
            simbolo_na_safe_zone(BRANDING / master, LADO_NO_APP, RAIO_NO_APP),
            BRANDING / destino,
        )

    for lado in (192, 512):
        salvar(
            icone.resize((lado, lado), Image.Resampling.LANCZOS),
            ROOT / f"web/icons/Icon-{lado}.png",
        )
        salvar(icone_maskable(lado), ROOT / f"web/icons/Icon-maskable-{lado}.png")

    salvar(icone.resize((64, 64), Image.Resampling.LANCZOS), ROOT / "web/favicon.png")


if __name__ == "__main__":
    main()
