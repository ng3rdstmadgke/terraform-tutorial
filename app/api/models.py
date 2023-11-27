import enum
from datetime import datetime
from sqlalchemy import Boolean, Column, Integer, String, UniqueConstraint, text
from sqlalchemy.orm import relationship
from sqlalchemy.sql.sqltypes import DateTime, Enum

from sqlalchemy.orm.decl_api import declarative_base
Base = declarative_base()

class Job(Base):
    __tablename__ = "jobs"
    __table_args__ = {'mysql_engine':'InnoDB', 'mysql_charset':'utf8mb4','mysql_collate':'utf8mb4_bin'}

    id      = Column(Integer, primary_key=True)
    job_id  = Column(String(255, collation="utf8mb4_bin"), index=True, nullable=False)
    args    = Column(String(255, collation="utf8mb4_bin"), nullable=False)
    result  = Column(String(255, collation="utf8mb4_bin"), nullable=True)
    created = Column(DateTime, default=datetime.now, nullable=False)
    updated = Column(DateTime, default=datetime.now, onupdate=datetime.now, nullable=False)

    def __repr__(self):
        return f"<Job(id={self.id}, job_id={self.job_id}, args={self.args}, result={self.result})>"