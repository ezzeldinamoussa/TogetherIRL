import socketio
from fastapi import FastAPI
import logging
import os
from dotenv import load_dotenv
from pydantic import BaseModel
from livekit import api

load_dotenv()

LIVEKIT_URL = os.getenv("LIVEKIT_URL")
LIVEKIT_API_KEY = os.getenv("LIVEKIT_API_KEY")
LIVEKIT_API_SECRET = os.getenv("LIVEKIT_API_SECRET")


class TokenRequest(BaseModel):
    username: str
    room: str = "tabletalk-room"


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

sio = socketio.AsyncServer(
    async_mode="asgi",
    cors_allowed_origins="*",
    logger=True,
    engineio_logger=True,
)

socket_app = socketio.ASGIApp(sio, app)

# Stores which socket ID belongs to each username.
# Example:
# {
#   "tabletalk-room": {
#       "Alex": "abc123",
#       "Jordan": "xyz789"
#   }
# }
room_users = {}


@app.post("/token")
async def create_token(request: TokenRequest):
    if not LIVEKIT_URL or not LIVEKIT_API_KEY or not LIVEKIT_API_SECRET:
        return {"error": "LiveKit environment variables are missing"}

    token = (
        api.AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET)
        .with_identity(request.username)
        .with_name(request.username)
        .with_grants(
            api.VideoGrants(
                room_join=True,
                room=request.room,
                can_publish=True,
                can_subscribe=True,
            )
        )
        .to_jwt()
    )

    return {
        "url": LIVEKIT_URL,
        "token": token,
        "room": request.room,
    }


@sio.event
async def connect(sid, environ):
    logger.info(f"CONNECTED: {sid}")


@sio.event
async def register(sid, data):
    username = data.get("username")
    room = data.get("room", "tabletalk-room")

    if not username:
        logger.warning(f"REGISTER FAILED: missing username for SID {sid}")
        return

    # Put this socket connection into the Socket.IO room.
    await sio.enter_room(sid, room)

    # Save session info so disconnect can clean up later.
    await sio.save_session(
        sid,
        {
            "username": username,
            "room": room,
        },
    )

    # Track username -> socket ID for targeted nudges.
    if room not in room_users:
        room_users[room] = {}

    room_users[room][username] = sid

    logger.info(f"REGISTERED: {username} in room {room} with SID {sid}")

    # Let everyone in the room know the current registered users.
    await sio.emit(
        "registered_users",
        {
            "room": room,
            "users": list(room_users[room].keys()),
        },
        room=room,
    )


@sio.event
async def send_nudge(sid, data):
    room = data.get("room", "tabletalk-room")
    from_user = data.get("fromUser")
    to_user = data.get("toUser")

    if not from_user or not to_user:
        logger.warning(f"NUDGE FAILED: missing fromUser or toUser. Data: {data}")
        return

    target_sid = room_users.get(room, {}).get(to_user)

    if not target_sid:
        logger.warning(f"NUDGE FAILED: could not find {to_user} in room {room}")
        await sio.emit(
            "nudge_failed",
            {
                "toUser": to_user,
                "message": f"{to_user} is not currently connected.",
            },
            to=sid,
        )
        return

    logger.info(f"NUDGE: {from_user} nudged {to_user} in room {room}")

    # Send only to the person being nudged.
    await sio.emit(
        "receive_nudge",
        {
            "fromUser": from_user,
            "toUser": to_user,
            "message": f"{from_user} wants to talk to you.",
        },
        to=target_sid,
    )

    # Optional confirmation back to the sender.
    await sio.emit(
        "nudge_sent",
        {
            "toUser": to_user,
            "message": f"Nudge sent to {to_user}.",
        },
        to=sid,
    )


@sio.event
async def disconnect(sid):
    logger.info(f"DISCONNECTED: {sid}")

    try:
        session = await sio.get_session(sid)
    except KeyError:
        return

    username = session.get("username")
    room = session.get("room")

    if room in room_users and username in room_users[room]:
        del room_users[room][username]

        if not room_users[room]:
            del room_users[room]
        else:
            await sio.emit(
                "registered_users",
                {
                    "room": room,
                    "users": list(room_users[room].keys()),
                },
                room=room,
            )

    logger.info(f"REMOVED USER: {username} from room {room}")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(socket_app, host="0.0.0.0", port=8001, log_level="info")