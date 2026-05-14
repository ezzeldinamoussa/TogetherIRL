import socketio
import asyncio

# Create the client
sio = socketio.AsyncClient(logger=True, engineio_logger=True)

async def main():
    print("Attempting to connect...")
    try:
        await sio.connect('http://127.0.0.1:8001')
        print("Connected!")
        # Register after connection
        await sio.emit('register', {'username': 'Tester_1'})
        print("Registration sent!")
        await sio.wait()
    except Exception as e:
        print(f"Failed to connect: {e}")

if __name__ == "__main__":
    asyncio.run(main())
