# Dino Crisis 3 — static recompilation

A native Windows build of **Dino Crisis 3** for the original Xbox (title ID `43430003`),
made by statically recompiling the game's XBE with
[xboxrecomp](https://github.com/phobos665/xboxrecomp).

This repository holds only what is specific to Dino Crisis 3: the title project, its
hand-written overrides, the seed list the disassembler needs, and notes. The
recompiler and the runtime (kernel, D3D8 HLE renderer, audio, input, launcher) are
the `external/xboxrecomp` submodule.

**No game code or data is included, and none may be committed.** You need your own
copy of the game. Do not distribute builds: the lifted C is derived from the game's
code.

## Status (29 Sep 2026)

- **Reaches gameplay and plays.** Intro, title screen, menus, difficulty select, the
  opening movie (Bink, skippable with START), the controls tutorial, then the first
  room with the player character, the HUD, and the Status, Options and Map screens.
- 60 fps in gameplay. A five-minute scripted session of walking and firing ran at
  60 fps throughout, with no crash and no stall.
- Needs the toolkit branch `fix/dc3-into-gameplay` (the submodule pin). It carries
  four general fixes, found on this title:
  - `IDirectSoundBuffer_Pause` is replaced. The music fade after difficulty select
    waited for a paused buffer to stop playing, and it never did.
  - `MmFreeContiguousMemory` frees. The front end left 62 of 64 MB of contiguous
    memory allocated, so the first stage's 5 MB request failed, and the stage file
    was read over the game's own code. That was the source of the old intermittent
    crash (`0x04XX04XX` wild calls).
  - A vertex attribute at an unaligned offset is realigned for the host. Skinned
    meshes (the player, the dinosaurs) put their weights after 6-byte bone
    indices, so they exploded into screen-sized triangles. That was the
    "flickering".
  - Fixed-function lighting (material, lights, `D3DRS_LIGHTING`) is forwarded. The
    map's rooms were flat white; they are now the lit blue hologram.
- Not yet checked: progress past the first room (doors, loading the next area),
  combat against dinosaurs, in-game cutscenes, saving and loading.
- To check by eye: with lighting forwarded, some walls in the first room are much
  darker than before. Probably correct, but not compared with a console.
- A null function-pointer call inside Bink (from guest `0x002324EB`, a callback
  field supplied to Bink as 0) is skipped during movies. Harmless so far.
- No overrides. Seven seeds, for thread start routines and indirect-call targets
  the disassembler misses.

## Requirements

- Windows 10 or 11, x64.
- Visual Studio 2019 or 2022 (or the Build Tools) with the C++ workload, and CMake
  3.20 or later. The CMake bundled with Visual Studio is found automatically.
- Python 3.10+ as `py -3`, with `capstone` and `pefile` (`py -3 -m pip install capstone pefile`).
- Your own extracted Dino Crisis 3 disc (the folder containing `default.xbe`).

## Setup

```powershell
git clone --recursive <this repository's URL>
cd dinoCrisis3-recomp
# or, in an existing clone:
git submodule update --init --recursive
```

Put the extracted disc in `game/`, so that `game/default.xbe` exists. Either copy it,
or make a directory junction to wherever it already is:

```powershell
New-Item -ItemType Junction -Path game -Target "D:\Xbox\Dino Crisis 3"
```

## Build

```powershell
./scripts/recompile.ps1          # lift the XBE into src/recomp/gen (a few minutes)
./scripts/build.ps1              # build/Release/dinocrisis3_recomp.exe
```

`recompile.ps1` takes `-From disasm|identify|lift` to resume part-way. **The
disassembly stage is what applies the seeds**, so after editing the seed file, run
`-From disasm`. `-From lift` ignores new seeds.

## Run

Run `build/Release/dinocrisis3_recomp_launcher.exe` to choose video settings and
bind keys or a pad, then press Play. Or run `dinocrisis3_recomp.exe` directly. It
looks for the game in this order:

1. `RECOMP_GAME_DIR`
2. a `game` folder beside the executable
3. this repository's `game/`

F9 shows the frame rate, F10 steps through the frame caps, and F11 saves a
screenshot and a replayable capture beside the executable. Closing the window exits.

A scripted path from boot to gameplay on a fresh profile: start through the title
screen, Normal difficulty, START to skip the opening movie, and A through the
controls tutorial. It's in the first room at about 60 s, and then walks forward.
Times are from the first pad read:

```powershell
$env:RECOMP_INPUT_SEQ = "20000:start,23000:start,26000:start,30000:a,34000:a,45000:start,50000:a,53000:a,56000:a,59000:a,62000:lstick_up:3000"
```

Add `,76000:black` to open the Map, or `,76000:back` for Status (B closes either).

The toolkit's switches all apply; see `external/xboxrecomp/CLAUDE.md` and
`docs/technical/` there.

## Layout

```
CMakeLists.txt             the title project; builds against external/xboxrecomp
src/main.c                 entry point: finds the game, maps the XBE, starts it
src/recomp_manual.c        Dino Crisis 3 overrides (none yet) and ICALL diagnostics
src/recomp/                generated by recompile.ps1 (gitignored)
config/seeds/43430003.json function starts the disassembler misses, each with why
scripts/                   recompile.ps1, build.ps1
external/xboxrecomp        the toolkit (submodule)
game/                      your extracted disc (gitignored)
```

## Working on it

- **What belongs here and what belongs in the toolkit.** A fix that would help any
  title goes in xboxrecomp: the lifter, the kernel, the renderer. A fix that only
  makes sense for Dino Crisis 3 goes here: seeds, `recomp_manual.c`, per-title defaults.
- **The submodule** tracks xboxrecomp's `main` at a pinned commit. To pick up
  toolkit changes:

  ```powershell
  cd external/xboxrecomp; git fetch; git checkout <commit>; cd ../..
  git add external/xboxrecomp; git commit -m "xboxrecomp: <what changed>"
  ```

  To change the toolkit, either work in the submodule or point CMake at another
  checkout with `-DXBOXRECOMP_DIR=...`.
- **When the game faults or goes quiet**, build with the ABI check
  (`./scripts/build.ps1 -AbiCheck`, into `build-abi/`). Then read the first
  `[ABI]` line after start-up, and any `[ICALL] unresolved call target` line. On
  the other titles, the usual cause was a function that starts straight after a
  `ret` with no padding and is reached only through a pointer. The fix is to seed
  it in `config/seeds/43430003.json`, with a note saying why.
- For a value that shouldn't be there, `RECOMP_WATCH_WRITE=<addr>` names the
  writer, and `RECOMP_FIND_VALUE=<value>` finds who holds it. See
  `external/xboxrecomp/docs/technical/memory-watchpoints.md`.
- An override in `recomp_manual.c` that wraps a generated function declares
  `extern void sub_XXXXXXXX_gen(void);`. The recompiler then emits the original
  body under that name, and routes every call through the wrapper.

## Licence

The code in this repository is GPL-3.0 (see `LICENSE`). The xboxrecomp submodule
carries its own licences. The game is not included, and neither licence covers it.
