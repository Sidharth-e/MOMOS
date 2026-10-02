# MOMOS — Mobile Models Ollama Setup

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Termux-brightgreen.svg)](https://termux.dev)
[![Architecture](https://img.shields.io/badge/Architecture-arm64%20%7C%20x86__64-blue.svg)](#requirements)
[![Root](https://img.shields.io/badge/Root-Not%20Required-success.svg)](#requirements)
[![Offline](https://img.shields.io/badge/Privacy-100%25%20Offline-blueviolet.svg)](#how-it-works)

Run lightweight AI models locally on your Android phone using Termux and Ollama. One command to install, no root needed, runs completely offline.

Nothing leaves your phone unless you ask it to. The model server listens on the phone itself; `momos serve --lan` is the one command that opens it to your Wi-Fi.

![MOMOS installation in Termux](assets/termux.png)

## What it does

- Checks your phone's architecture, RAM and storage
- Installs Ollama as a native Termux package — no container, no root
- Downloads a model sized for your device
- Adds a simple `momos` command to chat, serve the web UI and manage models

---

## Quick Install

Open **[Termux](https://f-droid.org/packages/com.termux/)** and run:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Sidharth-e/MOMOS/main/scripts/momos.sh)"
```

The installer checks your hardware, recommends a model, installs Ollama,
downloads the model, and installs the `momos` command. It prints how to start
when it is done.

---

## Supported Models (<7B)

Larger models (14B, 32B) require too much memory and quickly crash or throttle on phones. MOMOS focuses on models under 7B parameters that fit within typical smartphone RAM limits (2GB to 8GB+):

| Model | Tag | Download | RAM Needed | Best For |
|---|---|---|---|---|
| **Llama 3.2 1B** | `llama3.2:1b` | ~1.3 GB | 2 GB+ | Fast responses, low battery use, low-end phones |
| **DeepSeek R1 1.5B** | `deepseek-r1:1.5b` | ~1.1 GB | 2 GB+ | Step-by-step reasoning and logic |
| **Llama 3.2 3B** | `llama3.2:3b` | ~2.0 GB | 4 GB+ | Everyday chat, writing, and summarization |
| **Qwen 2.5 3B** | `qwen2.5:3b` | ~1.9 GB | 4 GB+ | Math, coding, and multilingual queries |
| **DeepSeek R1 7B** | `deepseek-r1:7b` | ~4.7 GB | 6–8 GB+ | Advanced reasoning on higher-RAM devices |
| **Qwen 2.5 7B** | `qwen2.5:7b` | ~4.7 GB | 6–8 GB+ | Detailed coding and technical answers |

You can also use any model tag from the [Ollama library](https://ollama.com/library) (e.g. `phi4-mini`, `smollm2:1.7b`).

---

## Usage

### Interactive Menu
```bash
momos
```
Shows a numbered menu: chat, open the web UI, list, pull and delete models, view
logs, update, or uninstall.

### Chat
```bash
momos chat                       # Chat with your last used model
momos chat llama3.2:1b           # Chat with Llama 3.2 1B
momos chat deepseek-r1:1.5b     # Chat with DeepSeek R1 1.5B
momos chat qwen2.5:3b            # Chat with Qwen 2.5 3B
```

### Manage Models
```bash
momos models list                # Show downloaded models
momos models pull qwen2.5:3b     # Download a model
momos models delete llama3.2:3b  # Remove a model
```

### Server Logs
```bash
momos logs                       # Follow the server and web UI output (Ctrl+C to exit)
```

![Ollama server logs](assets/ollama-server.png)

> [!NOTE]
> The Ollama server starts automatically in the background when running `momos chat` or managing models, and it starts **on the phone only**. You only need `momos logs` if you want to inspect server output directly.

```bash
momos serve                      # Start the server in the background, on the phone only
momos serve --lan                # Start it exposed to your Wi-Fi
momos stop                       # Stop the background server
```

Both `momos serve` and `momos ui` hand the terminal straight back and keep
running. Their output goes to `~/.momos/server.log` and `~/.momos/ui.log`, which
`momos logs` follows together — `tail` labels each line with the file it came
from, so the two are never mixed up.

> [!TIP]
> A backgrounded server stops when Android puts Termux to sleep. Run
> `termux-wake-lock` first if you are leaving the phone alone — see
> [Keeping Termux alive in background](#keeping-termux-alive-in-background).

`momos chat` and `momos models` start the server for you on `127.0.0.1` and leave it running. That is deliberately private: nothing on your network can reach it. `momos serve --lan` is the only way to change that.

### Chat from another device

```bash
momos serve --lan
```

This rebinds Ollama to all interfaces and tells it which browser origins to accept, then prints the addresses:

```
  Ollama:            http://192.168.1.42:11434
  OpenAI-compatible: http://192.168.1.42:11434/v1
                     (any non-empty key; the server ignores it)
  Chat page:         run 'momos ui' in this session, then open
                     the URL it prints (port 8080 by default)
```

It returns to the prompt once the server answers, so `momos ui` can be started
from the same session afterwards, and the phone and anything else on your Wi-Fi
can both chat with the same model.

The command only reports success after it has confirmed the server is really
reachable on the phone's Wi-Fi address. A `127.0.0.1` server looks identical to
an exposed one from inside the phone, so a bind that quietly failed would
otherwise be announced as exposure.

**OpenAI-compatible API**

`http://<phone-ip>:11434/v1` is a drop-in OpenAI base URL, so existing SDKs and tools work unchanged:

```bash
curl http://192.168.1.42:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3.2:3b","messages":[{"role":"user","content":"hi"}]}'
```

Some clients insist on an API key. Ollama requires a non-empty one and then ignores it, so any string will do — `ollama` is the conventional choice.

> [!WARNING]
> **There is no authentication.** Anyone on your Wi-Fi who has the address gets the whole API, not just chat — they can list, pull and **delete** your models. The origin check stops other *websites* from reaching your phone; it does nothing about `curl`. Use `--lan` only on a network you trust, and run `momos stop` when you are done.

> [!NOTE]
> Exposure is not remembered. A server started later by `momos chat` or `momos models` comes back private, and so does one after a reboot — re-run `momos serve --lan`. If you run it while a private server is already up, it says so rather than appearing to succeed: the bind only changes on a restart, so it tells you to `momos stop` first.

> [!TIP]
> If you only want to chat from a browser, you do not need `--lan` on the phone that is serving the page. See below.

### Web UI

```bash
momos ui                         # Serve on port 8080
momos ui 9000                    # Serve on a different port
momos ui stop                    # Stop the background web server
```

The UI is served to your Wi-Fi, so you can open it from a laptop at the network
address it prints:

```
MOMOS UI — running in the background

  Phone:   http://localhost:8080
  Network: http://192.168.1.42:8080   <- open this on your laptop
```

The page is a chat interface with a model picker and a list of saved chats.
Replies are rendered as Markdown — headings, lists, tables, and fenced code with
the language named — by a small parser written into the page, since fetching one
over the network would be the one thing on it that fails when the phone is
offline. It covers what a small model actually writes and shows anything else as
plain text rather than guessing.

Send starts a reply and **Stop** cancels one mid-generation, which matters when
a small model gets stuck in a loop. The ↻ beside the model picker re-reads the
installed models. Run on the phone, `momos ui` also opens the page in the
phone's browser for you.

The picker offers everything `momos models` would list, and each chat keeps the
model it was using — so a DeepSeek R1 reasoning thread and a small quick model
can sit side by side. A new chat starts from whichever model you used last; run
`momos chat <model>` once if the page tells you no model is chosen. Picking a
different model mid-conversation changes who answers from the next message on,
and the replies already on screen stay as they were.

Chats are saved in the browser, not on the phone, and reopening the page brings
back the one you left off in. Two consequences worth knowing:

- **The list is per browser.** The laptop's chats and the phone's chats are
  separate, and so are two browsers on the laptop. A chat begun on one does not
  appear on the other.
- **Clearing site data clears them.** A private window will not save them at all,
  and says so when it opens.

Keeping them on the phone instead would mean a second server process holding
state, which is memory the model wants more than your chat titles do.

Reasoning is not saved with a chat — the fold is working-out you have already
read, and keeping it would multiply the storage for no return.

Opened **on the phone**, it reaches Ollama over loopback and needs nothing else. Opened **from a laptop**, it needs `momos serve --lan` running too.

Running `momos ui` again while it is already serving reports the running one
rather than starting a second. `momos stop` does not stop it — the web server
has its own lifecycle, and `momos ui stop` is what ends it.

> [!WARNING]
> The port has no authentication — anyone on your Wi-Fi who has the address can
> open the page. Stop it with `momos ui stop` when you are done.

> [!IMPORTANT]
> Both the page and the `--lan` flag ship with the installer, so an existing
> install picks them up from `momos update`. Running `momos ui` alone on an
> install that predates them will serve the old placeholder page, and
> `momos serve --lan` will ignore the flag. Update first.

`momos ui` uses [darkhttpd](https://github.com/emikulic/darkhttpd) (about 1MB),
installing it on first use. If darkhttpd is unavailable it falls back to
`python3 -m http.server` instead.

### Update & Uninstall
```bash
momos update                     # Update MOMOS scripts and Ollama
momos uninstall                  # Remove Ollama, MOMOS and (if you confirm) models
momos help                       # Show all commands
```

`momos uninstall` stops both background servers, removes Ollama, the launcher
and `~/.momos`, and asks before deleting downloaded models.

### Testing a branch

The installers and `momos update` follow the ref they were installed from. Set
`MOMOS_BRANCH` to install or update from a branch — the value is checked before
it reaches a URL, and it is recorded so later updates keep following it:

```bash
MOMOS_BRANCH=my-branch bash -c "$(curl -fsSL https://raw.githubusercontent.com/Sidharth-e/MOMOS/my-branch/scripts/momos.sh)"
```

---

## Requirements

- **Android 7.0+**
- **64-bit device** (`arm64` or `x86_64`) — Ollama's Termux package is built for
  64-bit only. On a 32-bit device, see [32-bit devices](#32-bit-devices)
- **Termux** (install from [F-Droid](https://f-droid.org/packages/com.termux/) or [GitHub](https://github.com/termux/termux-app/releases), avoid Play Store builds)
- **RAM**: 2GB minimum (4GB+ recommended for 3B models, 6–8GB for 7B models)
- **Free Storage**: 2GB minimum; ~2.5GB for a 3B model, ~6GB for a 7B model
- **No root required**

### 32-bit devices

A 32-bit phone — or a 64-bit phone with a 32-bit Termux, which reports
`armv8l` — cannot install the native Ollama package. Both installers notice
this and point you at the legacy script, which sets up a Debian container via
PRoot and installs Ollama inside it instead:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Sidharth-e/MOMOS/main/scripts/legacy/proot/momos.sh)"
```

It needs roughly 1–2GB more storage and runs more slowly, but the `momos`
command it installs is the same. Running `scripts/setup.sh` picks the right one
for the device automatically.

---

## New to Termux?

If you just installed Termux, run this setup script first. It updates packages,
grants storage permissions, and then offers to install MOMOS — picking native or
legacy for your device:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/Sidharth-e/MOMOS/main/scripts/setup.sh)"
```

<details>
<summary>Manual setup commands</summary>

```bash
pkg update && pkg upgrade -y
pkg install curl -y
termux-setup-storage
```
Then run the Quick Install command above.
</details>

---

## How It Works

```
Termux (Android)
├── Ollama server (native, background)
│     └─ local model (<7B)
├── darkhttpd ──> the web UI page
└── 'momos' launcher command

32-bit devices: the same CLI, with Debian
under PRoot providing Ollama instead.
```

1. **Ollama**: installed as a native Termux package and run in the background —
   no container, no root. It listens on the phone only unless you pass `--lan`.
2. **Web UI**: a self-contained static page, served to the phone or your Wi-Fi
   by [darkhttpd](https://github.com/emikulic/darkhttpd).
3. **MOMOS launcher**: a bash script in `$PREFIX/bin/momos` that handles
   starting the server, serving the page, attaching to chats, and managing
   models with simple arguments.

---

## Troubleshooting

### Installation fails
Check the log:
```bash
cat ~/.momos/install.log
```

### "Permission denied"
Run:
```bash
termux-setup-storage
```
Then run the installer again.

### Model runs slowly or Termux crashes (Killed / OOM)
The model is using more RAM than your device has available. Switch to a smaller model:
```bash
momos chat llama3.2:1b
# or
momos chat deepseek-r1:1.5b
```

### Keeping Termux alive in background
Run `termux-wake-lock` to keep Android from sleeping Termux during inference.

### The installer says Ollama needs a 64-bit device
That build is 64-bit only. The installer prints the legacy command to use
instead — see [32-bit devices](#32-bit-devices). `scripts/setup.sh` makes this
choice for you.

### The laptop can't reach the model

Two causes look identical from the browser, so check both.

**The server is private.** `momos chat` and `momos models` start Ollama on the phone only. Run:

```bash
momos serve --lan
```

If it reports that the server is already running but only on this phone, that is the answer — run `momos stop` and then `momos serve --lan` again. The bind only changes on a restart.

**The browser's origin is no longer allowed.** `--lan` pins the origin to the phone's address at the moment it starts. If the phone got a new address since (a fresh DHCP lease, or a different network), the page still loads but its requests are refused. Restart `momos serve --lan` to re-pin it.

### The web page still loads after `momos stop`

The Ollama server and the web server have separate lifecycles. `momos stop`
ends the model server; `momos ui stop` ends the page.

### The web page says no model is chosen

It reads the last model you used. Pick one in Termux first:

```bash
momos chat llama3.2:1b
```

---

## License

MIT · [View License](LICENSE)
