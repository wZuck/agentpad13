// Direct OAI UF2 smoke test on rp2040js.
//
// This runner deliberately owns a separate USB host fixture from runner.cjs:
// default and Vial keep their historical 32-byte status protocol unchanged.
// It exercises the 64-byte, report-ID-6 OAI endpoint used by the codex_oai
// keymap and writes only emulator evidence (never a physical device).
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const {
  Simulator,
  ConsoleLogger,
  LogLevel,
  DescriptorType,
  createSetupPacket,
  getDescriptorPacket,
  setDeviceAddressPacket,
  setDeviceConfigurationPacket,
  DataDirection,
  SetupType,
  SetupRecipient,
} = require('rp2040js');
const { bootromB1 } = require('./bootrom.cjs');

const UF2_MAGIC0 = 0x0a324655;
const UF2_MAGIC1 = 0x9e5d5157;
const FLASH_START = 0x10000000;
const OAI_REPORT_ID = 6;
const OAI_REPORT_BYTES = 64;
const OAI_USAGE_PAGE = 0xff00;
const OAI_USAGE = 0x0061;

function usageHex(value, width) {
  return value.toString(16).padStart(width, '0');
}

function oaiReport(json) {
  const payload = Buffer.from(json, 'utf8');
  if (payload.length > 61) throw new Error('single-frame fixture too large');
  const report = Buffer.alloc(64);
  report[0] = 6;
  report[1] = 2;
  report[2] = payload.length;
  payload.copy(report, 3);
  return report;
}

function oaiReports(json) {
  const payload = Buffer.from(json, 'utf8');
  if (payload.length === 0) return [oaiReport('')];
  const reports = [];
  for (let offset = 0; offset < payload.length; offset += 61) {
    reports.push(oaiReport(payload.subarray(offset, offset + 61).toString('utf8')));
  }
  return reports;
}

function loadUF2(filename, rp2040) {
  const data = fs.readFileSync(filename);
  let blocks = 0;
  for (let off = 0; off + 512 <= data.length; off += 512) {
    if (data.readUInt32LE(off) !== UF2_MAGIC0 || data.readUInt32LE(off + 4) !== UF2_MAGIC1) continue;
    const target = data.readUInt32LE(off + 12);
    const size = data.readUInt32LE(off + 16);
    rp2040.flash.set(data.subarray(off + 32, off + 32 + size), target - FLASH_START);
    blocks++;
  }
  if (!blocks) throw new Error(`no UF2 blocks found in ${filename}`);
  return blocks;
}

function parseArguments(argv) {
  const [uf2Path, ...rest] = argv;
  if (!uf2Path || rest.length !== 2 || rest[0] !== '--json' || !rest[1]) {
    throw new Error('usage: node oai_runner.cjs <uf2-file> --json <evidence-file>');
  }
  return { uf2Path, evidencePath: rest[1] };
}

function parseConfig(desc) {
  const interfaces = [];
  let current = null;
  for (let offset = 0; offset + 2 <= desc.length;) {
    const length = desc[offset];
    const type = desc[offset + 1];
    if (length < 2 || offset + length > desc.length) break;
    if (type === DescriptorType.Interface && length === 9) {
      current = {
        number: desc[offset + 2], cls: desc[offset + 5], sub: desc[offset + 6],
        proto: desc[offset + 7], inEp: -1, outEp: -1, inBytes: 0, outBytes: 0,
        reportBytes: 0,
      };
      interfaces.push(current);
    } else if (type === 0x21 && length >= 9 && current) {
      // HID descriptor: the first subordinate descriptor is the report one.
      if (desc[offset + 6] === 0x22) current.reportBytes = desc[offset + 7] | (desc[offset + 8] << 8);
    } else if (type === DescriptorType.Endpoint && length === 7 && current) {
      const address = desc[offset + 2];
      const bytes = desc[offset + 4] | (desc[offset + 5] << 8);
      if (address & 0x80) {
        current.inEp = address & 0x0f;
        current.inBytes = bytes;
      } else {
        current.outEp = address & 0x0f;
        current.outBytes = bytes;
      }
    }
    offset += length;
  }
  return interfaces;
}

