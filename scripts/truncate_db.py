import sys
import os

# Add the parent directory to sys.path so we can import app modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.database import engine, Base
# Import all models so they are registered with Base.metadata
from app.models import User, Conversation, Message

def truncate_db():
    print("Dropping all tables...")
    Base.metadata.drop_all(bind=engine)
    
    print("Recreating all tables...")
    Base.metadata.create_all(bind=engine)
    
    print("Database has been completely truncated and recreated successfully!")

if __name__ == "__main__":
    truncate_db()
