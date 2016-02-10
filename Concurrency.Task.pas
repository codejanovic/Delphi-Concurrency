unit Concurrency.Task;

interface

uses
  Concurrency,
  OtlParallel,
  OtlSync,
  Spring,
  OtlTaskControl,
  System.SysUtils,
  OtlTask,
  Spring.Collections;

type

  TTask = class(TInterfacedObject, ITask, IRunnable, ICancelable, IMonitorable, IWaitable, IErrorable)
  protected
    fParallelTask: IOmniParallelTask;
    fCancellationToken: IOmniCancellationToken;
    fAsyncAction: IAsyncAction;
    fError: EUnhandledErrors;

    fTaskState: TMonitorState;
    fOnThreadTerminatedWithTaskControl: Event<TOnTaskThreadTerminated>;
    fOnThreadTerminated: Event<TSimpleProcedure>;
    fOnTaskStopped: Event<TOnTaskStopped>;

    procedure ExecuteTask(const task: IOmniTask);
    procedure HandleOnParallelTaskStop;
    procedure HandleOnParallelTaskTerminated(const task: IOmniTaskControl);
    procedure FireOnTaskStopped;
    procedure FireOnThreadTerminated(const task: IOmniTaskControl);
    procedure TaskFaulted;
    procedure TaskCompleted;
    procedure TaskCancelled;
    procedure TaskUndefined;
    procedure TaskRunning;
    function IsUndefined: boolean;
  public
    constructor Create(const AAsyncAction: IAsyncAction; const AParallelTask: IOmniParallelTask; const ACancellationToken: IOmniCancellationToken);
    destructor Destroy; override;

    function OnThreadTerminatedWithTaskControl: IEvent<TOnTaskThreadTerminated>;
    function OnThreadTerminated: IEvent<TSimpleProcedure>;
    function OnTaskStopped: IEvent<TOnTaskStopped>;

    procedure IRunnable.Run = Run;
    procedure ICancelable.Cancel = Cancel;
    function IWaitable.Wait = Wait;
    function IMonitorable.IsRunning = IsRunning;
    function IMonitorable.IsCancelled = IsCancelled;
    function IMonitorable.IsCompleted = IsCompleted;
    function IMonitorable.IsFaulted = IsFaulted;
    function IErrorable.Error = Error;
    function IErrorable.DetachError = DetachError;

    procedure Run;
    procedure Cancel;
    function Wait(const ATimeInMilliseconds: Integer): boolean;

    function IsRunning: boolean;
    function IsCancelled: Boolean;
    function IsCompleted: boolean;
    function IsFaulted: boolean;

    function Error: EUnhandledErrors;
    function DetachError: EUnhandledErrors;
  end;

implementation

uses
  System.Classes;

procedure TTask.Cancel;
begin
  TaskCancelled;
  fCancellationToken.Signal;
end;

constructor TTask.Create(
  const AAsyncAction: IAsyncAction;
  const AParallelTask: IOmniParallelTask;
  const ACancellationToken: IOmniCancellationToken);
begin
  Guard.CheckNotNull(AAsyncAction, 'missing AsyncAction');
  Guard.CheckNotNull(AParallelTask, 'missing ParallelTask');
  Guard.CheckNotNull(ACancellationToken, 'missing CancellationToken');

  fAsyncAction := AAsyncAction;
  fParallelTask := AParallelTask;
  fCancellationToken := ACancellationToken;

  fParallelTask.OnStop(HandleOnParallelTaskStop);
  fParallelTask.TaskConfig(Parallel.TaskConfig.CancelWith(fCancellationToken).OnTerminated(HandleOnParallelTaskTerminated));
end;

destructor TTask.Destroy;
begin
  if Assigned(fError) then
    fError.Free;

  inherited;
end;

function TTask.DetachError: EUnhandledErrors;
begin
  Result := fError;
  fError := NIL;
end;

function TTask.Error: EUnhandledErrors;
begin
  Result := fError;
end;

procedure TTask.ExecuteTask(const task: IOmniTask);
begin
  TaskRunning;
  fAsyncAction.RunAsync(task, fCancellationToken);
end;

procedure TTask.FireOnTaskStopped;
begin
  TaskCompleted;
  fOnTaskStopped.Invoke(fTaskState);
end;

procedure TTask.FireOnThreadTerminated(const task: IOmniTaskControl);
begin
  fOnThreadTerminatedWithTaskControl.Invoke(task);
  fOnThreadTerminated.Invoke();
end;

procedure TTask.HandleOnParallelTaskStop;
var
  LError: Exception;
begin
  if fParallelTask.IsExceptional then
  begin
    TaskFaulted;
    fError := EUnhandledErrors(fParallelTask.DetachException);
  end;
  TThread.Queue(nil, FireOnTaskStopped);
end;

procedure TTask.HandleOnParallelTaskTerminated(const task: IOmniTaskControl);
begin
  FireOnThreadTerminated(task);
end;

function TTask.IsCancelled: Boolean;
begin
  Result := fTaskState in [TMonitorState.Cancelled];
end;

function TTask.IsCompleted: boolean;
begin
  Result := fTaskState in [TMonitorState.Completed];
end;

function TTask.IsFaulted: boolean;
begin
  Result := fTaskState in [TMonitorState.Faulted];
end;

function TTask.IsRunning: boolean;
begin
  Result := fTaskState in [TMonitorState.Running];
end;

function TTask.IsUndefined: boolean;
begin
  Result := fTaskState in [TMonitorState.Undefined];
end;

function TTask.OnTaskStopped: IEvent<TOnTaskStopped>;
begin
  Result := fOnTaskStopped;
end;

function TTask.OnThreadTerminated: IEvent<TSimpleProcedure>;
begin
  Result := fOnThreadTerminated;
end;

function TTask.OnThreadTerminatedWithTaskControl: IEvent<TOnTaskThreadTerminated>;
begin
  Result := fOnThreadTerminatedWithTaskControl;
end;

procedure TTask.Run;
begin
  if not IsUndefined then
    Exit;

  fCancellationToken.Clear;
  TaskRunning;

  fParallelTask.Execute(ExecuteTask);
end;

procedure TTask.TaskCancelled;
begin
  if not IsRunning then
    Exit;

  fTaskState := TMonitorState.Cancelled;
end;

procedure TTask.TaskCompleted;
begin
  if not (fTaskState in [TMonitorState.Running]) then
    Exit;

  fTaskState := TMonitorState.Completed;
end;

procedure TTask.TaskFaulted;
begin
  if not (fTaskState in [TMonitorState.Running]) then
    Exit;

  fTaskState := TMonitorState.Faulted;
end;

procedure TTask.TaskRunning;
begin
  fTaskState := TMonitorState.Running;
end;

procedure TTask.TaskUndefined;
begin
  fTaskState := TMonitorState.Undefined;
end;

function TTask.Wait(const ATimeInMilliseconds: Integer): boolean;
begin
  Result := fParallelTask.WaitFor(ATimeInMilliseconds);
end;

end.
