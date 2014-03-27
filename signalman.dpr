program signalman;

{$R *.dres}

uses
  System.StartUpCopy,
  FMX.Forms,
  SignalManTemplate in 'SignalManTemplate.pas' {frmMain};

{$R *.res}

begin
  Application.Initialize;
  Application.FormFactor.Orientations := [TFormOrientation.soPortrait, TFormOrientation.soInvertedPortrait];
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.
