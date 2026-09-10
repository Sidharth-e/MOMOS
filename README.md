# MOMOS — Mobile Models Ollama Setup 🚀

Run AI models locally on your Android phone using Termux. One command to install, one command to chat.

## Quick Install

Open **Termux** and paste:

```bash
curl -fsSL https://raw.githubusercontent.com/Sidharth-e/MOMOS/main/scripts/momos.sh | bash
```

That's it. The installer will:
- Check your device (RAM, storage, internet)
- Recommend the best model for your hardware
- Install everything automatically
- Give you a `momos` command for daily use

## Daily Usage

After install, just type:

```bash
momos                # interactive menu
momos chat           # start chatting with your last model
momos chat llama3.2  # chat with a specific model
momos models         # list, pull, or remove models
momos server         # manage the Ollama server
```

## Supported Models

| Model | Size | RAM Needed | Best For |
|-------|------|------------|----------|
| DeepSeek R1 1.5B | ~800MB | 2GB+ | Low-end devices, quick responses |
| DeepSeek R1 7B | ~4GB | 4GB+ | Balanced performance |
| DeepSeek R1 14B | ~8GB | 8GB+ | Higher quality output |
| DeepSeek R1 32B | ~20GB | 12GB+ | Best quality, flagship devices |
| Gemma 3 4B | ~2.5GB | 4GB+ | Google's efficient model |
| Llama 3.2 3B | ~2GB | 3GB+ | Meta's compact model |
| Any Ollama model | Varies | Varies | Enter any tag from [ollama.com/library](https://ollama.com/library) |

The installer auto-detects your RAM and highlights the recommended model.

## Requirements

- **Android 7.0+**
- **Termux** from [F-Droid](https://f-droid.org/packages/com.termux/) or [GitHub Releases](https://github.com/termux/termux-app/releases)
- **2GB+ free storage** (more for larger models)
- **Internet connection** for initial setup

> [!WARNING]
> Do **not** install Termux from Google Play Store — it's outdated and will not work.

## First-Time Termux Setup

If you've never used Termux before, run this single command — it handles everything:

```bash
curl -fsSL https://raw.githubusercontent.com/Sidharth-e/MOMOS/main/scripts/setup.sh | bash
```

This will update Termux, install essential tools, configure storage access, and offer to install MOMOS automatically.

<details>
<summary>Manual setup (alternative)</summary>

```bash
pkg update && pkg upgrade -y
pkg install curl -y
termux-setup-storage
```

Then run the MOMOS install command above.
</details>

## How It Works

```
┌─────────────────────────────────────────┐
│  Termux (Android)                       │
│  ┌───────────────────────────────────┐  │
│  │  Debian 12 (via PRoot)            │  │
│  │  ┌─────────────────────────────┐  │  │
│  │  │  Ollama Server (tmux)       │  │  │
│  │  │  └─ Your AI Model          │  │  │
│  │  └─────────────────────────────┘  │  │
│  └───────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

MOMOS sets up a Debian container inside Termux using PRoot (no root needed), installs Ollama inside it, and manages everything through the `momos` command.

## Troubleshooting

### Installation fails
```bash
cat ~/.momos/install.log
```
The full log is always saved. Share it when asking for help.

### "Permission denied"
```bash
termux-setup-storage
```
Then retry the install.

### Model too slow / crashes
Your device may not have enough RAM. Run `momos models` and switch to a smaller model:
```bash
momos chat deepseek-r1:1.5b
```

### Ollama server not running
```bash
momos server
```
This will start or reattach to the server.

### Start fresh
```bash
proot-distro remove debian
rm -rf ~/.momos
```
Then run the install command again.

## Manual Install (Alternative)

If you prefer cloning the repo:

```bash
pkg install git -y
git clone https://github.com/Sidharth-e/MOMOS.git
bash MOMOS/scripts/momos.sh
```

## Updating

Re-run the install command — it's safe to run multiple times. It will skip steps that are already done and update what needs updating.

---

**Enjoy AI on your phone! 🧠✨**

*Star this repo if it helped you ⭐*
