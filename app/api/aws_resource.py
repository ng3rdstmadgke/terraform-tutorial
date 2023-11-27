import json
from typing import Dict, Union

import boto3
from pydantic import BaseModel

from api.env import get_env, Environment

class DBSecret(BaseModel):
    db_user: str
    db_password: str
    db_host: str
    db_port: int

class AwsResource:
    def __init__(self, env: Environment = get_env()):
        self.env = env

    def __get_client(self, service_name: str):
        client = boto3.client(
            service_name=service_name,
            region_name = self.env.aws_region,
            endpoint_url = self.env.aws_endpoint_url
        )
        return client

    def get_db_secret(self) -> DBSecret:
        client = self.__get_client('secretsmanager')
        secret = client.get_secret_value(SecretId=self.env.db_secret_name)['SecretString']
        return DBSecret.model_validate_json(secret)

    def send_message(self, sub: str, message: str, obj: Union[Dict,BaseModel,str]):
        if isinstance(obj, BaseModel):
            obj_str = obj.model_dump_json(indent=2)
        elif isinstance(obj, dict):
            obj_str = json.dumps(obj, indent=2, ensure_ascii=False)
        else:
            obj_str = obj

        sub = f"[terraform-tutorial][{self.env.stage}] ${sub}"
        msg = "Message:\n{message}\n\nObject:\n{obj_str}"
        client = self.__get_client('sns')
        client.publish(TopicArn=self.env.sns_arn, Subject=sub, Message=msg)

    def send_fibonacci_job(self, job_id: int, n: int) -> str:
        client = self.__get_client('sqs')
        response = client.send_message(
            QueueUrl=self.env.job_queue_url,
            MessageBody=json.dumps({"job_id": job_id, "n": n})
        )
        return response['MessageId']