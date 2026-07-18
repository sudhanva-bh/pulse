from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy.dialects.postgresql import insert
from app.database import get_db
from app.models import User, Conversation, Message
from app.schemas import MessageResponse, SyncRequest
from app.dependencies import get_current_user
from typing import List

router = APIRouter(prefix="/sync", tags=["sync"])

@router.post("", response_model=List[MessageResponse])
def sync_data(
    request: SyncRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Process incoming messages (client to server)
    if request.messages:
        # Check permissions for all conversations involved
        conv_ids = list(set([m.conversation_id for m in request.messages]))
        convs = db.query(Conversation).filter(Conversation.id.in_(conv_ids)).all()
        valid_conv_ids = set([c.id for c in convs if current_user.id in c.participant_ids])
        
        insert_values = []
        for msg in request.messages:
            if msg.conversation_id in valid_conv_ids:
                insert_values.append({
                    "id": msg.id,
                    "conversation_id": msg.conversation_id,
                    "sender_id": current_user.id,
                    "content": msg.content,
                    "status": "sent",
                    "created_at": msg.created_at,
                    "updated_at": msg.updated_at
                })
                
        if insert_values:
            stmt = insert(Message).values(insert_values)
            # PostgreSQL idempotent write
            stmt = stmt.on_conflict_do_update(
                index_elements=['id'],
                set_={
                    'content': stmt.excluded.content,
                    'status': stmt.excluded.status,
                    'updated_at': stmt.excluded.updated_at
                }
            )
            db.execute(stmt)
            db.commit()

    # Process outgoing messages (server to client)
    user_convs = db.query(Conversation).filter(
        Conversation.participant_ids.contains([current_user.id])
    ).all()
    user_conv_ids = [c.id for c in user_convs]
    
    if not user_conv_ids:
        return []
        
    messages_to_return = db.query(Message).filter(
        Message.conversation_id.in_(user_conv_ids),
        Message.synced_at > request.last_sync_timestamp
    ).order_by(Message.synced_at.asc()).all()
    
    return messages_to_return
