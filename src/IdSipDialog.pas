unit IdSipDialog;

interface

uses
  Contnrs, IdSipDialogID, IdSipMessage, IdSipHeaders, SyncObjs;

type
  TIdSipDialog = class;
  TIdSipDialogState = (sdsNotInitialized, sdsEarly, sdsConfirmed);
  TIdSipDialogEvent = procedure(Sender: TIdSipDialog) of object;

  // cf RFC 3261, section 12.1
  // Within this specification, only 2xx and 101-199 responses with a To tag,
  // where the request was INVITE, will establish a dialog.
  TIdSipDialog = class(TObject)
  private
    fCanBeEstablished:   Boolean;
    fID:                 TIdSipDialogID;
    fInitialRequest:     TIdSipRequest;
    fIsSecure:           Boolean;
    fLocalSequenceNo:    Cardinal;
    fLocalURI:           TIdSipURI;
    fOnEstablished:      TIdSipDialogEvent;
    fRemoteSequenceNo:   Cardinal;
    fRemoteTarget:       TIdSipURI;
    fRemoteURI:          TIdSipURI;
    fRouteSet:           TIdSipHeaders;
    fState:              TIdSipDialogState;
    LocalSequenceNoLock: TCriticalSection;

    function  GetIsEarly: Boolean;
    procedure CreateInternal(const DialogID: TIdSipDialogID;
                             const LocalSequenceNo,
                                   RemoteSequenceNo: Cardinal;
                             const LocalUri,
                                   RemoteUri,
                                   RemoteTarget: String;
                             const IsSecure: Boolean;
                             const RouteSet: TIdSipHeaderList);
    function  GetLocalSequenceNo: Cardinal;
    procedure SetCanBeEstablished(const Value: Boolean);
    procedure SetIsEarly(const Value: Boolean);
    procedure SetIsSecure(const Value: Boolean);
  protected
    procedure DoOnEstablished;
    procedure SetLocalSequenceNo(const Value: Cardinal);
    procedure SetRemoteSequenceNo(const Value: Cardinal);
    procedure SetRemoteTarget(const Value: TIdSipURI);
    procedure SetState(const Value: TIdSipDialogState);

    property CanBeEstablished: Boolean       read fCanBeEstablished;
    property InitialRequest:   TIdSipRequest read fInitialRequest;
  public
    constructor Create(const DialogID: TIdSipDialogID;
                       const LocalSequenceNo,
                             RemoteSequenceNo: Cardinal;
                       const LocalUri,
                             RemoteUri: TIdSipURI;
                       const RemoteTarget: TIdSipURI;
                       const IsSecure: Boolean;
                       const RouteSet: TIdSipHeaderList); overload;
    constructor Create(const DialogID: TIdSipDialogID;
                       const LocalSequenceNo,
                             RemoteSequenceNo: Cardinal;
                       const LocalUri,
                             RemoteUri,
                             RemoteTarget: String;
                       const IsSecure: Boolean;
                       const RouteSet: TIdSipHeaderList); overload;
    constructor Create(const Dialog: TIdSipDialog); overload;
    destructor  Destroy; override;

    procedure HandleMessage(const Request: TIdSipRequest); overload; virtual;
    procedure HandleMessage(const Response: TIdSipResponse); overload; virtual;
    function  IsNull: Boolean; virtual;
    function  IsOutOfOrder(const Request: TIdSipRequest): Boolean;
    function  NextLocalSequenceNo: Cardinal;

    property ID:               TIdSipDialogID read fID;
    property IsEarly:          Boolean        read GetIsEarly;
    property IsSecure:         Boolean        read fIsSecure;
    property LocalSequenceNo:  Cardinal       read GetLocalSequenceNo;
    property LocalURI:         TIdSipURI      read fLocalURI;
    property RemoteSequenceNo: Cardinal       read fRemoteSequenceNo;
    property RemoteTarget:     TIdSipURI      read fRemoteTarget write SetRemoteTarget;
    property RemoteURI:        TIdSipURI      read fRemoteURI;
    property RouteSet:         TIdSipHeaders  read fRouteSet;

    property OnEstablished: TIdSipDialogEvent read fOnEstablished write fOnEstablished;
  end;

  TIdSipNullDialog = class(TIdSipDialog)
  public
    function IsNull: Boolean; override;
  end;

  TIdSipDialogs = class(TObject)
  private
    List:    TObjectList;
    Lock:    TCriticalSection;
    NullDlg: TIdSipNullDialog;

    function GetItem(const Index: Integer): TIdSipDialog;
  public
    constructor Create;
    destructor  Destroy; override;

    procedure Add(const NewDialog: TIdSipDialog);
    function  Count: Integer;
    function  DialogAt(const ID: TIdSipDialogID): TIdSipDialog; overload;
    function  DialogAt(const CallID, LocalTag, RemoteTag: String): TIdSipDialog; overload;

    property Items[const Index: Integer]: TIdSipDialog read GetItem;
  end;

