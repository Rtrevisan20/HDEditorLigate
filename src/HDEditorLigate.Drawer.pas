unit HDEditorLigate.Drawer;

interface

uses
  System.SysUtils,
  Winapi.Windows,
  HDEditorLigate.UTF8;

type
  PIntegerArray = ^TIntegerArray;
  TIntegerArray = array [0 .. MaxInt div SizeOf(Integer) - 1] of Integer;
  TEditorTextOutOptions = set of (tooOpaque, tooClipped);

const
  GCP_CACHE_SIZE = 64;

type
  TGCPKey = record
    TextHash: Cardinal;
    FontHandle: HFont;
    FixedCount: Integer;
  end;

  TGCPEntry = record
    Key: TGCPKey;
    Glyphs: TArray<UINT>;
    nGlyphs: Integer;
    gcpOK: Boolean;
    IsValid: Boolean;
  end;

  { Funcao principal de renderizacao: renderiza texto com suporte a ligaduras.
    Consulta cache de GCP e usa DC memoria persistente para evitar
    CreateCompatibleDC/DeleteDC a cada chamada.
    Se ForceLeftAlign = True, usa TA_LEFT em vez de TA_RIGHT.
    Se ClipRect <> nil, usa este retangulo para clipping em vez de Rect. }
  function UniversalExtTextOut(DC: HDC; X, Y: Integer;
                               Options: TEditorTextOutOptions;
                               Rect: TRect;
                               Str: PWideChar;
                               Count: Integer;
                               ETODist: PIntegerArray;
                               ForceLeftAlign: Boolean = False;
                               ClipRect: PRect = nil): Boolean;

implementation

var
  GMemDC: HDC;
  GMemDCFont: HFont;
  GCPCache: array[0..GCP_CACHE_SIZE - 1] of TGCPEntry;

{ Calcula hash FNV-1a do conteudo WideChar + font handle para chave do cache.
  Overflow intencional na multiplicacao — necessario desabilitar overflow checks. }
{$OVERFLOWCHECKS OFF}
function HashGCPKey(Text: PWideChar; Count: Integer; Font: HFont): TGCPKey;
var
  i: Integer;
  P: PByte;
begin
  Result.TextHash := $811C9DC5;
  P := PByte(Text);
  for i := 0 to Count * SizeOf(WideChar) - 1 do
  begin
    Result.TextHash := Result.TextHash xor P^;
    Result.TextHash := Result.TextHash * $01000193;
    Inc(P);
  end;
  Result.FontHandle := Font;
  Result.FixedCount := Count;
end;
{$OVERFLOWCHECKS ON}

{ Retorna o indice da cache para a chave fornecida }
function GetCacheIndex(const Key: TGCPKey): Integer;
begin
  Result := ((Key.TextHash xor Cardinal(Key.FontHandle) xor
    Cardinal(Key.FixedCount)) mod GCP_CACHE_SIZE);
end;

{ Funcao principal de renderizacao de texto com suporte a ligaduras.
  Fluxo:
  1. Repara texto UTF-8 garbled (ex: acentos duplicados por bug do IDE)
  2. Ajusta largura do rect proporcionalmente quando o texto e reparado
  3. Consulta cache de GCP — se hit, pula etapa 4
  4. Chama GetCharacterPlacement com GCP_LIGATE|GCP_GLYPHSHAPE no DC memorio
  5. Se GCP ok: renderiza glyphs com dx proporcional e ETO_GLYPH_INDEX
  6. Se GCP falhou: renderiza texto normal com dx proporcional (sem ligaduras) }
function UniversalExtTextOut(DC: HDC; X, Y: Integer;
  Options: TEditorTextOutOptions; Rect: TRect; Str: PWideChar;
  Count: Integer; ETODist: PIntegerArray; ForceLeftAlign: Boolean;
  ClipRect: PRect): Boolean;
var
  TextOutFlags: DWORD;
  Glyphs: TArray<UINT>;
  GCP: TGCPResults;
  hFont: Winapi.Windows.HFont;
  dx: TArray<Integer>;
  rectW, i: Integer;
  gcpOK: Boolean;
  FixedBuf: array[0..4095] of WideChar;
  FixedCount: Integer;
  FixedStr: PWideChar;
  CacheKey: TGCPKey;
  CacheIdx: Integer;
  CacheHit: Boolean;
  ClipPtr: PRect;
