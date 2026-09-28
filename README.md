# linux_dictation_tool

> I built this for my own machine: Arch-based (CachyOS), KDE Plasma 6 on Wayland, AMD Radeon
> RX 7900 GRE. I'm happy to share it, but it's shared as-is. It's tuned to that setup and I'm
> not planning to support other distros or hardware. Feel free to fork and adapt it.

Local, offline voice dictation for KDE Plasma on Wayland. You speak and the text is typed into
whatever field has focus. Nothing leaves the machine and there is no API cost.

```
parecord (16 kHz mono) → whisper.cpp (Vulkan GPU) → filler cleanup → ydotool type / paste
```

## Usage

Start dictation with **Alt+Shift+D** or a left-click on the tray icon, speak, then press or click
again to stop. The hotkey and the tray icon are interchangeable, so you can start with one and stop
with the other. Recording stops by itself after 120 s.

| Tray icon | State |
|---|---|
| microphone | idle, click to start |
| 🔴 red dot | recording, click to stop |
| stopwatch | transcribing |

### Tray menu (right-click)

| Item | What it does |
|---|---|
| Start / Stop dictation | same as a left-click |
| Start / Stop server | keeps the model loaded on the GPU so transcription starts instantly; the label shows the current state (running, loading model…). Stays on across reboots until you stop it. |
| Language | Auto-detect, Français, English |
| Model | every `ggml-*.bin` in `~/.local/share/whisper/`, plus a **Download** submenu for models you don't have yet |
| History | the last 10 transcripts; click one to copy it. Kept in RAM (`$XDG_RUNTIME_DIR`), cleared at logout. |

### Server vs no server

Without the server, each dictation starts `whisper-cli`, which loads the model (about 3 s for
large-v3) before it transcribes. With the server running, the model is already loaded:

| 10 s clip, large-v3, RX 7900 GRE | Time to text |
|---|---|
| without server | ~2.6 s |
| with server | ~0.6 s |

Both give the same text: the server uses the same beam search settings, and it restarts in the
background after each dictation because whisper-server's output drifts after its first request.
If you dictate again before it's back (about 2 s), that dictation goes through `whisper-cli`.
The server holds about 3 GB of VRAM; stop it from the menu before a VRAM-heavy game.

## Files

| File | Role |
|---|---|
| `dictate` | toggle script: records, transcribes (server or CLI), cleans up, types |
| `dictate-tray` | PyQt6 tray icon and menu |
| `dictate-server.service` | systemd user unit running `whisper-server` via `dictate __server` |
| `install.sh` | symlinks the scripts into `~/.local/bin`, installs the unit, enables tray autostart |

## Setup from scratch

Only official Arch repo packages plus an upstream source build. No AUR.

```bash
# 1. packages
sudo pacman -S ydotool wl-clipboard spirv-headers python-pyqt6
#    also needed (usually present): cmake gcc make git curl shaderc vulkan-headers vulkan-radeon libnotify pipewire

# 2. whisper.cpp with the Vulkan backend (AMD GPU, no ROCm)
git clone https://github.com/ggml-org/whisper.cpp ~/.local/src/whisper.cpp
cd ~/.local/src/whisper.cpp
cmake -B build -DGGML_VULKAN=1 -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"

# 3. model (free open weights, ~2.9 GB)
mkdir -p ~/.local/share/whisper
curl -L --fail -o ~/.local/share/whisper/ggml-large-v3.bin \
  https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin

# 4. ydotool daemon (your user must be in the `input` group)
systemctl --user enable --now ydotool.service

# 5. this repo
./install.sh
dictate-tray &
```

**6. Hotkey.** In System Settings → Keyboard → Shortcuts, click **Add New** → **Command or Script**
and enter `~/.local/bin/dictate` (full path). Then select the new entry, click **＋ Add…** in the right
panel, press **Alt+Shift+D**, and click **Apply**. Use the GUI for this: on Plasma 6, editing
`kglobalshortcutsrc` by hand doesn't register the shortcut.

## Configuration

`~/.config/dictate/config` holds `KEY=value` lines. The tray writes `LANG_OPT` and `MODEL_NAME`;
anything else you add is kept.

| Key | Default | Purpose |
|---|---|---|
| `LANG_OPT` | `auto` | `auto`, `fr` or `en` |
| `MODEL_NAME` | `large-v3` | loads `~/.local/share/whisper/ggml-<name>.bin` |
| `PROMPT` | empty | comma-separated words you use often (names, jargon) so whisper spells them right |

Example:

```
PROMPT=Kubernetes, PostgreSQL, Grafana, Nextcloud.
```

`MAX_SECS`, `FILLERS` (interjections stripped from transcripts) and `HISTORY_MAX` are set at the top
of `dictate`.

## Models

**Model → Download** lists the models below that aren't installed yet. A download runs in the
background, gets its SHA-256 checked, and the model shows up in the Model menu once it's ready.
You can also drop any `ggml-*.bin` from https://huggingface.co/ggerganov/whisper.cpp into
`~/.local/share/whisper/` by hand.

| Model | Size | Notes |
|---|---|---|
| `large-v3` | 3.1 GB | most accurate; the default |
| `large-v3-turbo` | 1.6 GB | same encoder, decoder cut from 32 to 4 layers: about 2× faster, less accurate on jargon and French |
| `large-v3-q5_0`, `large-v3-turbo-q8_0`, `large-v3-turbo-q5_0` | 0.6–1.1 GB | quantized: less memory, slightly lower accuracy |
| `large-v2`, `medium`, `small`, `base`, `tiny` | 0.08–3.1 GB | older or smaller; faster, less accurate |

Quality is set almost entirely by the model. Beam search is already at 5, the standard maximum.

## Known limits

- **Accented text goes through the clipboard.** `ydotool type` only produces ASCII, so text
  containing é/à/ô is pasted with Ctrl+V. GUI fields accept that. Terminals need Ctrl+Shift+V, so
  accented dictation won't land in a terminal.
- **Don't dictate during a call.** Teams and `parecord` compete for the same mic and can freeze both.
- IDs, commit hashes and rare jargon are sometimes misheard. That's a limit of the speech model;
  `PROMPT` helps with recurring words.

## Updating whisper.cpp

```bash
cd ~/.local/src/whisper.cpp && git pull && cmake --build build -j"$(nproc)"
```

Restart the server afterwards if it's running: `systemctl --user restart dictate-server`.