implementation

uses
  IdSipConsts, IdSipRandom, SysUtils;

//******************************************************************************
//* TIdSipDialog                                                               *
//******************************************************************************
//* TIdSipDialog Public methods ************************************************

constructor TIdSipDialog.Create(const DialogID: TIdSipDialogID;
                                const LocalSequenceNo,
                                      RemoteSequenceNo: Cardinal;
                                const LocalUri,
                                      RemoteUri: TIdSipURI;
                                const RemoteTarget: TIdSipURI;
                                const IsSecure: Boolean;
                                const RouteSet: TIdSipHeaderList);
begin
  inherited Create;

  Self.CreateInternal(DialogID,
                      LocalSequenceNo,
                      RemoteSequenceNo,
                      LocalUri.URI,
                      RemoteUri.URI,
                      RemoteTarget.URI,
                      IsSecure,
                      RouteSet);
end;

constructor TIdSipDialog.Create(const DialogID: TIdSipDialogID;
                   const LocalSequenceNo,
                         RemoteSequenceNo: Cardinal;
                   const LocalUri,
                         RemoteUri,
                         RemoteTarget: String;
                   const IsSecure: Boolean;
                   const RouteSet: TIdSipHeaderList);
begin
  inherited Create;

  Self.CreateInternal(DialogID,
                      LocalSequenceNo,
                      RemoteSequenceNo,
                      LocalUri,
                      RemoteUri,
                      RemoteTarget,
                      IsSecure,
                      RouteSet);
end;

constructor TIdSipDialog.Create(const Dialog: TIdSipDialog);
begin
  inherited Create;

  Self.CreateInternal(Dialog.ID,
                      Dialog.LocalSequenceNo,
                      Dialog.RemoteSequenceNo,
                      Dialog.LocalUri.URI,
                      Dialog.RemoteUri.URI,
                      Dialog.RemoteTarget.URI,
                      Dialog.IsSecure,
                      Dialog.RouteSet);
end;

destructor TIdSipDialog.Destroy;
begin
  Self.RouteSet.Free;
  Self.RemoteTarget.Free;
  Self.RemoteURI.Free;
  Self.LocalUri.Free;
  Self.ID.Free;
  Self.LocalSequenceNoLock.Free;

  inherited Destroy;
end;

procedure TIdSipDialog.HandleMessage(const Request: TIdSipRequest);
begin
  if Request.IsInvite then
    Self.SetCanBeEstablished(true);
end;

procedure TIdSipDialog.HandleMessage(const Response: TIdSipResponse);
begin
  if (Self.RemoteTarget.Uri = '') then
    Self.RemoteTarget.URI := Response.FirstContact.Address.URI;

  if (Self.RemoteSequenceNo = 0) then
    Self.SetRemoteSequenceNo(Response.CSeq.SequenceNo);

  if Response.IsFinal then begin
    Self.SetIsEarly(false);

    if Self.CanBeEstablished and (Response.StatusCode = SIPOK) then
      Self.DoOnEstablished;
  end;

  if Response.IsProvisional then
    Self.SetIsEarly(true);
end;

function TIdSipDialog.IsNull: Boolean;
begin
  Result := false;
end;

function TIdSipDialog.IsOutOfOrder(const Request: TIdSipRequest): Boolean;
begin
  Result := (Self.RemoteSequenceNo > 0)
        and (Request.CSeq.SequenceNo < Self.RemoteSequenceNo);
end;

function TIdSipDialog.NextLocalSequenceNo: Cardinal;
begin
  Self.LocalSequenceNoLock.Acquire;
  try
    Inc(Self.fLocalSequenceNo);
    Result := Self.fLocalSequenceNo;
  finally
    Self.LocalSequenceNoLock.Release;
  end;
end;

//* TIdSipDialog Protected methods *********************************************

procedure TIdSipDialog.DoOnEstablished;
begin
  if Assigned(Self.OnEstablished) then
    Self.OnEstablished(Self);
end;

procedure TIdSipDialog.SetLocalSequenceNo(const Value: Cardinal);
begin
  Self.LocalSequenceNoLock.Acquire;
  try
    Self.fLocalSequenceNo := Value;
  finally
  Self.LocalSequenceNoLock.Release;
  end;
end;

procedure TIdSipDialog.SetRemoteSequenceNo(const Value: Cardinal);
begin
  Self.fRemoteSequenceNo := Value;
end;

