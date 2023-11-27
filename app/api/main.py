from typing import Union
from logging import config, getLogger, LogRecord, Filter as LoggingFilter

from fastapi import FastAPI, Depends
from fastapi.staticfiles import StaticFiles
from sqlalchemy import desc
from sqlalchemy.orm import Session
from sqlalchemy.sql import text

from api.env import get_env
from api.session import get_session
from api.models import Job, JobStatus
from api.aws_resource import AwsResource
from api.schema import *

env = get_env()

# /api/healthcheck へのアクセスはログ出力しないようにする
class HealthCheckFilter(LoggingFilter):
    def filter(self, record: LogRecord) -> bool:
        return record.getMessage().find("/api/healthcheck/") == -1

logger = getLogger()
getLogger("uvicorn.access").addFilter(HealthCheckFilter())


# APIの定義
app = FastAPI()

@app.get("/api/healthcheck")
def healthcheck():
    return {"message": "healthy"}

@app.get("/api/db-check/")
def dbcheck(session: Session = Depends(get_session)):
    row = session.execute(text("SELECT 'OK' as status")).first()
    return {"status": row.status}

@app.get("/api/jobs/", response_model=GetJobsResponse)
def fibonacci_jobs_read(
    limit: int = 100,
    session: Session = Depends(get_session)
):
    jobs = session.query(Job).order_by(desc(Job.id)).limit(limit).all()
    return {"items": jobs}

@app.post("/api/jobs/", response_model=PostJobResponse)
def fibonacci_jobs_create(
    data: PostJobRequest,
    session: Session = Depends(get_session)
):
    job = Job(
        args=str(data.n),
        status=JobStatus.RUNNING,
    )
    session.add(job)
    session.commit()
    session.refresh(job)
    aws_resource = AwsResource()
    message_id = aws_resource.send_fibonacci_job(job.id, data.n)
    return {"job_id": job.id, "message_id": message_id}

# html=True : パスの末尾が "/" の時に自動的に index.html をロードする
# name="static" : FastAPIが内部的に利用する名前を付けます
app.mount("/", StaticFiles(directory=f"/opt/app/static", html=True), name="static")