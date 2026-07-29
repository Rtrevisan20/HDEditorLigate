unit HDEditorLigate.FontPreview;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  Vcl.Forms,
  Vcl.Controls,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.Graphics,
  ToolsAPI;

type
  TfrmFontPreview = class(TForm)
  private
    cmbFont: TComboBox;
    pnlPreview: TPaintBox;
    btnApply: TButton;
    btnClose: TButton;
    FSampleText: string;
    procedure PopulateFonts;
    procedure cmbFontChange(Sender: TObject);
    procedure pnlPreviewPaint(Sender: TObject);
    procedure btnApplyClick(Sender: TObject);
    procedure btnCloseClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    class procedure Execute;
  end;

implementation

uses
  HDEditorLigate.Drawer,
  HDEditorLigate.Main;

function IsMonospaced(const AName: string): Boolean;
var
  LDC: HDC;
  LFont, LOld: THandle;
  I, M: TSize;
begin
  Result := False;
  LDC := GetDC(0);
  LFont := CreateFont(-12, 0, 0, 0, 0, 0, 0, 0, ANSI_CHARSET,
    OUT_STROKE_PRECIS, CLIP_STROKE_PRECIS, DRAFT_QUALITY,
    DEFAULT_PITCH or FF_ROMAN, PChar(AName));
  if LFont <> THandle(0) then
  begin
    LOld := SelectObject(LDC, LFont);
    GetTextExtentPoint32(LDC, 'i', 1, I);
    GetTextExtentPoint32(LDC, 'm', 1, M);
    Result := I.cx = M.cx;
    SelectObject(LDC, LOld);
    DeleteObject(LFont);
  end;
  ReleaseDC(0, LDC);
end;

class procedure TfrmFontPreview.Execute;
begin
  with TfrmFontPreview.Create(nil) do
  try
    ShowModal;
  finally
    Free;
  end;
end;

constructor TfrmFontPreview.Create(AOwner: TComponent);
var
  Lbl: TLabel;
begin
  inherited CreateNew(AOwner);

  var ThemeSvc: IOTAIDEThemingServices;
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, ThemeSvc) then
  begin
    ThemeSvc.RegisterFormClass(TfrmFontPreview);
    ThemeSvc.ApplyTheme(Self);
  end;

  Caption := 'Font Preview - HDEditorLigate';
  ClientWidth := 500;
  ClientHeight := 300;
  Position := poScreenCenter;
  BorderStyle := bsDialog;
  Font.Name := 'Segoe UI';
  Font.Height := -12;

  Lbl := TLabel.Create(Self);
  Lbl.Parent := Self;
  Lbl.SetBounds(12, 16, 36, 22);
  Lbl.Caption := 'Font:';

  cmbFont := TComboBox.Create(Self);
  cmbFont.Parent := Self;
  cmbFont.SetBounds(48, 14, ClientWidth - 64, 24);
  cmbFont.Style := csDropDownList;
  cmbFont.OnChange := cmbFontChange;

  pnlPreview := TPaintBox.Create(Self);
  pnlPreview.Parent := Self;
  pnlPreview.SetBounds(12, 48, ClientWidth - 24, 200);
  pnlPreview.OnPaint := pnlPreviewPaint;

  btnApply := TButton.Create(Self);
  btnApply.Parent := Self;
  btnApply.SetBounds(ClientWidth - 172, ClientHeight - 36, 75, 25);
  btnApply.Caption := 'Apply';
  btnApply.OnClick := btnApplyClick;

  btnClose := TButton.Create(Self);
  btnClose.Parent := Self;
  btnClose.SetBounds(ClientWidth - 88, ClientHeight - 36, 75, 25);
  btnClose.Caption := 'Close';
  btnClose.OnClick := btnCloseClick;

  FSampleText := 'var txt := ''-> => <== <> === -<''';
  PopulateFonts;
end;

procedure TfrmFontPreview.PopulateFonts;
var
  i, idx: Integer;
  FName: string;
begin
  cmbFont.Items.BeginUpdate;
  try
    for i := 0 to Screen.Fonts.Count - 1 do
    begin
      if IsMonospaced(Screen.Fonts[i]) then
        cmbFont.Items.Add(Screen.Fonts[i]);
    end;
  finally
    cmbFont.Items.EndUpdate;
  end;

  FName := GetEditorFontName;

  idx := cmbFont.Items.IndexOf(FName);
  if idx >= 0 then
    cmbFont.ItemIndex := idx
  else if cmbFont.Items.Count > 0 then
    cmbFont.ItemIndex := 0;
end;

procedure TfrmFontPreview.cmbFontChange(Sender: TObject);
begin
  pnlPreview.Invalidate;
end;

procedure TfrmFontPreview.pnlPreviewPaint(Sender: TObject);
var
  C: TCanvas;
  DC: HDC;
  hFont, OldFont: THandle;
  R: TRect;
  y, Cnt: Integer;
  BkColor, TxColor: TColor;
  MoreSamples: string;
begin
  if cmbFont.ItemIndex < 0 then
    Exit;

  BkColor := GetEditorBackgroundColor;
  TxColor := ColorToRGB(GetEditorFontColor(atWhiteSpace));

  C := pnlPreview.Canvas;
  DC := C.Handle;
  R := pnlPreview.ClientRect;

  C.Brush.Color := BkColor;
  C.FillRect(R);

  hFont := CreateFont(-16, 0, 0, 0, 0, 0, 0, 0, ANSI_CHARSET,
    OUT_STROKE_PRECIS, CLIP_STROKE_PRECIS, CLEARTYPE_QUALITY,
    DEFAULT_PITCH or FF_ROMAN, PChar(cmbFont.Text));
  if hFont = THandle(0) then
    Exit;

  InflateRect(R, -10, -10);
  y := R.Top + 4;

  C.Font.Name := 'Segoe UI';
  C.Font.Height := -12;
  C.Font.Color := TxColor;
  C.TextOut(R.Left + 2, y, Format('Font: %s  |  16pt', [cmbFont.Text]));
  Inc(y, 26);

  OldFont := SelectObject(DC, hFont);
  SetTextColor(DC, TxColor);
  SetBkColor(DC, ColorToRGB(BkColor));
  SetBkMode(DC, OPAQUE);

  Cnt := Length(FSampleText);
  UniversalExtTextOut(DC, R.Left, y, [], R, PWideChar(FSampleText), Cnt, nil, True);
  Inc(y, 36);

  MoreSamples := '->  =>  <==  <>  ===  -<  :=  <--  -->  ==>';
  Cnt := Length(MoreSamples);
  UniversalExtTextOut(DC, R.Left, y, [], R, PWideChar(MoreSamples), Cnt, nil, True);
  Inc(y, 34);

  SelectObject(DC, OldFont);
  DeleteObject(hFont);

  C.Font.Height := -11;
  C.Font.Color := TxColor;
  C.TextOut(R.Left + 2, y, 'Ligaduras via GetCharacterPlacement + ETO_GLYPH_INDEX');
end;

procedure TfrmFontPreview.btnApplyClick(Sender: TObject);
begin
  if cmbFont.ItemIndex < 0 then
    Exit;

  SetEditorFontName(cmbFont.Text);
  Close;
end;

procedure TfrmFontPreview.btnCloseClick(Sender: TObject);
begin
  Close;
end;

end.
