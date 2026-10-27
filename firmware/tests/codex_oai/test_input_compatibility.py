"""Input 1.0.2 discovery-handshake requests against the real C HID engine."""
import json
import unittest

from firmware.tests.codex_oai.test_protocol import Harness


class InputCompatibilityTests(unittest.TestCase):
    def setUp(self):
        self.harness = Harness()
        self.addCleanup(self.harness.close)

    def request(self, method, request_id=998, params=None):
        result = self.harness.rpc(json.dumps({
            "method": method, "params": params, "id": request_id,
        }, separators=(",", ":")).encode())
        self.assertTrue(result.sent)
        for report in result.sent:
            self.assertEqual(len(report), 64)
            self.assertEqual(report[:2], bytes((6, 2)))
            self.assertLessEqual(report[2], 61)
            self.assertEqual(report[3 + report[2]:], bytes(61 - report[2]))
        payload = b"".join(report[3:3 + report[2]] for report in result.sent)
        self.assertTrue(payload.endswith(b"\r\n"))
        response = json.loads(payload)
        self.assertEqual(response["id"], request_id)
        return result, response

    def test_status_has_version_required_by_input_connection_handler(self):
        result, response = self.request("device.status")
        self.assertEqual(response["result"]["version"], "0.0.28-agentpad13")
        self.assertFalse(result.ready)  # Input must not enable OAI routing.

    def test_version_fallback_matches_status_for_all_input_id_widths(self):
        for request_id in (0, 9, 10, 99, 100, 998):
            _, version = self.request("sys.version", request_id)
            _, status = self.request("device.status", request_id)
            self.assertEqual(version, status)

    def test_shared_keymap_file_is_advertised(self):
        _, response = self.request("fs.list", params={"checksum": True})
        self.assertEqual(response["result"][0]["name"], "keymap.json")
        self.assertGreater(response["result"][0]["size"], 0)

    def test_unsupported_writes_and_bootloader_return_structured_errors(self):
        for method in ("fs.delete", "fs.txbegin", "fs.txcommit", "sys.bootloader"):
            result, response = self.request(method, params={"file": "keymap.json"})
            self.assertEqual(response["error"]["code"], -32601)
            self.assertIsInstance(response["error"]["message"], str)
            self.assertGreater(len(result.sent), 1)  # Covers response fragmentation.
            self.assertFalse(result.ready)
        self.assertEqual(self.harness.keymap_get().sent[0][3:18], b'{"result":{"l":')

    def test_input_probes_do_not_break_codex_handshake(self):
        self.request("device.status")
        self.request("fs.list")
        self.request("fs.write")
        self.assertFalse(self.harness.rpc(b'{"method":"v.oai.rgbcfg","params":{},"id":1}').ready)
        self.assertTrue(self.harness.thstatus([]).ready)
        self.assertTrue(self.harness.notify("AG00", True).sent)

    def test_input_requests_preserve_studio_maps_colors_leds_and_persistence(self):
        self.harness.keymap_set("f23456789abfcd1", request_id=701)
        self.harness.led_set(enabled=False, brightness=37, request_id=702)
        for layer in range(4):
            mapping = bytes([40 + layer] * 13 + [12 + layer, 34, 56]).hex()
            self.request("v.agentpad.cfg.set", 703, {"l": layer, "m": mapping})

        def studio_snapshot():
            return (
                self.harness.keymap_get(request_id=701).sent,
                self.harness.led_get(request_id=702).sent,
                [self.request("v.agentpad.cfg.get", 703, {"l": layer})[1]
                 for layer in range(4)],
            )

        before = studio_snapshot()
        for method in ("device.status", "sys.version", "fs.list", "fs.write", "fs.delete", "sys.bootloader"):
            self.request(method)
            self.assertEqual(studio_snapshot(), before)
        self.harness.reset()
        self.assertEqual(studio_snapshot(), before)

    def test_input_queries_preserve_active_codex_task_state(self):
        self.harness.rpc(b'{"method":"v.oai.rgbcfg","params":{},"id":1}')
        before = self.harness.thstatus([
            {"id": slot, "c": 0x123456 + slot, "e": 1, "b": 1, "s": 0.5}
            for slot in range(6)
        ])
        for method in ("device.status", "sys.version", "fs.list", "fs.write"):
            result, _ = self.request(method)
            self.assertTrue(result.ready)
            self.assertEqual(result.snapshot.slots, before.snapshot.slots)
            self.assertEqual(result.snapshot.revision, before.snapshot.revision)
            self.assertEqual(result.snapshot.handshake_revision, before.snapshot.handshake_revision)


if __name__ == "__main__":
    unittest.main()
