# MOMOS — Mobile Models Ollama Setup 🚀

Run AI models locally on your Android phone using Termux. One command to install, one command to chat.

![MOMOS installation in Termux](assets/termux.png)

## Quick Install

Open **Termux** and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/Sidharth-e/MOMOS/main/scripts/momos.sh -o /tmp/momos.sh && bash /tmp/momos.sh
```

The installer will:

- Check your device (RAM, storage, internet)
- Recommend the best model for your hardware
- Set up a Debian container via PRoot (no root needed)
- Install Ollama and pull your chosen model
- Add a `momos` command for daily use

## Usage

### Chat

```bash
momos                           # interactive menu
momos chat                      # chat with your last used model
momos chat deepseek-r1:1.5b     # chat with a specific model
```

### Manage Models

```bash
momos models list               # show installed models
momos models pull gemma3:4b     # download a new model
momos models delete llama3.2:3b # remove a model
```

Browse all available models at [ollama.com/library](https://ollama.com/library).

### Server Logs

```bash
momos logs                      # view live Ollama server logs (Ctrl+C to stop)
```

![Ollama server logs](assets/ollama-server.png)

> [!NOTE]
> You don't need to run `momos logs` to use MOMOS. The server starts automatically in the background when you run `momos chat` or `momos models`. This command is only for viewing live server activity.

### Help

```bash
momos help                      # show all commands with examples
```

## Supported Models

| Model | Download Size | RAM Needed | Best For |
|-------|--------------|------------|----------|
| DeepSeek R1 1.5B | ~800MB | 2GB+ | Low-end devices, quick responses |
| DeepSeek R1 7B | ~4GB | 4GB+ | Balanced performance |
| DeepSeek R1 14B | ~8GB | 8GB+ | Higher quality output |
| DeepSeek R1 32B | ~20GB | 12GB+ | Best quality, flagship devices |
| Gemma 3 4B | ~2.5GB | 4GB+ | Google's efficient model |
| Llama 3.2 3B | ~2GB | 3GB+ | Meta's compact model |

You can also enter any model tag from [ollama.com/library](https://ollama.com/library) during setup.

The installer auto-detects your RAM and highlights the recommended model.

## Requirements

- **Android 7.0+**
- **Termux** from [F-Droid](https://f-droid.org/packages/com.termux/) or [GitHub Releases](https://github.com/termux/termux-app/releases)
- **2GB+ free storage** (more for larger models)
- **Internet connection** for initial setup

> [!WARNING]
> Do **not** install Termux from Google Play Store — it's outdated and will not work.

## New to Termux?

If you've never used Termux before, run this first — it updates Termux, installs essential tools (curl, wget, git), sets up storage access, and then offers to install MOMOS:

```bash
curl -fsSL https://raw.githubusercontent.com/Sidharth-e/MOMOS/main/scripts/setup.sh -o /tmp/setup.sh && bash /tmp/setup.sh
```

<details>
<summary>Manual Termux setup (if you prefer)</summary>

```bash
pkg update && pkg upgrade -y
pkg install curl -y
termux-setup-storage
```

Then run the MOMOS install command from the Quick Install section.
</details>

## How It Works

```
┌─────────────────────────────────────────┐
│  Termux (Android)                       │
│  ┌───────────────────────────────────┐  │
│  │  Debian (via PRoot — no root)     │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │  Ollama Server (background) │  │  │
│  │  │  └─ Your AI Model          │  │  │
│  │  └─────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

MOMOS creates a Debian container inside Termux using PRoot (no root required), installs Ollama inside it, and manages everything through the `momos` command. The Ollama server starts automatically in the background when needed.

## Troubleshooting

### Installation fails

Check the log:

```bash
cat ~/.momos/install.log
```

### "Permission denied"

```bash
termux-setup-storage
```

Then retry the install.

### Model too slow or crashes

Your device may not have enough RAM. Switch to a smaller model:

```bash
momos chat deepseek-r1:1.5b
```

### "Could not connect to ollama server"

The server should start automatically. If it doesn't, try running `momos logs` to see any errors, then open a new Termux tab and run `momos chat`.

## Alternative: Install from Source

```bash
pkg install git -y
git clone https://github.com/Sidharth-e/MOMOS.git
bash MOMOS/scripts/momos.sh
```

## Updating

Re-run the install command — it's safe to run multiple times. Already-completed steps are skipped automatically.

## Uninstall

```bash
proot-distro remove debian
rm -rf ~/.momos
rm "$PREFIX/bin/momos"
```

---

MIT License · [View License](LICENSE)

**Enjoy AI on your phone! 🧠✨**
