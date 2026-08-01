{*******************************************************************************
  Skia-CubesPopup;
********************************************************************************
  A floating 3D-cube grid popup menu rendered via Skia4Delphi.

*******************************************************************************}
{ Skia-CubesPopup; v0.3                                                        }
{ by Lara Miriam Tamy Reschke                                                  }
{                                                                              }
{------------------------------------------------------------------------------}
{
  Latest Changes:
   v 0.3:
   - Ported the CirclePopup WinAPI UpdateLayeredWindow pipeline to Cubes
   - Using TAlphaColor natively to prevent color type crashes
   - Added true drop shadows using Skia ImageFilters
   - Enabled true Anti-Aliasing for smooth rounded cube edges
   - Using PNG stream for 100% safe VCL Alpha transfer
}

unit SkiaCubesPopup;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Math, System.IOUtils, Vcl.Forms, Vcl.Graphics, Vcl.Controls,
  Vcl.ExtCtrls, Vcl.Imaging.pngimage, Vcl.Imaging.jpeg, Vcl.Skia, Skia, Skia.API;

type
  TSkiaCubesPopupClickEvent = procedure(Sender: TObject; SegmentIndex: Integer; const SegmentText: string) of object;

  TSkiaCubesPopup = class(TComponent)
  private
    FPopupForm: TForm;
    FBuffer: TBitmap;
    FSegmentCount: Integer;
    FOuterRadius: Integer;  // Reused as CubeSize
    FCenter: TPointF;
    FGapAngle: Single;      // Gap between cubes
    FSegmentColor: TAlphaColor;
    FHoverColor: TAlphaColor;
    FBorderColor: TAlphaColor;
    FTextColor: TAlphaColor;
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
    procedure UpdateLayeredWindowFromBitmap;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ShowSkiaCubesPopup(StartX, StartY: Integer; InnerRadius, OuterRadius: Integer;
      SegmentColor, HoverColor, BorderColor, TextColor: TAlphaColor;
      SegmentCount: Integer; SegmentText: TArray<string>;
      OnClick: TSkiaCubesPopupClickEvent);
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
  ExStyle: Integer;
  Padding: Integer;
begin
  CubeSize := FOuterRadius;
  TotalWidth := 3 * CubeSize + 2 * Round(FGapAngle); // 3 cubes + 2 gaps

  if FSegmentCount <= 3 then
    TotalHeight := CubeSize
  else
    TotalHeight := 2 * CubeSize + Round(FGapAngle); // 2 rows + 1 gap

  // 60px padding space reserved for the drop shadow to bleed into
  Padding := 60;
  FPopupForm := TForm.Create(nil);
  FPopupForm.FormStyle := fsStayOnTop;
  FPopupForm.BorderStyle := bsNone;
  FPopupForm.Color := clBlack; // Irrelevant due to layered window

  FPopupForm.ClientWidth := TotalWidth + (Padding * 2);
  FPopupForm.ClientHeight := TotalHeight + (Padding * 2);

  // Center the popup above the click point, adjusted for padding
  FPopupForm.Left := StartX - (FPopupForm.ClientWidth div 2);
  FPopupForm.Top := StartY - FPopupForm.ClientHeight - 10;

  // The drawing center shifts because of the padding
  FCenter := TPointF.Create(Padding + (TotalWidth / 2), Padding + (TotalHeight / 2));

  // Assign interaction events
  FPopupForm.OnMouseMove := PopupFormMouseMove;
  FPopupForm.OnClick := PopupFormClick;
  FPopupForm.OnClose := PopupFormClose;
  FPopupForm.OnDeactivate := PopupFormDeactivate;

  // Prepare the 32-bit VCL bitmap buffer.
  if FBuffer = nil then
  begin
    FBuffer := TBitmap.Create;
    FBuffer.PixelFormat := pf32bit;
    FBuffer.AlphaFormat := afDefined;
  end;
  FBuffer.SetSize(FPopupForm.ClientWidth, FPopupForm.ClientHeight);

  // Crucial: Convert form to Layered Window
  ExStyle := GetWindowLong(FPopupForm.Handle, GWL_EXSTYLE);
  SetWindowLong(FPopupForm.Handle, GWL_EXSTYLE, ExStyle or WS_EX_LAYERED);
end;

procedure TSkiaCubesPopup.UpdateLayeredWindowFromBitmap;
var
  ScreenDC, MemDC: HDC;
  OldBitmap: HBITMAP;
  BlendFunc: TBlendFunction;
  PtZero: TPoint;
  Size: TSize;
