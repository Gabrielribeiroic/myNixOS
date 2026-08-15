#!/usr/bin/env python3
"""Local HTTP control for a Tuya Wi-Fi relay (the PCIe power card).

Endpoints (GET): /status  /on  /off  /toggle
Credentials come from the systemd LoadCredential dir or TUYA_* env vars.
The device only accepts ONE local connection at a time: keep the Tuya
app closed, or commands return errors.
"""
import json
import os
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import tinytuya

CRED_DIR = os.environ.get("CREDENTIALS_DIRECTORY", "")
VERSIONS = [3.3, 3.5, 3.4, 3.2, 3.1]


def cred(name, env):
    if CRED_DIR:
        p = os.path.join(CRED_DIR, name)
        if os.path.exists(p):
            with open(p) as f:
                return f.read().strip()
    return os.environ.get(env, "")


IP = cred("tuya_ip", "TUYA_IP") or "127.0.0.1"
DEV_ID = cred("tuya_device_id", "TUYA_DEV_ID")
KEY = cred("tuya_local_key", "TUYA_KEY")
DP = int(cred("tuya_dp", "TUYA_DP") or "1")
VER = float(cred("tuya_version", "TUYA_VERSION") or "3.3")
PORT = int(os.environ.get("TUYA_PORT", "8090"))

_lock = threading.Lock()
_dev = None  # (version, OutletDevice) of the last working protocol


def connect():
    """Try protocol versions until one answers; the wizard-written version
    is tried first, then a fallback sweep."""
    global _dev
    for v in [VER] + [x for x in VERSIONS if x != VER]:
        d = tinytuya.OutletDevice(DEV_ID, IP, KEY, version=v, persist=True)
        try:
            st = d.status()
            if not st.get("Error"):
                _dev = (v, d)
                print(f"connected with protocol {v}")
                return d
        except Exception:
            pass
    raise RuntimeError(
        "device unreachable: check IP/key, or the Tuya app holds the one local connection"
    )


def cmd(fn):
    """Serialize commands; drop and reconnect the socket on failure.
    Rapid commands can reboot some Tuya devices, so pace them."""
    global _dev
    with _lock:
        if _dev is None:
            connect()
        d = _dev[1]
        try:
            r = fn(d)
        except Exception:
            _dev = None
            raise
        time.sleep(0.5)
        if isinstance(r, dict) and r.get("Error"):
            _dev = None
            raise RuntimeError(r["Error"])
        return r


def status():
    st = cmd(lambda d: d.status())
    dps = st.get("dps", {})
    relay = dps.get(str(DP), dps.get(DP))
    return {"dps": dps, "dp": DP, "relay_on": bool(relay)}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            path = self.path.split("?", 1)[0]
            if path == "/status":
                body = status()
            elif path == "/on":
                body = cmd(lambda d: d.set_status(True, DP)) or {}
            elif path == "/off":
                body = cmd(lambda d: d.set_status(False, DP)) or {}
            elif path == "/toggle":
                body = cmd(lambda d: d.set_status(not status()["relay_on"], DP)) or {}
            else:
                self.send_response(404)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(b'{"error": "use /status /on /off /toggle"}')
                return
            raw = json.dumps({"ok": True, **body}).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(raw)
        except Exception as e:
            raw = json.dumps({"ok": False, "error": str(e)}).encode()
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(raw)

    def log_message(self, fmt, *args):
        print(f"{self.client_address[0]} {fmt % args}")


if __name__ == "__main__":
    # Sanity-check credentials at boot; surface failures in journald.
    if not (DEV_ID and KEY):
        raise SystemExit("tuya_device_id / tuya_local_key missing")
    try:
        print(f"probing {IP} (dp {DP}, protocol {VER})...")
        connect()
    except Exception as e:
        print(f"startup probe failed: {e}")
    print(f"listening on 0.0.0.0:{PORT}")
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
