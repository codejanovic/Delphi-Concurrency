unit Concurrency;

interface

uses
  Spring,
  OtlTaskControl,
  System.SysUtils,
  OtlSync,
  OtlParallel,
  OtlTask, 
  Spring.Collections;

type
  TMonitorState = (Undefined, Running, Completed, Cancelled, Faulted);

  {$M+}
  TOnTaskThreadTerminated = reference to procedure(const task: IOmniTaskControl);
  TOnTaskStopped = reference to procedure(const AState: TMonitorState);
  TOnTimeoutExceeded = reference to procedure(const ATimeoutInMS: Integer);
  TOnTimeoutKept = reference to procedure(const ATimeoutInMS: Integer);
  TSimpleProcedure = reference to procedure;

  TAsyncAction = reference to procedure(const ATask: IOmniTask; const ACancellationToken: IOmniCancellationToken);
  {$M-}

  EUnhandledErrors = EJoinException;

  IAsyncAction = interface(IInvokable)
  ['{4AE26461-FDED-4DDC-AA02-49188A1DF682}']
    procedure RunAsync(const ATask: IOmniTask; const ACancellationToken: IOmniCancellationToken);
  end;

  ICancelable = interface(IInvokable)
    ['{914A3E25-9E04-4327-B00C-BE1FFDFF05D4}']
    {$REGION 'Documentation'}
    /// <summary>
    ///   Cancels a running task. (TTaskStatus.Cancelled)
    /// </summary>
    {$ENDREGION}
    procedure Cancel;
  end;

  IWaitable = interface(IInvokable)
    ['{4636A535-2D9B-4035-B845-AD1DBE9BA10C}']
    function Wait(const ATimeInMilliseconds: Integer): boolean;
  end;

  IRunnable = interface(IInvokable)
    ['{3638813F-7397-46BF-8B22-02F14CB22585}']
    {$REGION 'Documentation'}
    /// <summary>
    ///   Runs the task. (TTaskStatus.Running)
    /// </summary>
    {$ENDREGION}
    procedure Run;
  end;

  IErrorable = interface(IInvokable)
    ['{F0B32ED9-902B-4989-ABC6-D9C1DA78D567}']
    function Error: EUnhandledErrors;
    function DetachError: EUnhandledErrors;
  end;

  IMonitorable = interface(IInvokable)
    ['{E103B87C-0C23-43FA-A660-764987432C31}']

    {$REGION 'Documentation'}
    /// <summary>
    ///   task is up and running. (TTaskStatus.Running / TTaskStatus.Undefined)
    /// </summary>
    {$ENDREGION}
    function IsRunning: boolean;

    {$REGION 'Documentation'}
    /// <summary>
    ///   task has been cancelled by user. (TTaskStatus.Cancelled)
    /// </summary>
    {$ENDREGION}
    function IsCancelled: Boolean;

    {$REGION 'Documentation'}
    /// <summary>
    ///   task completed without errors. (TTaskStatus.Completed)
    /// </summary>
    {$ENDREGION}
    function IsCompleted: boolean;

    {$REGION 'Documentation'}
    /// <summary>
    ///   task completed with errors. (TTaskStatus.Faulted)
    /// </summary>
    {$ENDREGION}
    function IsFaulted: boolean;
  end;

  ITask = interface(IInvokable)
    ['{8C2B4438-8128-4D7C-9546-88B9477DEBD7}']
    {$REGION 'Documentation'}
    /// <summary>
    ///   Synchronous event, gets fired whenever a Thread terminates.
    ///   Runs multiple times if there is more than one Thread.
    ///   Sets the Taskstatus to TTaskStatus.Faulted when an uncaught exception occured in one of the Threads.
    /// </summary>
    {$ENDREGION}
    function OnThreadTerminated: IEvent<TSimpleProcedure>;
    function OnThreadTerminatedWithTaskControl: IEvent<TOnTaskThreadTerminated>;
    {$REGION 'Documentation'}
    /// <summary>
    ///   Synchronous Event, gets fired when the task has been completed (TTaskStatus.Completed|TTaskStatus.Cancelled|TTaskStatus.Faulted).
    ///   Runs only once on task completion.
    /// </summary>
    {$ENDREGION}
    function OnTaskStopped: IEvent<TOnTaskStopped>;

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

  ITaskBuilder = interface
    ['{09102B8D-ACED-4FC8-A061-B06DFACD2341}']
    {$REGION 'Documentation'}
    /// <summary>
    ///   sets up a task with maximum amount of threads
    /// </summary>
    {$ENDREGION}
    function WithMaxThreads: ITaskBuilder;  overload;
    {$REGION 'Documentation'}
    /// <summary>
    ///   sets up a task with given amount of threads
    /// </summary>
    {$ENDREGION}
    function WithMaxThreads(const AMaxThreads: Integer): ITaskBuilder; overload;
    {$REGION 'Documentation'}
    /// <summary>
    ///   sets up a task with a custom cancellation token
    /// </summary>
    {$ENDREGION}
    function WithCancellation(const ACancellationToken: IOmniCancellationToken): ITaskBuilder;

    {$REGION 'Documentation'}
    /// <summary>
    ///   builds the configured task
    /// </summary>
    {$ENDREGION}
    function BuildTask(const AAsyncAction: TAsyncAction): ITask; overload;
    function BuildTask(const AAsyncAction: IAsyncAction): ITask; overload;
  end;

  IWatchdog<T: IInterface> = interface(IInvokable)
    ['{CB479B36-B94A-469D-B42F-504A96005A5C}']
    {$REGION 'Documentation'}
    /// <summary>
    ///   gets fired when the watched operation takes longer than the given timeout
    /// </summary>
    {$ENDREGION}
    function OnTimeoutExceeded: IEvent<TOnTimeoutExceeded>;
    
    {$REGION 'Documentation'}
    /// <summary>
    ///   gets fired when the watched operation does not take longer than the given timeout
    /// </summary>
    {$ENDREGION}
    function OnTimeoutKept: IEvent<TOnTimeoutKept>;
    
    {$REGION 'Documentation'}
    /// <summary>
    ///   observes the amount of time through IWaitable.Wait of a running instance
    /// </summary>
    {$ENDREGION}
    procedure Run;
    
    {$REGION 'Documentation'}
    /// <summary>
    ///   the wrapped instance being watched
    /// </summary>
    {$ENDREGION}    
    function Watched: T;
  end;

  TConcurrency = class abstract
  public
    class function CreateTask: ITaskBuilder;
    class function CreateWatchdog<T: IInterface>(const AWatching: T; const ATimeout: Integer): IWatchdog<T>;
  end;

implementation

uses
  Concurrency.Task.Builder,
  Concurrency.Watchdog;

{ TConcurrency }

class function TConcurrency.CreateTask: ITaskBuilder;
begin
  Result := TTaskBuilder.Create;
end;

class function TConcurrency.CreateWatchdog<T>(const AWatching: T; const ATimeout: Integer): IWatchdog<T>;
begin
  Result := TWatchdog<T>.Create(AWatching, ATimeout, CreateTask);
end;

end.
