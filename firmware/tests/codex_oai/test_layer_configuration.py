"""Persistent four-layer configuration over the real C RPC and LED renderer."""
import json
import unittest
from firmware.tests.codex_oai.test_protocol import Harness
from firmware.tests.codex_oai.test_leds import Harness as LEDHarness


class LayerConfigurationTest(unittest.TestCase):
    def setUp(self):
        self.harness = Harness()

    def tearDown(self):
        self.harness.close()

    def rpc(self, method, params):
        result = self.harness.rpc(json.dumps({'method': method, 'params': params, 'id': 701}).encode())
        payload = b''.join(frame[3:3 + frame[2]] for frame in result.sent)
        return json.loads(payload)

    def test_all_layers_persist_independently_and_preserve_codex_and_led(self):
        before = self.harness.keymap_get().sent
        maps = []
        for layer in range(4):
            original = self.rpc('v.agentpad.cfg.get', {'l': layer})['result']
            self.assertEqual(original['l'], layer)
            self.assertEqual(len(original['m']), 32)
            mapping = bytes([40 + layer] * 13 + [layer * 40, 100, 255]).hex()
            maps.append(mapping)
            self.assertTrue(self.rpc('v.agentpad.cfg.set', {'l': layer, 'm': mapping})['result'])
        self.harness.reset()
        for layer, mapping in enumerate(maps):
            self.assertEqual(self.rpc('v.agentpad.cfg.get', {'l': layer})['result']['m'], mapping)
        self.assertEqual(self.harness.keymap_get().sent, before)
        self.assertIn(b'"brightness":100', self.harness.led_get().sent[0])

    def test_invalid_data_and_layers_do_not_mutate_any_layer(self):
        before = [self.rpc('v.agentpad.cfg.get', {'l': l}) for l in range(4)]
        for params in [{'l': 4}, {'l': -1}, {'l': 1, 'm': 'ff' * 16}, {'l': 1, 'm': '0' * 31},
                       {'l': 2, 'm': 'zz' * 16}, {'l': 0, 'm': '00' * 16, 'extra': 1}]:
            method = 'v.agentpad.cfg.set' if 'm' in params else 'v.agentpad.cfg.get'
            self.assertIn('error', self.rpc(method, params))
        self.assertEqual([self.rpc('v.agentpad.cfg.get', {'l': l}) for l in range(4)], before)

    def test_custom_indicator_tracks_layer_and_black_disables_it(self):
        led = LEDHarness()
        try:
            led.command('COLOR 0 12 34 56')
            led.command('COLOR 1 0 0 0')
            led.layer(0, 0)
            self.assertEqual(led.render(100)[13], (12, 34, 56))
            led.layer(1, 100)
            self.assertEqual(led.render(200)[13], (0, 0, 0))
            led.layer(0, 200)
            self.assertEqual(led.render(300)[13], (12, 34, 56))
        finally:
            led.close()
