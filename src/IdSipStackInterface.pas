{
  (c) 2004 Directorate of New Technologies, Royal National Institute for Deaf people (RNID)

  The RNID licence covers this unit. Read the licence at:
      http://www.ictrnid.org.uk/docs/gw/rnid_license.txt

  This unit contains code written by:
    * Frank Shearar
}
unit IdSipStackInterface;

interface

uses
  Classes, Contnrs, IdInterfacedObject, IdNotification, IdSipCore,
  IdSipDialogID, IdSipInviteModule, IdSipLocation, IdSipMessage,
  IdSipOptionsModule, IdSipRegistration, IdSipSubscribeModule,
  IdSipTransaction, IdSipTransport, IdSipUserAgent, IdTimerQueue, SyncObjs,
  SysUtils, Messages, Windows;

type
  TIdSipHandle = Cardinal;

  TIdSipStackInterface = class;
  TIdEventData = class;
  IIdSipStackListener = interface
    ['{BBC8C7F4-4031-4258-93B3-8CA71C9F8733}']
    procedure OnEvent(Stack: TIdSipStackInterface;
                      Event: Cardinal;
                      Data: TIdEventData);
  end;

  TIdActionAssociation = class(TObject)
  private
    fAction: TIdSipAction;
    fHandle: TIdSipHandle;
  public
    constructor Create(Action: TIdSipAction;
                       Handle: TIdSipHandle);

    property Action: TIdSipAction read fAction;
    property Handle: TIdSipHandle read fHandle;
  end;

  TIdSipStackInterfaceEventMethod = class;
  TIdSipStackInterfaceExtension = class;
  TIdSipStackInterfaceExtensionClass = class of TIdSipStackInterfaceExtension;

  // I provide a high-level interface to a SIP stack.
  // On one hand, I make sure that messages are sent in the context of the
  // stack's thread (its Timer). On the other, I make sure that events from the
  // network (e.g., an inbound call) result in messages posted to Application's
  // message queue.
  //
  // You receive Handles to actions by calling methods with the prefix "Make".
  // You can perform actions using those Handles using the other methods. If you
  // call a method of mine with an invalid handle (a handle for an action that's
  // finished, a handle I never gave you) or try issue an inappropriate command
  // using an otherwise valid handle (calling AcceptCall on an outbound call,
  // for instance) I will raise an EInvalidHandle exception.
  //
  // My current implementation is Windows-specific. Ultimately, of course, we
  // want to be OS-agnostic (at least, as much as we can be).
  //
  // Find the details on what to put in the Configuration TStrings by reading
  // the class comment of TIdSipStackConfigurator.
  TIdSipStackInterface = class(TIdInterfacedObject,
                               IIdSipActionListener,
                               IIdSipInviteModuleListener,
                               IIdSipMessageModuleListener,
                               IIdSipOptionsListener,
                               IIdSipRegistrationListener,
                               IIdSipSessionListener,
                               IIdSipSubscribeModuleListener,
                               IIdSipSubscriptionListener,
                               IIdSipTransactionUserListener,
                               IIdSipTransportListener,
                               IIdSipTransportSendingListener)
  private
    ActionLock:      TCriticalSection;
    Actions:         TObjectList;
    fID:             String;
    fUiHandle:       HWnd;
    fUserAgent:      TIdSipUserAgent;
    SubscribeModule: TIdSipSubscribeModule;
    TimerQueue:      TIdTimerQueue;

    function  ActionFor(Handle: TIdSipHandle): TIdSipAction;
    function  AssociationAt(Index: Integer): TIdActionAssociation;
    procedure Configure(Configuration: TStrings);
    function  GetAndCheckAction(Handle: TIdSipHandle;
                                ExpectedType: TIdSipActionClass): TIdSipAction;
    function  HandleFor(Action: TIdSipAction): TIdSipHandle;
    function  IndexOf(H: TIdSipHandle): Integer;
    function  HasHandle(H: TIdSipHandle): Boolean;
    procedure ListenToAllTransports;
    function  NewHandle: TIdSipHandle;
    procedure NotifyEvent(Event: Cardinal;
                          Data: TIdEventData);
    procedure NotifyOfSentMessage(Msg: TIdSipMessage;
                                  Destination: TIdSipLocation);
    procedure NotifyOfStackShutdown;
    procedure NotifyOfStackStartup;
    procedure NotifyReferral(ActionHandle: TIdSipHandle;
                             NotifyType: TIdSipInboundReferralWaitClass;
                             Response: TIdSipResponse);
    procedure NotifySubscriptionEvent(Event: Cardinal;
                                      Subscription: TIdSipSubscription;
                                      Notify: TIdSipRequest);
    procedure OnAuthenticationChallenge(Action: TIdSipAction;
                                        Response: TIdSipResponse); overload;
    procedure OnAuthenticationChallenge(UserAgent: TIdSipAbstractCore;
                                        Challenge: TIdSipResponse;
                                        var Username: String;
                                        var Password: String;
                                        var TryAgain: Boolean); overload;
    procedure OnAuthenticationChallenge(UserAgent: TIdSipAbstractCore;
                                        ChallengedRequest: TIdSipRequest;
                                        Challenge: TIdSipResponse); overload;
    procedure OnDroppedUnmatchedMessage(UserAgent: TIdSipAbstractCore;
                                        Message: TIdSipMessage;
                                        Binding: TIdSipConnectionBindings);
    procedure OnEndedSession(Session: TIdSipSession;
                             ErrorCode: Cardinal;
                             const Reason: String);
    procedure OnEstablishedSession(Session: TIdSipSession;
                                   const RemoteSessionDescription: String;
                                   const MimeType: String);
    procedure OnEstablishedSubscription(Subscription: TIdSipOutboundSubscription;
                                        Notify: TIdSipRequest);
    procedure OnException(FailedMessage: TIdSipMessage;
                          E: Exception;
                          const Reason: String);
    procedure OnExpiredSubscription(Subscription: TIdSipOutboundSubscription;
                                    Notify: TIdSipRequest);
    procedure OnFailure(RegisterAgent: TIdSipOutboundRegistrationBase;
                        ErrorCode: Cardinal;
                        const Reason: String); overload;
    procedure OnFailure(Subscription: TIdSipOutboundSubscription;
                        Response: TIdSipResponse); overload;
    procedure OnInboundCall(UserAgent: TIdSipInviteModule;
                            Session: TIdSipInboundSession); overload;
    procedure OnModifySession(Session: TIdSipSession;
                              const RemoteSessionDescription: String;
                              const MimeType: String);
    procedure OnModifiedSession(Session: TIdSipSession;
                                Answer: TIdSipResponse);
    procedure OnNetworkFailure(Action: TIdSipAction;
                               ErrorCode: Cardinal;
                               const Reason: String);
    procedure OnNotify(Subscription: TIdSipOutboundSubscription;
                       Notify: TIdSipRequest);
    procedure OnProgressedSession(Session: TIdSipSession;
                                  Progress: TIdSipResponse);
    procedure OnReceiveRequest(Request: TIdSipRequest;
                               Receiver: TIdSipTransport;
                               Source: TIdSipConnectionBindings);
    procedure OnReceiveResponse(Response: TIdSipResponse;
                                Receiver: TIdSipTransport;
                                Source: TIdSipConnectionBindings);
    procedure OnReferral(Session: TIdSipSession;
                         Refer: TIdSipRequest;
                         Binding: TIdSipConnectionBindings);
    procedure OnRejectedMessage(const Msg: String;
                                const Reason: String);
    procedure OnRenewedSubscription(UserAgent: TIdSipAbstractCore;
                                    Subscription: TIdSipOutboundSubscription);
    procedure OnResponse(OptionsAgent: TIdSipOutboundOptions;
                         Response: TIdSipResponse);
    procedure OnSendRequest(Request: TIdSipRequest;
                            Sender: TIdSipTransport;
                            Destination: TIdSipLocation);
    procedure OnSendResponse(Response: TIdSipResponse;
                             Sender: TIdSipTransport;
                             Destination: TIdSipLocation);
    procedure OnSubscriptionRequest(UserAgent: TIdSipAbstractCore;
                                    Subscription: TIdSipInboundSubscription);
    procedure OnSuccess(RegisterAgent: TIdSipOutboundRegistrationBase;
                        CurrentBindings: TIdSipContacts);

    procedure RemoveAction(Handle: TIdSipHandle);
    procedure SendAction(Action: TIdSipAction);
    procedure StopListeningToAllTransports;
  protected
    function  AddAction(Action: TIdSipAction): TIdSipHandle;
    procedure ParseLine(Directive, Configuration: String); virtual;
    procedure PostConfigurationActions; virtual;
    procedure PreConfigurationActions; virtual;

    property UiHandle:  HWnd            read fUiHandle;
    property UserAgent: TIdSipUserAgent read fUserAgent;
  public
    constructor Create(UiHandle: HWnd;
                       TimerQueue: TIdTimerQueue;
                       Configuration: TStrings); reintroduce; virtual;
    destructor  Destroy; override;

    procedure AcceptCallModify(ActionHandle: TIdSipHandle;
                               const LocalSessionDescription: String;
                               const ContentType: String);
    procedure AnswerCall(ActionHandle: TIdSipHandle;
                         const Offer: String;
                         const ContentType: String);
    function  AttachExtension(EType: TIdSipStackInterfaceExtensionClass): TIdSipStackInterfaceExtension;
    procedure Authenticate(ActionHandle: TIdSipHandle;
                           Credentials: TIdSipAuthorizationHeader);
    function  GruuOf(ActionHandle: TIdSipHandle): String;
    function  HandleOf(const LocalGruu: String): TIdSipHandle;
    procedure HangUp(ActionHandle: TIdSipHandle);
    function  MakeCall(From: TIdSipFromHeader;
                       Dest: TIdSipAddressHeader;
                       const LocalSessionDescription: String;
                       const MimeType: String): TIdSipHandle; virtual;
    function  MakeOptionsQuery(Dest: TIdSipAddressHeader): TIdSipHandle;
    function  MakeRefer(Target: TIdSipAddressHeader;
                        Resource: TIdSipAddressHeader): TIdSipHandle;
    function  MakeRegistration(Registrar: TIdSipUri): TIdSipHandle;
    function  MakeSubscription(Target: TIdSipAddressHeader;
                               const EventPackage: String): TIdSipHandle;
    function  MakeTransfer(Transferee: TIdSipAddressHeader;
                           TransferTarget: TIdSipAddressHeader;
                           Call: TIdSipHandle): TIdSipHandle;
    procedure ModifyCall(ActionHandle: TIdSipHandle;
                         const Offer: String;
                         const ContentType: String);
    procedure NotifyOfReconfiguration;
    procedure NotifyReferralDenied(ActionHandle: TIdSipHandle);
    procedure NotifyReferralFailed(ActionHandle: TIdSipHandle;
                                   Response: TIdSipResponse = nil);
    procedure NotifyReferralSucceeded(ActionHandle: TIdSipHandle);
    procedure NotifyReferralTrying(ActionHandle: TIdSipHandle);
    procedure NotifySubcriber(ActionHandle: TIdSipHandle;
                              const Notification: String;
                              const MimeType: String);
    procedure ReconfigureStack(NewConfiguration: TStrings);
    procedure RedirectCall(ActionHandle: TIdSipHandle;
                           NewTarget: TIdSipAddressHeader);
    procedure RejectCall(ActionHandle: TIdSipHandle;
                         StatusCode: Cardinal;
                         StatusText: String = '');
    procedure Resume;
    procedure Send(ActionHandle: TIdSipHandle);
    procedure Terminate;

    property ID: String read fID;
  end;

  // I provide a registry for TIdSipStackInterface instances. Typically my
  // registry will only contain one entry, i.e., typically, there will be only
  // one TIdSipStackInterface instance in existence. However, if you built a
  // B2BUA, you would need two TIdSipStackInterfaces. The point of my existence
  // is to provide a safe way for TIdSipStackInterfaces to interact with other
  // objects sharing the same TIdTimerQueue: Wait objects for a
  // TIdSipStackInterface will use an ID to find the appropriate instance and,
  // only if that instance is found, will the Wait object trigger.
  TIdSipStackInterfaceRegistry = class(TObject)
  private
    class function StackInterfaceAt(Index: Integer): TIdSipStackInterface;
    class function StackInterfaceRegistry: TStrings;
  public
    class function  RegisterStackInterface(Instance: TIdSipStackInterface): String;
    class function  FindStackInterface(const StackInterfaceID: String): TIdSipStackInterface;
    class procedure UnregisterStackInterface(const StackInterfaceID: String);
  end;

  TIdSipStackInterfaceExtension = class(TObject)
  private
    fUserAgent: TIdSipUserAgent;
  protected
    property UserAgent: TIdSipUserAgent read fUserAgent;
  public
    constructor Create(UA: TIdSipUserAgent); virtual;
  end;

  TIdSipColocatedRegistrarExtension = class(TIdSipStackInterfaceExtension)
  private
    DB:             TIdSipAbstractBindingDatabase;
    RegisterModule: TIdSipRegisterModule;
  public
    constructor Create(UA: TIdSipUserAgent); override;

    procedure TargetsFor(URI: TIdSipUri; Targets: TIdSipContacts);
  end;

  // I contain data relating to a particular event.
  TIdEventData = class(TPersistent)
  private
    fHandle: TIdSipHandle;

    function TimestampLine: String;
  protected
    function Data: String; virtual;
    function EventName: String; virtual;
  public
    constructor Create; virtual;

    procedure Assign(Src: TPersistent); override;
    function  AsString: String;
    function  Copy: TIdEventData; virtual;

    property Handle: TIdSipHandle read fHandle write fHandle;
  end;

  TIdEventDataClass = class of TIdEventData;

  // An ErrorCode of 0 means "no error".
  // Usually the ErrorCode will map to a SIP response Status-Code.
  TIdInformationalData = class(TIdEventData)
  private
    fErrorCode: Cardinal;
    fReason:    String;

    procedure SetErrorCode(Value: Cardinal);
  protected
    function Data: String; override;
  public
    constructor Create; override;

    procedure Assign(Src: TPersistent); override;

    property ErrorCode: Cardinal read fErrorCode write SetErrorCode;
    property Reason: String read fReason write fReason;
  end;

  TIdAuthenticationChallengeData = class(TIdEventData)
  private
    fChallenge:         TIdSipResponse;
    fChallengedRequest: TIdSipRequest;

    procedure SetChallenge(Response: TIdSipResponse);
    procedure SetChallengedRequest(Request: TIdSipRequest);
  protected
    function Data: String; override;
    function EventName: String; override;
  public
    constructor Create; override;
    destructor  Destroy; override;

    procedure Assign(Src: TPersistent); override;

    property Challenge:         TIdSipResponse read fChallenge write SetChallenge;
    property ChallengedRequest: TIdSipRequest  read fChallengedRequest write SetChallengedRequest;
  end;

  TIdFailData = class(TIdInformationalData);

  TIdNetworkFailureData = class(TIdFailData)
  protected
    function EventName: String; override;
  end;

  // You might think that we should have a Response property to indicate why a
  // call ended (due to a failure). You'd be wrong. A call COULD end because
  // the UAS returned 486 Busy Here. A call could also end because we sent or
  // received a BYE, in which case a Response field would be misleading.
  TIdCallEndedData = class(TIdInformationalData)
  protected
    function EventName: String; override;
  end;

  TIdDebugData = class(TIdEventData)
  private
    fEvent: Cardinal;
  protected
    function EventName: String; override;
  public
    procedure Assign(Src: TPersistent); override;

    property Event: Cardinal read fEvent write fEvent;
  end;

  TIdDebugMessageData = class(TIdDebugData)
  private
    fMessage: TIdSipMessage;

  protected
    function Data: String; override;
  public
    destructor Destroy; override;

    procedure Assign(Src: TPersistent); override;

    property Message: TIdSipMessage read fMessage write fMessage;
  end;

  TIdDebugDroppedMessageData = class(TIdDebugMessageData)
  private
    fBinding: TIdSipConnectionBindings;

  protected
    function Data: String; override;
    function EventName: String; override;
  public
    destructor Destroy; override;

    procedure Assign(Src: TPersistent); override;

    property Binding: TIdSipConnectionBindings read fBinding write fBinding;
  end;

  TIdDebugReceiveMessageData = class(TIdDebugMessageData)
  private
    fBinding: TIdSipConnectionBindings;
  protected
    function Data: String; override;
    function EventName: String; override;
  public
    destructor Destroy; override;

    procedure Assign(Src: TPersistent); override;

    property Binding: TIdSipConnectionBindings read fBinding write fBinding;
  end;

  TIdDebugSendMessageData = class(TIdDebugMessageData)
  private
    fDestination: TIdSipLocation;
  protected
    function Data: String; override;
    function EventName: String; override;
  public
    destructor Destroy; override;

    procedure Assign(Src: TPersistent); override;

    property Destination: TIdSipLocation read fDestination write fDestination;
  end;

  TIdDebugTransportExceptionData = class(TIdDebugData)
  private
    fError:  String;
    fReason: String;
  protected
    function Data: String; override;
    function EventName: String; override;
  public
    procedure Assign(Src: TPersistent); override;

    property Error:  String read fError write fError;
    property Reason: String read fReason write fReason;
  end;

  TIdDebugTransportRejectedMessageData = class(TIdDebugData)
  private
    fMsg:    String;
    fReason: String;
  protected
    function Data: String; override;
    function EventName: String; override;
  public
    procedure Assign(Src: TPersistent); override;

    property Msg:    String read fMsg write fMsg;
    property Reason: String read fReason write fReason;
  end;

  TIdQueryOptionsData = class(TIdEventData)
  private
    fResponse: TIdSipResponse;

    procedure SetResponse(Value: TIdSipResponse);
  protected
    function Data: String; override;
    function EventName: String; override;
  public
    constructor Create; override;
    destructor  Destroy; override;

    procedure Assign(Src: TPersistent); override;

    property Response: TIdSipResponse read fResponse write SetResponse;
  end;

  TIdRegistrationData = class(TIdEventData)
  private
    fContacts: TIdSipContacts;

    procedure SetContacts(Value: TIdSipContacts);
  protected
    function Data: String; override;
    function EventName: String; override;
  public
    constructor Create; override;
    destructor  Destroy; override;

    procedure Assign(Src: TPersistent); override;

    property Contacts: TIdSipContacts read fContacts write SetContacts;
  end;

  TIdFailedRegistrationData = class(TIdFailData)
  private
    RegistrationData: TIdRegistrationData;

  protected
    function EventName: String; override;
  public
    constructor Create; override;
    destructor  Destroy; override;

    procedure Assign(Src: TPersistent); override;
  end;

  TIdSessionData = class(TIdEventData)
  private
    fLocalMimeType:            String;
    fLocalSessionDescription:  String;
    fRemoteContact:            TIdSipContactHeader;
    fRemoteMimeType:           String;
    fRemoteParty:              TIdSipAddressHeader;
    fRemoteSessionDescription: String;

    procedure SetRemoteContact(Value: TIdSipContactHeader);
    procedure SetRemoteParty(Value: TIdSipAddressHeader);
  protected
    function Data: String; override;
  public
    constructor Create; override;
    destructor  Destroy; override;

    procedure Assign(Src: TPersistent); override;

    property LocalMimeType:            String              read fLocalMimeType write fLocalMimeType;
    property LocalSessionDescription:  String              read fLocalSessionDescription write fLocalSessionDescription;
    property RemoteContact:            TIdSipContactHeader read fRemoteContact write SetRemoteContact;
    property RemoteMimeType:           String              read fRemoteMimeType write fRemoteMimeType;
    property RemoteParty:              TIdSipAddressHeader read fRemoteParty write SetRemoteParty;
    property RemoteSessionDescription: String              read fRemoteSessionDescription write fRemoteSessionDescription;
  end;

  TIdSessionDataClass = class of TIdSessionData;

  TIdEstablishedSessionData = class(TIdSessionData)
  protected
    function EventName: String; override;
  end;

  TIdInboundCallData = class(TIdSessionData)
  private
    fInvite: TIdSipRequest;

    procedure SetInvite(Value: TIdSipRequest);
  protected
    function EventName: String; override;
  public
    constructor Create; override;
    destructor  Destroy; override;

    procedure Assign(Src: TPersistent); override;

    property Invite: TIdSipRequest read fInvite write SetInvite;
  end;

  TIdModifiedSessionData = class(TIdSessionData)
  protected
    function EventName: String; override;
  end;

  TIdModifySessionData = class(TIdSessionData)
  protected
    function EventName: String; override;
  end;

  TIdSessionProgressData = class(TIdSessionData)
  private
    fBanner:       String;
    fProgressCode: Cardinal;
  protected
    function Data: String; override;
    function EventName: String; override;
  public
    procedure Assign(Src: TPersistent); override;

    property Banner:       String   read fBanner write fBanner;
    property ProgressCode: Cardinal read fProgressCode write fProgressCode;
  end;

  TIdSubscriptionData = class(TIdEventData)
  private
    fEventPackage: String;
  protected
    function Data: String; override;
  public
    procedure Assign(Src: TPersistent); override;

    property EventPackage: String read fEventPackage write fEventPackage;
  end;

  TIdSubscriptionRequestData = class(TIdSubscriptionData)
  private
    fFrom:          TIdSipFromHeader;
    fReferTo:       TIdSipReferToHeader;
    fRemoteContact: TIdSipContactHeader;
    fTarget:        TIdSipUri;

    procedure SetFrom(Value: TIdSipFromHeader);
    procedure SetReferTo(Value: TIdSipReferToHeader);
    procedure SetRemoteContact(Value: TIdSipContactHeader);
    procedure SetTarget(Value: TIdSipUri);
  protected
    function Data: String; override;
    function EventName: String; override;
  public
    constructor Create; override;
    destructor  Destroy; override;

    procedure Assign(Src: TPersistent); override;

    property From:          TIdSipFromHeader    read fFrom write SetFrom;
    property ReferTo:       TIdSipReferToHeader read fReferTo write SetReferTo;
    property RemoteContact: TIdSipContactHeader read fRemoteContact write SetRemoteContact;
    property Target:        TIdSipUri           read fTarget write SetTarget;
  end;

  TIdResubscriptionData = class(TIdSubscriptionData)
  end;

  // ReferAction contains the handle of the TIdSipInboundReferral that the stack
  // has allocated to handling this request.
  TIdSessionReferralData = class(TIdSubscriptionRequestData)
  private
    fReferAction: TIdSipHandle;
  protected
    function Data: String; override;
    function EventName: String; override;
  public
    procedure Assign(Src: TPersistent); override;

    property ReferAction: TIdSipHandle read fReferAction write fReferAction;
  end;

  TIdSubscriptionNotifyData = class(TIdEventData)
  private
    fEvent:  Cardinal;
    fNotify: TIdSipRequest;

    procedure SetNotify(Value: TIdSipRequest);
  protected
    function Data: String; override;
    function EventName: String; override;
  public
    constructor Create; override;
    destructor  Destroy; override;

    procedure Assign(Src: TPersistent); override;

    property Event:  Cardinal      read fEvent write fEvent;
    property Notify: TIdSipRequest read fNotify write SetNotify;
  end;

  TIdFailedSubscriptionData = class(TIdFailData)
  private
    fResponse: TIdSipResponse;

    procedure SetResponse(Value: TIdSipResponse);
  protected
    function Data: String; override;
    function EventName: String; override;
  public
    constructor Create; override;
    destructor  Destroy; override;

    procedure Assign(Src: TPersistent); override;

    property Response: TIdSipResponse read fResponse write SetResponse;
  end;

  TIdStackReconfiguredData = class(TIdEventData)
  private
    fActsAsRegistrar: Boolean;
  protected
    function Data: String; override;
    function EventName: String; override;
  public
    procedure Assign(Src: TPersistent); override;

    property ActsAsRegistrar: Boolean read fActsAsRegistrar write fActsAsRegistrar;
  end;

  // I represent a reified method call, like my ancestor, that a
  // SipStackInterface uses to signal that something interesting happened (an
  // inbound call has arrived, a network failure occured, an action succeeded,
  // tc.)
  TIdSipStackInterfaceEventMethod = class(TIdNotification)
  private
    fData:   TIdEventData;
    fEvent:  Cardinal;
    fStack:  TIdSipStackInterface;
  public
    procedure Run(const Subject: IInterface); override;

    property Data:   TIdEventData         read fData write fData;
    property Event:  Cardinal             read fEvent write fEvent;
    property Stack:  TIdSipStackInterface read fStack write fStack;
  end;

  TIdSipStackReconfigureStackInterfaceWait = class(TIdWait)
  private
    fConfiguration: TStrings;
    fStackID:       String;

    procedure SetConfiguration(Value: TStrings);
  public
    constructor Create; override;
    destructor  Destroy; override;

    procedure Trigger; override;

    property Configuration: TStrings read fConfiguration write SetConfiguration;
    property StackID:       String   read fStackID write fStackID;
  end;

  EInvalidHandle = class(Exception);

  // Raise me when the UserAgent doesn't support an action (e.g., it doesn't use
  // the SubscribeModule and the caller tried to MakeRefer).
  ENotSupported = class(Exception);

