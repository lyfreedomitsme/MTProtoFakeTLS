#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'
CONFIG_FILE="$HOME/.tg-ui-config.env"
CONTAINER_NAME="mtproto-proxy"

# Make sudo optional if not installed
if ! command -v sudo >/dev/null; then
  sudo() { "$@"; }
fi

# Load state
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    FAKE_DOMAIN="ya.ru"
    PORT="443"
    SECRET=""
    SERVER_IP=""
fi

function save_config() {
    cat > "$CONFIG_FILE" << EOF
FAKE_DOMAIN="${FAKE_DOMAIN}"
PORT="${PORT}"
SECRET="${SECRET}"
SERVER_IP="${SERVER_IP}"
EOF
}

function generate_secret() {
    DOMAIN_HEX=$(echo -n "$FAKE_DOMAIN" | xxd -ps | tr -d '\n')
    DOMAIN_LEN=${#DOMAIN_HEX}
    NEEDED=$((30 - DOMAIN_LEN))
    
    # Check if openssl exists, otherwise fallback to /dev/urandom
    if command -v openssl >/dev/null 2>&1; then
        RANDOM_HEX=$(openssl rand -hex 15 | cut -c1-$NEEDED)
    else
        RANDOM_HEX=$(head -c 15 /dev/urandom | xxd -p | cut -c1-$NEEDED)
    fi
    
    SECRET="ee${DOMAIN_HEX}${RANDOM_HEX}"
}

function start_proxy() {
    echo -e "\n${YELLOW}🚀 Starting/Restarting MTProto Proxy...${NC}"
    
    if [ -z "$SECRET" ]; then
        generate_secret
    fi
    
    # Check if port is in use and assign a new one if necessary
    if command -v ss >/dev/null 2>&1; then
        if ss -tuln | grep -q ":${PORT} "; then
            for alt_port in 8443 8444 8445 4443; do
                if ! ss -tuln | grep -q ":${alt_port} "; then
                    PORT=$alt_port
                    break
                fi
            done
        fi
    fi

    echo -n "🛑 Stopping old container... "
    sudo docker stop ${CONTAINER_NAME} >/dev/null 2>&1 || true
    sudo docker rm ${CONTAINER_NAME} >/dev/null 2>&1 || true
    echo "Done."

    echo -n "📦 Starting new container... "
    if sudo docker run -d --name ${CONTAINER_NAME} --restart unless-stopped -p ${PORT}:443 -e SECRET="${SECRET}" telegrammessenger/proxy >/dev/null 2>&1; then
        sleep 3
        if sudo docker ps | grep -q ${CONTAINER_NAME}; then
            if command -v curl >/dev/null 2>&1; then
                SERVER_IP=$(curl -s ifconfig.me)
            else
                SERVER_IP="YOUR_SERVER_IP"
            fi
            save_config
            echo -e "${GREEN}✅ Proxy started successfully!${NC}"
            show_link
        else
            echo -e "${RED}❌ Failed to start proxy (container immediately exited).${NC}"
            sudo docker logs ${CONTAINER_NAME}
        fi
    else
        echo -e "${RED}❌ Failed to run docker command.${NC}"
    fi
}

function show_link() {
    if [ -z "$SERVER_IP" ] || [ -z "$SECRET" ]; then
        echo -e "${RED}⚠️  Proxy config missing! Start the proxy first.${NC}"
        return
    fi
    echo -e "\n📊 ${BLUE}ИНФОРМАЦИЯ ДЛЯ ПОДКЛЮЧЕНИЯ:${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "🌐 Сервер: ${GREEN}${SERVER_IP}${NC}"
    echo -e "🔌 Порт: ${GREEN}${PORT}${NC}"
    echo -e "🔑 Секрет: ${YELLOW}${SECRET}${NC}"
    echo -e "🎭 Fake TLS: ${BLUE}${FAKE_DOMAIN}${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🔗 Ссылка для подключения:"
    echo -e "${GREEN}tg://proxy?server=${SERVER_IP}&port=${PORT}&secret=${SECRET}${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

function set_domain() {
    echo -e "\nТекущий домен маскировки: ${BLUE}${FAKE_DOMAIN}${NC}"
    echo -n "Введите новый домен (например, google.com) или оставьте пустым для отмены: "
    read input
    if [ -n "$input" ]; then
        FAKE_DOMAIN="$input"
        generate_secret
        save_config
        echo -e "${GREEN}✅ Домен маскировки обновлен на $FAKE_DOMAIN${NC}"
        echo -n "Перезапустить прокси для применения настроек? (y/n) [y]: "
        read restart_ok
        restart_ok=${restart_ok:-y}
        if [[ "$restart_ok" == "y" || "$restart_ok" == "Y" ]]; then
            start_proxy
        fi
    else
        echo -e "${YELLOW}Отменено.${NC}"
    fi
}

function stop_proxy() {
    echo -e "\n🛑 Остановка и удаление контейнера прокси..."
    sudo docker stop ${CONTAINER_NAME} >/dev/null 2>&1 || true
    sudo docker rm ${CONTAINER_NAME} >/dev/null 2>&1 || true
    echo -e "${GREEN}Контейнер прокси успешно остановлен и удален.${NC}"
}

function set_port() {
    echo -e "\nТекущий порт: ${BLUE}${PORT}${NC}"
    echo -n "Введите новый порт (например, 443, 8443) или оставьте пустым для отмены: "
    read input
    if [ -n "$input" ]; then
        if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 1 ] && [ "$input" -le 65535 ]; then
            PORT="$input"
            save_config
            echo -e "${GREEN}✅ Порт обновлен на $PORT${NC}"
            echo -n "Перезапустить прокси для применения настроек? (y/n) [y]: "
            read restart_ok
            restart_ok=${restart_ok:-y}
            if [[ "$restart_ok" == "y" || "$restart_ok" == "Y" ]]; then
                start_proxy
            fi
        else
            echo -e "${RED}❌ Неверный формат порта (от 1 до 65535)!${NC}"
        fi
    else
        echo -e "${YELLOW}Отменено.${NC}"
    fi
}

function show_menu() {
    while true; do
        echo -e "\n=== ${BLUE}MTProto Proxy Manager (tg-ui)${NC} ==="
        if sudo docker ps | grep -q ${CONTAINER_NAME}; then
            echo -e "Статус: ${GREEN}▶ Запущен (Порт: $PORT)${NC}"
        else
            echo -e "Статус: ${RED}■ Остановлен${NC}"
        fi
        echo "1) 🚀 Запустить / Перезапустить прокси"
        echo "2) 🎭 Изменить Fake TLS домен (Текущий: $FAKE_DOMAIN)"
        echo "3) 🔌 Изменить порт (Текущий: $PORT)"
        echo "4) 🔗 Показать ссылку для подключения"
        echo "5) 🛑 Остановить и удалить контейнер"
        echo "6) 📋 Посмотреть логи"
        echo "7) ❌ Выход"
        echo -n "Выберите действие (1-7): "
        read choice

        case $choice in
            1) start_proxy ;;
            2) set_domain ;;
            3) set_port ;;
            4) show_link ;;
            5) stop_proxy ;;
            6) 
               echo -e "\n📋 Последние логи контейнера:"
               sudo docker logs --tail 20 ${CONTAINER_NAME} || echo "Логи недоступны."
               ;;
            7) echo "Выход..."; exit 0 ;;
            *) echo -e "${RED}Неверная команда!${NC}" ;;
        esac
    done
}

# Start the interactive UI or Auto mode
if [ "$1" == "--auto" ]; then
    start_proxy
else
    show_menu
fi
