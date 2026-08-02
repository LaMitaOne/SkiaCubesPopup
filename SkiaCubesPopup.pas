{*******************************************************************************
  Skia-CubesPopup;
********************************************************************************
  A floating cube grid popup menu rendered via Skia4Delphi.
*******************************************************************************}
{ Skia-CubesPopup; v0.4                                                        }
{ by Lara Miriam Tamy Reschke                                                  }
{                                                                              }
{------------------------------------------------------------------------------}
{
  Latest Changes:
   v 0.4:
   - Per-Segment color tracking! Each cube fades individually between states.
   - Smooth Alpha Fade-In and Fade-Out (Show/Close).
   - Renamed Inner/OuterRadius conceptually to Gap/CubeSize (Interface remains compatible).
}
unit SkiaCubesPopup;

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Math, System.IOUtils, Vcl.Forms, Vcl.Graphics, Vcl.Controls,
  Vcl.ExtCtrls, Vcl.Imaging.pngimage, Vcl.Imaging.jpeg, Vcl.Skia, Skia, Skia.API;

type
  TSkiaCubesPopupClickEvent = procedure(Sender: TObject; SegmentIndex: Integer; const SegmentText: string) of object;

  TPopupState = (psIdle, psFadeIn, psFadeOut);

  TSkiaCubesPopup = class(TComponent)
  private
    FPopupForm: TForm;
    FBuffer: TBitmap;
    FSegmentCount: Integer;
    FCubeSize: Integer;
    FGap: Integer;
    FCenter: TPointF;
    FSegmentColor: TAlphaColor;
    FHoverColor: TAlphaColor;
    FBorderColor: TAlphaColor;
    FTextColor: TAlphaColor;
    FHoverIndex: Integer;
    FOnSegmentClick: TSkiaCubesPopupClickEvent;
    FSegmentText: TStringList;
    FAnimTimer: TTimer;
    FState: TPopupState;
    FCurrentAlpha: Integer;
    FPendingClickIndex: Integer;
    FIsClosing: Boolean;
    FSegmentColors: array of TAlphaColor;

    procedure CreatePopupForm(StartX, StartY: Integer);
    function GetSegmentFromMouse(X, Y: Integer): Integer;
    procedure DoDraw;
    procedure PopupFormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure PopupFormClick(Sender: TObject);
    procedure PopupFormClose(Sender: TObject; var Action: TCloseAction);
    procedure PopupFormDeactivate(Sender: TObject);
    procedure UpdateLayeredWindowFromBitmap;
    procedure AnimTimerTick(Sender: TObject);
    function BlendColorStep(Current, Target: TAlphaColor): TAlphaColor;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ShowSkiaCubesPopup(StartX, StartY: Integer; InnerRadius, OuterRadius: Integer; SegmentColor, HoverColor, BorderColor, TextColor: TAlphaColor; SegmentCount: Integer; SegmentText: TArray<string>; OnClick: TSkiaCubesPopupClickEvent);
  end;

implementation

{ TSkiaCubesPopup }

constructor TSkiaCubesPopup.Create(AOwner: TComponent);
begin
  inherited;
  FSegmentText := TStringList.Create;
  FAnimTimer := TTimer.Create(nil);
  FAnimTimer.Enabled := False;
  FAnimTimer.Interval := 15;
  FAnimTimer.OnTimer := AnimTimerTick;
end;

destructor TSkiaCubesPopup.Destroy;
begin
  if Assigned(FPopupForm) then
  begin
    FPopupForm.Close;
    FPopupForm := nil;
  end;
  FAnimTimer.Free;
  FBuffer.Free;
  FSegmentText.Free;
  inherited;
end;

procedure TSkiaCubesPopup.CreatePopupForm(StartX, StartY: Integer);
var
  TotalWidth, TotalHeight: Integer;
  ExStyle: Integer;
  Padding, OffsetY: Integer;