// Call management constants
const
  InvalidHandle = 0;

const
  CM_BASE = WM_USER;

  CM_SUCCESS                      = CM_BASE + 0;
  CM_FAIL                         = CM_BASE + 1;
  CM_NETWORK_FAILURE              = CM_BASE + 2;
  CM_CALL_REQUEST_NOTIFY          = CM_BASE + 3;
  CM_CALL_ENDED                   = CM_BASE + 4;
  CM_CALL_ESTABLISHED             = CM_BASE + 5;
  CM_CALL_REMOTE_MODIFY_REQUEST   = CM_BASE + 6;
  CM_CALL_OUTBOUND_MODIFY_SUCCESS = CM_BASE + 7;
  CM_CALL_PROGRESS                = CM_BASE + 8;
  CM_CALL_REFERRAL                = CM_BASE + 9;
  CM_AUTHENTICATION_CHALLENGE     = CM_BASE + 10;
  CM_SUBSCRIPTION_ESTABLISHED     = CM_BASE + 11;
  CM_SUBSCRIPTION_RECV_NOTIFY     = CM_BASE + 12;
  CM_SUBSCRIPTION_EXPIRED         = CM_BASE + 13;
  CM_SUBSCRIPTION_REQUEST_NOTIFY  = CM_BASE + 14;
  CM_SUBSCRIPTION_RESUBSCRIBED    = CM_BASE + 15;
  CM_QUERY_OPTIONS_RESPONSE       = CM_BASE + 16;
  CM_STACK_RECONFIGURED           = CM_BASE + 17;

  CM_DEBUG = CM_BASE + 10000;

  CM_DEBUG_DROPPED_MSG            = CM_DEBUG + 0;
  CM_DEBUG_RECV_MSG               = CM_DEBUG + 1;
  CM_DEBUG_SEND_MSG               = CM_DEBUG + 2;
  CM_DEBUG_TRANSPORT_EXCEPTION    = CM_DEBUG + 3;
  CM_DEBUG_TRANSPORT_REJECTED_MSG = CM_DEBUG + 4;
  CM_DEBUG_STACK_STARTED          = CM_DEBUG + 5;
  CM_DEBUG_STACK_STOPPED          = CM_DEBUG + 6;
  CM_LAST                         = CM_DEBUG_STACK_STOPPED;