begin
  ClipPtr := ClipRect;
  if ClipPtr = nil then
    ClipPtr := @Rect;
  TextOutFlags := 0;
  if tooOpaque in Options then
    TextOutFlags := TextOutFlags or ETO_OPAQUE;
  if tooClipped in Options then
    TextOutFlags := TextOutFlags or ETO_CLIPPED;

  if Count <= 0 then
  begin
    Result := False;
    Exit;
  end;

  FixedCount := RepairGarbledUTF8(Str, Count, FixedBuf);

  rectW := Rect.Right - Rect.Left;
  if FixedCount <> Count then
    rectW := rectW * FixedCount div Count;

  FixedStr := @FixedBuf[0];
  gcpOK := False;

  hFont := GetCurrentObject(DC, OBJ_FONT);
  CacheKey := HashGCPKey(FixedStr, FixedCount, hFont);
  CacheIdx := GetCacheIndex(CacheKey);
  CacheHit := GCPCache[CacheIdx].IsValid and
    (GCPCache[CacheIdx].Key.TextHash = CacheKey.TextHash) and
    (GCPCache[CacheIdx].Key.FontHandle = CacheKey.FontHandle) and
    (GCPCache[CacheIdx].Key.FixedCount = CacheKey.FixedCount);

  if CacheHit then
  begin
    Glyphs := GCPCache[CacheIdx].Glyphs;
    GCP.nGlyphs := GCPCache[CacheIdx].nGlyphs;
    gcpOK := GCPCache[CacheIdx].gcpOK;
  end
  else if GMemDC <> 0 then
  begin
    if hFont <> GMemDCFont then
    begin
      SelectObject(GMemDC, hFont);
      GMemDCFont := hFont;
    end;

    SetLength(Glyphs, FixedCount);
    FillChar(GCP, SizeOf(GCP), 0);
    GCP.lStructSize := SizeOf(GCP);
    GCP.lpGlyphs := @Glyphs[0];
    GCP.nGlyphs := FixedCount;

    gcpOK := GetCharacterPlacement(GMemDC, FixedStr, FixedCount, 0, GCP,
      GCP_LIGATE or GCP_GLYPHSHAPE) <> 0;

    GCPCache[CacheIdx].Key := CacheKey;
    GCPCache[CacheIdx].Glyphs := Copy(Glyphs);
    GCPCache[CacheIdx].nGlyphs := GCP.nGlyphs;
    GCPCache[CacheIdx].gcpOK := gcpOK;
    GCPCache[CacheIdx].IsValid := True;
  end;

  if gcpOK then
  begin
    SetLength(dx, GCP.nGlyphs);
    for i := 0 to GCP.nGlyphs - 1 do
      dx[i] := rectW div Integer(GCP.nGlyphs);

    var savedAlign := GetTextAlign(DC);
    if (FixedCount <> Count) or ForceLeftAlign then
      SetTextAlign(DC, (savedAlign and not TA_RIGHT and not TA_CENTER) or TA_LEFT or TA_TOP)
    else
      SetTextAlign(DC, savedAlign or TA_RIGHT or TA_TOP);
    try
      if (FixedCount <> Count) or ForceLeftAlign then
        ExtTextOut(DC, Rect.Left, Y, TextOutFlags or ETO_GLYPH_INDEX,
          ClipPtr, PWideChar(@Glyphs[0]), GCP.nGlyphs, @dx[0])
      else
        ExtTextOut(DC, Rect.Right, Y, TextOutFlags or ETO_GLYPH_INDEX,
          ClipPtr, PWideChar(@Glyphs[0]), GCP.nGlyphs, @dx[0]);
    finally
      SetTextAlign(DC, savedAlign);
    end;
  end
  else
  begin
    SetLength(dx, FixedCount);
    for i := 0 to FixedCount - 1 do
      dx[i] := rectW div FixedCount;
    ExtTextOut(DC, X, Y, TextOutFlags, ClipPtr, FixedStr, FixedCount, @dx[0]);
  end;

  Result := True;
end;

initialization
  GMemDC := CreateCompatibleDC(0);
  GMemDCFont := 0;
finalization
  if GMemDC <> 0 then
    DeleteDC(GMemDC);

end.