begin
  if not Assigned(FPopupForm) or not Assigned(FBuffer) then Exit;

  ScreenDC := GetDC(0);
  try
    MemDC := CreateCompatibleDC(ScreenDC);
    try
      OldBitmap := SelectObject(MemDC, FBuffer.Handle);

      PtZero := Point(0, 0);
      Size.cx := FBuffer.Width;
      Size.cy := FBuffer.Height;

      BlendFunc.BlendOp := AC_SRC_OVER;
      BlendFunc.BlendFlags := 0;
      BlendFunc.SourceConstantAlpha := 255;
      BlendFunc.AlphaFormat := AC_SRC_ALPHA;

      UpdateLayeredWindow(
        FPopupForm.Handle,
        ScreenDC,
        nil,
        @Size,
        MemDC,
        @PtZero,
        0,
        @BlendFunc,
        ULW_ALPHA
      );

      SelectObject(MemDC, OldBitmap);
    finally
      DeleteDC(MemDC);
    end;
  finally
    ReleaseDC(0, ScreenDC);
  end;
end;

procedure TSkiaCubesPopup.PopupFormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caFree;
  FPopupForm := nil;
end;

procedure TSkiaCubesPopup.PopupFormDeactivate(Sender: TObject);
begin
  if Assigned(FPopupForm) then
    FPopupForm.Close;
end;

procedure TSkiaCubesPopup.ShowSkiaCubesPopup(StartX, StartY: Integer; InnerRadius, OuterRadius: Integer;
  SegmentColor, HoverColor, BorderColor, TextColor: TAlphaColor;
  SegmentCount: Integer; SegmentText: TArray<string>;
  OnClick: TSkiaCubesPopupClickEvent);
var
  I: Integer;
begin
  FOuterRadius := OuterRadius; // Mapped to CubeSize
  FSegmentCount := SegmentCount;
  FSegmentColor := SegmentColor;
  FHoverColor := HoverColor;
  FBorderColor := BorderColor;
  FTextColor := TextColor;
  FOnSegmentClick := OnClick;
  FHoverIndex := -1;
  FGapAngle := 8;              // 8px gap between cubes
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
  PngImage: TPngImage;
  I: Integer;
  CubeSize, Gap: Single;
  Col, Row: Integer;
  X, Y: Single;
  Rect: TRectF;
  TextSize: TSize;
  TextPos: TPointF;
  PathBuilder: ISkPathBuilder;
  CubePath: ISkPath;
  R: Single;
begin
  SkImgInfo := TSkImageInfo.Create(FBuffer.Width, FBuffer.Height);
  Surface := TSkSurface.MakeRaster(SkImgInfo);

  if Assigned(Surface) then
  begin
    Canvas := Surface.Canvas;
    Canvas.Clear(TAlphaColorRec.Null); // 100% transparent background

    CubeSize := FOuterRadius;
    Gap := FGapAngle;
    R := 8; // Corner radius

    Paint := TSkPaint.Create;
    Paint.AntiAlias := True;
    Paint.Style := TSkPaintStyle.Fill;

    PathBuilder := TSkPathBuilder.Create;

    // 1. DRAW CUBES
    for I := 0 to FSegmentCount - 1 do
    begin
      Col := I mod 3;
      Row := I div 3;

      // Offset by FCenter.X/Y to account for the 60px form padding
      X := FCenter.X - ((3 * (CubeSize + Gap) - Gap) / 2) + (Col * (CubeSize + Gap));
      Y := FCenter.Y - ((2 * (CubeSize + Gap) - Gap) / 2) + (Row * (CubeSize + Gap));

      // Manually build the rounded rect path to avoid interface crashes
      Rect := TRectF.Create(X, Y, X + CubeSize, Y + CubeSize);
      PathBuilder.Reset;
      PathBuilder.MoveTo(Rect.Right - R, Rect.Top);
      PathBuilder.ArcTo(TRectF.Create(Rect.Right - (R*2), Rect.Top, Rect.Right, Rect.Top + (R*2)), -90, 90, False);
      PathBuilder.LineTo(Rect.Right, Rect.Bottom - R);
      PathBuilder.ArcTo(TRectF.Create(Rect.Right - (R*2), Rect.Bottom - (R*2), Rect.Right, Rect.Bottom), 0, 90, False);
      PathBuilder.LineTo(Rect.Left + R, Rect.Bottom);
      PathBuilder.ArcTo(TRectF.Create(Rect.Left, Rect.Bottom - (R*2), Rect.Left + (R*2), Rect.Bottom), 90, 90, False);
      PathBuilder.LineTo(Rect.Left, Rect.Top + R);
      PathBuilder.ArcTo(TRectF.Create(Rect.Left, Rect.Top, Rect.Left + (R*2), Rect.Top + (R*2)), 180, 90, False);
      PathBuilder.Close;
      CubePath := PathBuilder.Detach;

      // A) DROP SHADOW
      Paint.AntiAlias := False;
      Paint.Color := TAlphaColors.Black;
      Paint.ImageFilter := TSkImageFilter.MakeDropShadow(0, 12, 12, 12, TAlphaColors.Black);
      Canvas.DrawPath(CubePath, Paint);

      Paint.ImageFilter := nil;
      Paint.AntiAlias := True;

      // B) FILL CUBE
      if I = FHoverIndex then
        Paint.Color := FHoverColor
      else
        Paint.Color := FSegmentColor;

      Canvas.DrawPath(CubePath, Paint);

      // C) INNER 3D BORDER
      Paint.Style := TSkPaintStyle.Stroke;
      Paint.StrokeWidth := 2;
      Paint.Color := $40000000;
      Canvas.DrawPath(CubePath, Paint);
      Paint.Style := TSkPaintStyle.Fill;
    end;

    // 2. DRAW TEXT
    SkStyle := TSkFontStyle.Bold;
    SkTypeface := TSkTypeface.MakeFromName('Tahoma', SkStyle);
    SkFont := TSkFont.Create(SkTypeface, 12);

    Paint.Style := TSkPaintStyle.Fill;
    Paint.AntiAlias := True;
    Paint.Color := FTextColor;

    if Assigned(FPopupForm) then
    begin
      FPopupForm.Canvas.Font.Name := 'Tahoma';
      FPopupForm.Canvas.Font.Size := 12;
      FPopupForm.Canvas.Font.Style := [fsBold];
    end;

    for I := 0 to FSegmentCount - 1 do
    begin
      if (I < FSegmentText.Count) and (FSegmentText[I] <> '') then
      begin
        Col := I mod 3;
        Row := I div 3;
        X := FCenter.X - ((3 * (CubeSize + Gap) - Gap) / 2) + (Col * (CubeSize + Gap));
        Y := FCenter.Y - ((2 * (CubeSize + Gap) - Gap) / 2) + (Row * (CubeSize + Gap));

        TextPos.X := X + (CubeSize / 2);
        TextPos.Y := Y + (CubeSize / 2);

        if Assigned(FPopupForm) then
        begin
          GetTextExtentPoint32(FPopupForm.Canvas.Handle, PChar(FSegmentText[I]), Length(FSegmentText[I]), TextSize);
          TextPos.X := TextPos.X - (TextSize.cx / 2);
          TextPos.Y := TextPos.Y - (TextSize.cy / 2);
        end;

        Canvas.DrawSimpleText(FSegmentText[I], TextPos.X, TextPos.Y + 6, SkFont, Paint);
      end;
    end;

    // 3. TRANSFER TO VCL
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
            PngImage := TPngImage.Create;
            try
              PngImage.LoadFromStream(MemStream);
              FBuffer.Canvas.Lock;
              try
                FBuffer.Canvas.Brush.Color := clBlack;
                FBuffer.Canvas.FillRect(FBuffer.Canvas.ClipRect);
                FBuffer.Canvas.Draw(0, 0, PngImage);
              finally
                FBuffer.Canvas.Unlock;
              end;
            finally
              PngImage.Free;
            end;
          end;
        end;
      finally
        MemStream.Free;
      end;

      // 4. PUSH TO SCREEN
      UpdateLayeredWindowFromBitmap;
    end;
  end;
