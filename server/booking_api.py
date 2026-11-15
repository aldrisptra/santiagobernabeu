"""API booking lokal untuk demonstrasi aplikasi Flutter (Python 3.10+)."""

import argparse
from contextlib import closing
from datetime import date, timedelta
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import sqlite3
from urllib.parse import unquote, urlsplit


MAX_BODY_BYTES = 16 * 1024
DEFAULT_DATABASE = Path(__file__).resolve().parent / "data" / "bookings.sqlite3"


class ApiError(Exception):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status
        self.message = message


class BookingStore:
    """Satu koneksi per operasi agar aman dipakai oleh HTTP worker threads."""

    def __init__(self, database):
        self.database = Path(database).resolve()
        self.database.parent.mkdir(parents=True, exist_ok=True)
        self._initialize()

    def _connect(self):
        connection = sqlite3.connect(self.database, timeout=10)
        connection.row_factory = sqlite3.Row
        return connection

    def _initialize(self):
        with closing(self._connect()) as connection, connection:
            connection.execute(
                """CREATE TABLE IF NOT EXISTS bookings (
                    id TEXT PRIMARY KEY,
                    date TEXT NOT NULL,
                    hours TEXT NOT NULL,
                    customer_name TEXT NOT NULL,
                    customer_phone TEXT NOT NULL,
                    day_price INTEGER NOT NULL,
                    night_price INTEGER NOT NULL,
                    status TEXT NOT NULL
                        CHECK (status IN ('pending', 'confirmed', 'cancelled'))
                )"""
            )
            if connection.execute("SELECT COUNT(*) FROM bookings").fetchone()[0]:
                return
            today = date.today()
            samples = [
                ("API-001", today, ["08:00"], "Budi", "081234567801", "pending"),
                ("API-002", today + timedelta(days=1), ["19:00"], "Sinta", "081234567802", "confirmed"),
                ("API-003", today - timedelta(days=1), ["09:00"], "Budi", "081234567801", "confirmed"),
            ]
            connection.executemany(
                "INSERT INTO bookings VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                [
                    (booking_id, day.isoformat(), json.dumps(hours), name, phone, 250000, 350000, status)
                    for booking_id, day, hours, name, phone, status in samples
                ],
            )

    @staticmethod
    def _record(row):
        record = dict(row)
        record["hours"] = json.loads(record["hours"])
        return record

    def list_bookings(self):
        with closing(self._connect()) as connection:
            rows = connection.execute("SELECT * FROM bookings ORDER BY date DESC, id").fetchall()
        return [self._record(row) for row in rows]

    def update_status(self, booking_id, status):
        with closing(self._connect()) as connection, connection:
            # Lock before reading so concurrent requests cannot validate stale status.
            connection.execute("BEGIN IMMEDIATE")
            row = connection.execute("SELECT * FROM bookings WHERE id = ?", (booking_id,)).fetchone()
            if row is None:
                raise ApiError(HTTPStatus.NOT_FOUND, "Booking tidak ditemukan.")
            if date.fromisoformat(row["date"]) < date.today():
                raise ApiError(HTTPStatus.CONFLICT, "Booking yang sudah lewat tidak dapat diubah.")
            allowed = ("pending",) if status == "confirmed" else ("pending", "confirmed")
            if row["status"] not in allowed:
                raise ApiError(HTTPStatus.CONFLICT, "Status booking tidak mengizinkan perubahan tersebut.")
            connection.execute("UPDATE bookings SET status = ? WHERE id = ?", (status, booking_id))
            record = self._record(row)
            record["status"] = status
            return record


class BookingApiServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address, database):
        self.store = BookingStore(database)
        super().__init__(address, BookingHandler)


class BookingHandler(BaseHTTPRequestHandler):
    server_version = "BookingDemo/1.0"

    def _json(self, status, payload=None):
        body = b"" if payload is None else json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, PATCH, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Accept")
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        if body and self.command != "HEAD":
            self.wfile.write(body)

    def send_error(self, code, message=None, explain=None):
        self._json(code, {"message": message or HTTPStatus(code).phrase})

    def _handle(self, action):
        try:
            action()
        except ApiError as error:
            self._json(error.status, {"message": error.message})
        except (sqlite3.Error, ValueError) as error:
            self.log_error("Kesalahan server: %s", error)
            self._json(HTTPStatus.INTERNAL_SERVER_ERROR, {"message": "Terjadi kesalahan pada server."})

    def do_GET(self):
        def action():
            if urlsplit(self.path).path != "/bookings":
                raise ApiError(HTTPStatus.NOT_FOUND, "Endpoint tidak ditemukan.")
            self._json(HTTPStatus.OK, {"data": self.server.store.list_bookings()})

        self._handle(action)

    def _read_json(self):
        if self.headers.get("Transfer-Encoding"):
            raise ApiError(HTTPStatus.BAD_REQUEST, "Gunakan Content-Length untuk mengirim JSON.")
        try:
            length = int(self.headers.get("Content-Length", ""))
        except ValueError:
            raise ApiError(HTTPStatus.BAD_REQUEST, "Content-Length harus berupa angka.") from None
        if length < 0:
            raise ApiError(HTTPStatus.BAD_REQUEST, "Content-Length tidak valid.")
        if length > MAX_BODY_BYTES:
            raise ApiError(HTTPStatus.REQUEST_ENTITY_TOO_LARGE, "Body request terlalu besar (maksimal 16 KiB).")
        if self.headers.get_content_type() != "application/json":
            raise ApiError(HTTPStatus.UNSUPPORTED_MEDIA_TYPE, "Gunakan Content-Type: application/json.")
        try:
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            raise ApiError(HTTPStatus.BAD_REQUEST, "Body harus berupa JSON yang valid.") from None
        if not isinstance(payload, dict) or set(payload) != {"status"}:
            raise ApiError(HTTPStatus.BAD_REQUEST, 'Body harus berisi satu field: "status".')
        if payload["status"] not in ("confirmed", "cancelled"):
            raise ApiError(HTTPStatus.BAD_REQUEST, 'Status harus "confirmed" atau "cancelled".')
        return payload

    def do_PATCH(self):
        def action():
            parts = urlsplit(self.path).path.strip("/").split("/")
            if len(parts) != 2 or parts[0] != "bookings" or not parts[1]:
                raise ApiError(HTTPStatus.NOT_FOUND, "Endpoint tidak ditemukan.")
            payload = self._read_json()
            booking = self.server.store.update_status(unquote(parts[1]), payload["status"])
            self._json(HTTPStatus.OK, {"data": booking})

        self._handle(action)

    def do_OPTIONS(self):
        self._json(HTTPStatus.NO_CONTENT)


def main():
    parser = argparse.ArgumentParser(description="API demo booking untuk Flutter, tanpa dependency tambahan.")
    parser.add_argument("--host", default="0.0.0.0", help="Alamat bind (default: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=8000, help="Port HTTP (default: 8000)")
    parser.add_argument("--database", type=Path, default=DEFAULT_DATABASE, help="Lokasi file SQLite")
    args = parser.parse_args()
    with BookingApiServer((args.host, args.port), args.database) as server:
        print(f"Booking API berjalan di http://{args.host}:{server.server_port}/bookings", flush=True)
        print(f"Database: {server.store.database}", flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\nServer dihentikan.")


if __name__ == "__main__":
    main()