// Constants for TIdCallEndedData
const
  CallEndedSuccess        = 0;
  CallEndedFailure        = 1;
  CallEndedNotFound       = SIPNotFound;
  CallEndedRejected       = SIPBusyHere;
  CallServiceNotAvailable = SIPServiceUnavailable;

type
  TIdSipEventMessage = packed record
    Event:    Cardinal;
    Data:     TIdSipStackInterfaceEventMethod;
    Reserved: DWord;
  end;

function EventNames(Event: Cardinal): String;

implementation

uses
  IdRandom, IdSimpleParser, IdSipAuthentication, IdSipIndyLocator,
  IdSipMockLocator, IdStack, IdUDPServer;

var
  GStackInterfaces: TStrings;

const
  ActionNotAllowedForHandle = 'You cannot perform a %s action on a %s handle (%d)';
  NoSuchHandle              = 'No such handle (%d)';

function EventNames(Event: Cardinal): String;
begin
  case Event of
    CM_AUTHENTICATION_CHALLENGE:     Result := 'CM_AUTHENTICATION_CHALLENGE';
    CM_FAIL:                         Result := 'CM_FAIL';
    CM_NETWORK_FAILURE:              Result := 'CM_NETWORK_FAILURE';
    CM_CALL_ENDED:                   Result := 'CM_CALL_ENDED';
    CM_CALL_ESTABLISHED:             Result := 'CM_CALL_ESTABLISHED';
    CM_CALL_OUTBOUND_MODIFY_SUCCESS: Result := 'CM_CALL_OUTBOUND_MODIFY_SUCCESS';
    CM_CALL_PROGRESS:                Result := 'CM_CALL_PROGRESS';
    CM_CALL_REMOTE_MODIFY_REQUEST:   Result := 'CM_CALL_REMOTE_MODIFY_REQUEST';
    CM_CALL_REQUEST_NOTIFY:          Result := 'CM_CALL_REQUEST_NOTIFY';
    CM_SUBSCRIPTION_ESTABLISHED:     Result := 'CM_SUBSCRIPTION_ESTABLISHED';
    CM_SUBSCRIPTION_EXPIRED:         Result := 'CM_SUBSCRIPTION_EXPIRED';
    CM_SUBSCRIPTION_RECV_NOTIFY:     Result := 'CM_SUBSCRIPTION_RECV_NOTIFY';
    CM_SUBSCRIPTION_REQUEST_NOTIFY:  Result := 'CM_SUBSCRIPTION_REQUEST_NOTIFY';
    CM_SUBSCRIPTION_RESUBSCRIBED:    Result := 'CM_SUBSCRIPTION_RESUBSCRIBED';
    CM_SUCCESS:                      Result := 'CM_SUCCESS';
    CM_QUERY_OPTIONS_RESPONSE:       Result := 'CM_QUERY_OPTIONS_RESPONSE';
    CM_STACK_RECONFIGURED:           Result := 'CM_STACK_RECONFIGURED';

    CM_DEBUG_DROPPED_MSG:            Result := 'CM_DEBUG_DROPPED_MSG';
    CM_DEBUG_RECV_MSG:               Result := 'CM_DEBUG_RECV_MSG';
    CM_DEBUG_SEND_MSG:               Result := 'CM_DEBUG_SEND_MSG';
    CM_DEBUG_TRANSPORT_EXCEPTION:    Result := 'CM_DEBUG_TRANSPORT_EXCEPTION';
    CM_DEBUG_TRANSPORT_REJECTED_MSG: Result := 'CM_DEBUG_TRANSPORT_REJECTED_MSG';
    CM_DEBUG_STACK_STARTED:          Result := 'CM_DEBUG_STACK_STARTED';
    CM_DEBUG_STACK_STOPPED:          Result := 'CM_DEBUG_STACK_STOPPED';
  else
    Result := 'Unknown: ' + IntToStr(Event);
  end;
end;

//******************************************************************************
//* TIdActionAssociation                                                       *
//******************************************************************************
//* TIdActionAssociation Public methods ****************************************

constructor TIdActionAssociation.Create(Action: TIdSipAction;
                                        Handle: TIdSipHandle);
begin
  inherited Create;

  Self.fAction := Action;
  Self.fHandle := Handle;
end;

//******************************************************************************
//* TIdSipStackInterface                                                       *
//******************************************************************************
//* TIdSipStackInterface Public methods ****************************************

constructor TIdSipStackInterface.Create(UiHandle: HWnd;
                                        TimerQueue: TIdTimerQueue;
                                        Configuration: TStrings);
var
  Configurator: TIdSipStackConfigurator;
  Module:       TIdSipMessageModule;
begin
  inherited Create;

  Self.TimerQueue := TimerQueue;

  Self.ActionLock := TCriticalSection.Create;
  Self.Actions    := TObjectList.Create(true);

  Self.fUiHandle := UiHandle;

  Configurator := TIdSipStackConfigurator.Create;
  try
    Self.fUserAgent := Configurator.CreateUserAgent(Configuration, Self.TimerQueue);
    Self.UserAgent.AddListener(Self);
    Self.UserAgent.InviteModule.AddListener(Self);
//    Self.UserAgent.AddTransportListener(Self);

    Self.ListenToAllTransports;

    Module := Self.UserAgent.ModuleFor(TIdSipSubscribeModule);

    if not Module.IsNull then begin
      Self.SubscribeModule := Module as TIdSipSubscribeModule;
      Self.SubscribeModule.AddListener(Self);
    end;
  finally
    Configurator.Free;
  end;

  Self.Configure(Configuration);

  Self.fID := TIdSipStackInterfaceRegistry.RegisterStackInterface(Self);
  Self.NotifyOfReconfiguration;
end;

destructor TIdSipStackInterface.Destroy;
begin
  Self.NotifyOfStackShutdown;

  TIdSipStackInterfaceRegistry.UnregisterStackInterface(Self.ID);

//  Self.DebugUnregister;

  Self.UserAgent.Free;

  Self.Actions.Free;
  Self.ActionLock.Free;

  inherited Destroy;
end;

procedure TIdSipStackInterface.AcceptCallModify(ActionHandle: TIdSipHandle;
                                                const LocalSessionDescription: String;
                                                const ContentType: String);
var
  Action: TIdSipAction;
  Wait:   TIdSipSessionAcceptCallModify;
begin
  Self.ActionLock.Acquire;
  try
    Action := Self.GetAndCheckAction(ActionHandle, TIdSipSession);
    Wait   := TIdSipSessionAcceptCallModify.Create;
    Wait.ContentType := ContentType;
    Wait.Offer       := LocalSessionDescription;
    Wait.Session     := Action as TIdSipSession;

   Self.TimerQueue.AddEvent(TriggerImmediately, Wait);
  finally
    Self.ActionLock.Release;
  end;
end;

procedure TIdSipStackInterface.AnswerCall(ActionHandle: TIdSipHandle;
                                          const Offer: String;
                                          const ContentType: String);
var
  Action: TIdSipAction;
  Wait:   TIdSipSessionAcceptWait;
begin
  Self.ActionLock.Acquire;
  try
    Action := Self.GetAndCheckAction(ActionHandle, TIdSipInboundSession);

    Wait := TIdSipSessionAcceptWait.Create;
    Wait.ContentType := ContentType;
    Wait.Offer       := Offer;
    Wait.Session     := Action as TIdSipInboundSession;

    Self.TimerQueue.AddEvent(TriggerImmediately, Wait);
  finally
    Self.ActionLock.Release;
  end;
end;

function TIdSipStackInterface.AttachExtension(EType: TIdSipStackInterfaceExtensionClass): TIdSipStackInterfaceExtension;
begin
  Result := EType.Create(Self.UserAgent);
end;

procedure TIdSipStackInterface.Authenticate(ActionHandle: TIdSipHandle;
                                            Credentials: TIdSipAuthorizationHeader);
var
  Action: TIdSipAction;
begin
  Self.ActionLock.Acquire;
  try
    Action := Self.GetAndCheckAction(ActionHandle, TIdSipAction);

    Action.Resend(Credentials);
  finally
    Self.ActionLock.Release;
  end;
end;

function TIdSipStackInterface.GruuOf(ActionHandle: TIdSipHandle): String;
var
  Action: TIdSipAction;
begin
  // Return the GRUU of the action referenced by ActionHandle. This can be the
  // empty string - typically if the stack doesn't support GRUU.

  Self.ActionLock.Acquire;
  try
    Action := Self.GetAndCheckAction(ActionHandle, TIdSipSession);

    Result := Action.LocalGruu.FullValue;
  finally
    Self.ActionLock.Release;
  end;
end;

function TIdSipStackInterface.HandleOf(const LocalGruu: String): TIdSipHandle;
begin
  // Find the handle of the action that uses LocalGruu as a Contact (typically
  // either a Session or a Subscription/Referral).
  Self.ActionLock.Acquire;
  try
    Result := Self.HandleFor(Self.UserAgent.FindActionForGruu(LocalGruu));
  finally
    Self.ActionLock.Release;
  end;
end;

procedure TIdSipStackInterface.HangUp(ActionHandle: TIdSipHandle);
var
  Action: TIdSipAction;
  TerminateWait: TIdSipActionTerminateWait;
begin
  Self.ActionLock.Acquire;
  try
    Action := Self.GetAndCheckAction(ActionHandle, TIdSipSession);

    TerminateWait := TIdSipActionTerminateWait.Create;
    TerminateWait.ActionID := Action.ID;

    Self.TimerQueue.AddEvent(TriggerImmediately, TerminateWait);
  finally
    Self.ActionLock.Release;
  end;
end;

function TIdSipStackInterface.MakeCall(From: TIdSipFromHeader;
                                       Dest: TIdSipAddressHeader;
                                       const LocalSessionDescription: String;
                                       const MimeType: String): TIdSipHandle;
var
  Sess: TIdSipOutboundSession;
begin
  if From.IsMalformed then begin
    Result := InvalidHandle;
    Exit;
  end;

  if Dest.IsMalformed then begin
    Result := InvalidHandle;
    Exit;
  end;

  Sess := Self.UserAgent.InviteModule.Call(From, Dest, LocalSessionDescription, MimeType);
  Result := Self.AddAction(Sess);
  Sess.AddSessionListener(Self);
end;

function TIdSipStackInterface.MakeOptionsQuery(Dest: TIdSipAddressHeader): TIdSipHandle;
var
  Options: TIdSipOutboundOptions;
begin
  if Dest.IsMalformed then begin
    Result := InvalidHandle;
    Exit;
  end;

  Options := Self.UserAgent.QueryOptions(Dest) as TIdSipOutboundOptions;
  Result := Self.AddAction(Options);
  Options.AddListener(Self);
end;

