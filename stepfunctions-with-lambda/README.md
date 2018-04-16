# What?

Create an AWS [step function](https://aws.amazon.com/step-functions/) that calls a [lambda](https://aws.amazon.com/lambda/) function and handles an error condition by calling a Lambda error handler function.

# How?

Deploy:

```
terraform init
terraform apply
```

List available state machines:

```
aws stepfunctions list-state-machines
```

Run a state machine execution which will return success:

```
aws stepfunctions start-execution --state-machine-arn=${STATE_MACHINE_ARN}
```

Get execution history:

```
aws stepfunctions get-execution-history --execution-arn=${EXECUTION_HISTORY_ARN}
```

The last event should look something like:

```
        {
            "timestamp": 1523876307.372,
            "type": "ExecutionSucceeded",
            "id": 9,
            "previousEventId": 8,
            "executionSucceededEventDetails": {
                "output": "\"success\""
            }
        }
```

To see a diagram of the state machine execution, go to AWS Console > Step Functions > Dashboard > State Machines > state and click on the most recent execution. You should see a diagram like [this](./success.png).

Run a state machine execution which will raise `TestError`, catch it within the state machine and call `error_handler`.

```
aws stepfunctions start-execution --generate-cli-skeleton > input.json
```

Edit `input.json`:

```
{
    "stateMachineArn": "${STATE_MACHINE_ARN}",
    "name": "test",
    "input": "{\"fail\": true}"
}
```

Run the state machine execution defined within `input.json`:

```
aws stepfunctions start-execution --cli-input-json file://input.json
```

Get execution history:

```
aws stepfunction get-execution-history --execution-arn=${EXECUTION_HISTORY_ARN}
```

The workflow diagram shoud look like [this](./fail.png).

The last 2 events should look something like:

```

        {
            "timestamp": 1523876472.978,
            "type": "PassStateExited",
            "id": 13,
            "previousEventId": 12,
            "stateExitedEventDetails": {
                "name": "FailState",
                "output": "\"handled error\""
            }
        },
        {
            "timestamp": 1523876472.978,
            "type": "ExecutionSucceeded",
            "id": 14,
            "previousEventId": 13,
            "executionSucceededEventDetails": {
                "output": "\"handled error\""
            }
        }
```

The output was generated from `FailState` within `states.json`.

`error_handler` from `source/test.py` was called with the output being written to a CloudWatch log. Go to AWS Console > CloudWatch > Log Groups > /aws/lambda/Error and click the latest log stream. You should see `called error_handler` as an event.

Destroy all resources.

```
terraform destroy
```
