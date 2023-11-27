from typing import Union
from logging import config, getLogger, LogRecord, Filter as LoggingFilter

from fastapi import FastAPI, Depends
from sqlalchemy.orm import Session
from sqlalchemy.sql import text

from api.env import get_env
from api.session import get_session
from api.aws_resource import AwsResource

env = get_env()

# /healthcheck へのアクセスはログ出力しないようにする
class HealthCheckFilter(LoggingFilter):
    def filter(self, record: LogRecord) -> bool:
        return record.getMessage().find("/healthcheck") == -1

logger = getLogger()
getLogger("uvicorn.access").addFilter(HealthCheckFilter())


# APIの定義
app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "root"}

@app.get("/healthcheck")
def healthcheck():
    return {"message": "healthy"}

@app.get("/db-check/")
def dbcheck(session: Session = Depends(get_session)):
    row = session.execute(text("SELECT 'OK' as status")).first()
    return {"status": row.status}

@app.get("/fibonacci/")
def fibonacci(n: int = 100):
    aws_resource = AwsResource()
    message_id = aws_resource.send_fibonacci_job(n)
    return {"message_id": message_id}