begin
  TotalWidth := 3 * FCubeSize + 2 * FGap;
  if FSegmentCount <= 3 then
    TotalHeight := FCubeSize
  else
    TotalHeight := 2 * FCubeSize + FGap;

  Padding := 60;
  FPopupForm := TForm.Create(nil);
  FPopupForm.FormStyle := fsStayOnTop;
  FPopupForm.BorderStyle := bsNone;
  FPopupForm.Color := clBlack;
  FPopupForm.ClientWidth := TotalWidth + (Padding * 2);
  FPopupForm.ClientHeight := TotalHeight + (Padding * 2);

  FPopupForm.Left := StartX - (FPopupForm.ClientWidth div 2);
  OffsetY := 5;
  FPopupForm.Top := StartY - TotalHeight - Padding - OffsetY;
  FCenter := TPointF.Create(Padding + (TotalWidth / 2), Padding + (TotalHeight / 2));

  FPopupForm.OnMouseMove := PopupFormMouseMove;
  FPopupForm.OnClick := PopupFormClick;
  FPopupForm.OnClose := PopupFormClose;
  FPopupForm.OnDeactivate := PopupFormDeactivate;

  if FBuffer = nil then
  begin
    FBuffer := TBitmap.Create;
    FBuffer.PixelFormat := pf32bit;
    FBuffer.AlphaFormat := afDefined;
  end;
  FBuffer.SetSize(FPopupForm.ClientWidth, FPopupForm.ClientHeight);

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
  if not Assigned(FPopupForm) or not Assigned(FBuffer) then
    Exit;
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
      BlendFunc.SourceConstantAlpha := FCurrentAlpha;
      BlendFunc.AlphaFormat := AC_SRC_ALPHA;
      UpdateLayeredWindow(FPopupForm.Handle, ScreenDC, nil, @Size, MemDC, @PtZero, 0, @BlendFunc, ULW_ALPHA);
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
  if FIsClosing then
    Exit;
  if Assigned(FPopupForm) then
  begin
    FIsClosing := True;
    FState := psFadeOut;
    FPendingClickIndex := -1;
    FAnimTimer.Enabled := True;
  end;
end;

function TSkiaCubesPopup.BlendColorStep(Current, Target: TAlphaColor): TAlphaColor;
var
  R1, G1, B1, R2, G2, B2: Integer;
begin
  if Current = Target then
    Exit(Current);

  R1 := TAlphaColorRec(Current).R;
  G1 := TAlphaColorRec(Current).G;
  B1 := TAlphaColorRec(Current).B;
  R2 := TAlphaColorRec(Target).R;
  G2 := TAlphaColorRec(Target).G;
  B2 := TAlphaColorRec(Target).B;

  if R1 < R2 then
    Inc(R1, Min(15, R2 - R1))
  else if R1 > R2 then
    Dec(R1, Min(15, R1 - R2));
  if G1 < G2 then
    Inc(G1, Min(15, G2 - G1))
  else if G1 > G2 then
    Dec(G1, Min(15, G1 - G2));
  if B1 < B2 then
    Inc(B1, Min(15, B2 - B1))
  else if B1 > B2 then
    Dec(B1, Min(15, B1 - B2));

  TAlphaColorRec(Result).R := R1;
  TAlphaColorRec(Result).G := G1;
  TAlphaColorRec(Result).B := B1;
  TAlphaColorRec(Result).A := 255;
end;

procedure TSkiaCubesPopup.AnimTimerTick(Sender: TObject);
var
  I: Integer;
  TargetColor: TAlphaColor;
  NeedsRedraw: Boolean;
  LClickIndex: Integer;
  LCallback: TSkiaCubesPopupClickEvent;
  LText: string;
