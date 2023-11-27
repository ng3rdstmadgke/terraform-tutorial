from functools import lru_cache
from pydantic_settings import BaseSettings

class Environment(BaseSettings):
    """環境変数を定義する構造体。
    pydanticを利用した環境変数の読み込み: https://fastapi.tiangolo.com/advanced/settings/#environment-variables
    """
    stage: str
    sns_arn: str
    db_name: str
    db_secret_name: str
    fibonacci_job_queue_url: str
    debug: bool = False


@lru_cache
def get_env() -> Environment:
    return Environment()