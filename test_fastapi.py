import asyncio
from app.database import SessionLocal
from app.models import User, Conversation
from app.schemas import ConversationCreate
from app.routers.conversations import create_or_fetch_conversation

db = SessionLocal()
u1 = db.query(User).first()
u2 = db.query(User).filter(User.id != u1.id).first()

if not u1 or not u2:
    print("Users missing")
    exit(1)

# Delete existing conv between u1 and u2
db.query(Conversation).filter(
    Conversation.participant_ids.contains([u1.id]),
    Conversation.participant_ids.contains([u2.id])
).delete(synchronize_session=False)
db.commit()

conv_data = ConversationCreate(participant_username=u2.username)

try:
    response = create_or_fetch_conversation(conv_data=conv_data, db=db, current_user=u1)
    print("Response type:", type(response))
    if hasattr(response, 'model_dump_json'):
        print(response.model_dump_json())
    else:
        print(response)
except Exception as e:
    print("Exception!")
    print(e)
