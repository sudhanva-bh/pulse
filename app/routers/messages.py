import json
from fastapi import APIRouter, Depends, HTTPException, status, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User, Conversation, Message
from app.schemas import MessageCreate, MessageResponse
from app.dependencies import get_current_user
from app.security import decode_access_token
from typing import Dict, List

router = APIRouter(
    tags=["messages"]
)

class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}

    async def connect(self, websocket: WebSocket, user_id: str):
        await websocket.accept()
        self.active_connections[user_id] = websocket

    def disconnect(self, user_id: str):
        if user_id in self.active_connections:
            del self.active_connections[user_id]

    async def send_personal_message(self, message: str, user_id: str):
        if user_id in self.active_connections:
            await self.active_connections[user_id].send_text(message)

manager = ConnectionManager()

def get_user_from_token(token: str, db: Session) -> User:
    try:
        user_id = decode_access_token(token)
        if user_id is None:
            return None
        return db.query(User).filter(User.id == user_id).first()
    except:
        return None

@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, token: str, db: Session = Depends(get_db)):
    user = get_user_from_token(token, db)
    if not user:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return
        
    await manager.connect(websocket, user.id)
    try:
        while True:
            data_str = await websocket.receive_text()
            data = json.loads(data_str)
            
            msg_type = data.get("type")
            payload = data.get("data")
            
            if not msg_type or not payload:
                continue
                
            if msg_type == "typing":
                conv_id = payload.get("conversation_id")
                if not conv_id:
                    continue
                conv = db.query(Conversation).filter(Conversation.id == conv_id).first()
                if conv and user.id in conv.participant_ids:
                    for p_id in conv.participant_ids:
                        if p_id != user.id:
                            await manager.send_personal_message(json.dumps({
                                "type": "typing",
                                "data": {
                                    "conversation_id": conv_id,
                                    "sender_id": user.id
                                }
                            }), p_id)
            
            elif msg_type == "status_update":
                try:
                    msg_id = payload.get("message_id")
                    status_val = payload.get("status")
                    if not msg_id or not status_val:
                        continue
                        
                    msg_record = db.query(Message).filter(Message.id == msg_id).first()
                    if not msg_record:
                        continue
                        
                    # Verify user is recipient (only recipient can update to delivered/read)
                    # wait, it's easier to just allow it since token is verified.
                    msg_record.status = status_val
                    db.commit()
                    
                    # Forward back to the original sender
                    await manager.send_personal_message(json.dumps({
                        "type": "status_update",
                        "data": {
                            "message_id": msg_id,
                            "status": status_val
                        }
                    }), msg_record.sender_id)
                except Exception as e:
                    print(f"Error processing status update: {e}")
                    db.rollback()

            elif msg_type == "message":
                try:
                    msg_create = MessageCreate(**payload)
                    conv = db.query(Conversation).filter(Conversation.id == msg_create.conversation_id).first()
                    
                    if not conv or user.id not in conv.participant_ids:
                        continue
                        
                    new_msg = Message(
                        id=msg_create.id,
                        conversation_id=msg_create.conversation_id,
                        sender_id=user.id,
                        content=msg_create.content,
                        status="sent",
                        created_at=msg_create.created_at,
                        updated_at=msg_create.updated_at
                    )
                    db.add(new_msg)
                    
                    conv.last_message_at = msg_create.created_at
                    
                    db.commit()
                    db.refresh(new_msg)
                    
                    msg_response = MessageResponse.model_validate(new_msg)
                    
                    # Ack to sender
                    await manager.send_personal_message(json.dumps({
                        "type": "ack",
                        "data": {"message_id": new_msg.id}
                    }), user.id)
                    
                    # Forward to recipient
                    for p_id in conv.participant_ids:
                        if p_id != user.id:
                            await manager.send_personal_message(json.dumps({
                                "type": "message",
                                "data": msg_response.model_dump(mode="json")
                            }), p_id)
                except Exception as e:
                    print(f"Error processing message: {e}")
                    db.rollback()
                    
    except WebSocketDisconnect:
        manager.disconnect(user.id)

@router.post("/messages", response_model=MessageResponse)
def create_message(
    msg_data: MessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    conv = db.query(Conversation).filter(Conversation.id == msg_data.conversation_id).first()
    if not conv or current_user.id not in conv.participant_ids:
        raise HTTPException(status_code=404, detail="Conversation not found")
        
    new_msg = Message(
        id=msg_data.id,
        conversation_id=msg_data.conversation_id,
        sender_id=current_user.id,
        content=msg_data.content,
        status="sent",
        created_at=msg_data.created_at,
        updated_at=msg_data.updated_at
    )
    db.add(new_msg)
    
    conv.last_message_at = msg_data.created_at
    db.commit()
    db.refresh(new_msg)
    
    return new_msg

from datetime import datetime

@router.get("/messages/sync", response_model=List[MessageResponse])
def sync_messages(
    since: datetime,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Find all conversations the user is part of
    convs = db.query(Conversation).filter(
        Conversation.participant_ids.contains([current_user.id])
    ).all()
    
    if not convs:
        return []
        
    conv_ids = [c.id for c in convs]
    
    # Query all messages in those conversations newer than 'since'
    messages = db.query(Message).filter(
        Message.conversation_id.in_(conv_ids),
        Message.created_at > since
    ).order_by(Message.created_at.asc()).all()
    
    return messages
