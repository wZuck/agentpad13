"""Input file transfer, shared Studio state, rejection and restart contracts."""
import base64
import copy
import hashlib
import json
import re
import subprocess
import unittest
from pathlib import Path

from firmware.tests.codex_oai.test_protocol import Harness


class InputKeymapTests(unittest.TestCase):
    def setUp(self):
        self.harness = Harness()
        self.addCleanup(self.harness.close)

    def rpc(self, method, params=None, request_id=998):
        result = self.harness.rpc(json.dumps({"method": method, "params": params, "id": request_id}, separators=(",", ":")).encode())
        self.assertTrue(result.sent, method)
        payload = b"".join(frame[3:3 + frame[2]] for frame in result.sent)
        response = json.loads(payload)
        self.assertEqual(response["id"], request_id)
        return response

    def read(self):
        summary = self.rpc('fs.list', {'checksum': True})['result'][0]
        raw = bytearray()
        while len(raw) < summary['size']:
            result = self.rpc('fs.readbin', {'file': 'keymap.json', 'offset': len(raw), 'len': 3072})['result']
            self.assertEqual(result['total_size'], summary['size'])
            chunk = base64.b64decode(result['data'], validate=True)
            self.assertTrue(chunk)
            raw.extend(chunk)
        self.assertEqual(hashlib.sha1(raw).hexdigest(), summary['checksum'])
        return bytes(raw)

    def write(self, raw, chunk_size=3072):
        response = None
        for offset in range(0, len(raw), chunk_size):
            response = self.rpc('fs.writebin', {
                'file': 'keymap.json', 'data': base64.b64encode(raw[offset:offset + chunk_size]).decode(),
                'append': True, 'completed': offset + chunk_size >= len(raw), 'offset': offset,
            })
            if 'error' in response:
                break
        return response

    def layers(self):
        return [self.rpc('v.agentpad.cfg.get', {'l': layer})['result']['m'] for layer in range(4)]

    def test_initial_file_represents_all_existing_layers_and_codex_map(self):
        doc = json.loads(self.read())
        self.assertEqual(doc['activeProfileId'], 0)
        layers = doc['profiles'][0]['layers']
        self.assertEqual([layer['name'] for layer in layers], ['CODEX', 'FN', 'NAV', 'MEDIA'])
        self.assertEqual([len(row) for row in layers[0]['layout']['keymap']], [2, 4, 4, 3])
        self.assertEqual(layers[0]['layout']['keymap'][0], ['KV_OAI_AG00', 'KV_OAI_AG01'])
        self.assertEqual(layers[1]['layout']['keymap'][0][1], 'KC_F2')

    def test_input_write_updates_studio_reads_preserves_led_and_survives_reset(self):
        doc = json.loads(self.read())
        doc['profiles'][0]['name'] = '测试 AgentPad13'
        layers = doc['profiles'][0]['layers']
        layers[0]['layout']['keymap'][0][0] = 'KC_A'
        layers[1]['layout']['keymap'][0][1] = 'KC_LCTL'
        layers[2]['layout']['keymap'][0][0] = 'KV_OAI_AG03'
        layers[3]['layout']['keymap'][3][2] = 'KC_NONE'
        layers[2]['color'] = 0x123456
        self.harness.led_set(enabled=False, brightness=37)
        led = self.harness.led_get().sent
        oai = self.harness.keymap_get().sent
        raw = json.dumps(doc, separators=(',', ':'), ensure_ascii=True).encode()
        self.assertEqual(self.write(raw), {'result': True, 'id': 998})
        native = self.layers()
        self.assertEqual(native[0][:2], '2a')  # A = Studio action 42.
        self.assertEqual(native[1][2:4], '62')  # left control = 98.
        self.assertEqual(native[2][:2], '56')  # OAI REVIEW = 82 + 4.
        self.assertEqual(native[3][24:26], '52')  # explicit no-op.
        self.assertTrue(native[2].endswith('123456'))
        self.assertEqual(self.read(), raw)  # Exact Input checksum, including metadata.
        self.harness.reset()
        self.assertEqual(self.layers(), native)
        self.assertEqual(json.loads(self.read()), doc)
        self.assertEqual(self.harness.led_get().sent, led)
        self.assertEqual(self.harness.keymap_get().sent, oai)

    def test_studio_edit_invalidates_input_file_and_is_visible_after_restart(self):
        doc = json.loads(self.read())
        self.assertTrue(self.write(json.dumps(doc).encode())['result'])
        mapping = bytes([42] * 13 + [12, 34, 56]).hex()
        self.assertTrue(self.rpc('v.agentpad.cfg.set', {'l': 1, 'm': mapping})['result'])
        self.harness.keymap_set('423456789abecd1')
        self.harness.reset()
        reread = json.loads(self.read())['profiles'][0]['layers']
        self.assertEqual(reread[0]['layout']['keymap'][0][0], 'KV_OAI_AG03')
        self.assertEqual(reread[1]['layout']['keymap'][0], ['KC_A', 'KC_A'])
        self.assertEqual(reread[1]['color'], 0x0c2238)

    def test_multichunk_write_stages_until_complete_and_checks_exact_offsets(self):
        doc = json.loads(self.read())
        doc['comment'] = 'X' * 1750
        raw = json.dumps(doc, separators=(',', ':')).encode()
        self.assertGreater(len(raw), 3072)
        self.assertLessEqual(len(raw), 3584)
        before = self.layers()
        first = {'file': 'keymap.json', 'data': base64.b64encode(raw[:3072]).decode(), 'append': True, 'completed': False, 'offset': 0}
        self.assertTrue(self.rpc('fs.writebin', first)['result'])
        self.assertEqual(self.layers(), before)
        second = dict(first, offset=3073, completed=True, data=base64.b64encode(raw[3072:]).decode())
        self.assertIn('error', self.rpc('fs.writebin', second))
        self.assertEqual(self.layers(), before)
        self.assertTrue(self.write(raw)['result'])
        self.assertEqual(self.read(), raw)

    def test_rejected_document_does_not_replace_maps_or_previous_file(self):
        original = self.read()
        before = self.layers()
        doc = json.loads(original)
        invalid = []
        for key in ('KA_A1', 'KI_LS5', 'UNKNOWN', 'KV_OAI_ENC_CLK'):
            item = copy.deepcopy(doc)
            item['profiles'][0]['layers'][0]['layout']['keymap'][0][0] = key
            invalid.append(item)
        item = copy.deepcopy(doc); item['profiles'].append(copy.deepcopy(item['profiles'][0])); invalid.append(item)
        item = copy.deepcopy(doc); item['profiles'][0]['layers'][0]['layout']['encoders'][0][0]='KC_A'; invalid.append(item)
        item = copy.deepcopy(doc); item['macros']=[{'id': 1}]; invalid.append(item)
        item = copy.deepcopy(doc); item['profiles'][0]['layers'][0]['layout']['joystick']['sectors']=[{'k':'KC_A'}]; invalid.append(item)
        for item in invalid:
            self.assertIn('error', self.write(json.dumps(item, separators=(',', ':')).encode()))
            self.assertEqual(self.layers(), before)
            self.assertEqual(self.read(), original)

    def test_invalid_base64_oversize_and_interrupted_write_leave_config_intact(self):
        before = self.read()
        for data in ('AA=A', 'A===', '####', 'AAA', 'AB==', base64.b64encode(b'X' * 3585).decode()):
            # App's maximum wire chunk is 4096 chars; a larger frame is rejected
            # by the RX boundary without publishing anything.
            if len(data)>4096: continue
            response = self.rpc('fs.writebin', {'file':'keymap.json','data':data,'offset':0,'append':True,'completed':True})
            self.assertIn('error', response)
            self.assertEqual(self.read(), before)
        partial = base64.b64encode(before[:100]).decode()
        self.rpc('fs.writebin', {'file':'keymap.json','data':partial,'offset':0,'append':True,'completed':False})
        self.harness.reset()
        self.assertIn('error', self.rpc('fs.writebin', {'file':'keymap.json','data':partial,'offset':100,'append':True,'completed':True}))
        self.assertEqual(self.read(), before)

    def test_studio_write_during_staging_rejects_stale_input_commit(self):
        raw = self.read()
        split = 100
        self.rpc('fs.writebin', {'file':'keymap.json','data':base64.b64encode(raw[:split]).decode(),'offset':0,'append':True,'completed':False})
        self.rpc('v.agentpad.cfg.set', {'l':1,'m': '2a'*13+'123456'})
        before = self.layers()
        self.assertIn('error', self.rpc('fs.writebin', {'file':'keymap.json','data':base64.b64encode(raw[split:]).decode(),'offset':split,'append':True,'completed':True}))
        self.assertEqual(self.layers(), before)

    def test_failed_flash_write_preserves_the_previous_document_and_studio_maps(self):
        raw = self.read()
        doc = json.loads(raw)
        doc['profiles'][0]['layers'][0]['layout']['keymap'][0][0] = 'KC_A'
        before = self.layers()
        self.harness._command('FAILWRITE')
        self.assertIn('error', self.write(json.dumps(doc).encode()))
        self.assertEqual(self.layers(), before)
        self.assertEqual(self.read(), raw)
        self.harness.reset()
        self.assertEqual(self.layers(), before)

    def test_legacy_studio_records_migrate_without_changing_layout(self):
        self.harness._command('LEGACY_PAD')
        self.harness.reset()
        before = self.layers()
        self.assertEqual(before[0][:26], '2a' * 13)
        doc = json.loads(self.read())
        doc['profiles'][0]['layers'][1]['layout']['keymap'][0][0] = 'KC_F13'
        self.assertTrue(self.write(json.dumps(doc).encode())['result'])
        self.harness.reset()
        self.assertEqual(self.layers()[0], before[0])
        self.assertNotEqual(self.layers()[1], before[1])
        self.harness._command('CORRUPT_INPUT')
        self.harness.reset()
        self.assertEqual(self.layers(), before)

    def test_oversized_document_is_rejected_before_publication(self):
        before = self.read()
        doc = json.loads(before)
        doc['comment'] = 'X' * 17000
        raw = json.dumps(doc).encode()
        self.assertGreater(len(raw), 16384)
        self.assertIn('error', self.write(raw))
        self.assertEqual(self.read(), before)

    def test_installed_input_models_can_edit_and_serialize_the_firmware_file(self):
        app = Path('/Applications/input.app/Contents/Resources/app.asar')
        if not app.is_file():
            self.skipTest('Input 1.0.2 is not installed')
        root = Path(__file__).resolve().parent
        result = subprocess.run(['node', str(root/'input_app_roundtrip.cjs'), str(app)],
                                input=json.dumps(self.add_layers(json.loads(self.read()), 16)).encode(), capture_output=True, check=True)
        self.assertTrue(self.write(result.stdout)['result'])
        self.assertEqual(self.layers()[0][:2], '2a')
        self.assertEqual(self.read(), result.stdout)
        self.assertEqual(self.rpc('v.agentpad.cfg.info', {})['result']['n'],16)

    def add_layers(self, doc, count):
        layers = doc['profiles'][0]['layers']
        while len(layers) < count:
            index = len(layers)
            layer = copy.deepcopy(layers[0])
            layer.update(id=index, name=f'Layer {index + 1}', color=0x123400 + index, os=1)
            layer['layout']['keymap'] = [['KC_NONE'] * width for width in (2,4,4,3)]
            layer['layout']['keymap'][0][0] = f'KC_F{index + 1}'
            # Input's blank-layer defaults, distinct from existing OAI rows.
            layer['layout']['encoders'] = [['KC_NONE'] * 3]
            layer['layout']['joystick'] = {'type':'RADIAL','sectors':[
                {'k':'KI_X','a1':0.1875,'a2':0.3125}, {'k':'KC_NONE','a1':0.3125,'a2':0.1875}]}
            layers.append(layer)
        return doc

    def test_fifth_and_sixteenth_layers_save_and_survive_restart(self):
        for count in (5, 6, 12, 16):
            doc = self.add_layers(json.loads(self.read()), count)
            doc['profiles'][0]['layers'][-1]['name'] = '新层 ' + str(count)
            raw = json.dumps(doc, separators=(',', ':')).encode()
            self.assertTrue(self.write(raw)['result'])
            self.assertEqual(self.read(), raw)
            self.assertEqual(self.rpc('v.agentpad.cfg.info', {})['result'], {'n':count, 'max':16})
            original = self.layers()
            last = self.rpc('v.agentpad.cfg.get', {'l':count-1})['result']['m']
            self.harness.reset()
            restored = json.loads(self.read())['profiles'][0]['layers']
            self.assertEqual(len(restored), count)
            self.assertEqual(restored[-1]['name'], '新层 ' + str(count))
            self.assertEqual(restored[-1]['layout']['keymap'][0][0], f'KC_F{count}')
            self.assertEqual(restored[-1]['os'], 1)
            self.assertEqual(self.layers(), original)
            self.assertEqual(self.rpc('v.agentpad.cfg.get', {'l':count-1})['result']['m'], last)

    def test_studio_can_resize_and_edit_the_new_layers_without_losing_the_first_four(self):
        before = self.layers()
        self.assertEqual(self.rpc('v.agentpad.cfg.info', {'n':8})['result']['n'], 8)
        self.assertEqual(self.layers(), before)
        self.assertTrue(self.rpc('v.agentpad.cfg.set', {'l':7, 'm':'2a'*13+'123456'})['result'])
        self.harness.reset()
        doc = json.loads(self.read())
        self.assertEqual(len(doc['profiles'][0]['layers']),8)
        self.assertEqual(doc['profiles'][0]['layers'][7]['layout']['keymap'][0][0], 'KC_A')
        self.assertEqual(self.rpc('v.agentpad.cfg.info', {'n':4})['result']['n'],4)
        self.assertEqual(self.layers(),before)
        for count in (0,3,17):
            self.assertIn('error',self.rpc('v.agentpad.cfg.info',{'n':count}))

    def test_layer_limit_and_duplicate_ids_are_rejected_atomically(self):
        before = self.read()
        doc = self.add_layers(json.loads(before),17)
        self.assertIn('error',self.write(json.dumps(doc).encode()))
        self.assertEqual(self.read(),before)
        doc = self.add_layers(json.loads(before),5)
        doc['profiles'][0]['layers'][-1]['id']=0
        self.assertIn('error',self.write(json.dumps(doc).encode()))
        self.assertEqual(self.read(),before)

    def test_layer_switch_keys_reference_configured_layers(self):
        doc = self.add_layers(json.loads(self.read()),6)
        doc['profiles'][0]['layers'][0]['layout']['keymap'][0]=['KI_LS5','KI_LM6']
        self.assertTrue(self.write(json.dumps(doc).encode())['result'])
        self.assertEqual(self.layers()[0][:4], '8c9d')
        doc['profiles'][0]['layers'][0]['layout']['keymap'][0][0]='KI_LS16'
        self.assertIn('error',self.write(json.dumps(doc).encode()))

    def test_native_catalog_matches_studio_ids_and_wire_names(self):
        root = Path(__file__).resolve().parents[3]
        firmware = (root/'firmware/loudest_micro/keymaps/codex_oai/native_actions.def').read_text()
        swift = (root/'macos/Sources/AgentPadCore/LayerConfiguration.swift').read_text()
        fw = re.findall(r'PAD_ACTION\((\d+), "([^"]+)"', firmware)
        ui = re.findall(r'\.init\(id: (\d+), title: "[^"]+", wire: "([^"]+)"\)', swift)
        self.assertEqual(fw, ui)


if __name__ == '__main__':
    unittest.main()
