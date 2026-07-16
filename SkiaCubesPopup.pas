{*******************************************************************************
  Skia-CubesPopup; v0.2 (Stable Edition)
********************************************************************************
  A floating 3D-cube grid popup menu rendered via Skia4Delphi.
  Uses the classic VCL Fuchsia transparency approach.
  Text color is currently hardcoded to white internally to bypass
  specific Skia/VCL system-color translation quirks.
*******************************************************************************}

unit SkiaCubesPopup;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Math, System.IOUtils, Vcl.Forms, Vcl.Graphics, Vcl.Controls,
  Vcl.ExtCtrls, Vcl.Imaging.pngimage, Vcl.Imaging.jpeg, Vcl.Skia, Skia, Skia.API;

type
  // Event callback for when a cube is clicked
  TSkiaCubesPopupClickEvent = procedure(Sender: TObject; SegmentIndex: Integer; const SegmentText: string) of object;

  TSkiaCubesPopup = class(TComponent)
  private
    FPopupForm: TForm;
    FPopupImage: TImage;
    FBuffer: TBitmap;
    FSegmentCount: Integer;
    FInnerRadius: Integer;  // Kept for interface compatibility, ignored in cube mode
    FOuterRadius: Integer;  // Reused as the CubeSize in pixels
    FCenter: TPointF;
    FGapAngle: Single;      // Reused as the gap size in pixels between cubes
    FSegmentColor: TColor;
    FHoverColor: TColor;
    FBorderColor: TColor;
    FTextColor: TColor;
    FHoverIndex: Integer;
    FOnSegmentClick: TSkiaCubesPopupClickEvent;
    FSegmentText: TStringList;

    procedure CreatePopupForm(StartX, StartY: Integer);
    function GetSegmentFromMouse(X, Y: Integer): Integer;
    procedure DoDraw;
    procedure PopupFormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure PopupFormClick(Sender: TObject);
    procedure PopupFormClose(Sender: TObject; var Action: TCloseAction);
    procedure PopupFormDeactivate(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ShowSkiaCubesPopup(StartX, StartY: Integer; InnerRadius, OuterRadius: Integer; SegmentColor, HoverColor, BorderColor, TextColor: TColor; SegmentCount: Integer; SegmentText: array of string; OnClick: TSkiaCubesPopupClickEvent);
  end;

implementation

{ TSkiaCubesPopup }

constructor TSkiaCubesPopup.Create(AOwner: TComponent);
begin
  inherited;
  FSegmentText := TStringList.Create;
end;

destructor TSkiaCubesPopup.Destroy;
begin
  // Ensure the popup form is cleaned up if the component is destroyed
  if Assigned(FPopupForm) then
  begin
    FPopupForm.Close;
    FPopupForm := nil;
  end;
  FBuffer.Free;
  FSegmentText.Free;
  inherited;
end;

procedure TSkiaCubesPopup.CreatePopupForm(StartX, StartY: Integer);
var
  CubeSize, TotalWidth, TotalHeight: Integer;
begin
  FPopupForm := TForm.Create(nil);
  FPopupForm.FormStyle := fsStayOnTop;
  FPopupForm.BorderStyle := bsNone;

  // The classic Delphi transparency hack: Fuchsia background becomes transparent
  FPopupForm.Color := clFuchsia;
  FPopupForm.TransparentColor := True;
  FPopupForm.TransparentColorValue := clFuchsia;

  // Calculate grid dimensions dynamically based on item count (Max 3 columns)
  CubeSize := FOuterRadius;
  TotalWidth := 3 * CubeSize + 2 * Round(FGapAngle); // 3 cubes + 2 gaps

  if FSegmentCount <= 3 then
    TotalHeight := CubeSize
  else
    TotalHeight := 2 * CubeSize + Round(FGapAngle); // 2 rows + 1 gap

  FPopupForm.ClientWidth := TotalWidth;
  FPopupForm.ClientHeight := TotalHeight;

  // Position the popup centered above the click point
  FPopupForm.Left := StartX - (TotalWidth div 2);
  FPopupForm.Top := StartY - TotalHeight - 10;

  // Create a TImage to hold the rendered Skia graphics
  FPopupImage := TImage.Create(FPopupForm);
  FPopupImage.Parent := FPopupForm;
  FPopupImage.Align := alClient;
  FPopupImage.Stretch := False;
  FPopupImage.Center := False;
  FPopupImage.Transparent := True; // Let the underlying Fuchsia form show through where needed

  FPopupImage.OnMouseMove := PopupFormMouseMove;
  FPopupImage.OnClick := PopupFormClick;

  FPopupForm.OnClose := PopupFormClose;
  FPopupForm.OnDeactivate := PopupFormDeactivate;

  // Prepare the 32-bit buffer for Skia rendering
  if FBuffer = nil then
  begin
    FBuffer := TBitmap.Create;
    FBuffer.PixelFormat := pf32bit;
    FBuffer.AlphaFormat := afIgnored; // We rely on Fuchsia, not alpha channels
  end;
  FBuffer.SetSize(FPopupForm.ClientWidth, FPopupForm.ClientHeight);

  FPopupImage.Picture.Assign(nil);
  FPopupImage.Picture.Bitmap := FBuffer;
end;

procedure TSkiaCubesPopup.PopupFormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
  FPopupForm := nil;
end;

procedure TSkiaCubesPopup.PopupFormDeactivate(Sender: TObject);
begin
  // Close the popup if the user clicks somewhere else on the screen
  if Assigned(FPopupForm) then
    FPopupForm.Close;
end;

procedure TSkiaCubesPopup.ShowSkiaCubesPopup(StartX, StartY: Integer; InnerRadius, OuterRadius: Integer; SegmentColor, HoverColor, BorderColor, TextColor: TColor; SegmentCount: Integer; SegmentText: array of string; OnClick: TSkiaCubesPopupClickEvent);
var
  I: Integer;
begin
  FInnerRadius := InnerRadius; // Ignored
  FOuterRadius := OuterRadius; // Mapped to CubeSize
  FSegmentCount := SegmentCount;
  FSegmentColor := SegmentColor;
  FHoverColor := HoverColor;
  FBorderColor := BorderColor;
  FTextColor := TextColor;     // Stored, but overridden to white internally during draw
  FOnSegmentClick := OnClick;
  FHoverIndex := -1;
  FGapAngle := 6;              // Default 6px gap between cubes
  FSegmentText.Clear;

  for I := Low(SegmentText) to High(SegmentText) do
    FSegmentText.Add(SegmentText[I]);

  CreatePopupForm(StartX, StartY);
  DoDraw;
  FPopupForm.Show;
end;

procedure TSkiaCubesPopup.DoDraw;
var
  Surface: ISkSurface;
  Canvas: ISkCanvas;
  Paint: ISkPaint;
  SkFont: TSkFont;
  SkTypeface: ISkTypeface;
  SkStyle: TSkFontStyle;
  SkImgInfo: TSkImageInfo;
  SkImage: ISkImage;
  MemStream: TMemoryStream;
  I: Integer;
  CubeSize, Gap: Single;
  Col, Row: Integer;
  X, Y: Single;
  Rect, ShadowRect: TRectF;
  TextSize: TSize;
  TextPos: TPointF;
begin
  // Initialize Skia surface using our VCL buffer dimensions
  SkImgInfo := TSkImageInfo.Create(FBuffer.Width, FBuffer.Height);
  Surface := TSkSurface.MakeRaster(SkImgInfo);

  if Assigned(Surface) then
  begin
    Canvas := Surface.Canvas;
    // Clear with Fuchsia so the VCL transparency hack works
    Canvas.Clear(TAlphaColors.Fuchsia);

    CubeSize := FOuterRadius;
    Gap := FGapAngle;

    Paint := TSkPaint.Create;
    Paint.AntiAlias := False; // Hard edges prevent Fuchsia color bleeding
    Paint.Style := TSkPaintStyle.Fill;

    // --- 1. DRAW CUBES ---
    for I := 0 to FSegmentCount - 1 do
    begin
      // Calculate grid position (max 3 columns)
      Col := I mod 3;
      Row := I div 3;

      X := Col * (CubeSize + Gap);
      Y := Row * (CubeSize + Gap);

      // Draw 3D drop shadow (offset down-right)
      ShadowRect := TRectF.Create(X + 4, Y + 4, X + CubeSize + 4, Y + CubeSize + 4);
      Paint.Color := $FF404040; // Dark gray shadow
      Canvas.DrawRect(ShadowRect, Paint);

      // Draw main cube face
      if I = FHoverIndex then
        Paint.Color := FHoverColor
      else
        Paint.Color := FSegmentColor;

      Rect := TRectF.Create(X, Y, X + CubeSize, Y + CubeSize);
      Canvas.DrawRect(Rect, Paint);
    end;

    // --- 2. DRAW TEXT ---
    SkStyle := TSkFontStyle.Normal;
    SkTypeface := TSkTypeface.MakeFromName('Tahoma', SkStyle);
    SkFont := TSkFont.Create(SkTypeface, 11);

    Paint.Style := TSkPaintStyle.Fill;
    // Hardcoded to white to avoid Skia interpreting VCL system colors incorrectly
    Paint.Color := $FFFFFFFF;

    if Assigned(FPopupForm) then
    begin
      FPopupForm.Canvas.Font.Name := 'Tahoma';
      FPopupForm.Canvas.Font.Size := 11;
    end;

    for I := 0 to FSegmentCount - 1 do
    begin
      if (I < FSegmentText.Count) and (FSegmentText[I] <> '') then
      begin
        // Calculate cube center for text placement
        Col := I mod 3;
        Row := I div 3;
        X := Col * (CubeSize + Gap);
        Y := Row * (CubeSize + Gap);

        TextPos.X := X + (CubeSize / 2);
        TextPos.Y := Y + (CubeSize / 2);

        // Use WinAPI to accurately measure text width for centering
        if Assigned(FPopupForm) then
        begin
          GetTextExtentPoint32(FPopupForm.Canvas.Handle, PChar(FSegmentText[I]), Length(FSegmentText[I]), TextSize);
          TextPos.X := TextPos.X - (TextSize.cx / 2);
          TextPos.Y := TextPos.Y - (TextSize.cy / 2);
        end;

        // Slight Y offset to visually perfectly center the text baseline
        Canvas.DrawSimpleText(FSegmentText[I], TextPos.X, TextPos.Y + (7 * 0.3), SkFont, Paint);
      end;
    end;

    // --- 3. EXPORT TO PNG AND LOAD INTO VCL ---
    SkImage := Surface.MakeImageSnapshot;
    if Assigned(SkImage) then
    begin
      MemStream := TMemoryStream.Create;
      try
        if SkImage.EncodeToStream(MemStream, TSkEncodedImageFormat.PNG) then
        begin
          if MemStream.Size > 0 then
          begin
            MemStream.Position := 0;
            if Assigned(FPopupImage) then
              FPopupImage.Picture.LoadFromStream(MemStream);
          end;
        end;
      finally
        MemStream.Free;
      end;
    end;
  end;
end;

procedure TSkiaCubesPopup.PopupFormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  NewIndex: Integer;
begin
  NewIndex := GetSegmentFromMouse(X, Y);
  if FHoverIndex <> NewIndex then
  begin
    FHoverIndex := NewIndex;
    DoDraw; // Redraw to show hover color
    if Assigned(FPopupImage) then
      FPopupImage.Invalidate;
  end;
end;

procedure TSkiaCubesPopup.PopupFormClick(Sender: TObject);
var
  Index: Integer;
  Pt: TPoint;
begin
  Pt := FPopupImage.ScreenToClient(Mouse.CursorPos);
  Index := GetSegmentFromMouse(Pt.X, Pt.Y);

  if (Index >= 0) and Assigned(FOnSegmentClick) then
  begin
    // Invert index to match visual top-left to bottom-right reading order
    Index := FSegmentCount - 1 - Index;
    FOnSegmentClick(Self, Index, FSegmentText[Index]);
  end;

  if Assigned(FPopupForm) then
    FPopupForm.Close;
end;

function TSkiaCubesPopup.GetSegmentFromMouse(X, Y: Integer): Integer;
var
  CubeSize, Gap: Single;
  Col, Row: Integer;
  CubeX, CubeY: Single;
begin
  Result := -1;
  CubeSize := FOuterRadius;
  Gap := FGapAngle;

  // Determine which grid cell the mouse is over
  Col := Trunc(X / (CubeSize + Gap));
  Row := Trunc(Y / (CubeSize + Gap));

  // Boundary check: max 3 columns, max 2 rows
  if (Col > 2) or (Row > 1) then
    Exit;

  Result := (Row * 3) + Col;

  // Calculate exact pixel bounds of the hovered cube
  CubeX := Col * (CubeSize + Gap);
  CubeY := Row * (CubeSize + Gap);

  // If the mouse is in the gap between cubes, ignore it
  if (X < CubeX) or (X > CubeX + CubeSize) or (Y < CubeY) or (Y > CubeY + CubeSize) then
    Result := -1;

  // If we have less than 6 items, ignore empty grid slots
  if Result >= FSegmentCount then
    Result := -1;
end;

end.

