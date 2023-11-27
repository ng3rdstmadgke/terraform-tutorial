from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from api.env import get_env
from api.aws_resource import AwsResource


env = get_env()
aws_resource = AwsResource()
db_secret = aws_resource.get_db_secret()
SQLALCHEMY_DATABASE_URL = f"mysql+pymysql://{db_secret.db_user}:{db_secret.db_password}@{db_secret.db_host}:{db_secret.db_port}/{env.db_name}?charset=utf8mb4"
engine = create_engine(SQLALCHEMY_DATABASE_URL)
SessionLocal = sessionmaker(autocommit = False, autoflush = True, bind=engine)

def get_session():
    """DBのセッションを生成する。
    1リクエスト1セッションの想定で、 レスポンスが返却される際に自動でcloseされる。
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()