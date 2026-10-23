"""Serve src/ to Roblox Studio so tools/studio_sync.luau can mirror it into the open place.

Run from anywhere:  py tools/studio_sync_server.py   (stdlib only, listens on 127.0.0.1:34999)
GET /manifest -> JSON list of every .lua file under src/ (forward slashes, sorted)
GET /tool     -> tools/studio_sync.luau (installed in Studio as ServerStorage.StudioSync)
GET /<path>   -> that file's bytes
"""
import http.server
import json
import os

PORT = 34999
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src"))


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def do_GET(self):
        if self.path == "/tool":
            with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "studio_sync.luau"), "rb") as f:
                return self.reply(f.read(), "text/plain; charset=utf-8")
        if self.path != "/manifest":
            return super().do_GET()
        files = []
        for folder, _, names in os.walk(ROOT):
            for name in names:
                if name.endswith(".lua"):
                    files.append(os.path.relpath(os.path.join(folder, name), ROOT).replace(os.sep, "/"))
        self.reply(json.dumps(sorted(files)).encode("utf-8"), "application/json")

    def reply(self, body, content_type):
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    print(f"serving {ROOT} on http://127.0.0.1:{PORT}", flush=True)
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