function vendorHid(interfaces) {
  return interfaces.find((iface) =>
    iface.cls === 3 && iface.proto === 0 && iface.inEp >= 0 && iface.outEp >= 0 &&
    iface.inBytes === OAI_REPORT_BYTES && iface.outBytes === OAI_REPORT_BYTES
  );
}

function vendorHidInput(interfaces) {
  return interfaces.find((iface) =>
    iface.cls === 3 && iface.proto === 0 && iface.inEp >= 0 &&
    iface.inBytes === OAI_REPORT_BYTES
  );
}

function recoverTruncatedRawOut(interfaces, complete) {
  if (complete) return;
  const rawInput = vendorHidInput(interfaces);
  if (rawInput && rawInput.outEp < 0) {
    rawInput.outEp = rawInput.inEp + 1;
    rawInput.outBytes = OAI_REPORT_BYTES;
  }
}

function keyboardHid(interfaces) {
  return interfaces.find((iface) =>
    iface.cls === 3 && iface.sub === 1 && iface.proto === 1 &&
    iface.inEp >= 0 && iface.inBytes > 0
  );
}

function readOaiFrame(frame) {
  if (frame.length !== OAI_REPORT_BYTES || frame[0] !== OAI_REPORT_ID || frame[1] !== 2 || frame[2] > 61) return null;
  return frame.subarray(3, 3 + frame[2]).toString('utf8');
}

function requireAck(frames, expected) {
  return frames.map(readOaiFrame).filter(Boolean).join('').includes(expected);
}

function reportDescriptorMatches(report) {
  // Raw HID's compact descriptor identifies its vendor collection with these
  // little-endian Usage Page / Usage items.  Report ID and 64-byte IN/OUT
  // counts are asserted separately, so this remains robust to item ordering.
  const hasPage = report.some((_, index) => index + 2 < report.length && report[index] === 0x06 && report[index + 1] === 0x00 && report[index + 2] === 0xff);
  const hasUsage = report.some((_, index) =>
    (index + 1 < report.length && report[index] === 0x09 && report[index + 1] === OAI_USAGE) ||
    (index + 2 < report.length && report[index] === 0x0a && report[index + 1] === OAI_USAGE && report[index + 2] === 0x00)
  );
  const hasReportId = report.some((_, index) => report[index] === 0x85 && report[index + 1] === OAI_REPORT_ID);
  // QMK describes 63 payload bytes when a report-ID byte is enabled. The
  // descriptor plus the endpoint's 64-byte max packet proves the full frame.
  const hasPayload = report.some((_, index) => report[index] === 0x95 && report[index + 1] === OAI_REPORT_BYTES - 1);
  return hasPage && hasUsage && hasReportId && hasPayload;
}

