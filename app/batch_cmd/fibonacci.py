import json
import click

from pydantic import BaseModel

CONTEXT_SETTINGS = dict(help_option_names=['-h', '--help'])

class QueueBody(BaseModel):
    cnt: int

@click.command(context_settings=CONTEXT_SETTINGS)
@click.option("-b", "--queue_body", required=True, type=str)
def main(queue_body):
    print(f"queue_body: {queue_body}")
    args = QueueBody.model_validate_json(queue_body)
    arr = [1, 1]
    for i in range(args.cnt):
        arr.append(arr[i] + arr[i + 1])
    ret = {"fibonacci": arr[len(arr) - 1]}
    print(json.dumps(ret))

if __name__ == "__main__":
    #queue_body = json.dumps({"cnt": 10})
    main()