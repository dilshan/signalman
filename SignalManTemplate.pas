{ SignalMan – Audio/Visual Morse Code Generator for Android.

  Copyright (c) 2014 Dilshan R Jayakody.

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to
  deal in the Software without restriction, including without limitation the
  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
  sell copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
  IN THE SOFTWARE. }

unit SignalManTemplate;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  FMX.ListBox, FMX.Layouts, FMX.Memo, FMX.Media, Posix.Pthread,
  Androidapi.NativeActivity, System.IOUtils, FMX.Platform, FMX.VirtualKeyboard;

type
  PMorseEntry = ^TMorseEntry;
  TMorseEntry = record
    MorseChar : Char;
    KeyID : Word;
  end;

  TOutputThread = class(TThread)
  protected
    procedure Execute(); override;
  end;

  TfrmMain = class(TForm)
    tbHeader: TToolBar;
    tbFooter: TToolBar;
    lblHeader: TLabel;
    btnStop: TButton;
    pnlBaseLabel: TPanel;
    pnlEditor: TPanel;
    txtMsg: TMemo;
    pnlTools: TPanel;
    pnlEditUtil: TPanel;
    pnlClear: TPanel;
    btnClear: TButton;
    lblMode: TLabel;
    lblEditTitle: TLabel;
    btnOK: TButton;
    pnlToolOptions: TPanel;
    cmbMode: TComboBox;
    camControl: TCameraComponent;
    mediaPlayer: TMediaPlayer;
    lblSpeed: TLabel;
    tbDelay: TTrackBar;
    procedure SetUIState(IsEnable : Boolean);
    procedure btnClearClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FillMorseTable();
    procedure FormKeyDown(Sender: TObject; var Key: Word; var KeyChar: Char;
      Shift: TShiftState);
  private
    PlayFile : String;
    KBService : IFMXVirtualKeyboardService;
    MorseTable : TList;
    thScan: TOutputThread;
  public
    BaseTime : Word;
    IsHalt, IsFlash : Boolean;
    StrMsg : String;
    BeepSteamD1, BeepSteamD2: TResourceStream;
    procedure GenerateMorseOutput(InChar : Char);
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.fmx}

procedure AppEndSubThreadProc(ExitCode:Integer);
var
  PActivity: PANativeActivity;
begin
    // fix for thread exit bug in Delphi XE5 Android builds.
    PActivity := PANativeActivity(System.DelphiActivity);
    PActivity^.vm^.DetachCurrentThread(PActivity^.vm);
    pthread_exit(ExitCode);
end;

procedure TfrmMain.SetUIState(IsEnable : Boolean);
begin
  txtMsg.Enabled := IsEnable;
  btnClear.Enabled := txtMsg.Enabled;
  cmbMode.Enabled := txtMsg.Enabled;
  tbDelay.Enabled := txtMsg.Enabled;
  lblSpeed.Enabled := txtMsg.Enabled;
  lblMode.Enabled := txtMsg.Enabled;
  btnOK.Enabled := txtMsg.Enabled;
  btnStop.Enabled := not txtMsg.Enabled;
end;

procedure TOutputThread.Execute;
var
  ScanPos : Integer;
begin
  if(Length(frmMain.StrMsg) > 0) then
  begin
    for ScanPos := 0 to (Length(frmMain.StrMsg) - 1) do
    begin
      // looking for user initiated halts.
      if((frmMain.IsHalt) or Terminated) then
        break;
      frmMain.GenerateMorseOutput(frmMain.StrMsg[ScanPos]);
      Sleep(2 * frmMain.BaseTime);
    end;
    // end of character transmission.
    Synchronize(
      procedure
      begin
        frmMain.camControl.TorchMode := TTorchMode.tmModeOff;
        frmMain.SetUIState(true);
      end);
  end;
end;

procedure TfrmMain.btnClearClick(Sender: TObject);
begin
  txtMsg.Text := '';
  txtMsg.SetFocus;
end;

procedure TfrmMain.btnOKClick(Sender: TObject);
begin
  StrMsg := UpperCase(Trim(txtMsg.Text));
  if(StrMsg = '') then
  begin
    MessageDlg('Transmission message is not specified!', TMsgDlgType.mtWarning, [TMsgDlgBtn.mbOK], 0);
    txtMsg.SetFocus;
  end
  else
  begin
    IsHalt := false;
    SetUIState(false);

    IsFlash := (cmbMode.ItemIndex = 0);
    BaseTime := Trunc(tbDelay.Value);
    PlayFile := TPath.Combine(TPath.GetTempPath,'dsound.mp3');

    if(Assigned(thScan)) then
    begin
      try
        thScan.Free;
      finally
        thScan := nil;
      end;
    end;

    thScan := TOutputThread.Create(true);
    thScan.FreeOnTerminate := true;
    thScan.Start;
  end;
end;

procedure TfrmMain.btnStopClick(Sender: TObject);
begin
  if(Assigned(thScan)) then
    thScan.Terminate;

  IsHalt := true;
  SetUIState(true);
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  EndThreadProc := AppEndSubThreadProc;
  BaseTime := 150;
  IsHalt := false;
  MorseTable := TList.Create;

  SetUIState(true);
  FillMorseTable;

  BeepSteamD1 := TResourceStream.Create(HInstance, 'd1', RT_RCDATA);
  BeepSteamD2 := TResourceStream.Create(HInstance, 'd2', RT_RCDATA);

  tbDelay.Value := BaseTime;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  if(Assigned(MorseTable)) then
    FreeAndNil(MorseTable);
  if(Assigned(BeepSteamD1)) then
    FreeAndNil(BeepSteamD1);
  if(Assigned(BeepSteamD2)) then
    FreeAndNil(BeepSteamD2);
