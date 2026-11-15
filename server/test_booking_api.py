"""Tes integrasi melalui HTTP nyata pada loopback, tanpa dependency tambahan."""

from datetime import date, timedelta
from http.client import HTTPConnection
import json
from pathlib import Path
from tempfile import TemporaryDirectory
from threading import Thread
import unittest

from booking_api import BookingApiServer, MAX_BODY_BYTES


class BookingApiTests(unittest.TestCase):
    def setUp(self):
        self.directory = TemporaryDirectory()
        self.database = Path(self.directory.name) / "bookings.sqlite3"
        self.start_server()

    def start_server(self):
        self.server = BookingApiServer(("127.0.0.1", 0), self.database)
        self.thread = Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def stop_server(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=5)

    def tearDown(self):
        self.stop_server()
        self.directory.cleanup()

    def request(self, method="GET", path="/bookings", payload=None, raw=None, headers=None):
        request_headers = {"Content-Type": "application/json"}
        request_headers.update(headers or {})
        body = raw if raw is not None else json.dumps(payload) if payload is not None else None
        connection = HTTPConnection("127.0.0.1", self.server.server_port, timeout=5)
        try:
            connection.request(method, path, body=body, headers=request_headers)
            response = connection.getresponse()
            contents = response.read()
            return response.status, dict(response.getheaders()), json.loads(contents) if contents else None
        finally:
            connection.close()

    def patch(self, booking_id, status):
        return self.request("PATCH", f"/bookings/{booking_id}", {"status": status})

    def test_list_returns_seeded_records_with_expected_contract(self):
        status, headers, body = self.request()
        self.assertEqual(status, 200)
        self.assertEqual(headers["Content-Type"], "application/json; charset=utf-8")
        self.assertEqual(headers["Access-Control-Allow-Origin"], "*")
        bookings = {record["id"]: record for record in body["data"]}
        self.assertEqual(len(bookings), 3)
        today = date.today()
        self.assertEqual(bookings["API-001"]["date"], today.isoformat())
        self.assertEqual(bookings["API-001"]["status"], "pending")
        self.assertEqual(bookings["API-002"]["date"], (today + timedelta(days=1)).isoformat())
        self.assertEqual(bookings["API-003"]["date"], (today - timedelta(days=1)).isoformat())
        self.assertEqual(
            set(bookings["API-001"]),
            {"id", "date", "hours", "customer_name", "customer_phone", "day_price", "night_price", "status"},
        )
        self.assertEqual(bookings["API-001"]["hours"], ["08:00"])
        self.assertEqual(bookings["API-001"]["customer_name"], "Budi")
        self.assertEqual(bookings["API-001"]["customer_phone"], "081234567801")
        self.assertEqual(bookings["API-002"]["hours"], ["19:00"])
        self.assertEqual(bookings["API-002"]["customer_name"], "Sinta")
        self.assertEqual(bookings["API-002"]["customer_phone"], "081234567802")
        self.assertEqual(bookings["API-003"]["hours"], ["09:00"])
        self.assertEqual(bookings["API-003"]["customer_name"], "Budi")
        self.assertEqual(bookings["API-003"]["customer_phone"], "081234567801")
        self.assertEqual(bookings["API-001"]["day_price"], 250000)
        self.assertEqual(bookings["API-001"]["night_price"], 350000)

    def test_confirm_pending_is_visible_on_following_get(self):
        status, _, body = self.patch("API-001", "confirmed")
        self.assertEqual(status, 200)
        self.assertEqual(body["data"]["status"], "confirmed")
        records = self.request()[2]["data"]
        self.assertEqual(next(record for record in records if record["id"] == "API-001")["status"], "confirmed")

    def test_can_cancel_pending_or_confirmed(self):
        for booking_id in ("API-001", "API-002"):
            with self.subTest(booking_id=booking_id):
                status, _, body = self.patch(booking_id, "cancelled")
                self.assertEqual(status, 200)
                self.assertEqual(body["data"]["status"], "cancelled")

    def test_repeated_confirmation_is_conflict(self):
        self.assertEqual(self.patch("API-002", "confirmed")[0], 409)

    def test_cancelled_booking_cannot_be_changed_again(self):
        self.assertEqual(self.patch("API-001", "cancelled")[0], 200)
        for status in ("confirmed", "cancelled"):
            with self.subTest(status=status):
                self.assertEqual(self.patch("API-001", status)[0], 409)

    def test_past_booking_cannot_be_changed(self):
        for status in ("confirmed", "cancelled"):
            with self.subTest(status=status):
                status_code, _, body = self.patch("API-003", status)
                self.assertEqual(status_code, 409)
                self.assertIn("lewat", body["message"])

    def test_unknown_booking_and_route_return_json_404(self):
        for result in (self.patch("missing", "confirmed"), self.request(path="/missing")):
            self.assertEqual(result[0], 404)
            self.assertIsInstance(result[2]["message"], str)

    def test_rejects_invalid_json_status_and_shape(self):
        for raw in ('{', '[]', '{"status":"pending"}', '{"status":null}', '{"status":[]}', '{}',
                    '{"status":"confirmed","id":"API-002"}'):
            with self.subTest(raw=raw):
                status, _, body = self.request("PATCH", "/bookings/API-001", raw=raw)
                self.assertEqual(status, 400)
                self.assertIsInstance(body["message"], str)

    def test_rejects_wrong_media_type_and_oversized_body(self):
        status, _, _ = self.request("PATCH", "/bookings/API-001", {"status": "confirmed"},
                                    headers={"Content-Type": "text/plain"})
        self.assertEqual(status, 415)
        status, _, body = self.request("PATCH", "/bookings/API-001", raw="x" * (MAX_BODY_BYTES + 1))
        self.assertEqual(status, 413)
        self.assertIsInstance(body["message"], str)

    def test_options_allows_browser_preflight(self):
        status, headers, body = self.request("OPTIONS", headers={"Origin": "http://localhost:5000"})
        self.assertEqual(status, 204)
        self.assertIsNone(body)
        self.assertIn("PATCH", headers["Access-Control-Allow-Methods"])
        self.assertIn("Content-Type", headers["Access-Control-Allow-Headers"])

    def test_status_and_seed_dates_survive_server_restart(self):
        self.patch("API-001", "confirmed")
        before_restart = self.request()[2]
        self.stop_server()
        self.start_server()
        self.assertEqual(self.request()[2], before_restart)


if __name__ == "__main__":
    unittest.main()
