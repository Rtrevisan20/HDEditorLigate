# HDEditorLigate

Plugin para o IDE Delphi que adiciona suporte a **ligaduras tipográficas** no editor de código-fonte.

Flechas (`->`, `=>`, `-->`, `==>`), comparações (`<>`, `===`) e outros operadores são renderizados com ligaduras nativas da fonte, sem alterar o comportamento do editor.

![Delphi IDE with ligatures](https://img.shields.io/badge/Delphi-Plugin-blue) ![License](https://img.shields.io/badge/License-MIT-green)

---

## Funcionalidades

- **Ligaduras tipográficas** — Operadores como `->`, `=>`, `-->`, `===`, `<>` são fundidos visualmente
- **Correção UTF-8** — Corrige automaticamente caracteres acentuados corrompidos pelo bug do IDE (ex: `ç` vira `Ã§`)
- **Toggle pelo menu de contexto** — Ative/desative as ligaduras diretamente pelo menu de contexto do editor (clique direito)
- **Cache de performance** — Resultados de ligaduras são cacheados para tokens repetidos, eliminando recálculos
- **Espaçamento proporcional** — Texto mantém alinhamento correto entre fragmentos do editor
- **Compatível com múltiplas fontes** — Funciona com JetBrains Mono, Fira Code, Cascadia Code, Iosevka, e outras com suporte a ligaduras

---

## Como Funciona

O plugin intercepta o callback `OnEditorPaintText` do IDE e sobrepõe a pintura padrão do texto:

1. **Correção UTF-8** — Decodifica bytes UTF-8 que foram interpretados incorretamente como code page 1252
2. **Cache GCP** — Consulta cache de 64 entradas (hash FNV-1a) para tokens já processados
3. **GCP (GetCharacterPlacement)** — Usa `GCP_LIGATE | GCP_GLYPHSHAPE` em DC isolado para obter glifos com ligaduras
4. **Renderização** — Desenha os glifos com `ExtTextOut` + `ETO_GLYPH_INDEX` e espaçamento proporcional ao retângulo do editor

```
IDE chama PaintText(texto, rect)
  → FillRect(drawRect) com ajuste de gutter
  → RepairGarbledUTF8(texto)
  → Cache lookup (FNV-1a hash)
    → HIT: copia glyphs do cache
    → MISS: GCP em DC persistente + salva no cache
  → ExtTextOut com ETO_GLYPH_INDEX + ClipRect separado (gutter)
```

---

## Requisitos

- **Delphi** — Embarcadero Delphi 11+ (testado com Delphi 11 a 13)
- **Plataforma** — Windows (Win32)
- **Fonte com ligaduras** — Instale uma fonte que suporte ligaduras (ex: [JetBrains Mono](https://www.jetbrains.com/mono/))

---

## Instalação

1. Abra o projeto `HDEditorLigate.dproj` no Delphi
2. Compile o package (Build)
3. Instale o package via `Component > Install Packages`
4. Reinicie o IDE

Ou copie o `.bpl` compilado para a pasta de plugins do Delphi e instale manualmente.

---

## Uso

Após a instalação, o plugin ativa automaticamente. Para usar ligaduras:

1. Configure uma fonte com suporte a ligaduras no editor (`Tools > Options > Editor > Font`)
2. Fontes recomendadas: JetBrains Mono, Fira Code, Cascadia Code, Iosevka, Hasklig, DejaVu Sans Mono
3. O editor passará a renderizar operadores com ligaduras imediatamente
4. Para alternar ligaduras ON/OFF, clique com o botão direito no editor e selecione **Toggle Ligatures** (um ✓ indica que está ativo)
5. Configure a fonte usando o Font Preview e aplique a fonte direto dessa tela.

Ligaduras ON: ![LigadurasON](https://github.com/Rtrevisan20/HDEditorLigate/blob/master/Resources/LigadurasON.jpg)

Ligaduras OFF: ![LigadurasOFF](https://github.com/Rtrevisan20/HDEditorLigate/blob/master/Resources/LigadurasOFF.jpg)

Font Preview:
![Ativar Font Preview](https://github.com/Rtrevisan20/HDEditorLigate/blob/master/Resources/AtivarFontPreview.jpg)
![Font Preview](https://github.com/Rtrevisan20/HDEditorLigate/blob/master/Resources/FontPreview.jpg)

---

## Estrutura do Projeto

```
HDEditorLigate/
├── src/
│   ├── HDEditorLigate.Main.pas      # Wizard do plugin e callback de pintura
│   ├── HDEditorLigate.Drawer.pas    # Renderização com GCP, cache e DC persistente
│   ├── HDEditorLigate.FontPreview.pas # Preview de fontes com ligaduras
│   └── HDEditorLigate.UTF8.pas      # Correção de texto UTF-8 garbled
├── HDEditorLigate.dpk               # Package do Delphi
├── HDEditorLigate.dproj             # Projeto do Delphi
└── README.md
```

### Módulos

| Arquivo           | Responsabilidade                                                                                                                             |
| ----------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `Main.pas`        | Wizard do IDE, intercepta `OnEditorPaintText`, configura cores de sintaxe, itens **Toggle Ligatures** e **Font Preview** no menu de contexto |
| `Drawer.pas`      | Função `UniversalExtTextOut` — cache GCP, DC persistente, renderização de ligaduras, `ClipRect` separado para gutter                         |
| `FontPreview.pas` | Diálogo `TfrmFontPreview` — lista fontes monoespaçadas, preview com ligaduras, aplica fonte ao editor                                        |
| `UTF8.pas`        | Função `RepairGarbledUTF8` — decodifica bytes UTF-8 corrompidos pelo IDE                                                                     |

---

## Limitações Conhecidas

- **Apenas Windows** — Plugin usa APIs Win32 (GDI) diretamente

---

## Licença

MIT