function TIdSipStackInterface.MakeRefer(Target: TIdSipAddressHeader;
                                        Resource: TIdSipAddressHeader): TIdSipHandle;
var
  Ref: TIdSipOutboundReferral;
begin
  if Target.IsMalformed then begin
    Result := InvalidHandle;
    Exit;
  end;

  // Refer Target to the Resource by sending a REFER message to Target.

  // Check that the UA even supports REFER!
  if not Assigned(Self.SubscribeModule) then
    raise ENotSupported.Create(MethodRefer);

  Ref := Self.SubscribeModule.Refer(Target, Resource);
  Result := Self.AddAction(Ref);
  Ref.AddListener(Self);
end;

function TIdSipStackInterface.MakeRegistration(Registrar: TIdSipUri): TIdSipHandle;
var
  Reg: TIdSipOutboundRegistrationBase;
begin
  if Registrar.IsMalformed then begin
    Result := InvalidHandle;
    Exit;
  end;

  if not Self.UserAgent.UsesModule(TIdSipOutboundRegisterModule) then begin
    Result := InvalidHandle;
    Exit;
  end;

  Reg := Self.UserAgent.RegisterWith(Registrar, Self.UserAgent.From);
  Result := Self.AddAction(Reg);
  Reg.AddListener(Self);
end;

function TIdSipStackInterface.MakeSubscription(Target: TIdSipAddressHeader;
                                               const EventPackage: String): TIdSipHandle;
var
  Sub: TIdSipOutboundSubscription;
  SubMod: TIdSipSubscribeModule;
begin
  if Target.IsMalformed then begin
    Result := InvalidHandle;
    Exit;
  end;

  if not Self.UserAgent.UsesModule(MethodSubscribe) then begin
    Result := InvalidHandle;
    Exit;
  end;

  SubMod := Self.UserAgent.ModuleFor(MethodSubscribe) as TIdSipSubscribeModule;
  Sub := SubMod.Subscribe(Target, EventPackage);
  Result := Self.AddAction(Sub);
  Sub.AddListener(Self);
end;

function TIdSipStackInterface.MakeTransfer(Transferee: TIdSipAddressHeader;
                                           TransferTarget: TIdSipAddressHeader;
                                           Call: TIdSipHandle): TIdSipHandle;
var
  Action:       TIdSipAction;
  Ref:          TIdSipOutboundReferral;
  Session:      TIdSipSession;
  TargetDialog: TIdSipDialogID;
begin
  // Transfer Transferee to TranserTarget using the (remote party's) dialog
  // ID of Call as authorization.

  if Transferee.IsMalformed
    or TransferTarget.IsMalformed then begin
    Result := InvalidHandle;
    Exit;
  end;

  // Check that the UA even supports REFER!
  if not Assigned(Self.SubscribeModule) then
    raise ENotSupported.Create(MethodRefer);

  Self.ActionLock.Acquire;
  try
    Action := Self.GetAndCheckAction(Call, TIdSipSession);

    Session := Action as TIdSipSession;

    TargetDialog := Session.Dialog.ID.GetRemoteID;
    try
      Ref := Self.SubscribeModule.Transfer(Transferee,
                                           TransferTarget,
                                           TargetDialog);
      Result := Self.AddAction(Ref);
      Ref.AddListener(Self);
    finally
      TargetDialog.Free;
    end;
  finally
    Self.ActionLock.Release;
  end;
end;

procedure TIdSipStackInterface.ModifyCall(ActionHandle: TIdSipHandle;
                                          const Offer: String;
                                          const ContentType: String);
var
  Action: TIdSipAction;
  Wait:   TIdSipSessionModifyWait;
begin
  Self.ActionLock.Acquire;
  try
    Action := Self.GetAndCheckAction(ActionHandle, TIdSipSession);

    Wait := TIdSipSessionModifyWait.Create;
    Wait.Session := Action as TIdSipSession;
    Wait.ContentType := ContentType;
    Wait.Offer := Offer;

    Self.TimerQueue.AddEvent(TriggerImmediately, Wait);
  finally
    Self.ActionLock.Release;
  end;
end;

procedure TIdSipStackInterface.NotifyOfReconfiguration;
var
  Data: TIdStackReconfiguredData;
begin
  Data := TIdStackReconfiguredData.Create;
  try
    Data.ActsAsRegistrar := Self.UserAgent.UsesModule(TIdSipRegisterModule);
    Data.Handle          := InvalidHandle;

    Self.NotifyEvent(CM_STACK_RECONFIGURED, Data);
  finally
    Data.Free;
  end;
end;

procedure TIdSipStackInterface.NotifyReferralDenied(ActionHandle: TIdSipHandle);
begin
  Self.NotifyReferral(ActionHandle, TIdSipNotifyReferralDeniedWait, nil);
end;

procedure TIdSipStackInterface.NotifyReferralFailed(ActionHandle: TIdSipHandle;
                                                    Response: TIdSipResponse = nil);
begin
  Self.NotifyReferral(ActionHandle, TIdSipNotifyReferralFailedWait, Response);
end;

procedure TIdSipStackInterface.NotifyReferralSucceeded(ActionHandle: TIdSipHandle);
begin
  Self.NotifyReferral(ActionHandle, TIdSipNotifyReferralSucceededWait, nil);
end;

procedure TIdSipStackInterface.NotifyReferralTrying(ActionHandle: TIdSipHandle);
begin
  Self.NotifyReferral(ActionHandle, TIdSipNotifyReferralTryingWait, nil);
end;

procedure TIdSipStackInterface.NotifySubcriber(ActionHandle: TIdSipHandle;
                                               const Notification: String;
                                               const MimeType: String);
var
  Action: TIdSipAction;
  Wait:   TIdSipInboundSubscriptionNotifyWait;
begin
  Self.ActionLock.Acquire;
  try
    Action := Self.GetAndCheckAction(ActionHandle, TIdSipInboundSubscription);

    Wait := TIdSipInboundSubscriptionNotifyWait.Create;
    Wait.MimeType     := MimeType;
    Wait.Notification := Notification;
    Wait.Subscription := Action as TIdSipInboundSubscription;

    Self.TimerQueue.AddEvent(TriggerImmediately, Wait);
  finally
    Self.ActionLock.Release;
  end;
end;

procedure TIdSipStackInterface.ReconfigureStack(NewConfiguration: TStrings);
var
  Wait: TIdSipStackReconfigureStackInterfaceWait;
begin
  Wait := TIdSipStackReconfigureStackInterfaceWait.Create;
  Wait.Configuration := NewConfiguration;
  Wait.StackID       := Self.ID;
  
  Self.TimerQueue.AddEvent(TriggerImmediately, Wait);
end;

procedure TIdSipStackInterface.RedirectCall(ActionHandle: TIdSipHandle;
                                            NewTarget: TIdSipAddressHeader);
var
  Action: TIdSipAction;
  Wait:   TIdSipSessionRedirectWait;
begin
  Self.ActionLock.Acquire;
  try
    Action := Self.GetAndCheckAction(ActionHandle, TIdSipInboundSession);

    Wait := TIdSipSessionRedirectWait.Create;
    Wait.NewTarget := NewTarget;
    Wait.Session   := Action as TIdSipInboundSession;

    Self.TimerQueue.AddEvent(TriggerImmediately, Wait);
  finally
    Self.ActionLock.Release;
  end;
end;

procedure TIdSipStackInterface.RejectCall(ActionHandle: TIdSipHandle;
                                          StatusCode: Cardinal;
                                          StatusText: String = '');
var
  Action: TIdSipAction;
  Wait:   TIdSipSessionRejectWait;
begin
  Self.ActionLock.Acquire;
  try
    Action := Self.GetAndCheckAction(ActionHandle, TIdSipInboundSession);

    Wait := TIdSipSessionRejectWait.Create;
    Wait.Session    := Action as TIdSipInboundSession;
    Wait.StatusCode := StatusCode;
    Wait.StatusText := StatusText;

    Self.TimerQueue.AddEvent(TriggerImmediately, Wait);
  finally
    Self.ActionLock.Release;
  end;
end;

procedure TIdSipStackInterface.Resume;
var
  I: Integer;
begin
  // Start me first (since I'm the "heartbeat" thread).
  Self.TimerQueue.Resume;

  // THEN start my transport threads.
  for I := 0 to Self.UserAgent.Dispatcher.TransportCount - 1 do
    Self.UserAgent.Dispatcher.Transports[I].Start;

  Self.NotifyOfStackStartup;
end;

procedure TIdSipStackInterface.Send(ActionHandle: TIdSipHandle);
var
  Action: TIdSipAction;
begin
  Self.ActionLock.Acquire;
  try
    Action := Self.GetAndCheckAction(ActionHandle, TIdSipAction);

    Self.SendAction(Action);
  finally
    Self.ActionLock.Release;
  end;
end;

procedure TIdSipStackInterface.Terminate;
begin
  Self.Free;
end;

//* TIdSipStackInterface Protected methods *************************************

function TIdSipStackInterface.AddAction(Action: TIdSipAction): TIdSipHandle;
var
  Assoc: TIdActionAssociation;
begin
  Self.ActionLock.Acquire;
  try
    Result := Self.NewHandle;
    Assoc := TIdActionAssociation.Create(Action, Result);
    Self.Actions.Add(Assoc);
  finally
    Self.ActionLock.Release;
  end;
end;

procedure TIdSipStackInterface.ParseLine(Directive, Configuration: String);
begin
  // I have no special processing directives, even though my subclasses might.
end;

procedure TIdSipStackInterface.PostConfigurationActions;
begin
  Self.ListenToAllTransports;
end;

procedure TIdSipStackInterface.PreConfigurationActions;
begin
  Self.StopListeningToAllTransports;
end;

//* TIdSipStackInterface Private methods ***************************************

function TIdSipStackInterface.ActionFor(Handle: TIdSipHandle): TIdSipAction;
var
  I: Integer;
begin
  // Precondition: ActionLock acquired.
  I      := 0;
  Result := nil;

  while (I < Self.Actions.Count) and not Assigned(Result) do begin
    if (Self.AssociationAt(I).Handle = Handle) then
      Result := Self.AssociationAt(I).Action
    else
      Inc(I);
  end;
end;

function TIdSipStackInterface.AssociationAt(Index: Integer): TIdActionAssociation;
begin
  Result := Self.Actions[Index] as TIdActionAssociation;
end;

procedure TIdSipStackInterface.Configure(Configuration: TStrings);
var
  Config:    String;
  Directive: String;
  I:         Integer;
begin
  Self.PreConfigurationActions;
  try
    for I := 0 to Configuration.Count - 1 do begin
      Config := Configuration[I];
      Directive := Trim(Fetch(Config, ':'));

      Self.ParseLine(Directive, Trim(Config));
    end;
  finally
    Self.PostConfigurationActions;
  end;
end;

function TIdSipStackInterface.GetAndCheckAction(Handle: TIdSipHandle;
                                                ExpectedType: TIdSipActionClass): TIdSipAction;
begin
  Result := Self.ActionFor(Handle);

  if not Assigned(Result) then
    raise EInvalidHandle.Create(Format(NoSuchHandle, [Handle]));

  if not (Result is ExpectedType) then
    raise EInvalidHandle.Create(Format(ActionNotAllowedForHandle, [Result.ClassName, ExpectedType.ClassName, Handle]));
end;

function TIdSipStackInterface.HandleFor(Action: TIdSipAction): TIdSipHandle;
var
  I: Integer;
begin
  // Precondition: ActionLock acquired.
  I      := 0;
  Result := InvalidHandle;

  while (I < Self.Actions.Count) and (Result = InvalidHandle) do begin
    if (Self.AssociationAt(I).Action = Action) then
      Result := Self.AssociationAt(I).Handle
    else
      Inc(I);
  end;
end;

function TIdSipStackInterface.IndexOf(H: TIdSipHandle): Integer;
var
  Found: Boolean;
begin
  // Precondition: ActionLock acquired.

  if (Self.Actions.Count = 0) then begin
    Result := ItemNotFoundIndex;
    Exit;
  end;

  Found  := false;
  Result := 0;
  while (Result < Self.Actions.Count) and not Found do begin
    if (Self.AssociationAt(Result).Handle = H) then
      Found := true
    else
      Inc(Result);
  end;

  if not Found then
    Result := ItemNotFoundIndex;
end;

function TIdSipStackInterface.HasHandle(H: TIdSipHandle): Boolean;
begin
  // Precondition: ActionLock acquired.
  Result := Self.IndexOf(H) <> ItemNotFoundIndex;
end;

procedure TIdSipStackInterface.ListenToAllTransports;
var
  I: Integer;
begin
  for I := 0 to Self.UserAgent.Dispatcher.TransportCount - 1 do begin
    Self.UserAgent.Dispatcher.Transports[I].AddTransportListener(Self);
    Self.UserAgent.Dispatcher.Transports[I].AddTransportSendingListener(Self);
  end;
