from fastapi import FastAPI
from typing import Union
from logging import config, getLogger, LogRecord, Filter as LoggingFilter

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

@app.get("/fibonacci")
def fibonacci(cnt: int = 100):
    arr = [1, 1]
    for i in range(cnt):
        arr.append(arr[i] + arr[i + 1])
    return {"fibonacci": arr[len(arr) - 1]}