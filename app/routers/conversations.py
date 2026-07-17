import uuid
import json
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User, Conversation, Message
from app.schemas import ConversationCreate, ConversationResponse, MessageResponse
from app.dependencies import get_current_user
from app.routers.messages import manager

router = APIRouter(
    prefix="/conversations",
    tags=["conversations"]
)

@router.post("", response_model=ConversationResponse)
async def create_or_fetch_conversation(
    conv_data: ConversationCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
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
        if existing.status == 'rejected':
            existing.status = 'pending'
            existing.initiator_id = current_user.id
            db.commit()
            db.refresh(existing)
            
            resp = ConversationResponse(
                id=existing.id, participant_ids=existing.participant_ids,
                created_at=existing.created_at, last_message_at=existing.last_message_at,
                title=target_user.username, last_message_content=None,
                status=existing.status, initiator_id=existing.initiator_id
            )
            # Notify target user
            target_resp = resp.model_copy()
            target_resp.title = current_user.username
            await manager.send_personal_message(json.dumps({
                "type": "conversation_update",
                "data": target_resp.model_dump(mode="json")
            }), target_user.id)
            return resp

        return ConversationResponse(
            id=existing.id,
            participant_ids=existing.participant_ids,
            created_at=existing.created_at,
            last_message_at=existing.last_message_at,
            title=target_user.username,
            last_message_content=None,
            status=existing.status,
            initiator_id=existing.initiator_id
        )
        
    new_conv = Conversation(
        id=str(uuid.uuid4()),
        participant_ids=[current_user.id, target_user.id],
        status="pending",
        initiator_id=current_user.id
    )
    db.add(new_conv)
    db.commit()
    db.refresh(new_conv)
    
    resp = ConversationResponse(
        id=new_conv.id,
        participant_ids=new_conv.participant_ids,
        created_at=new_conv.created_at,
        last_message_at=new_conv.last_message_at,
        title=target_user.username,
        last_message_content=None,
        status=new_conv.status,
        initiator_id=new_conv.initiator_id
    )
    
    target_resp = resp.model_copy()
    target_resp.title = current_user.username
    await manager.send_personal_message(json.dumps({
        "type": "conversation_update",
        "data": target_resp.model_dump(mode="json")
    }), target_user.id)
    
    return resp

@router.post("/{conversation_id}/accept", response_model=ConversationResponse)
async def accept_conversation(
    conversation_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    conv = db.query(Conversation).filter(Conversation.id == conversation_id).first()
    if not conv or current_user.id not in conv.participant_ids:
        raise HTTPException(status_code=404, detail="Conversation not found")
        
    if conv.initiator_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot accept your own request")
        
    conv.status = 'accepted'
    db.commit()
    db.refresh(conv)
    
    other_id = next((pid for pid in conv.participant_ids if pid != current_user.id), None)
    other_user = db.query(User).filter(User.id == other_id).first() if other_id else None
    
    resp = ConversationResponse(
        id=conv.id, participant_ids=conv.participant_ids, created_at=conv.created_at,
        last_message_at=conv.last_message_at, title=other_user.username if other_user else "Unknown",
        last_message_content=None, status=conv.status, initiator_id=conv.initiator_id
    )
    
    if other_id:
        target_resp = resp.model_copy()
        target_resp.title = current_user.username
        await manager.send_personal_message(json.dumps({
            "type": "conversation_update",
            "data": target_resp.model_dump(mode="json")
        }), other_id)
        
    return resp

@router.post("/{conversation_id}/reject", response_model=ConversationResponse)
async def reject_conversation(
    conversation_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    conv = db.query(Conversation).filter(Conversation.id == conversation_id).first()
    if not conv or current_user.id not in conv.participant_ids:
        raise HTTPException(status_code=404, detail="Conversation not found")
        
    if conv.initiator_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot reject your own request")
        
    conv.status = 'rejected'
    db.commit()
    db.refresh(conv)
    
    other_id = next((pid for pid in conv.participant_ids if pid != current_user.id), None)
    other_user = db.query(User).filter(User.id == other_id).first() if other_id else None
    
    resp = ConversationResponse(
        id=conv.id, participant_ids=conv.participant_ids, created_at=conv.created_at,
        last_message_at=conv.last_message_at, title=other_user.username if other_user else "Unknown",
        last_message_content=None, status=conv.status, initiator_id=conv.initiator_id
    )
    
    if other_id:
        target_resp = resp.model_copy()
        target_resp.title = current_user.username
        await manager.send_personal_message(json.dumps({
            "type": "conversation_update",
            "data": target_resp.model_dump(mode="json")
        }), other_id)
        
    return resp

@router.get("", response_model=List[ConversationResponse])
def get_conversations(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    convs = db.query(Conversation).filter(
        Conversation.participant_ids.contains([current_user.id])
    ).order_by(Conversation.last_message_at.desc().nulls_last()).all()
    
    result = []
    for c in convs:
        other_id = next((pid for pid in c.participant_ids if pid != current_user.id), None)
        title = "Unknown"
        if other_id:
            other_user = db.query(User).filter(User.id == other_id).first()
            if other_user:
                title = other_user.username
                
        last_msg = db.query(Message).filter(Message.conversation_id == c.id).order_by(Message.created_at.desc()).first()
        last_message_content = last_msg.content if last_msg else None
        
        c_dict = {
            "id": c.id, "participant_ids": c.participant_ids, "created_at": c.created_at,
            "last_message_at": c.last_message_at, "title": title, "last_message_content": last_message_content,
            "status": c.status, "initiator_id": c.initiator_id
        }
        result.append(c_dict)
        
    return result

@router.get("/{conversation_id}/messages", response_model=List[MessageResponse])
def get_messages(
    conversation_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    conv = db.query(Conversation).filter(Conversation.id == conversation_id).first()
    if not conv or current_user.id not in conv.participant_ids:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")
        
    messages = db.query(Message).filter(
        Message.conversation_id == conversation_id
    ).order_by(Message.created_at.asc()).all()
    
    return messages
