import uuid
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User, Conversation, Message
from app.schemas import ConversationCreate, ConversationResponse, MessageResponse
from app.dependencies import get_current_user

router = APIRouter(
    prefix="/conversations",
    tags=["conversations"]
)

@router.post("", response_model=ConversationResponse)
def create_or_fetch_conversation(
    conv_data: ConversationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Find the target user
    target_user = db.query(User).filter(User.username == conv_data.participant_username).first()
    if not target_user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    
    if target_user.id == current_user.id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot create conversation with yourself")

    existing = db.query(Conversation).filter(
        Conversation.participant_ids.contains([current_user.id]),
        Conversation.participant_ids.contains([target_user.id])
    ).first()

    if existing:
        return existing
        
    # Create new
    new_conv = Conversation(
        id=str(uuid.uuid4()),
        participant_ids=[current_user.id, target_user.id]
    )
    db.add(new_conv)
    db.commit()
    db.refresh(new_conv)
    return new_conv

@router.get("", response_model=List[ConversationResponse])
def get_conversations(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    return db.query(Conversation).filter(
        Conversation.participant_ids.contains([current_user.id])
    ).order_by(Conversation.last_message_at.desc().nulls_last()).all()

@router.get("/{conversation_id}/messages", response_model=List[MessageResponse])
def get_messages(
    conversation_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Check if user is part of the conversation
    conv = db.query(Conversation).filter(Conversation.id == conversation_id).first()
    if not conv or current_user.id not in conv.participant_ids:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")
        
    messages = db.query(Message).filter(
        Message.conversation_id == conversation_id
    ).order_by(Message.created_at.asc()).all()
    
    return messages