procedure TIdSipDialog.SetRemoteTarget(const Value: TIdSipURI);
begin
  Self.RemoteTarget.URI := Value.URI;
end;

procedure TIdSipDialog.SetState(const Value: TIdSipDialogState);
begin
  Self.fState := Value;
end;

//* TIdSipDialog Private methods ***********************************************

procedure TIdSipDialog.CreateInternal(const DialogID: TIdSipDialogID;
                                      const LocalSequenceNo,
                                            RemoteSequenceNo: Cardinal;
                                      const LocalUri,
                                            RemoteUri,
                                            RemoteTarget: String;
                                      const IsSecure: Boolean;
                                      const RouteSet: TIdSipHeaderList);
begin
  Self.LocalSequenceNoLock := TCriticalSection.Create;

  fID := TIdSipDialogID.Create(DialogID);
  Self.SetLocalSequenceNo(LocalSequenceNo);
  Self.SetRemoteSequenceNo(RemoteSequenceNo);

  fLocalUri := TIdSipURI.Create(LocalUri);
  fRemoteUri := TIdSipURI.Create(RemoteUri);

  fRemoteTarget := TIdSipURI.Create(RemoteTarget);

  Self.SetIsSecure(IsSecure);

  fRouteSet := TIdSipHeaders.Create;
  fRouteSet.Add(RouteSet);
end;

function TIdSipDialog.GetIsEarly: Boolean;
begin
  Result := Self.fState = sdsEarly;
end;

function TIdSipDialog.GetLocalSequenceNo: Cardinal;
begin
  Self.LocalSequenceNoLock.Acquire;
  try
    Result := Self.fLocalSequenceNo;
  finally
    Self.LocalSequenceNoLock.Release;
  end;
end;

procedure TIdSipDialog.SetCanBeEstablished(const Value: Boolean);
begin
  Self.fCanBeEstablished := Value;
end;

procedure TIdSipDialog.SetIsEarly(const Value: Boolean);
begin
  if Value then
    Self.SetState(sdsEarly)
  else
    Self.SetState(sdsConfirmed);
end;

procedure TIdSipDialog.SetIsSecure(const Value: Boolean);
begin
  Self.fIsSecure := Value;
end;

//******************************************************************************
//* TIdSipNullDialog                                                           *
//******************************************************************************
//* TIdSipNullDialog Public methods ********************************************

function TIdSipNullDialog.IsNull: Boolean;
begin
  Result := true;
end;

//******************************************************************************
//* TIdSipDialogs                                                              *
//******************************************************************************
//* TIdSipDialogs Public methods ***********************************************

constructor TIdSipDialogs.Create;
begin
  inherited Create;

  Self.List := TObjectList.Create(true);
  Self.Lock := TCriticalSection.Create;
  Self.NullDlg := TIdSipNullDialog.Create;
end;

destructor TIdSipDialogs.Destroy;
begin
  Self.NullDlg.Free;
  Self.Lock.Free;
  Self.List.Free;

  inherited Destroy;
end;

procedure TIdSipDialogs.Add(const NewDialog: TIdSipDialog);
var
  D: TIdSipDialog;
begin
  Self.Lock.Acquire;
  try
    D := TIdSipDialog.Create(NewDialog);
    try
      Self.List.Add(D);
    except
      Self.List.Remove(D);
      D.Free;

      raise;
    end;
  finally
    Self.Lock.Release;
  end;
end;

function TIdSipDialogs.Count: Integer;
begin
  Self.Lock.Acquire;
  try
    Result := Self.List.Count;
  finally
    Self.Lock.Release;
  end;
end;

function TIdSipDialogs.DialogAt(const ID: TIdSipDialogID): TIdSipDialog;
var
  I: Integer;
begin
  Self.Lock.Acquire;
  try
    Result := nil;
    I := 0;
    while (I < Self.List.Count) and not Assigned(Result) do
      if (Self.List[I] as TIdSipDialog).ID.IsEqualTo(ID) then
        Result := Self.List[I] as TIdSipDialog
      else
        Inc(I);

    if not Assigned(Result) then
      Result := Self.NullDlg;
  finally
    Self.Lock.Release;
  end;
end;

function TIdSipDialogs.DialogAt(const CallID, LocalTag, RemoteTag: String): TIdSipDialog;
var
  ID: TIdSipDialogID;
begin
  ID := TIdSipDialogID.Create(CallID, LocalTag, RemoteTag);
  try
    Result := Self.DialogAt(ID);
  finally
    ID.Free;
  end;
end;

//* TIdSipDialogs Private methods **********************************************

function TIdSipDialogs.GetItem(const Index: Integer): TIdSipDialog;
begin
  Result := Self.List[Index] as TIdSipDialog;
end;

end.
