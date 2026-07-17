import urllib.request
try:
    req = urllib.request.Request("http://localhost:8000/messages/sync?since=2026-07-18T00:00:00Z")
    with urllib.request.urlopen(req) as response:
        print(response.status)
except urllib.error.HTTPError as e:
    print(e.code)
