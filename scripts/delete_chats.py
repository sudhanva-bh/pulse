import sys
import os
from sqlalchemy import delete

# Add the parent directory to sys.path so we can import app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import SessionLocal
from app.models import Message, Conversation

def delete_chats():
    db = SessionLocal()
    try:
        print("Deleting all messages...")
        db.execute(delete(Message))
        
        print("Deleting all conversations...")
        db.execute(delete(Conversation))
        
        db.commit()
        print("Successfully deleted all chats and messages (accounts preserved).")
    except Exception as e:
        print(f"An error occurred: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    delete_chats()
