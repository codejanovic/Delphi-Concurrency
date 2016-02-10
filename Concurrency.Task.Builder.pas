unit Concurrency.Task.Builder;

interface

uses
  OtlParallel,
  OtlSync,
  OtlCommon,
  Concurrency;

type
  TTaskBuilder = class(TInterfacedObject, ITaskBuilder)
  protected
    fParallelTask: IOmniParallelTask;
    fCancellationToken: IOmniCancellationToken;

    procedure Reset;
  public
    constructor Create;

    function WithMaxThreads: ITaskBuilder;  overload;
    function WithMaxThreads(const AMaxThreads: Integer): ITaskBuilder; overload;
    function WithCancellation(const ACancellationToken: IOmniCancellationToken): ITaskBuilder;

    function BuildTask(const AAsyncAction: TAsyncAction): ITask; overload;
    function BuildTask(const AAsyncAction: IAsyncAction): ITask; overload;
  end;

implementation

uses
  Concurrency.Task,
  Concurrency.Task.AsyncAction;

{ TTaskBuilder }

function TTaskBuilder.BuildTask(const AAsyncAction: TAsyncAction): ITask;
var
  LAsyncAction: IAsyncAction;
begin
  LAsyncAction := TAsyncActionInstance.Create(AAsyncAction);
  Result := TTask.Create(LAsyncAction, fParallelTask, fCancellationToken);
end;

function TTaskBuilder.BuildTask(const AAsyncAction: IAsyncAction): ITask;
begin
  Result := TTask.Create(AAsyncAction, fParallelTask, fCancellationToken);
end;

constructor TTaskBuilder.Create;
begin
  Reset;
end;

procedure TTaskBuilder.Reset;
begin
  fParallelTask := Parallel.ParallelTask;
  fParallelTask.NoWait;

  fCancellationToken := CreateOmniCancellationToken;
end;

function TTaskBuilder.WithCancellation(const ACancellationToken: IOmniCancellationToken): ITaskBuilder;
begin
  fCancellationToken := ACancellationToken;
  Result := Self;
end;

function TTaskBuilder.WithMaxThreads(const AMaxThreads: Integer): ITaskBuilder;
begin
  fParallelTask.NumTasks(AMaxThreads);
  Result := Self;
end;

function TTaskBuilder.WithMaxThreads: ITaskBuilder;
begin
  fParallelTask.NumTasks(Environment.Process.Affinity.Count);
  Result := Self;
end;

end.
