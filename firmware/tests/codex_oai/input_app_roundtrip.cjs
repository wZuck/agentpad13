// Validate a generated document with the installed Input model/serializer.
// Loads selected JavaScript class definitions only, with no app startup,
// native modules, HID access, filesystem writes or network access in the VM.
const fs = require('fs');
const vm = require('vm');
const archive = fs.readFileSync(process.argv[2]);
const header = JSON.parse(archive.subarray(16, 16 + archive.readUInt32LE(12)).toString());
const entry = header.files['dist-electron'].files.main.files['index.js'];
const base = 8 + archive.readUInt32LE(4);
const code = archive.subarray(base + Number(entry.offset), base + Number(entry.offset) + entry.size).toString();
function definition(kind, name) {
  const regex = new RegExp(`^${kind} ${name}(?: \\{|\\([^\\n]*\\) \\{)[\\s\\S]*?^}`, 'm');
  const match = code.match(regex);
  if (!match) throw new Error(`Input 1.0.2 definition missing: ${name}`);
  return match[0];
}
const sandbox = {
  source: fs.readFileSync(0, 'utf8'),
  structuredClone,
  y: (object, key, value) => { object[key] = value; },
  c: {info() {}, error() {}, debug() {}},
};
vm.createContext(sandbox);
vm.runInContext([
  definition('function', 'To'), definition('function', 'Pe'),
  definition('class', 'dt'), definition('class', 'Xe'), definition('class', 'vs'),
  `const doc = JSON.parse(source);
   const profiles = doc.profiles.map(profile => Xe.fromDeviceJson(profile));
   profiles[0].layers[0].layout.keymap[0][0] = 'KC_A';
   const config = {...doc, profiles, actions: [], actionGroups: [], multiactions: [], multiactionGroups: []};
   output = new vs().prepareKeymapJson(config);
   if (!output) throw new Error('Input serializer rejected document');`,
].join('\n'), sandbox, {timeout: 3000});
process.stdout.write(sandbox.output);
