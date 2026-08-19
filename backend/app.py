import os
import socket
import time

from flask import Flask, jsonify, request

app = Flask(__name__)

NODE_NAME = os.environ.get("NODE_NAME", socket.gethostname())
NODE_COLOR = os.environ.get("NODE_COLOR", "#2f6feb")
STARTED_AT = time.time()

state = {"healthy": True, "served": 0}

PAGE = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>HA lab - served by {node}</title>
<style>
  body {{ font-family: system-ui, sans-serif; margin: 0; height: 100vh;
         display: flex; align-items: center; justify-content: center;
         background: {color}; color: #fff; }}
  .card {{ text-align: center; }}
  h1 {{ font-size: 3rem; margin: 0 0 .5rem; }}
  p {{ opacity: .85; margin: .2rem 0; }}
  code {{ background: rgba(0,0,0,.25); padding: .1rem .4rem; border-radius: 4px; }}
</style>
</head>
<body>
  <div class="card">
    <h1>{node}</h1>
    <p>container <code>{host}</code></p>
    <p>request #{served} &middot; uptime {uptime}s</p>
  </div>
</body>
</html>
"""


@app.get("/")
def index():
    state["served"] += 1
    return PAGE.format(
        node=NODE_NAME,
        color=NODE_COLOR,
        host=socket.gethostname(),
        served=state["served"],
        uptime=int(time.time() - STARTED_AT),
    )


@app.get("/api/whoami")
def whoami():
    state["served"] += 1
    return jsonify(
        node=NODE_NAME,
        container=socket.gethostname(),
        healthy=state["healthy"],
        served=state["served"],
        uptime=round(time.time() - STARTED_AT, 1),
        forwarded_for=request.headers.get("X-Forwarded-For"),
    )


@app.get("/healthz")
def healthz():
    if state["healthy"]:
        return "ok", 200
    return "draining", 503


@app.post("/admin/health/<mode>")
def toggle(mode):
    if mode not in ("up", "down"):
        return jsonify(error="mode must be up or down"), 400
    state["healthy"] = mode == "up"
    return jsonify(node=NODE_NAME, healthy=state["healthy"])
