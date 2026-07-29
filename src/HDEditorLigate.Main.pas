unit HDEditorLigate.Main;

interface

uses
  ToolsAPI,
  System.Classes,
  ToolsAPI.Editor,
  Vcl.Menus,
  WinApi.Windows;

type
  { Wizard principal do plugin que intercepta a pintura do editor de codigo.
    Registra um notificador de eventos de editor e sobrepoe a pintura do texto
    para renderizar ligaduras (ex: ->, ===, -->, etc) usando GDI.}
  TIDEWizard = class(TNotifierObject, IOTAWizard)
  private
    FEditorEventsNotifier: Integer;
    FEditorOptions: INTACodeEditorOptions;
    FLigateMenuItem: TMenuItem;
    procedure PaintText(const Rect: TRect; const ColNum: SmallInt;
      const Text: string; const SyntaxCode: TOTASyntaxCode;
      const Hilight, BeforeEvent: Boolean; var AllowDefaultPainting: Boolean;
      const Context: INTACodeEditorPaintContext);
    procedure ToggleLigateClick(Sender: TObject);
    procedure EditorPopupPopup(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;
    function GetIDString: string;
    procedure Execute;
    function GetName: string;
    function GetState: TWizardState;
  end;

  { Notificador de eventos do editor que permite interceptar eventos de pintura.
    O unico evento permitido e cevPaintTextEvents. }
  TCodeEditorNotifier = class(TNTACodeEditorNotifier)
  protected
    function AllowedEvents: TCodeEditorEvents; override;
  end;

procedure Register;

implementation

uses
  HDEditorLigate.Drawer,
  System.SysUtils,
  Vcl.Forms,
  Vcl.Graphics;

var
  { Quando True, intercepta a pintura do editor para renderizar ligaduras.
    Quando False, permite que o IDE pinte o texto normalmente. }
  LigateEnabled: Boolean = True;

  { Guarda para evitar crash no uninstall }
  ShuttingDown: Boolean = False;

{ Registra o wizard no package do Delphi IDE }
procedure Register;
begin
  RegisterPackageWizard(TIDEWizard.Create);
end;

{ TIDEWizard }

{ Cria o wizard, registra o notificador de eventos e configura o callback de pintura }
constructor TIDEWizard.Create;
begin
  inherited;
  var LNotifier := TCodeEditorNotifier.Create;
  var LEditorServices: INTACodeEditorServices;
  if Supports(BorlandIDEServices, INTACodeEditorServices, LEditorServices) then
  begin
    FEditorEventsNotifier := LEditorServices.AddEditorEventsNotifier(LNotifier);
    FEditorOptions := LEditorServices.Options;
  end else
    FEditorEventsNotifier := -1;
  LNotifier.OnEditorPaintText := PaintText;

  FLigateMenuItem := nil;
  var LEditorServices2: IOTAEditorServices;
  if Supports(BorlandIDEServices, IOTAEditorServices, LEditorServices2) then
  begin
    var LEditView := LEditorServices2.TopView;
    if (LEditView <> nil) and (LEditView.GetEditWindow <> nil) then
    begin
      var LPopup := TPopupMenu(LEditView.GetEditWindow.Form.FindComponent('EditorLocalMenu'));
      if LPopup <> nil then
      begin
        FLigateMenuItem := TMenuItem.Create(LPopup);
        FLigateMenuItem.Caption := 'Toggle Ligatures';
        FLigateMenuItem.OnClick := ToggleLigateClick;
        LPopup.Items.Add(FLigateMenuItem);
        LPopup.OnPopup := EditorPopupPopup;
      end;
    end;
  end;
end;

{ Remove o notificador de eventos ao destruir o wizard }
destructor TIDEWizard.Destroy;
begin
  ShuttingDown := True;

  if FLigateMenuItem <> nil then
  begin
    var LPopup := FLigateMenuItem.GetParentMenu as TPopupMenu;
    if LPopup <> nil then
      LPopup.Items.Remove(FLigateMenuItem);
    FLigateMenuItem.Free;
    FLigateMenuItem := nil;
  end;

  var LEditorServices: INTACodeEditorServices;
  if Supports(BorlandIDEServices, INTACodeEditorServices, LEditorServices) and
    (FEditorEventsNotifier <> -1) and Assigned(LEditorServices) then
    LEditorServices.RemoveEditorEventsNotifier(FEditorEventsNotifier);

  inherited;
end;

procedure TIDEWizard.Execute;
begin
end;

function TIDEWizard.GetIDString: string;
begin
  Result := '[FB1A6A46-3376-4E3A-AA88-FE4E3F3085A3]';
end;

function TIDEWizard.GetName: string;
begin
  Result := 'HDEditor.Ligate';
end;

function TIDEWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

{ Callback de pintura de texto do IDE.
  Interrompe a pintura padrao e renderiza o texto com ligaduras.
  Ajusta o rect para nao sobrepor o gutter e configura cores de syntax.
  Chama UniversalExtTextOut para renderizar com suporte a ligaduras. }
procedure TIDEWizard.PaintText(const Rect: TRect; const ColNum: SmallInt;
  const Text: string; const SyntaxCode: TOTASyntaxCode;
  const Hilight, BeforeEvent: Boolean; var AllowDefaultPainting: Boolean;
  const Context: INTACodeEditorPaintContext);
var
  drawRect: TRect;
  gutterWidth: Integer;
  lineState: INTACodeEditorLineState;
begin
  if BeforeEvent or Hilight then
  begin
    if not LigateEnabled then
    begin
      AllowDefaultPainting := True;
      Exit;
    end;

    AllowDefaultPainting := False;

    drawRect := Rect;

    if Context.LineState <> nil then
    begin
      lineState := Context.LineState;
      gutterWidth := lineState.GutterRect.Width + lineState.GutterLineDataRect.Width;
      if drawRect.Left < gutterWidth then
        drawRect.Left := gutterWidth;
    end;

    Context.Canvas.Font.Color := FEditorOptions.FontColor[SyntaxCode];
    Context.Canvas.Font.Style := FEditorOptions.FontStyles[SyntaxCode];
    Context.Canvas.FillRect(drawRect);

    var DC := Context.Canvas.Handle;
    SetTextColor(DC, ColorToRGB(FEditorOptions.FontColor[SyntaxCode]));
    SetBkColor(DC, ColorToRGB(Context.Canvas.Brush.Color));

    UniversalExtTextOut(DC, drawRect.Left, drawRect.Top,
      [tooOpaque, tooClipped], drawRect,
      PWideChar(Text), Length(Text), nil);
  end;
end;

{ TCodeEditorNotifier }

{ Permite apenas eventos de pintura de texto (cevPaintTextEvents) }
function TCodeEditorNotifier.AllowedEvents: TCodeEditorEvents;
begin
  Result := [cevPaintTextEvents];
end;

{ ToggleLigateClick / EditorPopupPopup }

procedure TIDEWizard.ToggleLigateClick(Sender: TObject);
var
  LEditorServices: IOTAEditorServices;
  LView: IOTAEditView;
  LEditWindow: INTAEditWindow;
begin
  LigateEnabled := not LigateEnabled;

  if Supports(BorlandIDEServices, IOTAEditorServices, LEditorServices) then
  begin
    LView := LEditorServices.TopView;
    if LView <> nil then
    begin
      LEditWindow := LView.GetEditWindow;
      if LEditWindow <> nil then
        LEditWindow.Form.Invalidate;
    end;
  end;
end;

procedure TIDEWizard.EditorPopupPopup(Sender: TObject);
begin
  if FLigateMenuItem <> nil then
    FLigateMenuItem.Checked := LigateEnabled;
end;

end.
