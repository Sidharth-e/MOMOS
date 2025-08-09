# MOMOS (Mobile Open-source Model Operating Script) - DeepSeek R1 Edition

A streamlined solution for running DeepSeek R1 AI model on Android devices using Termux, optimized for mobile performance.
## 📋 Requirements
- **Android device** with at least:
  - 8 GB RAM
  - Snapdragon 8 Gen 2 or equivalent CPU
  - 12 GB free storage
- **Termux** installed from the official GitHub or F-Droid source
- Stable internet connection

---

## 🚀 Installation

### 1. Install Termux
Download Termux from the **official GitHub releases page**:  
[https://github.com/termux/termux-app/releases](https://github.com/termux/termux-app/releases)  
or from **F-Droid**:  
[https://f-droid.org/packages/com.termux/](https://f-droid.org/packages/com.termux/)

> **Note:** Do not install Termux from the Google Play Store — it's outdated and unsupported.

---

### 2. Clone or Copy the Script
Open Termux and run:
```bash
pkg update && pkg upgrade -y
pkg install git -y
git clone https://github.com/yourusername/deepseek-termux.git
cd deepseek-termux
chmod +x install_deepseek.sh
````

---

### 3. Run the Script

```bash
./install_deepseek.sh
```

This will:

1. Install **Proot-Distro**
2. Install **Debian 12** inside Termux
3. Install **tmux** and **Ollama**
4. Download the **DeepSeek R1 1.5B** model
5. Start the Ollama server in a background TMUX session

---

## ▶️ Running DeepSeek R1

After installation:

```bash
proot-distro login debian
ollama run deepseek-r1:1.5b
```

If you installed another model (e.g., `8b`), change the command:

```bash
ollama run deepseek-r1:8b
```

---

## 🔄 Keeping Ollama Running in Background

The installation script starts Ollama in a **TMUX** session named `ollama_server`.

To check if it's running:

```bash
tmux attach-session -t ollama_server
```

Press `CTRL+B` then `D` to detach and leave it running.

If it’s not running:

```bash
tmux new-session -d -s ollama_server 'ollama serve'
```

---

## 🧹 Common Issues

### 1. `Permission Denied` when accessing storage

Run:

```bash
termux-setup-storage
```

Then grant permissions in Android Settings.

### 2. `Package not found` error

Make sure Termux packages are updated:

```bash
apt update && apt upgrade -y
```

### 3. Ollama server not running

Start it manually in TMUX:

```bash
tmux new-session -d -s ollama_server 'ollama serve'
```

---

## 📌 Notes

* Larger models (e.g., `8B`, `14B`, `32B`, `70B`) require much more RAM and storage.
* The 1.5B model is recommended for most Android devices for smoother performance.
* Use `CTRL+C` to stop the model and `CTRL+D` to exit Debian.

---

## 📜 License

This project is provided as-is under the MIT License.
Ollama and DeepSeek are trademarks of their respective owners.