begin
  if not Assigned(FPopupForm) then
  begin
    FAnimTimer.Enabled := False;
    Exit;
  end;

  NeedsRedraw := False;

  case FState of
    psFadeIn:
      begin
        FCurrentAlpha := FCurrentAlpha + 25;
        if FCurrentAlpha >= 255 then
        begin
          FCurrentAlpha := 255;
          FState := psIdle;
        end;
        NeedsRedraw := True;
      end;
    psFadeOut:
      begin
        FCurrentAlpha := FCurrentAlpha - 25;
        if FCurrentAlpha <= 0 then
        begin
          FCurrentAlpha := 0;
          FAnimTimer.Enabled := False;
          FPopupForm.Hide;

          LClickIndex := FPendingClickIndex;
          LCallback := FOnSegmentClick;
          LText := '';
          if (LClickIndex >= 0) and (LClickIndex < FSegmentText.Count) then
            LText := FSegmentText[LClickIndex];

          FPopupForm.Close;

          if (LClickIndex >= 0) and Assigned(LCallback) then
            LCallback(Self, LClickIndex, LText);

          Exit;
        end;
        NeedsRedraw := True;
      end;
    psIdle:
      begin
        for I := 0 to FSegmentCount - 1 do
        begin
          if I = FHoverIndex then
            TargetColor := FHoverColor
          else
            TargetColor := FSegmentColor;

          if FSegmentColors[I] <> TargetColor then
          begin
            FSegmentColors[I] := BlendColorStep(FSegmentColors[I], TargetColor);
            NeedsRedraw := True;
          end;
        end;
      end;
  end;

  if NeedsRedraw then
  begin
    DoDraw;
    UpdateLayeredWindowFromBitmap;
  end
  else
  begin
    if (FState = psIdle) and (FCurrentAlpha = 255) then
      FAnimTimer.Enabled := False;
  end;
end;

procedure TSkiaCubesPopup.ShowSkiaCubesPopup(StartX, StartY: Integer; InnerRadius, OuterRadius: Integer; SegmentColor, HoverColor, BorderColor, TextColor: TAlphaColor; SegmentCount: Integer; SegmentText: TArray<string>; OnClick: TSkiaCubesPopupClickEvent);
var
  I: Integer;
begin
  if Assigned(FPopupForm) then
  begin
    FAnimTimer.Enabled := False;
    FPopupForm.Hide;
    FPopupForm.Close;
    FPopupForm := nil;
  end;

  FCubeSize := OuterRadius;
  FGap := InnerRadius;
  if FGap < 1 then
    FGap := 8;

  FSegmentCount := SegmentCount;
  FSegmentColor := SegmentColor;
  FHoverColor := HoverColor;
  FBorderColor := BorderColor;
  FTextColor := TextColor;
  FOnSegmentClick := OnClick;
  FHoverIndex := -1;

  SetLength(FSegmentColors, FSegmentCount);
  for I := 0 to FSegmentCount - 1 do
    FSegmentColors[I] := FSegmentColor;

  FSegmentText.Clear;
  for I := Low(SegmentText) to High(SegmentText) do
    FSegmentText.Add(SegmentText[I]);

  CreatePopupForm(StartX, StartY);

  FCurrentAlpha := 0;
  FIsClosing := False;

  DoDraw;
  UpdateLayeredWindowFromBitmap;
  FPopupForm.Show;

  FState := psFadeIn;
  FAnimTimer.Enabled := True;
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
    Canvas.Clear(TAlphaColorRec.Null);

    CubeSize := FCubeSize;
    Gap := FGap;
    R := 8;

    Paint := TSkPaint.Create;
    Paint.AntiAlias := True;
    Paint.Style := TSkPaintStyle.Fill;
    PathBuilder := TSkPathBuilder.Create;

    for I := 0 to FSegmentCount - 1 do
    begin
      Col := I mod 3;
      Row := I div 3;
      X := FCenter.X - ((3 * (CubeSize + Gap) - Gap) / 2) + (Col * (CubeSize + Gap));
      Y := FCenter.Y - ((2 * (CubeSize + Gap) - Gap) / 2) + (Row * (CubeSize + Gap));

      Rect := TRectF.Create(X, Y, X + CubeSize, Y + CubeSize);
      PathBuilder.Reset;
      PathBuilder.MoveTo(Rect.Right - R, Rect.Top);
      PathBuilder.ArcTo(TRectF.Create(Rect.Right - (R * 2), Rect.Top, Rect.Right, Rect.Top + (R * 2)), -90, 90, False);
      PathBuilder.LineTo(Rect.Right, Rect.Bottom - R);
      PathBuilder.ArcTo(TRectF.Create(Rect.Right - (R * 2), Rect.Bottom - (R * 2), Rect.Right, Rect.Bottom), 0, 90, False);
      PathBuilder.LineTo(Rect.Left + R, Rect.Bottom);
      PathBuilder.ArcTo(TRectF.Create(Rect.Left, Rect.Bottom - (R * 2), Rect.Left + (R * 2), Rect.Bottom), 90, 90, False);
      PathBuilder.LineTo(Rect.Left, Rect.Top + R);
      PathBuilder.ArcTo(TRectF.Create(Rect.Left, Rect.Top, Rect.Left + (R * 2), Rect.Top + (R * 2)), 180, 90, False);
      PathBuilder.Close;
      CubePath := PathBuilder.Detach;

      Paint.AntiAlias := False;
      Paint.Color := TAlphaColors.Black;
      Paint.ImageFilter := TSkImageFilter.MakeDropShadow(0, 12, 12, 12, TAlphaColors.Black);
      Canvas.DrawPath(CubePath, Paint);
      Paint.ImageFilter := nil;
      Paint.AntiAlias := True;

      Paint.Color := FSegmentColors[I];
      Canvas.DrawPath(CubePath, Paint);

      Paint.Style := TSkPaintStyle.Stroke;
      Paint.StrokeWidth := 2;
      Paint.Color := $40000000;
      Canvas.DrawPath(CubePath, Paint);
      Paint.Style := TSkPaintStyle.Fill;
    end;

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
    end;
  end;