end;

function TIdSipStackInterface.NewHandle: TIdSipHandle;
begin
  // Precondition: ActionLock acquired.
  // Postcondition: Result contains a handle that's not assigned to any ongoing
  // action.

  repeat
    Result := GRandomNumber.NextCardinal;
  until not Self.HasHandle(Result);
end;

procedure TIdSipStackInterface.NotifyEvent(Event: Cardinal;
                                           Data: TIdEventData);
var
  Notification: TIdSipStackInterfaceEventMethod;
begin
  Notification := TIdSipStackInterfaceEventMethod.Create;
  Notification.Data   := Data.Copy;
  Notification.Event  := Event;
  Notification.Stack  := Self;

  // The receiver of this message must free the Notification.
  PostMessage(Self.UiHandle, UINT(Notification.Event), WPARAM(Notification), 0)
end;

procedure TIdSipStackInterface.NotifyOfSentMessage(Msg: TIdSipMessage;
                                                   Destination: TIdSipLocation);

var
  Data: TIdDebugSendMessageData;
begin
  Data := TIdDebugSendMessageData.Create;
  try
    Data.Handle      := InvalidHandle;
    Data.Destination := Destination.Copy;
    Data.Message     := Msg.Copy;

    Self.NotifyEvent(CM_DEBUG_SEND_MSG, Data);
  finally
    Data.Free;
  end;
end;

procedure TIdSipStackInterface.NotifyOfStackShutdown;
var
  Data: TIdDebugData;
begin
  Data := TIdDebugData.Create;
  try
    Data.Handle := InvalidHandle;
    Data.Event  := CM_DEBUG_STACK_STOPPED;

    Self.NotifyEvent(CM_DEBUG_STACK_STOPPED, Data);
  finally
    Data.Free;
  end;
end;

procedure TIdSipStackInterface.NotifyOfStackStartup;
var
  Data: TIdDebugData;
begin
  Data := TIdDebugData.Create;
  try
    Data.Handle := InvalidHandle;
    Data.Event  := CM_DEBUG_STACK_STARTED;

    Self.NotifyEvent(CM_DEBUG_STACK_STARTED, Data);
  finally
    Data.Free;
  end;
end;

procedure TIdSipStackInterface.NotifyReferral(ActionHandle: TIdSipHandle;
                                              NotifyType: TIdSipInboundReferralWaitClass;
                                              Response: TIdSipResponse);
var
  Action: TIdSipAction;
  Wait:   TIdSipInboundReferralWait;
begin
  Self.ActionLock.Acquire;
  try
    Action := Self.GetAndCheckAction(ActionHandle, TIdSipInboundReferral);

    Wait := NotifyType.Create;
    Wait.Referral := Action as TIdSipInboundReferral;
    Wait.Response := Response;

    Self.TimerQueue.AddEvent(TriggerImmediately, Wait);
  finally
    Self.ActionLock.Release;
  end;
end;

procedure TIdSipStackInterface.NotifySubscriptionEvent(Event: Cardinal;
                                                       Subscription: TIdSipSubscription;
                                                       Notify: TIdSipRequest);
var
  Data: TIdSubscriptionNotifyData;
begin
  Data := TIdSubscriptionNotifyData.Create;
  try
    Data.Handle := Self.HandleFor(Subscription);
    Data.Event  := Event;

    if (Notify <> nil) then
      Data.Notify := Notify;

    Self.NotifyEvent(Event, Data);
  finally
    Data.Free;
  end;
end;

procedure TIdSipStackInterface.OnAuthenticationChallenge(Action: TIdSipAction;
                                                         Response: TIdSipResponse);
var
  Data: TIdAuthenticationChallengeData;
begin
  Data := TIdAuthenticationChallengeData.Create;
  try
    Data.Challenge         := Response;
    Data.ChallengedRequest := Action.InitialRequest;
    Data.Handle            := Self.HandleFor(Action);

    Self.NotifyEvent(CM_AUTHENTICATION_CHALLENGE, Data);
  finally
    Data.Free;
  end;
end;

procedure TIdSipStackInterface.OnAuthenticationChallenge(UserAgent: TIdSipAbstractCore;
                                                         Challenge: TIdSipResponse;
                                                         var Username: String;
                                                         var Password: String;
                                                         var TryAgain: Boolean);
begin
end;

procedure TIdSipStackInterface.OnAuthenticationChallenge(UserAgent: TIdSipAbstractCore;
                                                         ChallengedRequest: TIdSipRequest;
                                                         Challenge: TIdSipResponse);
begin
end;                                                         

procedure TIdSipStackInterface.OnDroppedUnmatchedMessage(UserAgent: TIdSipAbstractCore;
                                                         Message: TIdSipMessage;
                                                         Binding: TIdSipConnectionBindings);
var
  Data: TIdDebugDroppedMessageData;
begin
  Data := TIdDebugDroppedMessageData.Create;
  try
    Data.Binding := Binding.Copy;
    Data.Handle  := InvalidHandle;
    Data.Message := Message.Copy;

    Self.NotifyEvent(CM_DEBUG_DROPPED_MSG, Data);
  finally
    Data.Free;
  end;
end;

procedure TIdSipStackInterface.OnEndedSession(Session: TIdSipSession;
                                              ErrorCode: Cardinal;
                                              const Reason: String);
var
  Data: TIdCallEndedData;
begin
  Data := TIdCallEndedData.Create;
  try
    Data.Handle := Self.HandleFor(Session);
    Data.ErrorCode := ErrorCode;
    Data.Reason    := Reason;
    Self.NotifyEvent(CM_CALL_ENDED, Data);

    Self.RemoveAction(Data.Handle);
  finally
    Data.Free;
  end;
end;

procedure TIdSipStackInterface.OnEstablishedSession(Session: TIdSipSession;
                                                    const RemoteSessionDescription: String;
                                                    const MimeType: String);
var
  Data: TIdEstablishedSessionData;
begin
  Data := TIdEstablishedSessionData.Create;
  try
    Data.Handle                   := Self.HandleFor(Session);
    Data.LocalMimeType            := Session.LocalMimeType;
    Data.LocalSessionDescription  := Session.LocalSessionDescription;
    Data.RemoteContact            := Session.RemoteContact;
    Data.RemoteMimeType           := MimeType;
    Data.RemoteParty              := Session.RemoteParty;
    Data.RemoteSessionDescription := RemoteSessionDescription;

    Self.NotifyEvent(CM_CALL_ESTABLISHED, Data);
  finally
    Data.Free;
  end;
end;

procedure TIdSipStackInterface.OnEstablishedSubscription(Subscription: TIdSipOutboundSubscription;
                                                         Notify: TIdSipRequest);
begin
  Self.NotifySubscriptionEvent(CM_SUBSCRIPTION_ESTABLISHED,
                               Subscription,
                               Notify);
end;

procedure TIdSipStackInterface.OnException(FailedMessage: TIdSipMessage;
                                           E: Exception;
                                           const Reason: String);
var
  Data: TIdDebugTransportExceptionData;
begin
  Data := TIdDebugTransportExceptionData.Create;
  try
    Data.Handle := InvalidHandle;
    Data.Error  := E.ClassName;
    Data.Reason := E.Message;

    Self.NotifyEvent(CM_DEBUG_TRANSPORT_EXCEPTION, Data);
  finally
    Data.Free;
  end;
end;

procedure TIdSipStackInterface.OnExpiredSubscription(Subscription: TIdSipOutboundSubscription;
                                                     Notify: TIdSipRequest);
begin
  Self.NotifySubscriptionEvent(CM_SUBSCRIPTION_EXPIRED,
                               Subscription,
                               Notify);
end;

procedure TIdSipStackInterface.OnFailure(RegisterAgent: TIdSipOutboundRegistrationBase;
                                         ErrorCode: Cardinal;
                                         const Reason: String);
var
  Data: TIdFailedRegistrationData;
begin
  Data := TIdFailedRegistrationData.Create;
  try
    Data.Handle    := Self.HandleFor(RegisterAgent);
    Data.ErrorCode := ErrorCode;
    Data.Reason    := Reason;

    Self.NotifyEvent(CM_FAIL, Data);
  finally
    Data.Free;
  end;
end;

procedure TIdSipStackInterface.OnFailure(Subscription: TIdSipOutboundSubscription;
                                         Response: TIdSipResponse);
var
  Data: TIdFailedSubscriptionData;
begin
  Data := TIdFailedSubscriptionData.Create;
  try
    Data.Handle    := Self.HandleFor(Subscription);
    Data.ErrorCode := Response.StatusCode;
    Data.Reason    := Response.StatusText;
    Data.Response  := Response;

    Self.NotifyEvent(CM_FAIL, Data);
  finally
    Data.Free;
  end;
end;

procedure TIdSipStackInterface.OnInboundCall(UserAgent: TIdSipInviteModule;
                                             Session: TIdSipInboundSession);
var
  Data: TIdInboundCallData;
begin
  Session.AddSessionListener(Self);
  Self.AddAction(Session);

  Data := TIdInboundCallData.Create;
  try
    Data.Handle                   := Self.HandleFor(Session);
    Data.Invite                   := Session.InitialRequest;
    Data.RemoteContact            := Session.RemoteContact;
    Data.RemoteParty              := Session.RemoteParty;
    Data.RemoteSessionDescription := Session.RemoteSessionDescription;
    Data.RemoteMimeType           := Session.RemoteMimeType;

    Self.NotifyEvent(CM_CALL_REQUEST_NOTIFY, Data);
  finally
    Data.Free;
  end;
end;

procedure TIdSipStackInterface.OnModifySession(Session: TIdSipSession;
                                               const RemoteSessionDescription: String;
                                               const MimeType: String);
var
  Data: TIdModifySessionData;
begin
  Data := TIdModifySessionData.Create;
  try
    Data.Handle := Self.HandleFor(Session);
    Data.RemoteContact            := Session.RemoteContact;
    Data.RemoteMimeType           := MimeType;
    Data.RemoteParty              := Session.RemoteParty;
    Data.RemoteSessionDescription := RemoteSessionDescription;

    Self.NotifyEvent(CM_CALL_REMOTE_MODIFY_REQUEST, Data);
  finally
    Data.Free;
  end;
end;

procedure TIdSipStackInterface.OnModifiedSession(Session: TIdSipSession;
                                                 Answer: TIdSipResponse);
var
  Data: TIdModifiedSessionData;
begin
  Data := TIdModifiedSessionData.Create;
  try
    Data.Handle := Self.HandleFor(Session);
    Data.LocalMimeType            := Session.LocalMimeType;
    Data.LocalSessionDescription  := Session.LocalSessionDescription;
    Data.RemoteContact            := Session.RemoteContact;
    Data.RemoteMimeType           := Answer.ContentType;
    Data.RemoteParty              := Session.RemoteParty;
    Data.RemoteSessionDescription := Answer.Body;

    Self.NotifyEvent(CM_CALL_OUTBOUND_MODIFY_SUCCESS, Data);
  finally
    Data.Free;
  end;
end;

procedure TIdSipStackInterface.OnNetworkFailure(Action: TIdSipAction;
                                                ErrorCode: Cardinal;
                                                const Reason: String);
var
  Data: TIdNetworkFailureData;
begin
  Data := TIdNetworkFailureData.Create;
  try
    Data.Handle    := Self.HandleFor(Action);
    Data.ErrorCode := ErrorCode;
    Data.Reason    := Reason;
    Self.NotifyEvent(CM_NETWORK_FAILURE, Data);

    Self.RemoveAction(Data.Handle);
  finally
    Data.Free;
  end;
end;

procedure TIdSipStackInterface.OnNotify(Subscription: TIdSipOutboundSubscription;
                                        Notify: TIdSipRequest);
begin
  Self.NotifySubscriptionEvent(CM_SUBSCRIPTION_RECV_NOTIFY,
                               Subscription,
                               Notify);
end;

procedure TIdSipStackInterface.OnProgressedSession(Session: TIdSipSession;
                                                   Progress: TIdSipResponse);
var
  Data: TIdSessionProgressData;
begin
  Data := TIdSessionProgressData.Create;
  try
    Data.Banner                   := TIdUri.Decode(Progress.StatusText);
    Data.Handle                   := Self.HandleFor(Session);
    Data.LocalMimeType            := Session.LocalMimeType;
    Data.LocalSessionDescription  := Session.LocalSessionDescription;
    Data.ProgressCode             := Progress.StatusCode;
    Data.RemoteContact            := Session.RemoteContact;
    Data.RemoteMimeType           := Progress.ContentType;
    Data.RemoteParty              := Session.RemoteParty;
    Data.RemoteSessionDescription := Progress.Body;


    Self.NotifyEvent(CM_CALL_PROGRESS, Data);
  finally
    Data.Free;
  end;
end;

