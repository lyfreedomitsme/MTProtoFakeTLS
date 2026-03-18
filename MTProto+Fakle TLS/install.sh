#!/bin/bash
set -e

# Make sudo optional if not installed (e.g. Git Bash on Windows or some root environments)
if ! command -v sudo >/dev/null; then
  sudo() { "$@"; }
fi

echo -e "\n🚀 Starting MTProto Proxy CLI Tool Installation...\n"

# Check for docker
if ! command -v docker >/dev/null 2>&1; then
    echo "🐳 Docker is not installed. Attempting to install..."
    if command -v apt >/dev/null 2>&1; then
        sudo apt update && sudo apt upgrade -y
        sudo apt install docker.io xxd -y
    elif command -v yum >/dev/null 2>&1; then
        sudo yum update -y
        sudo yum install docker xxd -y
        sudo systemctl start docker
        sudo systemctl enable docker
    else
        echo "❌ Cannot install Docker automatically. Please install Docker and try again."
        exit 1
    fi
else
    echo "✅ Docker is already installed."
fi

echo "📦 Installing tg-ui..."
if [ -f "./tg-ui.sh" ]; then
    echo "Found local tg-ui.sh, installing..."
    sudo cp ./tg-ui.sh /usr/local/bin/tg-ui
else
    # Fallback to downloading from a generic GitHub placeholder 
    # USER: Replace the URL below with your actual GitHub Raw URL
    DOWNLOAD_URL="https://raw.githubusercontent.com/lyfreedomitsme/MTProtoFakeTLS/main/tg-ui.sh"
    echo "Downloading tg-ui.sh from remote ($DOWNLOAD_URL)..."
    sudo curl -sL "$DOWNLOAD_URL" -o /usr/local/bin/tg-ui
fi

sudo chmod +x /usr/local/bin/tg-ui

echo -e "\n🎉 Установка завершена!"
echo "👉 Автоматически поднимаем прокси..."
/usr/local/bin/tg-ui --auto

echo -e "\n💡 В будущем, для настройки, смены домена, остановки или просмотра логов, просто введи в консоли: tg-ui"
