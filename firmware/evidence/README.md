# Evidence files

`codex-oai-emulator.json` is the current emulator capture for
`release/firmware/prebuilt/agentpad13_codex_oai.uf2`. It was regenerated from
this checkout and must match the UF2 SHA-256 and byte size recorded in
`codex-oai-current-manifest.json`. The current port rebuild is 119,808 bytes
with SHA-256
`eb462190390f01ddbf819da7c2d6d20b806df4de9099a40b7dc34f4225492aff`.

Two earlier provenance layers remain explicit:

The v0014 four-layer build used the local QMK toolchain GCC 15.2.0
(crosstool-NG 1.27.0.82), rather than the GCC 15.2.1 release toolchain pinned
by `build_codex_oai.py`. The pinned Vial source and descriptor patches were
validated before QMK lint and the direct OAI build. The current ELF/UF2
equivalence and USB smoke were regenerated for this exact artifact. Emulator
evidence additionally verifies all four layer configuration RPCs and a native
key press/release across a layer change. The joystick layer-mode rebuild
uses the same local GCC 15.2.0; its smoke additionally checks both directions
on every layer, wraparound, hold/reversal until recentering, vertical input,
and TP5 coexistence. Physical checks remain PENDING.

The v001C Input keymap adapter uses the same source/toolchain. Its capture
records `input_recognition_rpc_verified` and `input_keymap_read_write_verified` / `input_extra_layers_verified`:
file reads/writes, exact SHA-1, a Studio configuration read and a native key
scan, plus Input uploads through layer 16, native key output, direct layer selection,
TP5 and joystick wraparound, alongside the original OAI regressions. Physical Input
UI and simultaneous clients remain unverified. Scope and remaining checks:
[Input compatibility](../../docs/input-compatibility.zh-CN.md).

- The imported phase-3 migration baseline was 92,160 bytes with SHA-256
  `d1768471eef4d0be12c1fc264279f20b9a7d293ea902c0608ebcfb4643ae35be`.
  It was copied byte-for-byte before the destination rebuild and is superseded
  by the current port artifact; it is not a claim about the final source.
- `codex-oai-manifest.json` is retained as historical full-image evidence for
  the still older 92,672-byte artifact with SHA-256
  `11ee3ed649cf198186fc1e3c190fcaf6a7a1cfbdb18f68ebbead974b09a1712b`.
  Its ELF metrics and hash intentionally refer to that older artifact; it is
  not a claim about the current release UF2.

To produce a new full manifest after a clean QMK build, run
`firmware/tools/verify_codex_oai_artifact.py` with the newly generated ELF, the
current emulator JSON and an output path below this directory. The verifier
checks the UF2 hash, ELF size/symbols and emulator handshake atomically; no
device or removable volume is accessed.
