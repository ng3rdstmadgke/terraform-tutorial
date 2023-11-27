from typing import List, Optional
from datetime import datetime
from pydantic import BaseModel
from api.models import JobStatus

class FibonacciJob(BaseModel):
    id: int
    job_id: Optional[str]
    args: str
    result: Optional[str]
    status: JobStatus
    created: datetime
    updated: datetime

class GetJobsResponse(BaseModel):
    items: List[FibonacciJob]

class PostJobRequest(BaseModel):
    n: int

class PostJobResponse(BaseModel):
    job_id: int
    message_id: str
