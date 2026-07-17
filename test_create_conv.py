import httpx
import json

# Login as a user to get token
r = httpx.post("http://localhost:8000/auth/login", data={"username": "user1", "password": "password"})
token = r.json().get("access_token")

headers = {"Authorization": f"Bearer {token}"}
r2 = httpx.post("http://localhost:8000/conversations", json={"participant_username": "user2"}, headers=headers)

print(r2.status_code)
print(r2.text)
