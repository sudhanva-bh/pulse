from pydantic import BaseModel, field_validator
from datetime import datetime
from typing import List, Optional, Any, Dict


class UserRegister(BaseModel):
    username: str
    password: str

    @field_validator("username")
    @classmethod
    def username_must_be_valid(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 3:
            raise ValueError("Username must be at least 3 characters")
        if not v.isalnum():
            raise ValueError("Username must be alphanumeric")
        return v

    @field_validator("password")
    @classmethod
    def password_must_be_strong(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        return v


class UserResponse(BaseModel):
    id: str
    username: str
    created_at: datetime

    model_config = {"from_attributes": True}


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str


class MessageCreate(BaseModel):
    id: str
    conversation_id: str
    content: str
    created_at: datetime
    updated_at: datetime


class MessageResponse(BaseModel):
    id: str
    conversation_id: str
    sender_id: str
    content: str
    status: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class ConversationCreate(BaseModel):
    participant_username: str


class ConversationResponse(BaseModel):
    id: str
    participant_ids: List[str]
    created_at: datetime
    last_message_at: Optional[datetime] = None
    title: Optional[str] = None
    last_message_content: Optional[str] = None
    status: str
    initiator_id: str

    model_config = {"from_attributes": True}


class MessageWs(BaseModel):
    type: str
    data: Dict[str, Any]