end;

procedure TfrmMain.FormKeyDown(Sender: TObject; var Key: Word;
  var KeyChar: Char; Shift: TShiftState);
begin
  if(Key = 18) then
  begin
    // try to load Android virtual keyboard.
    if(txtMsg.Enabled) then
    begin
      tbDelay.SetFocus;
      Sleep(10);
      txtMsg.SetFocus;
    end;
  end
  else if(Key = vkHardwareBack) then
  begin
    // try to close Android application.
    // TODO: this routine is not working properly on most of the Android devices.
    TPlatformServices.Current.SupportsPlatformService(IFMXVirtualKeyboardService, IInterface(KBService));
    if(not(KBService <> nil) and (vksVisible in KBService.VirtualKeyBoardState)) then
    begin
      tbDelay.SetFocus;
      Sleep(10);
      txtMsg.SetFocus;
      Sleep(10);
      if(Assigned(thScan)) then
        FreeAndNil(thScan);
      FreeAndNil(Application);
    end;
  end;
end;

procedure TfrmMain.FillMorseTable();

  procedure AddTableEntry(Symbol : Char; KeyID : Word);
  var
    ListData : PMorseEntry;
  begin
    New(ListData);
    ListData^.MorseChar := Symbol;
    ListData^.KeyID := KeyID;
    MorseTable.Add(ListData);
  end;

begin
  MorseTable.Clear;
  AddTableEntry(#65, $009);  // A .-
  AddTableEntry(#66, $056);  // B -...
  AddTableEntry(#67, $066);  // C -.-.
  AddTableEntry(#68, $016);  // D -..
  AddTableEntry(#69, $001);  // E .
  AddTableEntry(#70, $065);  // F ..-.
  AddTableEntry(#71, $01A);  // G --.
  AddTableEntry(#72, $055);  // H ....
  AddTableEntry(#73, $005);  // I ..
  AddTableEntry(#74, $0A9);  // J .---
  AddTableEntry(#75, $026);  // K -.-
  AddTableEntry(#76, $059);  // L .-..
  AddTableEntry(#77, $00A);  // M --
  AddTableEntry(#78, $006);  // N -.
  AddTableEntry(#79, $02A);  // O ---
  AddTableEntry(#80, $069);  // P .--.
  AddTableEntry(#81, $09A);  // Q --.-
  AddTableEntry(#82, $019);  // R .-.
  AddTableEntry(#83, $015);  // S ...
  AddTableEntry(#84, $002);  // T -
  AddTableEntry(#85, $025);  // U ..-
  AddTableEntry(#86, $095);  // V ...-
  AddTableEntry(#87, $029);  // W .--
  AddTableEntry(#88, $096);  // X -..-
  AddTableEntry(#89, $0A6);  // Y -.--
  AddTableEntry(#90, $05A);  // Z --..
  AddTableEntry(#49, $2A9);  // 1 .----
  AddTableEntry(#50, $2A5);  // 2 ..---
  AddTableEntry(#51, $295);  // 3 ...--
  AddTableEntry(#52, $255);  // 4 ....-
  AddTableEntry(#53, $155);  // 5 .....
  AddTableEntry(#54, $156);  // 6 -....
  AddTableEntry(#55, $15A);  // 7 --...
  AddTableEntry(#56, $16A);  // 8 ---..
  AddTableEntry(#57, $1AA);  // 9 ----.
  AddTableEntry(#48, $2AA);  // 0 -----
end;

procedure TfrmMain.GenerateMorseOutput(InChar : Char);
var
  MorseData : Word; CodePos, OutCode : Byte;

  function GetMorseID() : Word;
  var
    ScanPos : Integer;
  begin
    result := 0;
    for ScanPos := 0 to (frmMain.MorseTable.Count - 1) do
    begin
      if(InChar = PMorseEntry(frmMain.MorseTable.Items[ScanPos])^.MorseChar) then
      begin
        result := PMorseEntry(frmMain.MorseTable.Items[ScanPos])^.KeyID;
        break;
      end;
    end;
  end;

  // procedure for visual output.
  procedure SetFlashMode(Mode : Word);
  begin
    camControl.TorchMode := TTorchMode.tmModeOn;
    Sleep(BaseTime);
    if(Mode > 1) then
      Sleep(2 * BaseTime);
    camControl.TorchMode := TTorchMode.tmModeOff;
  end;

  // procedure for audio output.
  procedure SetAudioMode(Mode : Word);
  begin
    if(Mode > 1) then
    begin
      BeepSteamD2.Position := 0;
      BeepSteamD2.SaveToFile(PlayFile);
    end
    else
    begin
      BeepSteamD1.Position := 0;
      BeepSteamD1.SaveToFile(PlayFile);
    end;
    mediaPlayer.FileName := PlayFile;
    mediaPlayer.Play;
  end;

begin
  if(InChar = #32) then
    Sleep(5 * BaseTime)
  else
  begin
    MorseData := GetMorseID;
    if(MorseData > 0) then
    begin
      CodePos := 0;
      repeat
        OutCode := (MorseData and (3 shl CodePos)) shr CodePos;
        CodePos := CodePos + 2;
        if(OutCode > 0) then
        begin
          if(IsFlash) then
            SetFlashMode(OutCode)
          else
            SetAudioMode(OutCode);
          Sleep(BaseTime);
        end;
      until (OutCode = 0);
    end
    // treat unknown characters as spaces.
    else
      Sleep(BaseTime);
  end;
end;

end.