procedure TIdSipStackInterface.OnReceiveRequest(Request: TIdSipRequest;
                                                Receiver: TIdSipTransport;
                                                Source: TIdSipConnectionBindings);
var
  Data: TIdDebugReceiveMessageData;
begin
  Data := TIdDebugReceiveMessageData.Create;
  try
    Data.Handle := InvalidHandle;
    Data.Binding := Source.Copy;
    Data.Message := Request.Copy;

    Self.NotifyEvent(CM_DEBUG_RECV_MSG, Data);
  finally
    Data.Free;
  end;
end;

procedure TIdSipStackInterface.OnReceiveResponse(Response: TIdSipResponse;
                                                 Receiver: TIdSipTransport;
                                                 Source: TIdSipConnectionBindings);
var
  Data: TIdDebugReceiveMessageData;
begin
  Data := TIdDebugReceiveMessageData.Create;
  try
    Data.Handle := InvalidHandle;
    Data.Binding := Source.Copy;
    Data.Message := Response.Copy;

    Self.NotifyEvent(CM_DEBUG_RECV_MSG, Data);
  finally
    Data.Free;
  end;
end;

procedure TIdSipStackInterface.OnReferral(Session: TIdSipSession;
                                          Refer: TIdSipRequest;
                                          Binding: TIdSipConnectionBindings);
begin
  // We receive notifications of REFER messages sent to Session's GRUU through
  // Session. Specifically, REFERs outside of Session's dialog will end up here.
  // Since we're notified that a message has arrived, the stack doesn't know of
  // the message as a call flow (a TIdSipAction, in other words). Thus, we
  // inform the stack to keep track of the call flow around this message.
  Self.UserAgent.AddInboundAction(Refer, Binding);
end;

procedure TIdSipStackInterface.OnRejectedMessage(const Msg: String;
                                                 const Reason: String);
var
  Data: TIdDebugTransportRejectedMessageData;
begin
  Data := TIdDebugTransportRejectedMessageData.Create;
  try
    Data.Handle := InvalidHandle;
    Data.Msg    := Msg;
    Data.Reason := Reason;

    Self.NotifyEvent(CM_DEBUG_TRANSPORT_REJECTED_MSG, Data);
  finally
    Data.Free;
  end;
end;

procedure TIdSipStackInterface.OnRenewedSubscription(UserAgent: TIdSipAbstractCore;
                                                     Subscription: TIdSipOutboundSubscription);
var
  Data:   TIdResubscriptionData;
  Handle: TIdSipHandle;
begin
  Subscription.AddListener(Self);
  Handle := Self.AddAction(Subscription);

  Data := TIdResubscriptionData.Create;
  try
    Data.Handle       := Handle;
    Data.EventPackage := Subscription.EventPackage;

    Self.NotifyEvent(CM_SUBSCRIPTION_RESUBSCRIBED, Data);
  finally
    Data.Free;
  end;
end;

procedure TIdSipStackInterface.OnResponse(OptionsAgent: TIdSipOutboundOptions;
                                          Response: TIdSipResponse);
var
  Data: TIdQueryOptionsData;
begin
  Data := TIdQueryOptionsData.Create;
  try
    Data.Handle   := Self.HandleFor(OptionsAgent);
    Data.Response := Response;

    Self.NotifyEvent(CM_QUERY_OPTIONS_RESPONSE, Data);
  finally
    Data.Free;
  end;
end;

procedure TIdSipStackInterface.OnSendRequest(Request: TIdSipRequest;
                                             Sender: TIdSipTransport;
                                             Destination: TIdSipLocation);
begin
  Self.NotifyOfSentMessage(Request, Destination);
end;

procedure TIdSipStackInterface.OnSendResponse(Response: TIdSipResponse;
                                              Sender: TIdSipTransport;
                                              Destination: TIdSipLocation);
begin
  Self.NotifyOfSentMessage(Response, Destination);
end;

procedure TIdSipStackInterface.OnSubscriptionRequest(UserAgent: TIdSipAbstractCore;
                                                     Subscription: TIdSipInboundSubscription);
var
  Data: TIdSubscriptionRequestData;
begin
  Self.AddAction(Subscription);

  Data := TIdSubscriptionRequestData.Create;
  try
    Data.Handle        := Self.HandleFor(Subscription);
    Data.EventPackage  := Subscription.EventPackage;
    Data.From          := Subscription.InitialRequest.From;
    Data.ReferTo       := Subscription.InitialRequest.ReferTo;
    Data.RemoteContact := Subscription.InitialRequest.FirstContact;
    Data.Target        := Subscription.InitialRequest.RequestUri;

    Self.NotifyEvent(CM_SUBSCRIPTION_REQUEST_NOTIFY, Data);
  finally
    Data.Free;
  end;
end;

procedure TIdSipStackInterface.OnSuccess(RegisterAgent: TIdSipOutboundRegistrationBase;
                                         CurrentBindings: TIdSipContacts);
var
  Data: TIdRegistrationData;
begin
  Data := TIdRegistrationData.Create;
  try
    Data.Handle   := Self.HandleFor(RegisterAgent);
    Data.Contacts := CurrentBindings;

    Self.NotifyEvent(CM_SUCCESS, Data);
  finally
    Data.Free;
  end;
end;

procedure TIdSipStackInterface.RemoveAction(Handle: TIdSipHandle);
var
  I: Integer;
begin
  Self.ActionLock.Acquire;
  try
    I := Self.IndexOf(Handle);

    if (I <> ItemNotFoundIndex) then
      Self.Actions.Delete(I);
  finally
    Self.ActionLock.Release;
  end;
end;

procedure TIdSipStackInterface.SendAction(Action: TIdSipAction);
var
  Wait: TIdSipActionSendWait;
begin
  Wait := TIdSipActionSendWait.Create;
  Wait.ActionID := Action.ID;
  Self.UserAgent.ScheduleEvent(TriggerImmediately, Wait);
end;

procedure TIdSipStackInterface.StopListeningToAllTransports;
var
  I: Integer;
begin
  for I := 0 to Self.UserAgent.Dispatcher.TransportCount - 1 do begin
    Self.UserAgent.Dispatcher.Transports[I].RemoveTransportListener(Self);
    Self.UserAgent.Dispatcher.Transports[I].RemoveTransportSendingListener(Self);
  end;
end;

//******************************************************************************
//* TIdSipStackInterfaceRegistry                                               *
//******************************************************************************
//* TIdSipStackInterfaceRegistry Public methods ********************************

class function TIdSipStackInterfaceRegistry.RegisterStackInterface(Instance: TIdSipStackInterface): String;
begin
  repeat
    Result := GRandomNumber.NextHexString;
  until (Self.StackInterfaceRegistry.IndexOf(Result) = ItemNotFoundIndex);

  Self.StackInterfaceRegistry.AddObject(Result, Instance);
end;

class function TIdSipStackInterfaceRegistry.FindStackInterface(const StackInterfaceID: String): TIdSipStackInterface;
var
  Index: Integer;
begin
  Index := Self.StackInterfaceRegistry.IndexOf(StackInterfaceID);

  if (Index = ItemNotFoundIndex) then
    Result := nil
  else
    Result := Self.StackInterfaceAt(Index);
end;

class procedure TIdSipStackInterfaceRegistry.UnregisterStackInterface(const StackInterfaceID: String);
var
  Index: Integer;
begin
  Index := Self.StackInterfaceRegistry.IndexOf(StackInterfaceID);
  if (Index <> ItemNotFoundIndex) then
    Self.StackInterfaceRegistry.Delete(Index);
end;

//* TIdSipStackInterfaceRegistry Private methods *******************************

class function TIdSipStackInterfaceRegistry.StackInterfaceAt(Index: Integer): TIdSipStackInterface;
begin
  Result := TIdSipStackInterface(Self.StackInterfaceRegistry.Objects[Index]);
end;

class function TIdSipStackInterfaceRegistry.StackInterfaceRegistry: TStrings;
begin
  Result := GStackInterfaces;
end;

//******************************************************************************
//* TIdSipStackInterfaceExtension                                              *
//******************************************************************************
//* TIdSipStackInterfaceExtension Public methods *******************************

constructor TIdSipStackInterfaceExtension.Create(UA: TIdSipUserAgent);
begin
  inherited Create;

  Self.fUserAgent := UA;
end;

//******************************************************************************
//* TIdSipColocatedRegistrarExtension                                          *
//******************************************************************************
//* TIdSipColocatedRegistrarExtension Public methods ***************************

constructor TIdSipColocatedRegistrarExtension.Create(UA: TIdSipUserAgent);
begin
  inherited Create(UA);

  Assert(Self.UserAgent.UsesModule(TIdSipRegisterModule),
         'TIdSipColocatedRegistrarExtension needs a UA that supports receiving REGISTER methods');

  Self.RegisterModule := Self.UserAgent.ModuleFor(TIdSipRegisterModule) as TIdSipRegisterModule;
  Assert(Assigned(Self.RegisterModule.BindingDB), 'Register Module malformed: no BindingDatabase');

  Self.DB := Self.RegisterModule.BindingDB;
end;

procedure TIdSipColocatedRegistrarExtension.TargetsFor(URI: TIdSipUri; Targets: TIdSipContacts);
begin
  if not Self.DB.BindingsFor(URI, Targets, Self.DB.UseGruu) then begin
    // For now, do nothing: just return no valid targets.
    Targets.Clear;
  end;
end;

//******************************************************************************
//* TIdEventData                                                               *
//******************************************************************************
//* TIdEventData Public methods ************************************************

constructor TIdEventData.Create;
begin
  inherited Create;
end;

procedure TIdEventData.Assign(Src: TPersistent);
var
  Other: TIdEventData;
begin
  if (Src is TIdEventData) then begin
    Other := Src as TIdEventData;
    Self.Handle := Other.Handle;
  end
  else
    inherited Assign(Src);
end;

function TIdEventData.AsString: String;
begin
  Result := Self.TimestampLine
          + Self.EventName + CRLF
          + Self.Data;
end;

function TIdEventData.Copy: TIdEventData;
begin
  Result := TIdEventDataClass(Self.ClassType).Create;
  Result.Assign(Self);
end;

//* TIdEventData Protected methods *********************************************

function TIdEventData.Data: String;
begin
  Result := '';
end;

function TIdEventData.EventName: String;
begin
  Result := '';
end;

//* TIdEventData Private methods ***********************************************

function TIdEventData.TimestampLine: String;
begin
  Result := FormatDateTime('yyyy/mm/dd hh:mm:ss', Now)
          + ' Handle: ' + IntToStr(Self.Handle) + CRLF;
end;

//******************************************************************************
//* TIdInformationalData                                                       *
//******************************************************************************
//* TIdInformationalData Public methods ****************************************

constructor TIdInformationalData.Create;
begin
  inherited Create;

  Self.ErrorCode := CallEndedSuccess;
end;

procedure TIdInformationalData.Assign(Src: TPersistent);
var
  Other: TIdInformationalData;
begin
  inherited Assign(Src);

  if (Src is TIdInformationalData) then begin
    Other := Src as TIdInformationalData;

    Self.ErrorCode := Other.ErrorCode;
    Self.Reason    := Other.Reason;
  end;
end;

//* TIdInformationalData Protected methods *************************************

function TIdInformationalData.Data: String;
begin
  Result := IntToStr(Self.ErrorCode) + ' ' + Self.Reason + CRLF;
end;

//* TIdInformationalData Private methods ***************************************

procedure TIdInformationalData.SetErrorCode(Value: Cardinal);
begin
  Self.fErrorCode := Value;

  // TODO: Look up the reason string corresponding to ErrorCode here.
end;

//******************************************************************************
//* TIdAuthenticationChallengeData                                             *
//******************************************************************************
//* TIdAuthenticationChallengeData Public methods ******************************

constructor TIdAuthenticationChallengeData.Create;
begin
  inherited Create;

  Self.fChallenge         := TIdSipResponse.Create;
  Self.fChallengedRequest := TIdSipRequest.Create;
end;

destructor TIdAuthenticationChallengeData.Destroy;
begin
  Self.fChallengedRequest.Free;
  Self.fChallenge.Free;

  inherited Destroy;
end;

procedure TIdAuthenticationChallengeData.Assign(Src: TPersistent);
var
  Other: TIdAuthenticationChallengeData;
begin
  inherited Assign(Src);

  if (Src is TIdAuthenticationChallengeData) then begin
    Other := Src as TIdAuthenticationChallengeData;

    Self.Challenge         := Other.Challenge;
    Self.ChallengedRequest := Other.ChallengedRequest;
  end;
end;

//* TIdAuthenticationChallengeData Protected methods ***************************

function TIdAuthenticationChallengeData.Data: String;
begin
  Result := 'CHALLENGED REQUEST' + CRLF
          + Self.ChallengedRequest.AsString
          + CRLF
          + 'CHALLENGE' + CRLF
          + Self.Challenge.AsString;