end;

procedure TSkiaCubesPopup.PopupFormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  NewIndex: Integer;
begin
  // Pass the raw mouse coordinates, GetSegmentFromMouse will handle the math
  NewIndex := GetSegmentFromMouse(X, Y);
  if FHoverIndex <> NewIndex then
  begin
    FHoverIndex := NewIndex;
    DoDraw;
  end;
end;

procedure TSkiaCubesPopup.PopupFormClick(Sender: TObject);
var
  Index: Integer;
  Pt: TPoint;
begin
  Pt := FPopupForm.ScreenToClient(Mouse.CursorPos);
  Index := GetSegmentFromMouse(Pt.X, Pt.Y);

  if Assigned(FPopupForm) then
    FPopupForm.Hide;

  if (Index >= 0) and Assigned(FOnSegmentClick) then
  begin
    FOnSegmentClick(Self, Index, FSegmentText[Index]);
  end;

  if Assigned(FPopupForm) then
    FPopupForm.Close;
end;

function TSkiaCubesPopup.GetSegmentFromMouse(X, Y: Integer): Integer;
var
  CubeSize, Gap: Single;
  Col, Row: Integer;
  StartX, StartY: Single;
  CubeX, CubeY: Single;
begin
  Result := -1;
  CubeSize := FOuterRadius;
  Gap := FGapAngle;

  // Calculate top-left of the grid inside the padded form
  StartX := FCenter.X - ((3 * (CubeSize + Gap) - Gap) / 2);
  StartY := FCenter.Y - ((2 * (CubeSize + Gap) - Gap) / 2);

  // Determine which grid cell the mouse is over
  Col := Trunc((X - StartX) / (CubeSize + Gap));
  Row := Trunc((Y - StartY) / (CubeSize + Gap));

  if (Col < 0) or (Col > 2) or (Row < 0) or (Row > 1) then
    Exit;

  Result := (Row * 3) + Col;

  // Calculate exact bounds of the cube
  CubeX := StartX + (Col * (CubeSize + Gap));
  CubeY := StartY + (Row * (CubeSize + Gap));

  // If mouse is in the gap, ignore
  if (X < CubeX) or (X > CubeX + CubeSize) or (Y < CubeY) or (Y > CubeY + CubeSize) then
    Result := -1;

  if Result >= FSegmentCount then
    Result := -1;
end;

end.
