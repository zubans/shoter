#!/bin/bash

# Скрипт для тестирования AR Shooter Backend System

set -e

echo "🚀 Тестирование AR Shooter Backend System"
echo "=========================================="

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Базовые URL
GO_API="http://localhost:8080"
PYTHON_API="http://localhost:5001"

# Функция для проверки доступности сервиса
check_service() {
    local url="$1"
    local name="$2"
    
    echo -n "Проверяем $name... "
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" "$url")
    
    if [[ "$http_code" =~ ^[2-4][0-9][0-9]$ ]]; then
        echo -e "${GREEN}✓ Доступен (HTTP $http_code)${NC}"
        return 0
    else
        echo -e "${RED}✗ Недоступен (HTTP $http_code)${NC}"
        return 1
    fi
}

# Функция для выполнения HTTP запроса
make_request() {
    local method=$1
    local url=$2
    local data=$3
    local description=$4
    
    echo -n "Тестируем $description... "
    
    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "%{http_code}" "$url")
    else
        response=$(curl -s -w "%{http_code}" -X "$method" -H "Content-Type: application/json" -d "$data" "$url")
    fi
    
    http_code="${response: -3}"
    body="${response%???}"
    
    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        echo -e "${GREEN}✓ Успешно (HTTP $http_code)${NC}"
        echo "   Ответ: $body" | head -c 100
        echo ""
        return 0
    else
        echo -e "${RED}✗ Ошибка (HTTP $http_code)${NC}"
        echo "   Ответ: $body"
        return 1
    fi
}

echo ""
echo "1. Проверка доступности сервисов"
echo "--------------------------------"

check_service "$PYTHON_API/health" "Python Face Service"
check_service "$GO_API/api/game/status?gameId=test" "Go Backend API"

echo ""
echo "2. Тестирование Python Face Service"
echo "-----------------------------------"

# Тестовое base64 изображение (1x1 пиксель)
TEST_IMAGE="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=="

# Создание профиля в Python сервисе
PROFILE_DATA='{
  "playerId": "test-player-1",
  "images": ["'$TEST_IMAGE'", "'$TEST_IMAGE'", "'$TEST_IMAGE'", "'$TEST_IMAGE'"],
  "angles": ["front", "left", "right", "back"]
}'

make_request "POST" "$PYTHON_API/create-profile" "$PROFILE_DATA" "создание профиля в Python сервисе"

# Тестирование распознавания
RECOGNIZE_DATA='{
  "image": "'$TEST_IMAGE'",
  "sessionId": "test-session"
}'

make_request "POST" "$PYTHON_API/recognize" "$RECOGNIZE_DATA" "распознавание лица"

echo ""
echo "3. Тестирование Go Backend API"
echo "------------------------------"

# Создание профиля игрока через Go API
GO_PROFILE_DATA='{
  "playerId": "go-test-player-1",
  "images": ["'$TEST_IMAGE'", "'$TEST_IMAGE'", "'$TEST_IMAGE'", "'$TEST_IMAGE'"],
  "angles": ["front", "left", "right", "back"]
}'

make_request "POST" "$GO_API/api/create-player-profile" "$GO_PROFILE_DATA" "создание профиля через Go API"

# Создание второго игрока
GO_PROFILE_DATA2='{
  "playerId": "go-test-player-2", 
  "images": ["'$TEST_IMAGE'", "'$TEST_IMAGE'", "'$TEST_IMAGE'", "'$TEST_IMAGE'"],
  "angles": ["front", "left", "right", "back"]
}'

make_request "POST" "$GO_API/api/create-player-profile" "$GO_PROFILE_DATA2" "создание второго профиля"

# Запуск игры
GAME_DATA='{
  "gameMode": "pvp",
  "maxPlayers": 2,
  "gameDuration": 15,
  "playerIds": ["go-test-player-1", "go-test-player-2"]
}'

echo -n "Запускаем игру... "
game_response=$(curl -s -X POST -H "Content-Type: application/json" -d "$GAME_DATA" "$GO_API/api/game/start")
game_id=$(echo "$game_response" | grep -o '"gameId":"[^"]*"' | cut -d'"' -f4)

if [ -n "$game_id" ]; then
    echo -e "${GREEN}✓ Игра создана (ID: $game_id)${NC}"
    
    # Проверяем статус игры
    make_request "GET" "$GO_API/api/game/status?gameId=$game_id" "" "получение статуса игры"
    
    # Тестируем выстрел
    SHOT_DATA='{
      "shooterId": "go-test-player-1",
      "image": "'$TEST_IMAGE'",
      "timestamp": '$(date +%s000)'
    }'
    
    make_request "POST" "$GO_API/api/game/shot" "$SHOT_DATA" "выстрел игрока"
    
    # Очистка сессии
    make_request "DELETE" "$GO_API/api/game/cleanup/$game_id" "" "очистка игровой сессии"
    
else
    echo -e "${RED}✗ Не удалось создать игру${NC}"
    echo "   Ответ: $game_response"
fi

echo ""
echo "4. Очистка тестовых данных"
echo "-------------------------"

# Очистка профилей в Python сервисе
CLEANUP_DATA='{
  "sessionId": "test-session",
  "playerIds": ["test-player-1", "go-test-player-1", "go-test-player-2"]
}'

make_request "POST" "$PYTHON_API/cleanup-session" "$CLEANUP_DATA" "очистка профилей"

echo ""
echo -e "${GREEN}🎉 Тестирование завершено!${NC}"
echo ""
echo "Для мониторинга логов используйте:"
echo "  docker-compose logs -f"
echo ""
echo "Для остановки системы:"
echo "  docker-compose down"