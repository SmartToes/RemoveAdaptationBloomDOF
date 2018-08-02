{
  Disables eye adaptation, bloom, and optionally depth of field.
}
unit MakeItStop;

const
  DisableAdaptation = True;
  DisableBloom = True;
  IncludeSunrise = False;
  IncludeDay = True;
  IncludeSunset = False;
  IncludeNight = False;
  IncludeText = 'clear cloudy';
  ExcludeText = '_a';

var
  IncludeList, ExcludeList: TStringList;
  RecordSelectForm: TForm;
  CheckListBox: TCheckListBox;
  OutputFile: IInterface;

function Initialize: Integer;
begin
  IncludeList := Split(IncludeText);
  ExcludeList := Split(ExcludeText);
  BuildRecordSelectForm;
  try
    ScanWeathers;
    RecordSelectForm.ShowModal;
    OutputFile := AddNewFile;
    if not Assigned(OutputFile) then
      Exit;
    PatchImageSpaces;
  finally
    RecordSelectForm.Release
  end
end;

function Split(S: string): TStringList;
var
  I: Integer;
  Word: string;
begin
  Result := TStringList.Create;
  repeat
    I := Pos(' ', S);
    if I = 0 then
      I := Length(S);
    Word := Trim(Copy(S, 1, I));
    if Word <> '' then
      Result.Add(Word);
    Delete(S, 1, I);
  until Length(S) = 0;
  for I := 0 to Result.Count - 1 do
    AddMessage(Result[I]);
end;

procedure BuildRecordSelectForm;
var
  TopPanel: TPanel;
  DescLabel: TLabel;
begin
  RecordSelectForm := TForm.Create(Nil);
  RecordSelectForm.Constraints.MinWidth := 400;
  RecordSelectForm.Constraints.MaxWidth := 400;
  RecordSelectForm.Constraints.MinHeight := 200;
  RecordSelectForm.Height := 600;
  RecordSelectForm.Caption := 'Make It Stop';

  TopPanel := TPanel.Create(RecordSelectForm);
  TopPanel.BevelWidth := 0;
  TopPanel.BorderWidth := 6;
  TopPanel.Height := 103;
  TopPanel.Align := alTop;
  TopPanel.Parent := RecordSelectForm;

  DescLabel := TLabel.Create(TopPanel);
  DescLabel.Align := alClient;
  DescLabel.Caption := 'Eye adaptation and bloom will be disabled for all ' +
      'ImageSpaces. Additionally, depth of field will be disabled for the ' +
      'entries selected below. Rules for default selections can be edited ' +
      'at the beginning of the script. Close this window to continue.' +
      #13#10#13#10 +
      'Suffixes: COast, MArsh, FallForest/Riften, REach/Markarth, SNow, ' +
      'TUndra, VolcanicTundra, Aurora';
  DescLabel.WordWrap := True;
  DescLabel.Parent := TopPanel;

  CheckListBox := TCheckListBox.Create(RecordSelectForm);
  CheckListBox.Align := alClient;
  CheckListBox.Sorted := True;
  CheckListBox.Parent := RecordSelectForm
end;

procedure ScanWeathers;
var
  I, J: Integer;
  Group, WTHR, Override, IMSP: IInterface;
begin
  CheckListBox.Items.BeginUpdate;
  try
    for I := 0 to FileCount - 1 do
    begin
      Group := GroupBySignature(FileByIndex(I), 'WTHR');
      if not Assigned(Group) then
        Continue;
      for J := 0 to ElementCount(Group) - 1 do
      begin
        WTHR := ElementByIndex(Group, J);
        if not IsMaster(WTHR) then
          Continue;
        Override := WinningOverride(WTHR);
        IMSP := ElementByName(Override, 'IMSP - Image Spaces');
        AddImageSpace(ElementByName(IMSP, 'Sunrise'), IncludeSunrise);
        AddImageSpace(ElementByName(IMSP, 'Day'), IncludeDay);
        AddImageSpace(ElementByName(IMSP, 'Sunset'), IncludeSunset);
        AddImageSpace(ElementByName(IMSP, 'Night'), IncludeNight);
      end
    end
  finally
    CheckListBox.Items.EndUpdate
  end
end;

procedure AddImageSpace(E: IInterface; TimeFilter: Boolean);
var
  Edit: string;
  Native, I: Integer;
  Matched: Boolean;
begin
  Edit := GetEditValue(E);
  Delete(Edit, Pos(' [IMGS:', Edit), Length(Edit));
  if TimeFilter then
    if FilterByEditValue(Edit) then
      Matched := True;
  Native := GetNativeValue(E);
  I := CheckListBox.Items.IndexOf(Edit);
  if (I = -1) then
    I := CheckListBox.Items.AddObject(Edit, Native);
  if Matched then
    CheckListBox.Checked[I] := True
end;

function FilterByEditValue(V: string): Boolean;
var
  I: Integer;
begin
  V := LowerCase(V);
  for I := 0 to IncludeList.Count - 1 do
    if Pos(IncludeList[I], V) > 0 then
    begin
      Result := True;
      Break
    end;
  for I := 0 to ExcludeList.Count - 1 do
    if Pos(ExcludeList[I], V) > 0 then
    begin
      Result := False;
      Break
    end
end;

procedure PatchImageSpaces;
var
  I, J, CheckListIndex: Integer;
  Group, IMGS, Override, NewRecord: IInterface;
begin
  for I := 0 to FileCount - 1 do
  begin
    Group := GroupBySignature(FileByIndex(I), 'IMGS');
    if not Assigned(Group) then
      Continue;
    for J := 0 to ElementCount(Group) - 1 do
    begin
      IMGS := ElementByIndex(Group, J);
      if not IsMaster(IMGS) then
        Continue;
      Override := WinningOverride(IMGS);
      AddRequiredElementMasters(Override, OutputFile, False);
      NewRecord := wbCopyElementToFile(Override, OutputFile, False, True);
      if DisableAdaptation then
        SetElementNativeValues(NewRecord, 'HNAM - HDR\Eye Adapt Speed', 0.0001);
      if DisableBloom then
        SetElementNativeValues(NewRecord, 'HNAM - HDR\Bloom Threshold', 1.0);
      CheckListIndex := CheckListBox.Items.IndexOf(EditorID(IMGS));
      if CheckListIndex > -1 then
        if CheckListBox.Checked[CheckListIndex] then
          RemoveElement(NewRecord, 'DNAM');
    end
  end
end;

end.