end;

function TIdAuthenticationChallengeData.EventName: String;
begin
  Result := EventNames(CM_AUTHENTICATION_CHALLENGE);
end;

//* TIdAuthenticationChallengeData Private methods *****************************

procedure TIdAuthenticationChallengeData.SetChallenge(Response: TIdSipResponse);
begin
  Self.fChallenge.Assign(Response);
end;

procedure TIdAuthenticationChallengeData.SetChallengedRequest(Request: TIdSipRequest);
begin
  Self.fChallengedRequest.Assign(Request);
end;

//******************************************************************************
//* TIdNetworkFailureData                                                      *
//******************************************************************************
//* TIdNetworkFailureData Protected methods ************************************

function TIdNetworkFailureData.EventName: String;
begin
  Result := EventNames(CM_NETWORK_FAILURE);
end;

//******************************************************************************
//* TIdCallEndedData                                                           *
//******************************************************************************
//* TIdCallEndedData Protected methods *****************************************

function TIdCallEndedData.EventName: String;
begin
  Result := EventNames(CM_CALL_ENDED);
end;

//******************************************************************************
//* TIdDebugData                                                               *
//******************************************************************************
//* TIdDebugData Public methods ************************************************

procedure TIdDebugData.Assign(Src: TPersistent);
var
  Other: TIdDebugData;
begin
  inherited Assign(Src);

  if (Src is TIdDebugData) then begin
    Other := Src as TIdDebugData;

    Self.Event := Other.Event;
  end;
end;

//* TIdDebugData Protected methods *********************************************

function TIdDebugData.EventName: String;
begin
  Result := EventNames(Self.Event);
end;

//******************************************************************************
//* TIdDebugMessageData                                                        *
//******************************************************************************
//* TIdDebugMessageData Public methods *****************************************

destructor TIdDebugMessageData.Destroy;
begin
  Self.fMessage.Free;

  inherited Destroy;
end;

procedure TIdDebugMessageData.Assign(Src: TPersistent);
var
  Other: TIdDebugMessageData;
begin
  inherited Assign(Src);

  if (Src is TIdDebugMessageData) then begin
    Other := Src as TIdDebugMessageData;
    
    Self.Message := Other.Message.Copy;
  end;
end;

//* TIdDebugMessageData Protected methods **************************************

function TIdDebugMessageData.Data: String;
begin
  Result := Self.Message.AsString;
end;

//******************************************************************************
//* TIdDebugDroppedMessageData                                                 *
//******************************************************************************
//* TIdDebugDroppedMessageData Public methods **********************************

destructor TIdDebugDroppedMessageData.Destroy;
begin
  Self.Binding.Free;

  inherited Destroy;
end;

procedure TIdDebugDroppedMessageData.Assign(Src: TPersistent);
var
  Other: TIdDebugDroppedMessageData;
begin
  inherited Assign(Src);

  if (Src is TIdDebugDroppedMessageData) then begin
    Other := Src as TIdDebugDroppedMessageData;

    Self.Binding := Other.Binding.Copy;
  end;
end;

//* TIdDebugDroppedMessageData Protected methods *******************************

function TIdDebugDroppedMessageData.Data: String;
begin
  Result := Self.Binding.AsString + CRLF
          + inherited Data;
end;

function TIdDebugDroppedMessageData.EventName;
begin
  Result := EventNames(CM_DEBUG_DROPPED_MSG);
end;

//******************************************************************************
//* TIdDebugReceiveMessageData                                                 *
//******************************************************************************
//* TIdDebugReceiveMessageData Public methods **********************************

destructor TIdDebugReceiveMessageData.Destroy;
begin
  Self.Binding.Free;

  inherited Destroy;
end;

procedure TIdDebugReceiveMessageData.Assign(Src: TPersistent);
var
  Other: TIdDebugReceiveMessageData;
begin
  inherited Assign(Src);

  if (Src is TIdDebugReceiveMessageData) then begin
    Other := Src as TIdDebugReceiveMessageData;

    Self.Binding := Other.Binding.Copy;
  end;
end;

//* TIdDebugReceiveMessageData Protected methods *******************************

function TIdDebugReceiveMessageData.Data: String;
begin
  Result := Self.Binding.AsString + CRLF
          + inherited Data;
end;

function TIdDebugReceiveMessageData.EventName: String;
begin
  Result := EventNames(CM_DEBUG_RECV_MSG);
end;

//******************************************************************************
//* TIdDebugSendMessageData                                                    *
//******************************************************************************
//* TIdDebugSendMessageData Public methods *************************************

destructor TIdDebugSendMessageData.Destroy;
begin
  Self.Destination.Free;

  inherited Destroy;
end;

procedure TIdDebugSendMessageData.Assign(Src: TPersistent);
var
  Other: TIdDebugSendMessageData;
begin
  inherited Assign(Src);

  if (Src is TIdDebugSendMessageData) then begin
    Other := Src as TIdDebugSendMessageData;

    Self.Destination := Other.Destination.Copy;
  end;
end;

//* TIdDebugSendMessageData Protected methods **********************************

function TIdDebugSendMessageData.Data: String;
begin
  Result := Self.Destination.AsString + CRLF
          + inherited Data;
end;

function TIdDebugSendMessageData.EventName: String;
begin
  Result := EventNames(CM_DEBUG_SEND_MSG);
end;

//******************************************************************************
//* TIdDebugTransportExceptionData                                             *
//******************************************************************************
//* TIdDebugTransportExceptionData Public methods ******************************

procedure TIdDebugTransportExceptionData.Assign(Src: TPersistent);
var
  Other: TIdDebugTransportExceptionData;
begin
  inherited Assign(Src);

  if (Src is TIdDebugTransportExceptionData) then begin
    Other := Src as TIdDebugTransportExceptionData;

    Self.Error  := Other.Error;
    Self.Reason := Other.Reason;
  end;
end;

//******************************************************************************
//* TIdDebugTransportRejectedMessageData                                       *
//******************************************************************************
//* TIdDebugTransportRejectedMessageData Public methods ************************

procedure TIdDebugTransportRejectedMessageData.Assign(Src: TPersistent);
var
  Other: TIdDebugTransportRejectedMessageData;
begin
  inherited Assign(Src);

  if (Src is TIdDebugTransportRejectedMessageData) then begin
    Other := Src as TIdDebugTransportRejectedMessageData;

    Self.Msg    := Other.Msg;
    Self.Reason := Other.Reason;
  end;
end;

//* TIdDebugTransportRejectedMessageData Protected methods *********************

function TIdDebugTransportRejectedMessageData.Data: String;
begin
  Result := Self.Reason + CRLF
          + Self.Msg;
end;

function TIdDebugTransportRejectedMessageData.EventName: String;
begin
  Result := EventNames(CM_DEBUG_TRANSPORT_REJECTED_MSG);
end;

//******************************************************************************
//* TIdQueryOptionsData                                                        *
//******************************************************************************
//* TIdQueryOptionsData Public methods *****************************************

constructor TIdQueryOptionsData.Create;
begin
  inherited Create;

  Self.fResponse := TIdSipResponse.Create;
end;

destructor TIdQueryOptionsData.Destroy;
begin
  Self.Response.Free;

  inherited Destroy;
end;

procedure TIdQueryOptionsData.Assign(Src: TPersistent);
var
  Other: TIdQueryOptionsData;
begin
  inherited Assign(Src);

  if (Src is TIdQueryOptionsData) then begin
    Other := Src as TIdQueryOptionsData;

    Self.Response := Other.Response;
  end;
end;

//* TIdQueryOptionsData Protected methods **************************************

function TIdQueryOptionsData.Data: String;
begin
  Result := 'Response:' + CRLF
          + Self.Response.AsString;
end;

function TIdQueryOptionsData.EventName: String;
begin
  Result := EventNames(CM_QUERY_OPTIONS_RESPONSE);
end;

//* TIdQueryOptionsData Private methods ****************************************

procedure TIdQueryOptionsData.SetResponse(Value: TIdSipResponse);
begin
  Self.fResponse.Assign(Value);
end;

//******************************************************************************
//* TIdDebugTransportExceptionData                                             *
//******************************************************************************
//* TIdDebugTransportExceptionData Protected methods ***************************

function TIdDebugTransportExceptionData.Data: String;
begin
  Result := Self.Error + ': ' + Self.Reason;
end;

function TIdDebugTransportExceptionData.EventName: String;
begin
  Result := EventNames(CM_DEBUG_TRANSPORT_EXCEPTION);
end;

//******************************************************************************
//* TIdRegistrationData                                                        *
//******************************************************************************
//* TIdRegistrationData Public methods *****************************************

constructor TIdRegistrationData.Create;
begin
  inherited Create;

  Self.fContacts := TIdSipContacts.Create;
end;

destructor TIdRegistrationData.Destroy;
begin
  Self.fContacts.Free;

  inherited Destroy;
end;

procedure TIdRegistrationData.Assign(Src: TPersistent);
var
  Other: TIdRegistrationData;
begin
  inherited Assign(Src);

  if (Src is TIdRegistrationData) then begin
    Other := Src as TIdRegistrationData;

    Self.Contacts := Other.Contacts;
  end;
end;

//* TIdRegistrationData Protected methods **************************************

function TIdRegistrationData.Data: String;
begin
  Result := Self.Contacts.AsString;
end;

function TIdRegistrationData.EventName: String;
begin
  Result := EventNames(CM_SUCCESS) + ' Registration';
end;

//* TIdRegistrationData Private methods ****************************************

procedure TIdRegistrationData.SetContacts(Value: TIdSipContacts);
begin
  Self.Contacts.Clear;
  Self.Contacts.Add(Value);
end;

//******************************************************************************
//* TIdFailedRegistrationData                                                  *
//******************************************************************************
//* TIdFailedRegistrationData Public methods ***********************************

constructor TIdFailedRegistrationData.Create;
begin
  inherited Create;

  Self.RegistrationData := TIdRegistrationData.Create;
end;

destructor TIdFailedRegistrationData.Destroy;
begin
  Self.RegistrationData.Free;

  inherited Destroy;
end;

procedure TIdFailedRegistrationData.Assign(Src: TPersistent);
var
  Other: TIdFailedRegistrationData;
begin
  inherited Assign(Src);

  if (Src is TIdFailedRegistrationData) then begin
    Other := Src as TIdFailedRegistrationData;

    Self.ErrorCode := Other.ErrorCode;
    Self.Reason    := Other.Reason;
  end;
end;

//* TIdFailedRegistrationData Protected methods ********************************

function TIdFailedRegistrationData.EventName: String;
begin
  Result := EventNames(CM_FAIL) + ' Registration';
end;

//******************************************************************************
//* TIdSessionData                                                             *
//******************************************************************************
//* TIdSessionData Public methods **********************************************

constructor TIdSessionData.Create;
begin
  inherited Create;

  Self.fRemoteContact := TIdSipContactHeader.Create;
  Self.fRemoteParty   := TIdSipAddressHeader.Create;
end;

destructor TIdSessionData.Destroy;
begin
  Self.fRemoteParty.Free;
  Self.fRemoteContact.Free;

 inherited Destroy;
end;

procedure TIdSessionData.Assign(Src: TPersistent);
var
  Other: TIdSessionData;
begin
  inherited Assign(Src);

  if (Src is TIdSessionData) then begin
    Other := Src as TIdSessionData;

    Self.LocalMimeType            := Other.LocalMimeType;
    Self.LocalSessionDescription  := Other.LocalSessionDescription;
    Self.RemoteContact            := Other.RemoteContact;
    Self.RemoteMimeType           := Other.RemoteMimeType;
    Self.RemoteParty              := Other.RemoteParty;
    Self.RemoteSessionDescription := Other.RemoteSessionDescription;
  end;
end;

//* TIdSessionData Protected methods *******************************************

function TIdSessionData.Data: String;
begin
  Result := 'Remote party: ' + Self.RemoteParty.FullValue + CRLF
          + 'Remote contact: ' + Self.RemoteContact.FullValue + CRLF
          + 'Local session description (' + Self.LocalMimeType + '):' + CRLF
          + Self.LocalSessionDescription + CRLF
          + 'Remote session description (' + Self.RemoteMimeType + '):' + CRLF
          + Self.RemoteSessionDescription + CRLF
end;

//* TIdSessionData Private methods *********************************************

procedure TIdSessionData.SetRemoteContact(Value: TIdSipContactHeader);
begin
  Self.RemoteContact.Assign(Value);
end;

procedure TIdSessionData.SetRemoteParty(Value: TIdSipAddressHeader);
begin
  Self.RemoteParty.Assign(Value);

  if Self.RemoteParty.HasParameter(TagParam) then
    Self.RemoteParty.RemoveParameter(TagParam);
