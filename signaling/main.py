import socketio
from fastapi import FastAPI
import logging

# This tells Python to print EVERYTHING to the console
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Create the server with internal logging enabled
sio = socketio.AsyncServer(
    async_mode='asgi', 
    cors_allowed_origins='*',
    logger=True,        # <--- Add this: Logs Socket.io events
    engineio_logger=True # <--- Add this: Logs low-level connection data
)

app = FastAPI()
socket_app = socketio.ASGIApp(sio, app)

@sio.event
async def connect(sid, environ):
    # Use logger.info instead of print for more reliable terminal output
    logger.info(f"CONNECTED: {sid}")

@sio.event
async def register(sid, data):
    user_id = data.get('username')
    logger.info(f"REGISTERED: {user_id} with SID {sid}")

if __name__ == "__main__":
    import uvicorn
    # We use 8001 since 8000 is currently blocked on your Mac
    uvicorn.run(socket_app, host="0.0.0.0", port=8001, log_level="info")

''' Next Steps: Hosting for Free on Render.com
Since this is your first time with a backend, Render is great because it connects directly to your GitHub.
Push your code to GitHub: Create a repository and upload your main.py and a requirements.txt file (containing fastapi, uvicorn, and python-socketio).
Create a New Web Service on Render:
Runtime: Python
Build Command: pip install -r requirements.txt
Start Command: uvicorn main:socket_app --host 0.0.0.0 --port $PORT
Result: Render will give you a URL like https://my-app.onrender.com. You use this URL in your app instead of localhost.'''