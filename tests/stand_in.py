"""A llama-server for the plugin's tests: it answers what it is told to from
what the plugin asks, and logs each request, a line of JSON to a file. Run as
stand_in.py PORT LOG MODEL_PATH [busy|loading]."""
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

port, log, model, *mood = sys.argv[1:]
mood = mood[0] if mood else ""


class Server(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def reply(self, status, value):
        body = json.dumps(value).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def noted(self, body):
        with open(log, "a", encoding="utf-8") as out:
            out.write(json.dumps({"path": self.path, "body": body}) + "\n")

    def do_GET(self):
        self.noted({})
        if self.path == "/slots":
            self.reply(200, [{"id": 0, "is_processing": mood == "busy"}])
        elif mood == "loading":
            self.reply(503, {"error": {"code": 503, "message": "Loading model"}})
        elif self.path == "/health":
            self.reply(200, {"status": "ok"})
        else:
            self.reply(200, {"model_path": model, "default_generation_settings": {"n_ctx": 2000}})

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        self.noted(body)
        self.reply(200, {"content": " the answer", "timings": {"prompt_n": 3, "predicted_n": 1}})


ThreadingHTTPServer(("127.0.0.1", int(port)), Server).serve_forever()
