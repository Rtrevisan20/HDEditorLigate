unit HDEditorLigate.UTF8;

interface

{ Repara texto UTF-8 garbled causado por bug do Delphi IDE.
  O IDE Delphi interpreta bytes UTF-8 como code page 1252, gerando caracteres
  duplicados (ex: 'c' com cedilha vira 'Ã§' = U+00C3 + U+00A7).
  Esta funcao decodifica os bytes UTF-8 de volta para o caractere Unicode correto.

  Parametros:
    S       - Ponteiro para o array de WideChar de entrada (garbled)
    Count   - Numero de WideChars de entrada
    OutBuf  - Buffer de saida para os WideChars reparados

  Retorna:
    Numero de WideChars de saida (reparados)

  Algoritmo:
    - Bytes ASCII (<= $7F) sao copiados diretamente
    - Sequencias de 2 bytes ($C0-$DF seguido de $80-$BF) sao decodificadas em Unicode
    - Sequencias de 3 bytes ($E0-$EF seguido de 2x $80-$BF) sao decodificadas em Unicode
    - Bytes invalidos sao copiados como estao }
function RepairGarbledUTF8(S: PWideChar; Count: Integer;
  var OutBuf: array of WideChar): Integer;

implementation

function RepairGarbledUTF8(S: PWideChar; Count: Integer;
  var OutBuf: array of WideChar): Integer;
var
  i, o: Integer;
  B1, B2, B3: Word;
begin
  o := 0;
  i := 0;
  while (i < Count) and (o < Length(OutBuf) - 1) do
  begin
    B1 := Word(S[i]);
    if (B1 <= $7F) then
    begin
      OutBuf[o] := WideChar(B1);
      Inc(o);
      Inc(i);
    end
    else if ((B1 and $E0) = $C0) and (i + 1 < Count) then
    begin
      B2 := Word(S[i + 1]);
      if (B2 and $C0) = $80 then
      begin
        OutBuf[o] := WideChar(((B1 and $1F) shl 6) or (B2 and $3F));
        Inc(o);
        Inc(i, 2);
      end
      else
      begin
        OutBuf[o] := WideChar(B1);
        Inc(o);
        Inc(i);
      end;
    end
    else if ((B1 and $F0) = $E0) and (i + 2 < Count) then
    begin
      B2 := Word(S[i + 1]);
      B3 := Word(S[i + 2]);
      if ((B2 and $C0) = $80) and ((B3 and $C0) = $80) then
      begin
        OutBuf[o] := WideChar(((B1 and $0F) shl 12) or
          ((B2 and $3F) shl 6) or (B3 and $3F));
        Inc(o);
        Inc(i, 3);
      end
      else
      begin
        OutBuf[o] := WideChar(B1);
        Inc(o);
        Inc(i);
      end;
    end
    else
    begin
      OutBuf[o] := WideChar(B1);
      Inc(o);
      Inc(i);
    end;
  end;
  OutBuf[o] := #0;
  Result := o;
end;

end.
