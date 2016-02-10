unit Concurrency.Task.AsyncAction;

interface

uses
  Concurrency,
  OtlSync,
  OtlTask;

type
  TAsyncActionInstance = class(TInterfacedObject, IAsyncAction)
  protected
    fAsyncAction: TAsyncAction;
  public
    constructor Create(const AAsyncAction: TAsyncAction);
    procedure RunAsync(const ATask: IOmniTask; const ACancellationToken: IOmniCancellationToken);
  end;

implementation

uses
  Spring;

{ TAsyncTaskExecution }

constructor TAsyncActionInstance.Create(const AAsyncAction: TAsyncAction);
begin
  fAsyncAction := AAsyncAction;
end;

procedure TAsyncActionInstance.RunAsync(const ATask: IOmniTask;const ACancellationToken: IOmniCancellationToken);
begin
  Guard.CheckNotNull(ATask, 'missing Task');
  Guard.CheckNotNull(ACancellationToken, 'missing CancellationToken');

  fAsyncAction(ATask, ACancellationToken);
end;

end.
