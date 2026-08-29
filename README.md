<p align="center">
  <img src="art/XelaNotPu-LogoTransparent-GithubSocial.png" alt="ZN-1 MiSTer banner" width="100%">
</p>

# ZN-1 Capcom for MiSTer — First Public Release (2026-08-28)

This is the **first public release** of the **ZN1-Capcom** core: an FPGA
re-implementation of Sony's ZN-1 arcade board, Capcom variant (`coh1000c` /
`coh1002c`, QSound), for the
[MiSTer platform](https://github.com/MiSTer-devel/Main_MiSTer/wiki).

The ZN-1 (1995) is Sony's first PlayStation-based arcade board: an R3000A-compatible
MIPS CPU, a PSX-type GPU (CXD8561) with VRAM, and main RAM — paired with
ZN-specific hardware that has no consumer-PlayStation equivalent: a per-publisher
arcade boot ROM in place of the PS1 kernel, large banked game ROM in place of a CD
drive, **CAT702** challenge/response security chips with per-game keys, on-board
NVRAM/EEPROM, and a publisher sound sub-board. The Capcom variant carries the
**QSound** sound system (Z80 + Lucent DL-1425 DSP + PCM samples). The core is an
independent re-implementation of that board built on the **PSX_MiSTer**
PlayStation core by Robert Peip (FPGAzumSpass).

> **Provenance note:** the shipped bitstream is dated `20260820`
> (`Arcade-ZN1Capcom_20260820.rbf`, md5 `4eb0333e0b00a0292c7d00ad08f4098c`); this
> README publishes it on **2026-08-28**. ZN1-Capcom is the Capcom member of a
> family of ZN-1 publisher cores (separate Taito and Tecmo/Video System cores
> exist); it installs and runs standalone.

---

## Supported games

Five titles across **17 sets** (one primary MRA per title; other regions/revisions
live in `releases/_Arcade/_alternatives/_<Title>/`). Merged MAME romsets are
supported: clone sets load from the parent zip's subdirectories.

| Title (primary set) | Audio | State |
|---|---|---|
| Street Fighter EX (USA) | QSound | Boots + plays |
| Street Fighter EX Plus (USA 970311) | QSound | Boots + plays |
| Star Gladiator: Episode I – Final Crusade (USA) | QSound | Boots + plays; attract FMV plays |
| Battle Arena Toshinden 2 (USA) | QSound | Boots + plays |
| Gallop Racer | PSX SPU | Boots + plays (this title uses no QSound board — see below) |

## What this release supports

- **Video** — the full PSX-type GPU. **FMV playback** works (the PSX MDEC movie
  decoder is implemented, so Star Gladiator's attract movies play). **480i
  interlaced modes are field-correct** — the GPU field-status bit games poll to
  pace per-field rendering is returned correctly through vblank, so interlaced
  scenes don't ghost, flash under Bob deinterlacing, or comb.
- **Audio — QSound music and SFX both work** on the four QSound titles. The
  DL-1425 DSP microcode is loaded at runtime from your own `qsound_hle.zip` (no
  copyrighted firmware ships in the core). The long-standing residual static that
  once "rode with the music" is fixed, and the music/SFX balance matches MAME's
  reference routing. *Gallop Racer* is a non-QSound Capcom title and uses the PSX
  SPU for its audio.
- **Full game speed** — the ZN-1 CPU runs at its native rate; the catalog plays at
  full speed.
- **NVRAM saving** — game settings, rankings, and bookkeeping written to the
  mainboard EEPROM persist across core reloads (`config/nvram/<game>.nvm`).
- **Controls** — the Capcom CPS-style split panel: 3 punches on the P1 register +
  3 kicks on a separate kick harness. 6-button (SF EX / EX Plus, Toshinden 2) and
  4-button (Star Gladiator) layouts; per-game button labels come from each MRA.
- **CRT Adjust (analog)** — optional H-Size / H-Position / V-Shift for analog CRTs
  (OSD → Video & Audio; default Off).
- **DB9 / DB15 controllers (UserIO)** — native Mega Drive (DB9) and Neo-Geo-style
  (DB15) pads/sticks on the USER port for Antonio Villena-style DB9/SNAC8 splitter
  hardware, OR-merged with USB input.
- **Merged romsets** and a MiSTer-standard pause overlay.

## Known limitations / not yet supported

Stated plainly so expectations are accurate:

- **Saturn controllers via DB9-Pro are locked.** The Saturn pad path is part of
  the key-gated MiSTer-DB9-Pro program; this open-source build carries no key, so
  Saturn mode stays disabled. DB9 (Mega Drive) and DB15 (Neo Geo) work.
- **Gallop Racer has no QSound** — that is by design; the title never shipped with
  a QSound board and uses the PSX SPU. This is not a defect.
- **Capcom (`coh1000c` / `coh1002c`) titles only.** Other ZN-1 publishers
  (Taito FX-1, Tecmo, Video System) and others are handled by separate ZN-1 cores.
- **No copyrighted data is included.** You must supply your own ROMs, the Capcom
  boot ROM, and the QSound DL-1425 microcode (see *Requirements*).

## Requirements

- A MiSTer (DE10-Nano) setup.
- Your own legally-obtained **game romsets** (merged MAME sets recommended).
- The Capcom **boot ROM** — `coh1000c.zip` / `coh1002c.zip` (loads at runtime; not
  included).
- **`qsound_hle.zip`** containing the DL-1425 microcode (`dl-1425.bin`), for
  QSound audio on the four QSound titles (loads at runtime; not included).

## Install

Copy the contents of `releases/_Arcade/` onto your SD card's `_Arcade/` folder:
this places the `.mra` files (and `_alternatives/`) directly in `_Arcade/`, and
`cores/Arcade-ZN1Capcom_20260820.rbf` in `_Arcade/cores/`. Provide your own
romsets as above. Core name **ZN1Capcom** — every MRA references
`<rbf>ZN1Capcom</rbf>`.

---

## Credits & attribution

This core stands on the work of others, gratefully acknowledged. Where a
component is used, its own authors and license govern that component.

- **PSX_MiSTer** by **Robert Peip (FPGAzumSpass)** — the PlayStation core this
  ZN-1 core derives from, providing the R3000A CPU, GPU, GTE, DMA, MDEC, SPU, and
  memory subsystem.
- **The MiSTer project** and its framework (`sys/`) — **Alexey Melnikov
  (Sorgelig)** and the MiSTer-devel contributors.
- **QSound DSP — JTDSP16** by **Jose Tejada (Jotego)**: `jtdsp16`
  (`rtl/sound/jt_qsound/`, GPLv3) is Jotego's implementation of the Lucent DSP16A
  at the heart of Capcom's DL-1425 QSound chip, originally developed for his
  CPS1.5/CPS2 cores and used here essentially intact. The ZN-1 work is the
  integration around it: runtime microcode loading (so no firmware ships in the
  bitstream), sample-ROM service through this core's shared multi-channel SDRAM
  controller with a latency-tolerant dual-clock fetch handshake, serial-DAC audio
  recovery, and clock-enable generation. Without JTDSP16 there would be no QSound
  music on this core.
- **Z80 (T80) CPU core** — **Daniel Wallner** and contributors, used for the
  QSound program CPU.
- **MiSTer-CRT-Adjust** — the core-side analog CRT geometry module
  (`crt_adjust.sv`).
- **MiSTer-DB9 / DB9-Pro** — DB9/DB15/Saturn splitter support for **Antonio
  Villena**'s DB9/SNAC8 splitter hardware; control modules by **Aitor Pelaez
  (NeuroRulez)**, based on work by **Victor Trucco** and **Fernando Mosquera**;
  Saturn protocol adaptation by **Timothy Redaelli**.
- **The MAME project** — used solely as hardware documentation and behavioral
  reference for developing the ZN-1 board support as an independent
  re-implementation. No MAME source code is included in this core.
- **ZN-1 board support & original chip re-implementations** — **XelaNotPu**:
  per-publisher boot-ROM integration, CAT702 security, ROM banking, NVRAM/EEPROM,
  the QSound board wrapper and fetch/handshake work, the MDEC/480i work, and the
  pause-overlay artwork and README banner.

## Legal & licensing

**No affiliation.** This project is unofficial and is not affiliated with,
endorsed by, or sponsored by Sony Interactive Entertainment, Capcom, Arika,
Takara, QSound Labs, or any other rights holder.

**Trademarks.** "Sony", "PlayStation", and "ZN-1" are trademarks of Sony
Interactive Entertainment Inc. QSound is a trademark of QSound Labs. The game
titles playable on this core are trademarks of their respective owners —
**Capcom Co., Ltd.** and **Arika Co., Ltd.** (Street Fighter EX / EX Plus; Star
Gladiator), **Takara Co., Ltd. / Takara Tomy** (Battle Arena Toshinden 2), and
**Tecmo / Koei Tecmo Games Co., Ltd.** (Gallop Racer). Sega, Mega Drive, and
Saturn are trademarks of SEGA Corporation; Neo Geo is a trademark of SNK
Corporation — referenced solely to identify the third-party controllers the
DB9/DB15 feature supports. All such names are used in a purely nominative and
descriptive manner, solely to identify the hardware and games being
re-implemented or referenced.

**No ROMs or copyrighted data.** This release contains and distributes **no**
copyrighted ROMs, BIOS images, game data, or manufacturer firmware, and provides
no links or instructions for obtaining them. The bitstream embeds no boot ROM,
game ROMs, QSound microcode, or captured NVRAM; the Capcom boot ROM
(`coh1000c.zip` / `coh1002c.zip`) and the DL-1425 microcode load at runtime from
files you supply, and on-board EEPROM initialises blank and self-configures. MRA
files reference romsets by name only. You must supply your own legally-obtained
ROM dumps, made from original hardware or media you legally own, where and to the
extent your local law permits.

**Security-chip emulation.** ZN-1 boards used CAT702 challenge/response chips as a
protection measure. This core re-implements that algorithm for interoperability
and preservation, in the same manner as MAME and comparable FPGA cores. The
CAT702 is a small challenge/response algorithm rather than stored key data, so
**no manufacturer key material is embedded** in the bitstream (per-game keys
travel in your MRA files). Laws such as the U.S. DMCA §1201 address circumvention
of technological protection measures; whether and how they apply to this kind of
preservation/interoperability use can depend on your jurisdiction and
circumstances. You are responsible for your own compliance.

**Purpose.** This is an independent, non-commercial hardware-preservation and
interoperability project. The FPGA logic is an original re-implementation of the
ZN-1 board's behavior, developed from observation and publicly available
documentation and references (including the MAME project's hardware
documentation); it contains no proprietary source code from the original
manufacturers.

**User responsibility.** You are solely responsible for ensuring that your use of
this core — including the acquisition and use of any ROM images, boot ROMs, or
firmware — complies with copyright law and all other applicable laws in your
jurisdiction.

**No warranty.** This program is provided "AS IS", without warranty of any kind,
express or implied, including but not limited to the implied warranties of
merchantability and fitness for a particular purpose. The entire risk as to the
quality and performance of the program is with you. In no event will any copyright
holder or contributor be liable for any general, special, incidental, or
consequential damages arising out of the use or inability to use this program.

**License.** The FPGA source is released under the **GNU General Public License,
version 3 or later** (see `LICENSE`, `COPYING.GPL2`, `COPYING.GPL3` at the core
root). The source tree mixes GPLv2-or-later and GPLv3-or-later files, so the
combined work and its synthesized bitstream are GPLv3-or-later; every file remains
available under the terms in its own header, and upstream components (PSX_MiSTer,
the MiSTer framework, jtdsp16, T80, MiSTer-CRT-Adjust, MiSTer-DB9/DB9-Pro) retain
their respective licenses.