end;

procedure TSkiaCubesPopup.PopupFormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  NewIndex: Integer;
begin
  if FIsClosing then
    Exit;
  NewIndex := GetSegmentFromMouse(X, Y);
  if FHoverIndex <> NewIndex then
  begin
    FHoverIndex := NewIndex;
  end;
  if not FAnimTimer.Enabled then
    FAnimTimer.Enabled := True;
end;

procedure TSkiaCubesPopup.PopupFormClick(Sender: TObject);
var
  Index: Integer;
  Pt: TPoint;
begin
  if FIsClosing then
    Exit;
  Pt := FPopupForm.ScreenToClient(Mouse.CursorPos);
  Index := GetSegmentFromMouse(Pt.X, Pt.Y);
  FIsClosing := True;
  FState := psFadeOut;
  if Index >= 0 then
    FPendingClickIndex := Index
  else
    FPendingClickIndex := -1;
  FAnimTimer.Enabled := True;
end;

function TSkiaCubesPopup.GetSegmentFromMouse(X, Y: Integer): Integer;
var
  CubeSize, Gap: Single;
  Col, Row: Integer;
  StartX, StartY: Single;
  CubeX, CubeY: Single;
begin
  Result := -1;
  CubeSize := FCubeSize;
  Gap := FGap;
  StartX := FCenter.X - ((3 * (CubeSize + Gap) - Gap) / 2);
  StartY := FCenter.Y - ((2 * (CubeSize + Gap) - Gap) / 2);
  Col := Trunc((X - StartX) / (CubeSize + Gap));
  Row := Trunc((Y - StartY) / (CubeSize + Gap));
  if (Col < 0) or (Col > 2) or (Row < 0) or (Row > 1) then
    Exit;
  Result := (Row * 3) + Col;
  CubeX := StartX + (Col * (CubeSize + Gap));
  CubeY := StartY + (Row * (CubeSize + Gap));
  if (X < CubeX) or (X > CubeX + CubeSize) or (Y < CubeY) or (Y > CubeY + CubeSize) then
    Result := -1;
  if Result >= FSegmentCount then
    Result := -1;
end;

end.

