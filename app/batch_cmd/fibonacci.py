import json
import click

from pydantic import BaseModel

from api.aws_resource import AwsResource
from api.models import Job, JobStatus
from api.session import SessionLocal

CONTEXT_SETTINGS = dict(help_option_names=['-h', '--help'])

class QueueBody(BaseModel):
    job_id: int
    n: int

@click.command(context_settings=CONTEXT_SETTINGS)
@click.option("-b", "--queue_body", required=True, type=str)
def main(queue_body):
    print(f"queue_body: {queue_body}")
    queue_body_obj = QueueBody.model_validate_json(queue_body)
    with SessionLocal() as session:
        aws_resource = AwsResource()
        job = session.query(Job).filter(Job.id == queue_body_obj.job_id).first()
        if job is None:
            aws_resource.send_message(
                sub="fibonacciジョブの実行に失敗しました",
                message=f"job_id={queue_body_obj.job_id} が見つかりません。",
                obj=queue_body,
            )
            return
        try:
            arr = [1, 1]
            for i in range(queue_body_obj.n):
                arr.append(arr[i] + arr[i + 1])
            result = str(arr[len(arr) - 1])
            print(f"result: {result}")
            job.status = JobStatus.SUCCESS
            job.result = result
        except Exception as e:
            job.status = JobStatus.FAILED
            aws_resource.send_message(
                sub="fibonacciジョブの実行に失敗しました",
                message=str(e),
                obj=queue_body,
            )
        finally:
            session.add(job)
            session.commit()

if __name__ == "__main__":
    #queue_body = json.dumps({"job_id": 2, "n": 10})
    main()