end;

//******************************************************************************
//* TIdEstablishedSessionData                                                  *
//******************************************************************************
//* TIdEstablishedSessionData Protected methods ********************************

function TIdEstablishedSessionData.EventName: String;
begin
  Result := EventNames(CM_CALL_ESTABLISHED);
end;

//******************************************************************************
//* TIdInboundCallData                                                         *
//******************************************************************************

constructor TIdInboundCallData.Create;
begin
  inherited Create;

  Self.fInvite := TIdSipRequest.Create; 
end;

destructor TIdInboundCallData.Destroy;
begin
  Self.Invite.Free;

  inherited Destroy;
end;

procedure TIdInboundCallData.Assign(Src: TPersistent);
var
  Other: TIdInboundCallData;
begin
  inherited Assign(Src);

  if (Src is TIdInboundCallData) then begin
    Other := Src as TIdInboundCallData;

    Self.Invite := Other.Invite;
  end;
end;

//* TIdInboundCallData Protected methods ***************************************

function TIdInboundCallData.EventName: String;
begin
  Result := EventNames(CM_CALL_REQUEST_NOTIFY);
end;

//* TIdInboundCallData Private methods *****************************************

procedure TIdInboundCallData.SetInvite(Value: TIdSipRequest);
begin
  Self.fInvite.Assign(Value);
end;

//******************************************************************************
//* TIdModifiedSessionData                                                     *
//******************************************************************************
//* TIdModifiedSessionData Protected methods ***********************************

function TIdModifiedSessionData.EventName: String;
begin
  Result := EventNames(CM_CALL_OUTBOUND_MODIFY_SUCCESS);
end;

//******************************************************************************
//* TIdModifySessionData                                                       *
//******************************************************************************
//* TIdModifySessionData Protected methods *************************************

function TIdModifySessionData.EventName: String;
begin
  Result := EventNames(CM_CALL_REMOTE_MODIFY_REQUEST);
end;

//******************************************************************************
//* TIdSessionProgressData                                                     *
//******************************************************************************
//* TIdSessionProgressData Public methods **************************************

procedure TIdSessionProgressData.Assign(Src: TPersistent);
var
  Other: TIdSessionProgressData;
begin
  inherited Assign(Src);

  if (Src is TIdSessionProgressData) then begin
    Other := Src as TIdSessionProgressData;

    Self.Banner       := Other.Banner;
    Self.ProgressCode := Other.ProgressCode;
  end;
end;

//* TIdSessionProgressData Protected methods ***********************************

function TIdSessionProgressData.Data: String;
begin
  Result := IntToStr(Self.ProgressCode) + ' ' + Self.Banner + CRLF
          + inherited Data;
end;

function TIdSessionProgressData.EventName: String;
begin
  Result := EventNames(CM_CALL_PROGRESS);
end;

//******************************************************************************
//* TIdSubscriptionData                                                        *
//******************************************************************************
//* TIdSubscriptionData Public methods *****************************************

procedure TIdSubscriptionData.Assign(Src: TPersistent);
var
  Other: TIdSubscriptionData;
begin
  inherited Assign(Src);

  if (Src is TIdSubscriptionData) then begin
    Other := Src as TIdSubscriptionData;

    Self.EventPackage  := Other.EventPackage;
  end;
end;

//* TIdSubscriptionData Protected methods **************************************

function TIdSubscriptionData.Data: String;
begin
  Result := 'Event: ' + Self.EventPackage + CRLF;
end;

//******************************************************************************
//* TIdSubscriptionRequestData                                                 *
//******************************************************************************
//* TIdSubscriptionRequestData Public methods **********************************

constructor TIdSubscriptionRequestData.Create;
begin
  inherited Create;

  Self.fFrom          := TIdSipFromHeader.Create;
  Self.fReferTo       := TIdSipReferToHeader.Create;
  Self.fRemoteContact := TIdSipContactHeader.Create;
  Self.fTarget        := TIdSipUri.Create;
end;

destructor TIdSubscriptionRequestData.Destroy;
begin
  Self.fTarget.Free;
  Self.fRemoteContact.Free;
  Self.fReferTo.Free;
  Self.fFrom.Free;

  inherited Destroy;
end;

procedure TIdSubscriptionRequestData.Assign(Src: TPersistent);
var
  Other: TIdSubscriptionRequestData;
begin
  inherited Assign(Src);

  if (Src is TIdSubscriptionRequestData) then begin
    Other := Src as TIdSubscriptionRequestData;

    Self.From          := Other.From;
    Self.ReferTo       := Other.ReferTo;
    Self.RemoteContact := Other.RemoteContact;
    Self.Target        := Other.Target;
  end;
end;

//* TIdSubscriptionRequestData Protected methods *******************************

function TIdSubscriptionRequestData.Data: String;
begin
  Result := inherited Data
          + Self.ReferTo.AsString + CRLF
          + Self.From.AsString + CRLF
          + Self.RemoteContact.AsString + CRLF;
end;

function TIdSubscriptionRequestData.EventName: String;
begin
  Result := EventNames(CM_SUBSCRIPTION_REQUEST_NOTIFY);
end;

//* TIdSubscriptionRequestData Private methods *********************************

procedure TIdSubscriptionRequestData.SetFrom(Value: TIdSipFromHeader);
begin
  Self.fFrom.Assign(Value);
end;

procedure TIdSubscriptionRequestData.SetReferTo(Value: TIdSipReferToHeader);
begin
  Self.fReferTo.Assign(Value);
end;

procedure TIdSubscriptionRequestData.SetRemoteContact(Value: TIdSipContactHeader);
begin
  Self.fRemoteContact.Assign(Value);
end;

procedure TIdSubscriptionRequestData.SetTarget(Value: TIdSipUri);
begin
  Self.fTarget.Uri := Value.Uri;
end;

//******************************************************************************
//* TIdSessionReferralData                                                     *
//******************************************************************************
//* TIdSessionReferralData Public methods **************************************

procedure TIdSessionReferralData.Assign(Src: TPersistent);
var
  Other: TIdSessionReferralData;
begin
  inherited Assign(Src);

  if (Src is TIdSessionReferralData) then begin
    Other := Src as TIdSessionReferralData;
    Self.ReferAction := Other.ReferAction;
  end;
end;

//******************************************************************************
//* TIdSessionReferralData
//******************************************************************************
//* TIdSessionReferralData Protected methods ***********************************

function TIdSessionReferralData.Data: String;
begin
  Result := 'Refer action: ' + IntToStr(Self.ReferAction) + CRLF
          + inherited Data;
end;

function TIdSessionReferralData.EventName: String;
begin
  Result := EventNames(CM_CALL_REFERRAL);
end;

//******************************************************************************
//* TIdSubscriptionNotifyData                                                  *
//******************************************************************************
//* TIdSubscriptionNotifyData Public methods ***********************************

constructor TIdSubscriptionNotifyData.Create;
begin
  inherited Create;

  Self.fNotify := TIdSipRequest.Create;
end;

destructor TIdSubscriptionNotifyData.Destroy;
begin
  Self.fNotify.Free;

  inherited Destroy;
end;

procedure TIdSubscriptionNotifyData.Assign(Src: TPersistent);
var
  Other: TIdSubscriptionNotifyData;
begin
  inherited Assign(Src);

  if (Src is TIdSubscriptionNotifyData) then begin
    Other := Src as TIdSubscriptionNotifyData;

    Self.Notify := Other.Notify;
  end;
end;

//* TIdSubscriptionNotifyData Protected methods ********************************

function TIdSubscriptionNotifyData.Data: String;
begin
  Result := Self.Notify.AsString;
end;

function TIdSubscriptionNotifyData.EventName: String;
begin
  Result := EventNames(Self.Event);
end;

//* TIdSubscriptionNotifyData Private methods **********************************

procedure TIdSubscriptionNotifyData.SetNotify(Value: TIdSipRequest);
begin
  Self.fNotify.Assign(Value);
end;

//******************************************************************************
//* TIdFailedSubscriptionData                                                  *
//******************************************************************************
//* TIdFailedSubscriptionData Public methods ***********************************

constructor TIdFailedSubscriptionData.Create;
begin
  inherited Create;

  Self.fResponse := TIdSipResponse.Create;
end;

destructor TIdFailedSubscriptionData.Destroy;
begin
  inherited Destroy;
end;

procedure TIdFailedSubscriptionData.Assign(Src: TPersistent);
var
  Other: TIdFailedSubscriptionData;
begin
  inherited Assign(Src);

  if (Src is TIdFailedSubscriptionData) then begin
    Other := Src as TIdFailedSubscriptionData;

    Self.ErrorCode := Other.ErrorCode;
    Self.Reason    := Other.Reason;
    Self.Response  := Other.Response;
  end;
end;

//* TIdFailedSubscriptionData Protected methods ********************************

function TIdFailedSubscriptionData.Data: String;
begin
  Result := Self.Response.AsString;
end;

function TIdFailedSubscriptionData.EventName: String;
begin
  Result := EventNames(CM_FAIL) + ' Subscription';
end;

//* TIdFailedSubscriptionData Private methods **********************************

procedure TIdFailedSubscriptionData.SetResponse(Value: TIdSipResponse);
begin
  Self.Response.Assign(Value);
end;

//******************************************************************************
//* TIdStackReconfiguredData                                                   *
//******************************************************************************
//* TIdStackReconfiguredData Public methods ************************************

procedure TIdStackReconfiguredData.Assign(Src: TPersistent);
var
  Other: TIdStackReconfiguredData;
begin
  inherited Assign(Src);

  if (Src is TIdStackReconfiguredData) then begin
    Other := Src as TIdStackReconfiguredData;

    Self.ActsAsRegistrar := Other.ActsAsRegistrar;
  end;
end;

//* TIdStackReconfiguredData Protected methods *********************************

function TIdStackReconfiguredData.Data: String;
begin
  Result := 'ActsAsRegistrar: ' + BoolToStr(Self.ActsAsRegistrar, true) + CRLF;
end;

function TIdStackReconfiguredData.EventName: String;
begin
  Result := EventNames(CM_STACK_RECONFIGURED);
end;

//******************************************************************************
//* TIdSipStackInterfaceEventMethod                                            *
//******************************************************************************
//* TIdSipStackInterfaceEventMethod Public methods *****************************

procedure TIdSipStackInterfaceEventMethod.Run(const Subject: IInterface);
begin
  (Subject as IIdSipStackListener).OnEvent(Self.Stack,
                                           Self.Event,
                                           Self.Data);
end;

//******************************************************************************
//* TIdSipStackReconfigureStackInterfaceWait                                   *
//******************************************************************************
//* TIdSipStackReconfigureStackInterfaceWait Public methods ********************

constructor TIdSipStackReconfigureStackInterfaceWait.Create;
begin
  inherited Create;

  Self.fConfiguration := TStringList.Create;
end;

destructor TIdSipStackReconfigureStackInterfaceWait.Destroy;
begin
  Self.Configuration.Free;

  inherited Destroy;
end;

procedure TIdSipStackReconfigureStackInterfaceWait.Trigger;
var
  Stack:        TIdSipStackInterface;
  SubMod:       TIdSipSubscribeModule;
  Configurator: TIdSipStackConfigurator;
begin
  // The configuration file can contain both configuration details defined by
  // TIdSipStackInterface and TIdSipUserAgent.

  Stack := TIdSipStackInterfaceRegistry.FindStackInterface(Self.StackID);

  if Assigned(Stack) then begin
    Configurator := TIdSipStackConfigurator.Create;
    try
      Configurator.UpdateConfiguration(Stack.UserAgent, Self.Configuration);

      if Stack.UserAgent.UsesModule(TIdSipSubscribeModule) then begin
        SubMod := Stack.UserAgent.ModuleFor(TIdSipSubscribeModule) as TIdSipSubscribeModule;

        // "RemoveListener" first because SubMod may have existed before this
        // update. If it did, then Stack is already a Listener, and we wouldn't
        // want to re-add it. However, we've no way of knowing if Stack is
        // already a Listener.
        SubMod.RemoveListener(Stack);
        SubMod.AddListener(Stack);
      end;

      Stack.UserAgent.Dispatcher.StartAllTransports;
    finally
      Configurator.Free;
    end;

    Stack.Configure(Self.Configuration);    

    Stack.NotifyOfReconfiguration;
  end;
end;

//* TIdSipStackReconfigureStackInterfaceWait Private methods *******************

procedure TIdSipStackReconfigureStackInterfaceWait.SetConfiguration(Value: TStrings);
begin
  Self.Configuration.Assign(Value);
end;

initialization
  GStackInterfaces := TStringList.Create;
finalization
// These objects are purely memory-based, so it's safe not to free them here.
// Still, perhaps we need to review this methodology. How else do we get
// something like class variables?
//  GStackInterfaces.Free;
end.
