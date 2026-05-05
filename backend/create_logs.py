import os
import sys

# Make sure we can import the app
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.database.database import engine
from app.models.system_log import SystemLog

def recreate_system_logs():
    print("Creating system_logs table...")
    SystemLog.metadata.create_all(bind=engine)
    print("Successfully created system_logs table!")

if __name__ == "__main__":
    recreate_system_logs()