function main() {
  const { uf2Path, evidencePath } = parseArguments(process.argv.slice(2));
  if (!fs.existsSync(uf2Path)) throw new Error(`pre-hardware build gate: OAI UF2 is unavailable: ${uf2Path}`);

  const uf2Data = fs.readFileSync(uf2Path);
  const uf2Sha256 = crypto.createHash('sha256').update(uf2Data).digest('hex');

  const sim = new Simulator();
  const mcu = sim.rp2040;
  mcu.loadBootrom(bootromB1);
  mcu.logger = new ConsoleLogger(LogLevel.Error);
  const blocks = loadUF2(uf2Path, mcu);

  // The QMK ADC and WS2812 paths need these rp2040js-only silicon shims. They
  // are identical in scope to runner.cjs and do not affect firmware bytes.
  {
    const adc = mcu.adc;
    const originalRead = adc.readUint32.bind(adc);
    adc.readUint32 = (offset) => {
      const value = originalRead(offset);
      if (offset === 0x0c) adc.checkInterrupts();
      return value;
    };
    // Match real silicon: START_ONCE self-clears after each conversion.
    // Without this rp2040js leaves axis conversions one sample behind.
    const originalWrite = adc.writeUint32.bind(adc);
    adc.writeUint32 = (offset, value) => {
      originalWrite(offset, value);
      if (offset === 0x00) adc.cs &= ~(1 << 2);
    };
    adc.channelValues[0] = 2048;
    adc.channelValues[1] = 2048;
  }
  {
    const dma = mcu.dma;
    const originalRead = dma.readUint32.bind(dma);
    dma.readUint32 = (offset) => (offset === 0x444 ? 0 : originalRead(offset));
  }
  for (const pin of [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]) mcu.gpio[pin].setInputValue(true);

  let gp17Edges = 0;
  mcu.gpio[17].addListener(() => gp17Edges++);

  const usb = mcu.usbCtrl;
  let resetSeen = false;
  let configured = false;
  let enumState = 'address';
  let ep0Activity = 0;
  let configLength = 0;
  const configBytes = [];
  let interfaces = [];
  let deviceDescriptor = Buffer.alloc(0);
  const rawFrames = [];
  const keyboardFrames = [];
  const rawTxQueue = [];
  const armedReads = new Map();
  let reportDescriptor = Buffer.alloc(0);
  let reportDescriptorRequested = false;
  let reportDescriptorDone = false;
  const eventLog = [];

  const log = (message) => eventLog.push(`[${(sim.clock.micros / 1000).toFixed(1)}ms] ${message}`);
  const rawInterface = () => vendorHid(interfaces);
  const rawFrame = (frame) => Buffer.from(frame);

  usb.onUSBEnabled = () => {
    log('USB controller enabled');
    usb.resetDevice();
  };
  usb.onResetReceived = () => {
    resetSeen = true;
    log('USB reset');
  };
  usb.onEndpointWrite = (endpoint, buffer) => {
    const bytes = Buffer.from(buffer);
    if (endpoint === 0) {
      ep0Activity++;
      if (bytes.length === 0) {
        if (enumState === 'address') {
          enumState = 'device';
          usb.sendSetupPacket(getDescriptorPacket(DescriptorType.Device, 18));
        } else if (enumState === 'set-configuration') {
          configured = true;
          enumState = 'configured';
          interfaces = parseConfig(Buffer.from(configBytes));
          recoverTruncatedRawOut(interfaces, configBytes.length >= configLength);
        }
        return;
      }
      if (enumState === 'device' && bytes[1] === DescriptorType.Device) {
        deviceDescriptor = bytes;
        enumState = 'config-header';
        usb.sendSetupPacket(getDescriptorPacket(DescriptorType.Configration, 9));
      } else if (enumState === 'config-header' && bytes.length === 9 && bytes[1] === DescriptorType.Configration) {
        configLength = bytes[2] | (bytes[3] << 8);
        enumState = 'config';
        usb.sendSetupPacket(getDescriptorPacket(DescriptorType.Configration, configLength));
      } else if (enumState === 'config') {
        configBytes.push(...bytes);
        interfaces = parseConfig(Buffer.from(configBytes));
        const rawInput = vendorHidInput(interfaces);
        // rp2040js currently truncates a multi-packet control-IN transfer at
        // its first packet. The first packet contains the raw HID interface
        // and IN endpoint but not the immediately following OUT endpoint.
        // QMK's fixed endpoint allocator places RAW_OUT directly after
        // RAW_IN, so recover only that parser state for the emulator smoke;
        // the physical descriptor is still checked separately below.
        if (configBytes.length >= configLength || (keyboardHid(interfaces) && rawInput)) {
          recoverTruncatedRawOut(interfaces, configBytes.length >= configLength);
          enumState = 'set-configuration';
          usb.sendSetupPacket(setDeviceConfigurationPacket(1));
        }
      } else if (enumState === 'report-descriptor') {
        reportDescriptor = Buffer.from(bytes);
        reportDescriptorDone = true;
        enumState = 'configured';
      }
      return;
    }
    const raw = rawInterface();
    const keyboard = keyboardHid(interfaces);
    if (keyboard && endpoint === keyboard.inEp) keyboardFrames.push(bytes);
    if (raw && endpoint === raw.inEp) {
      rawFrames.push(rawFrame(bytes));
      log(`raw IN ${bytes.length}B`);
    }
  };
  usb.onEndpointRead = (endpoint, byteCount) => {
    const raw = rawInterface();
    if (raw && endpoint === raw.outEp && rawTxQueue.length) {
      usb.endpointReadDone(endpoint, rawTxQueue.shift());
    } else {
      armedReads.set(endpoint, byteCount);
    }
  };
  function sendRaw(frame) {
    const raw = rawInterface();
    if (!raw) throw new Error('OAI raw interface was not enumerated');
    if (frame.length !== OAI_REPORT_BYTES) throw new Error(`OAI frame must be ${OAI_REPORT_BYTES} bytes`);
    if (armedReads.has(raw.outEp)) {
      armedReads.delete(raw.outEp);
      usb.endpointReadDone(raw.outEp, frame);
    } else {
      rawTxQueue.push(frame);
    }
  }

  const cycleNanos = 1e9 / 125000000;
  const wallStart = Date.now();
  let pioTick = 0;
  function runForMicros(micros) {
    const target = sim.clock.nanos + micros * 1000;
    let stallGuard = 0;
    while (sim.clock.nanos < target) {
      if (Date.now() - wallStart > 25 * 60 * 1000) throw new Error('emulator wall-clock budget exceeded');
      const before = sim.clock.nanos;
      if (mcu.core.waiting) sim.clock.tick(Math.min(sim.clock.nanosToNextAlarm, target - sim.clock.nanos));
      else sim.clock.tick(mcu.core.executeInstruction() * cycleNanos);
      if ((++pioTick & 3) === 0) {
        if (!mcu.pio[0].stopped) mcu.pio[0].step();
        if (!mcu.pio[1].stopped) mcu.pio[1].step();
      }
      if (sim.clock.nanos === before) {
        if (++stallGuard > 1e7) throw new Error(`simulation stalled at PC=0x${mcu.core.PC.toString(16)}`);
      } else stallGuard = 0;
    }
  }

  mcu.core.PC = 0x10000000;
  let addressAttempts = 0;
  let lastActivity = 0;
  for (let attempt = 0; attempt < 80 && !configured; attempt++) {
    runForMicros(100000);
    if (resetSeen && enumState === 'address' && ep0Activity === 0 && addressAttempts < 5) {
      addressAttempts++;
      usb.sendSetupPacket(setDeviceAddressPacket(1));
    } else if (ep0Activity > 0 && ep0Activity === lastActivity && attempt % 5 === 4) {
      if (enumState === 'device') usb.sendSetupPacket(getDescriptorPacket(DescriptorType.Device, 18));
      else if (enumState === 'config-header') usb.sendSetupPacket(getDescriptorPacket(DescriptorType.Configration, 9));
      else if (enumState === 'config') {
        configBytes.length = 0;
        usb.sendSetupPacket(getDescriptorPacket(DescriptorType.Configration, configLength));
      } else if (enumState === 'set-configuration') usb.sendSetupPacket(setDeviceConfigurationPacket(1));
    }
    lastActivity = ep0Activity;
  }
  if (!configured) throw new Error(`USB enumeration did not complete (state=${enumState})`);

  // QMK begins output scheduling after USB configuration. Match runner.cjs's
  // DREQ workaround so GP17 activity can be observed deterministically.
  for (const dreq of [0, 1, 2, 3, 8, 9, 10, 11]) mcu.dma.setDREQ(dreq);
  for (const channel of mcu.dma.channels) {
    const originalStart = channel.start.bind(channel);
    channel.start = () => {
      originalStart();
      if (channel.active && mcu.dma.dreq[channel.treq]) channel.scheduleTransfer();
    };
  }

  const raw = rawInterface();
  if (!raw) throw new Error('USB configuration has no 64-byte vendor HID interface');
  const keyboard = keyboardHid(interfaces);
  if (!keyboard) throw new Error('USB configuration has no boot keyboard HID interface');
  if (!raw.reportBytes) throw new Error('OAI HID descriptor has no report descriptor length');
  enumState = 'report-descriptor';
  reportDescriptorRequested = true;
  usb.sendSetupPacket(createSetupPacket({
    dataDirection: DataDirection.DeviceToHost,
    type: SetupType.Standard,
    recipient: SetupRecipient.Interface,
    bRequest: 6,
    wValue: 0x2200,
    wIndex: raw.number,
    wLength: raw.reportBytes,
  }));
  for (let attempt = 0; attempt < 20 && !reportDescriptorDone; attempt++) runForMicros(100000);
  if (!reportDescriptorDone) throw new Error('OAI HID report descriptor was not returned');

  function rpc(json, ack) {
    const before = rawFrames.length;
    const reports = oaiReports(json);
    for (const report of reports) {
      sendRaw(report);
      runForMicros(20000);
    }
    runForMicros(250000);
    return {
      acknowledged: requireAck(rawFrames.slice(before), ack),
      fragmentCount: reports.length,
      response: rawFrames.slice(before).map(readOaiFrame).filter(Boolean).join('').split('\n')
        .filter(line => line.trim().startsWith('{')).map(line => {
          try { return JSON.parse(line); } catch { return null; }
        }).find(message => message && message.id === JSON.parse(json).id),
    };
  }

  const rgbcfgAck = rpc('{"method":"v.oai.rgbcfg","id":1,"params":{}}', '{"result":true,"id":1}\r\n').acknowledged;
  const edgesBeforeStatus = gp17Edges;
  const visibleStatus = { id: 0, c: 3162110, e: 4, b: 1, s: 0.5 };
  const thstatusResult = rpc(
    '{"method":"v.oai.thstatus","id":2,"params":[{"id":0,"c":3162110,"e":4,"b":1,"s":0.5}]}',
    '{"result":true,"id":2}\r\n'
  );
  const thstatusAck = thstatusResult.acknowledged;
  runForMicros(250000);
  const edgesAfterStatus = gp17Edges;
  const deviceStatusAck = rpc('{"method":"device.status","id":3,"params":{}}', '{"result":{"version":"0.0.28-agentpad13"},"id":3}\r\n').acknowledged;
  const inputVersionAck = rpc('{"method":"sys.version","params":null,"id":998}', '{"result":{"version":"0.0.28-agentpad13"},"id":998}\r\n').acknowledged;
  const inputListing = rpc('{"method":"fs.list","params":{"checksum":true},"id":997}').response;
  const inputFilesAck = inputListing?.result?.[0]?.name === 'keymap.json';
  const inputUnsupportedAck = rpc('{"method":"fs.delete","params":{"file":"keymap.json"},"id":996}', '{"error":{"code":-32601,"message":"Unsupported on AgentPad13"},"id":996}\r\n').acknowledged;

  // Input's actual file workflow, followed by a Studio read and a physical
  // key scan. Restore the original document before the existing regressions.
  const inputOriginal = rpc('{"method":"fs.read","params":{"file":"keymap.json"},"id":990}').response?.result;
  let inputKeymapVerified = !!inputOriginal;
  function inputWrite(document, id) {
    const bytes = Buffer.from(JSON.stringify(document));
    let ok = true;
    for (let offset = 0; offset < bytes.length; offset += 3072) {
      ok &&= rpc(JSON.stringify({method: 'fs.writebin', id, params: {
        file: 'keymap.json', data: bytes.subarray(offset, offset + 3072).toString('base64'),
        offset, append: true, completed: offset + 3072 >= bytes.length,
      }}), `{"result":true,"id":${id}}\r\n`).acknowledged;
    }
    return ok;
  }
  if (inputOriginal) {
    const modified = structuredClone(inputOriginal);
    modified.profiles[0].layers[0].layout.keymap[0][0] = 'KC_A';
    inputKeymapVerified &&= inputWrite(modified, 991);
    const listing = rpc('{"method":"fs.list","params":{"checksum":true},"id":992}').response?.result?.[0];
    inputKeymapVerified &&= listing?.checksum === crypto.createHash('sha1').update(JSON.stringify(modified)).digest('hex');
    const studio = rpc('{"method":"v.agentpad.cfg.get","params":{"l":0},"id":993}').response?.result;
    inputKeymapVerified &&= studio?.m.startsWith('2a');
    const beforeNative = keyboardFrames.length;
    mcu.gpio[12].setInputValue(false); runForMicros(30000);
    mcu.gpio[12].setInputValue(true); runForMicros(30000);
    inputKeymapVerified &&= keyboardFrames.slice(beforeNative).some(frame => frame.subarray(2).includes(4));
    inputKeymapVerified &&= inputWrite(inputOriginal, 994);
  }

  const beforeKey = rawFrames.length;
  mcu.gpio[12].setInputValue(false);
  runForMicros(150000);
  mcu.gpio[12].setInputValue(true);
  runForMicros(150000);
  const keyFrame = rawFrames.slice(beforeKey).map(readOaiFrame).find((json) => json === '{"method":"v.oai.hid","params":{"k":"AG00","act":1}}\r\n');

  // Configure every layer through the production USB endpoint, including
  // response fragmentation. Then exercise a native mapping and release it
  // after TP5 changes layer while the key remains held.
  let layerConfigVerified = true;
  for (let layer = 0; layer < 4; layer++) {
    const mapping = Buffer.from([42, ...Array(12).fill(0), 12, 34, 56]).toString('hex');
    const setID = 710 + layer * 2, getID = setID + 1;
    layerConfigVerified &&= rpc(JSON.stringify({method: 'v.agentpad.cfg.set', id: setID, params: {l: layer, m: mapping}}), `{"result":true,"id":${setID}}\r\n`).acknowledged;
    layerConfigVerified &&= rpc(JSON.stringify({method: 'v.agentpad.cfg.get', id: getID, params: {l: layer}}), `{"result":{"l":${layer},"m":"${mapping}"},"id":${getID}}\r\n`).acknowledged;
  }
  mcu.gpio[16].setInputValue(false);
  runForMicros(100000);
  function touch() {
    mcu.gpio[16].setInputValue(true); runForMicros(30000);
    mcu.gpio[16].setInputValue(false); runForMicros(30000);
  }
  touch(); // CODEX -> FN
  const beforeNative = keyboardFrames.length;
  mcu.gpio[12].setInputValue(false); runForMicros(100000);
  const nativePress = keyboardFrames.slice(beforeNative).some(frame => frame.subarray(2).includes(4)); // KC_A
  touch(); // FN -> NAV, with A still held
  const beforeRelease = keyboardFrames.length;
  mcu.gpio[12].setInputValue(true); runForMicros(100000);
  const nativeRelease = keyboardFrames.slice(beforeRelease).some(frame => frame.every(byte => byte === 0));

  // CODEX now supports native overrides too. Restore its dynamic OAI
  // bindings before using OAI notifications as the joystick's layer marker.
  const codexDefault = Buffer.from([...Array(13).fill(0), 255, 0, 0]).toString('hex');
  if (!rpc(JSON.stringify({method: 'v.agentpad.cfg.set', id: 729, params: {l: 0, m: codexDefault}}), '{"result":true,"id":729}\r\n').acknowledged) {
    throw new Error('CODEX fixture restore failed');
  }
  // Distinct native keys identify FN/NAV/MEDIA without inspecting RAM.
  for (let layer = 1; layer < 4; layer++) {
    const mapping = Buffer.from([41 + layer, ...Array(12).fill(0), 12, 34, 56]).toString('hex');
    if (!rpc(JSON.stringify({method: 'v.agentpad.cfg.set', id: 730 + layer, params: {l: layer, m: mapping}}), `{"result":true,"id":${730 + layer}}\r\n`).acknowledged) {
      throw new Error('joystick fixture configuration failed');
    }
  }
  function expectLayer(layer) {
    const beforeKeyboard = keyboardFrames.length, beforeRaw = rawFrames.length;
    mcu.gpio[12].setInputValue(false); runForMicros(30000);
    mcu.gpio[12].setInputValue(true); runForMicros(30000);
    const matched = layer === 0
      ? rawFrames.slice(beforeRaw).map(readOaiFrame).includes('{"method":"v.oai.hid","params":{"k":"AG00","act":1}}\r\n')
      : keyboardFrames.slice(beforeKeyboard).some(frame => frame.subarray(2).includes(3 + layer));
    if (!matched) console.error(`Expected layer ${layer}; keyboard=${keyboardFrames.slice(beforeKeyboard).map(f => f.toString('hex'))}; raw=${rawFrames.slice(beforeRaw).map(readOaiFrame)}`);
    return matched;
  }
  function stick(value, duration = 30000) {
    // The physical horizontal axis is GP27 after CODEX's XY swap.
    mcu.adc.channelValues[1] = value; runForMicros(duration);
  }
  const beforeJoystick = rawFrames.length;
  let joystickLayersVerified = expectLayer(2); // previous touch left us on NAV
  stick(0); joystickLayersVerified &&= expectLayer(3);
  stick(0, 300000); joystickLayersVerified &&= expectLayer(3); // hold cannot repeat
  stick(4095); joystickLayersVerified &&= expectLayer(3); // reversal needs centre first
  stick(2048); stick(0); joystickLayersVerified &&= expectLayer(0); // forward wrap
  stick(2048); stick(0); joystickLayersVerified &&= expectLayer(1);
  stick(2048); stick(4095); joystickLayersVerified &&= expectLayer(0);
  stick(2048); stick(4095); joystickLayersVerified &&= expectLayer(3); // reverse wrap
  stick(2048); stick(4095); joystickLayersVerified &&= expectLayer(2);
  stick(2048); stick(4095); joystickLayersVerified &&= expectLayer(1);
  stick(2048);
  mcu.adc.channelValues[0] = 0; runForMicros(30000);
  joystickLayersVerified &&= expectLayer(1); // up/down does not change layers
  mcu.adc.channelValues[0] = 2048; runForMicros(800000);
  const joystickSessionEvents = rawFrames.slice(beforeJoystick).map(readOaiFrame)
    .filter(json => json && json.includes('"k":"AG01"'));
  touch(); joystickLayersVerified &&= expectLayer(2); // TP5 still works after cooldown

  // Reproduce Input's Add Layer defaults and cross the original four-layer
  // boundary through the actual file protocol. Then visit layer 16 by a
  // mapped key, TP5 and the joystick; no RAM state is used as an oracle.
  const expanded = structuredClone(inputOriginal);
  for (let index=4;index<16;index++) {
    const layer = structuredClone(expanded.profiles[0].layers[0]);
    layer.id=index; layer.name=`Layer ${index+1}`;
    layer.layout.keymap=layer.layout.keymap.map(row => row.map(() => 'KC_NONE'));
    layer.layout.keymap[0][0]='KC_Z';
    layer.layout.encoders=[['KC_NONE','KC_NONE','KC_NONE']];
    layer.layout.joystick={type:'RADIAL',sectors:[{k:'KI_X',a1:0.1875,a2:0.3125},{k:'KC_NONE',a1:0.3125,a2:0.1875}]};
    expanded.profiles[0].layers.push(layer);
  }
  expanded.profiles[0].layers[2].layout.keymap[0][1]='KI_LS16';
  let inputExtraLayersVerified=inputWrite(expanded, 940);
  const countInfo=rpc('{"method":"v.agentpad.cfg.info","params":{},"id":941}').response?.result;
  inputExtraLayersVerified &&= countInfo?.n===16;
  const lastLayer=rpc('{"method":"v.agentpad.cfg.get","params":{"l":15},"id":942}').response?.result;
  inputExtraLayersVerified &&= lastLayer?.m.startsWith('43'); // Studio's Z = 67.
  mcu.gpio[9].setInputValue(false); runForMicros(30000);
  mcu.gpio[9].setInputValue(true); runForMicros(30000);
  function expectExtended(codex) {
    const kb=keyboardFrames.length, raw=rawFrames.length;
    mcu.gpio[12].setInputValue(false); runForMicros(30000);
    mcu.gpio[12].setInputValue(true); runForMicros(30000);
    return codex ? rawFrames.slice(raw).map(readOaiFrame).includes('{"method":"v.oai.hid","params":{"k":"AG00","act":1}}\r\n')
      : keyboardFrames.slice(kb).some(frame => frame.subarray(2).includes(29));
  }
  inputExtraLayersVerified &&= expectExtended(false);
  touch(); inputExtraLayersVerified &&= expectExtended(true); // 16 -> CODEX
  stick(2048); stick(4095); inputExtraLayersVerified &&= expectExtended(false); // CODEX -> 16
  stick(2048); stick(0); inputExtraLayersVerified &&= expectExtended(true); // 16 -> CODEX
  stick(2048);
  inputExtraLayersVerified &&= rpc('{"method":"v.agentpad.cfg.info","params":{"n":4},"id":943}').response?.result?.n===4;

  const vid = deviceDescriptor.length >= 12 ? deviceDescriptor.readUInt16LE(8) : 0;
  const pid = deviceDescriptor.length >= 12 ? deviceDescriptor.readUInt16LE(10) : 0;
  const descriptorOk = reportDescriptorMatches(reportDescriptor);
  const evidence = {
    uf2_blocks: blocks,
    uf2_size_bytes: uf2Data.length,
    uf2_sha256: uf2Sha256,
    usb_enumerated: configured,
    vid_pid: `${usageHex(vid, 4)}:${usageHex(pid, 4)}`,
    usage: `${usageHex(OAI_USAGE_PAGE, 4)}:${usageHex(OAI_USAGE, 4)}`,
    report_id: OAI_REPORT_ID,
    report_bytes: OAI_REPORT_BYTES,
    keyboard_hid_enumerated: true,
    oai_hid_enumerated: true,
    keyboard_interface: { number: keyboard.number, in_endpoint: keyboard.inEp, in_bytes: keyboard.inBytes },
    interface: { number: raw.number, in_endpoint: raw.inEp, out_endpoint: raw.outEp, in_bytes: raw.inBytes, out_bytes: raw.outBytes },
    descriptor_verified: descriptorOk && reportDescriptorRequested,
    rgbcfg_ack: rgbcfgAck,
    thstatus_ack: thstatusAck,
    device_status_ack: deviceStatusAck,
    input_recognition_rpc_verified: inputVersionAck && inputFilesAck && inputUnsupportedAck,
    input_keymap_read_write_verified: inputKeymapVerified,
    input_extra_layers_verified: inputExtraLayersVerified,
    layer_configuration_verified: layerConfigVerified,
    joystick_layers_verified: joystickLayersVerified,
    joystick_no_session_events: joystickSessionEvents.length === 0,
    native_mapping_press: nativePress,
    native_mapping_release_after_layer_change: nativeRelease,
    task_status: visibleStatus,
    task_status_fragment_count: thstatusResult.fragmentCount,
    key_event: keyFrame ? { k: 'AG00', act: 1 } : null,
    ws2812_activity: edgesAfterStatus > edgesBeforeStatus && thstatusResult.fragmentCount > 1,
    gp17_edges_after_thstatus: edgesAfterStatus - edgesBeforeStatus,
    usb_events: eventLog,
  };
  fs.mkdirSync(path.dirname(evidencePath), { recursive: true });
  fs.writeFileSync(evidencePath, `${JSON.stringify(evidence, null, 2)}\n`);
  console.log(JSON.stringify(evidence));

  const checks = [
    evidence.vid_pid === '303a:8360', evidence.descriptor_verified,
    evidence.keyboard_hid_enumerated, evidence.oai_hid_enumerated,
    evidence.rgbcfg_ack, evidence.thstatus_ack, evidence.device_status_ack,
    evidence.input_recognition_rpc_verified, evidence.input_keymap_read_write_verified, evidence.input_extra_layers_verified,
    evidence.task_status_fragment_count > 1, evidence.key_event !== null, evidence.ws2812_activity,
    evidence.layer_configuration_verified, evidence.native_mapping_press, evidence.native_mapping_release_after_layer_change,
    evidence.joystick_layers_verified, evidence.joystick_no_session_events,
  ];
  if (!checks.every(Boolean)) throw new Error(`OAI smoke failed; evidence written to ${evidencePath}`);
  // rp2040js may leave a scheduling timer alive after the synchronous smoke;
  // force a clean CLI exit once the evidence and all assertions are complete.
  process.exit(0);
}

module.exports = { oaiReport, oaiReports, keyboardHid };

if (require.main === module) {
  try {
    main();
  } catch (error) {
    console.error(`OAI EMULATOR SMOKE: FAIL: ${error.message}`);
    process.exitCode = 1;
  }
}
