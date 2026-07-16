{*******************************************************************************
  Skia-CubePopup; v0.2 (Stable Edition)
********************************************************************************
  A floating 3D-cube grid popup menu rendered via Skia4Delphi
  Based on the stable Fuchsia transparency approach.
  Text is fixed to white to avoid Skia system-color quirks.
*******************************************************************************}

unit SkiaCubesPopup;

interface

uses
  Winapi.Windows,
  System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  System.IOUtils,
  Vcl.Forms, Vcl.Graphics, Vcl.Controls, Vcl.ExtCtrls,
  Vcl.Imaging.pngimage, Vcl.Imaging.jpeg,
  Vcl.Skia, Skia, Skia.API;

type
  TSkiaCubesPopupClickEvent = procedure(Sender: TObject; SegmentIndex: Integer; const SegmentText: string) of object;

  TSkiaCubesPopup = class(TComponent)
  private
    FPopupForm: TForm;
    FPopupImage: TImage;
    FBuffer: TBitmap;
    FSegmentCount: Integer;
    FInnerRadius: Integer;
    FOuterRadius: Integer;
    FCenter: TPointF;
    FGapAngle: Single;
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
    procedure ShowSkiaCubesPopup(StartX, StartY: Integer; InnerRadius, OuterRadius: Integer;
      SegmentColor, HoverColor, BorderColor, TextColor: TColor;
      SegmentCount: Integer; SegmentText: array of string;
      OnClick: TSkiaCubesPopupClickEvent);
  end;

implementation

{ TSkiaCirclePopup }

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
begin
  FPopupForm := TForm.Create(nil);
  FPopupForm.FormStyle := fsStayOnTop;
  FPopupForm.BorderStyle := bsNone;

  FPopupForm.Color := clFuchsia;
  FPopupForm.TransparentColor := True;
  FPopupForm.TransparentColorValue := clFuchsia;

  CubeSize := FOuterRadius;
  TotalWidth := 3 * CubeSize + 2 * Round(FGapAngle);
  if FSegmentCount <= 3 then
    TotalHeight := CubeSize
  else
    TotalHeight := 2 * CubeSize + Round(FGapAngle);

  FPopupForm.ClientWidth := TotalWidth;
  FPopupForm.ClientHeight := TotalHeight;

  FPopupForm.Left := StartX - (TotalWidth div 2);
  FPopupForm.Top := StartY - TotalHeight - 10;

  FPopupImage := TImage.Create(FPopupForm);
  FPopupImage.Parent := FPopupForm;
  FPopupImage.Align := alClient;
  FPopupImage.Stretch := False;
  FPopupImage.Center := False;
  FPopupImage.Transparent := True;

  FPopupImage.OnMouseMove := PopupFormMouseMove;
  FPopupImage.OnClick := PopupFormClick;

  FPopupForm.OnClose := PopupFormClose;
  FPopupForm.OnDeactivate := PopupFormDeactivate;

  if FBuffer = nil then
  begin
    FBuffer := TBitmap.Create;
    FBuffer.PixelFormat := pf32bit;
    FBuffer.AlphaFormat := afIgnored;
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
  if Assigned(FPopupForm) then
    FPopupForm.Close;
end;

procedure TSkiaCubesPopup.ShowSkiaCubesPopup(StartX, StartY: Integer; InnerRadius, OuterRadius: Integer;
  SegmentColor, HoverColor, BorderColor, TextColor: TColor;
  SegmentCount: Integer; SegmentText: array of string;
  OnClick: TSkiaCubesPopupClickEvent);
var
  I: Integer;
begin
  FInnerRadius := InnerRadius;
  FOuterRadius := OuterRadius;
  FSegmentCount := SegmentCount;
  FSegmentColor := SegmentColor;
  FHoverColor := HoverColor;
  FBorderColor := BorderColor;
  FTextColor := TextColor;
  FOnSegmentClick := OnClick;
  FHoverIndex := -1;
  FGapAngle := 6;
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
  SkImgInfo := TSkImageInfo.Create(FBuffer.Width, FBuffer.Height);
  Surface := TSkSurface.MakeRaster(SkImgInfo);

  if Assigned(Surface) then
  begin
    Canvas := Surface.Canvas;
    Canvas.Clear(TAlphaColors.Fuchsia);

    CubeSize := FOuterRadius;
    Gap := FGapAngle;

    Paint := TSkPaint.Create;
    Paint.AntiAlias := False;
    Paint.Style := TSkPaintStyle.Fill;

    // 1. WÜRFEL ZEICHNEN
    for I := 0 to FSegmentCount - 1 do
    begin
      Col := I mod 3;
      Row := I div 3;

      X := Col * (CubeSize + Gap);
      Y := Row * (CubeSize + Gap);

      // Schatten
      ShadowRect := TRectF.Create(X + 4, Y + 4, X + CubeSize + 4, Y + CubeSize + 4);
      Paint.Color := $FF404040;
      Canvas.DrawRect(ShadowRect, Paint);

      // Haupt-Würfel
      if I = FHoverIndex then
        Paint.Color := FHoverColor
      else
        Paint.Color := FSegmentColor;

      Rect := TRectF.Create(X, Y, X + CubeSize, Y + CubeSize);
      Canvas.DrawRect(Rect, Paint);
    end;

    // 2. TEXT ZEICHNEN
    SkStyle := TSkFontStyle.Normal;
    SkTypeface := TSkTypeface.MakeFromName('Tahoma', SkStyle);
    SkFont := TSkFont.Create(SkTypeface, 11);

    Paint.Style := TSkPaintStyle.Fill;
    // FESTER WEISSER TEXT
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
        Col := I mod 3;
        Row := I div 3;
        X := Col * (CubeSize + Gap);
        Y := Row * (CubeSize + Gap);

        TextPos.X := X + (CubeSize / 2);
        TextPos.Y := Y + (CubeSize / 2);

        if Assigned(FPopupForm) then
        begin
          GetTextExtentPoint32(FPopupForm.Canvas.Handle, PChar(FSegmentText[I]), Length(FSegmentText[I]), TextSize);
          TextPos.X := TextPos.X - (TextSize.cx / 2);
          TextPos.Y := TextPos.Y - (TextSize.cy / 2);
        end;

        Canvas.DrawSimpleText(FSegmentText[I], TextPos.X, TextPos.Y + (7 * 0.3), SkFont, Paint);
      end;
    end;

    // 3. PNG STREAM
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
    DoDraw;
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

  Col := Trunc(X / (CubeSize + Gap));
  Row := Trunc(Y / (CubeSize + Gap));

  if (Col > 2) or (Row > 1) then Exit;

  Result := (Row * 3) + Col * -1;

  CubeX := Col * (CubeSize + Gap);
  CubeY := Row * (CubeSize + Gap);

  if (X < CubeX) or (X > CubeX + CubeSize) or (Y < CubeY) or (Y > CubeY + CubeSize) then
    Result := -1;

  if Result >= FSegmentCount then
    Result := -1;
end;

end.
