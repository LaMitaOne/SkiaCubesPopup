unit Unit9;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, SkiaCubesPopup;

type
  TForm9 = class(TForm)
    Button1: TButton;
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
    // Event handler for when a cube in the popup is clicked
    procedure HandleSegmentClick(Sender: TObject; SegmentIndex: Integer; const SegmentText: string);
  public
    { Public declarations }
  end;

var
  Form9: TForm9;

implementation

{$R *.dfm}

procedure TForm9.HandleSegmentClick(Sender: TObject; SegmentIndex: Integer; const SegmentText: string);
begin
  // Display which segment was clicked
  ShowMessage('Clicked - Index: ' + IntToStr(SegmentIndex) + ', Text: ' + SegmentText);
end;

procedure TForm9.Button1Click(Sender: TObject);
var
  Popup: TSkiaCubesPopup;
  Items: array of string;
begin
  // Define the 6 items for the 3x2 grid
  SetLength(Items, 6);
  Items[0] := '10%';
  Items[1] := '30%';
  Items[2] := '50%';
  Items[3] := '70%';
  Items[4] := '90%';
  Items[5] := '100%';

  Popup := TSkiaCubesPopup.Create(nil);
  Popup.ShowSkiaCubesPopup(Mouse.CursorPos.X,    // Start X
    Mouse.CursorPos.Y,    // Start Y
    20,                   // InnerRadius (Ignored in cube mode)
    60,                   // OuterRadius (Mapped to CubeSize in pixels)
    clGray,               // SegmentColor
    clLime,               // HoverColor
    TColor($00333300),    // BorderColor (Unused currently)
    clAqua,               // TextColor (Unused currently, hardcoded to white internally)
    6,                    // SegmentCount
    Items,                // SegmentText array
    HandleSegmentClick    // OnClick Event
  );
end;

end.

