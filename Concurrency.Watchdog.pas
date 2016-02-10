unit Concurrency.Watchdog;

interface

uses
  Concurrency,
  Spring,
  OtlSync,
  OtlTask;

type
  TWatchdog<T: IInterface> = class(TInterfacedObject, IWatchdog<T>, IAsyncAction)
  protected
    fTask: ITask;
    fWatched: T;
    fWatchedWaitable: IWaitable;

    fWatchedTimeout: Integer;
    fOnTimeoutExceeded: Event<TOnTimeoutExceeded>;
    fOnTimeoutKept: Event<TOnTimeoutKept>;

    procedure SuppressAllExceptions;
  public
    constructor Create(const AWatched: T; const ATimeoutInMilliseconds: integer; const ATaskBuilder: ITaskBuilder);

    procedure RunAsync(const ATask: IOmniTask; const ACancellationToken: IOmniCancellationToken);
    function OnTimeoutExceeded: IEvent<TOnTimeoutExceeded>;
    function OnTimeoutKept: IEvent<TOnTimeoutKept>;

    procedure Run;
    function Watched: T;
  end;

implementation

uses
  System.SysUtils;

{ TWatchdog<T> }

constructor TWatchdog<T>.Create(const AWatched: T; const ATimeoutInMilliseconds: integer; const ATaskBuilder: ITaskBuilder);
begin
  Guard.CheckNotNull(AWatched, 'missing watched instance');
  Guard.CheckNotNull(ATaskBuilder, 'missing taskbuilder');
  if not Supports(AWatched, IWaitable, fWatchedWaitable) then
    Guard.RaiseArgumentFormatException('watched instance must implement IWaitable');

  fWatched := AWatched;
  fWatchedTimeout := ATimeoutInMilliseconds;
  fTask := ATaskBuilder.WithMaxThreads(1).BuildTask(Self);
end;

function TWatchdog<T>.OnTimeoutExceeded: IEvent<TOnTimeoutExceeded>;
begin
  Result := fOnTimeoutExceeded;
end;

function TWatchdog<T>.OnTimeoutKept: IEvent<TOnTimeoutKept>;
begin
  Result := fOnTimeoutKept;
end;

procedure TWatchdog<T>.Run;
begin
  if fTask.IsRunning then
    Exit;

  fTask.Run;
end;

procedure TWatchdog<T>.RunAsync(const ATask: IOmniTask; const ACancellationToken: IOmniCancellationToken);
begin
  try
    if fWatchedWaitable.Wait(fWatchedTimeout) then
      fOnTimeoutKept.Invoke(fWatchedTimeout)
    else
      fOnTimeoutExceeded.Invoke(fWatchedTimeout);
  except
    SuppressAllExceptions;
  end;
end;

procedure TWatchdog<T>.SuppressAllExceptions;
begin
  //NOOP
end;

function TWatchdog<T>.Watched: T;
begin
  Result := fWatched;
end;

end.
