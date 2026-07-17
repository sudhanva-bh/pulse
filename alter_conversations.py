import asyncio
from sqlalchemy import text
from app.database import SessionLocal

def upgrade():
    db = SessionLocal()
    try:
        # Add columns
        db.execute(text("ALTER TABLE conversations ADD COLUMN IF NOT EXISTS status VARCHAR DEFAULT 'pending'"))
        db.execute(text("ALTER TABLE conversations ADD COLUMN IF NOT EXISTS initiator_id VARCHAR"))
        
        # Migrate existing conversations
        db.execute(text("UPDATE conversations SET status = 'accepted' WHERE status = 'pending' OR status IS NULL"))
        db.execute(text("UPDATE conversations SET initiator_id = participant_ids[1] WHERE initiator_id IS NULL"))
        
        # Make initiator_id NOT NULL
        db.execute(text("ALTER TABLE conversations ALTER COLUMN initiator_id SET NOT NULL"))
        
        db.commit()
        print("Successfully updated conversations table.")
    except Exception as e:
        db.rollback()
        print(f"Error upgrading database: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    upgrade()
