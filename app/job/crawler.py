import click

from api.aws_resource import AwsResource
from api.models import Job, JobStatus
from api.session import SessionLocal

CONTEXT_SETTINGS = dict(help_option_names=['-h', '--help'])

@click.command(context_settings=CONTEXT_SETTINGS)
def main():
    with SessionLocal() as session:
        aws_resource = AwsResource()
        try:
            jobs = session.query(Job).filter(Job.status == JobStatus.RUNNING).all()
            aws_resource.send_message(
                sub="crawlerジョブ",
                message=f"処理中のジョブは {len(jobs)} 件です。",
                obj="",
            )

        except Exception as e:
            aws_resource.send_message(
                sub="fibonacciジョブの実行に失敗しました",
                message=str(e),
                obj="",
            )

if __name__ == "__main__":
    main()
