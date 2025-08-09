@echo off
echo ==========================================
echo 🤖 MOMOS - DeepSeek R1 Setup Instructions
echo ==========================================
echo.
echo This script provides instructions for setting up DeepSeek R1
echo on Android devices using Termux.
echo.
echo 📱 PREREQUISITES:
echo - Android device with Android 7.0+
echo - Minimum 8GB RAM (16GB+ recommended)
echo - At least 12GB free storage
echo - Active internet connection
echo.
echo 🔧 SETUP STEPS:
echo.
echo 1. INSTALL TERMUX:
echo    - Download from: https://github.com/termux/termux-app/releases
echo    - Install the APK file
echo    - Enable "Install from Unknown Sources" in Android settings
echo.
echo 2. SETUP TERMUX:
echo    - Open Termux app
echo    - Run: termux-change-repo
echo    - Run: apt update && apt upgrade -y
echo.
echo 3. INSTALL DEBIAN:
echo    - Run: pkg install proot-distro -y
echo    - Run: proot-distro install debian
echo    - Run: proot-distro login debian
echo.
echo 4. INSTALL DEPENDENCIES:
echo    - Run: apt update && apt upgrade -y
echo    - Run: apt install tmux -y
echo    - Run: curl -fsSL https://ollama.ai/install.sh ^| sh
echo.
echo 5. INSTALL DEEPSEEK R1:
echo    - Run: tmux ollama serve
echo    - In new terminal: ollama pull deepseek-r1:1.5b
echo.
echo 6. RUN DEEPSEEK R1:
echo    - Run: ollama run deepseek-r1:1.5b
echo.
echo 📚 FOR DETAILED INSTRUCTIONS:
echo Read the README-DEEPSEEK-R1.md file
echo.
echo 🚀 QUICK START (after setup):
echo - Use the run-deepseek.sh script in Termux
echo - Or run: ollama run deepseek-r1:1.5b
echo.
echo 🔧 TROUBLESHOOTING:
echo - Run: ./scripts/termux-troubleshoot.sh in Termux
echo - Check system requirements
echo - Ensure sufficient storage and RAM
echo.
echo ==========================================
echo Happy AI Chatting! 🚀
echo ==========================================
pause
