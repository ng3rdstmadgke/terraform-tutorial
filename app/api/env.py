from functools import lru_cache
from pydantic_settings import BaseSettings
from typing import Optional

class Environment(BaseSettings):
    """環境変数を定義する構造体。
    pydanticを利用した環境変数の読み込み: https://fastapi.tiangolo.com/advanced/settings/#environment-variables
    """
    stage: str
    sns_arn: str
    db_name: str
    db_secret_name: str
    fibonacci_job_queue_url: str
    local: bool = False

    # 以下はローカル環境でのみ利用する環境変数
    aws_endpoint_url: Optional[str] = None
    aws_region: str = "ap-northeast-1"

@lru_cache
def get_env() -> Environment:
    return Environment()