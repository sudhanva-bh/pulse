import uuid
from sqlalchemy import Column, String, DateTime, func, Integer
from sqlalchemy.dialects.postgresql import ARRAY
from app.database import Base

class User(Base):
    __tablename__ = "users"
    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    username = Column(String, unique=True, nullable=False)
    password_hash = Column(String, nullable=False)
    fcm_token = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class Message(Base):
    __tablename__ = "messages"
    id = Column(String, primary_key=True)
    conversation_id = Column(String, nullable=False)
    sender_id = Column(String, nullable=False)
    content = Column(String, nullable=False)
    status = Column(String, nullable=False, default='sent')
    created_at = Column(DateTime(timezone=True), nullable=False)
    updated_at = Column(DateTime(timezone=True), nullable=False)
    synced_at = Column(DateTime(timezone=True), server_default=func.now())
    attachment_name = Column(String, nullable=True)
    attachment_size = Column(Integer, nullable=True)

class Conversation(Base):
    __tablename__ = "conversations"
    id = Column(String, primary_key=True)
    participant_ids = Column(ARRAY(String), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    last_message_at = Column(DateTime(timezone=True), nullable=True)
    status = Column(String, default="pending", nullable=False)
    initiator_id = Column(String, nullable=False)