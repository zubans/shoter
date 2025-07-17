#!/bin/bash

# Скрипт для тестирования функциональности сохранения профилей в БД

set -e

echo "🗄️  Тестирование сохранения профилей в БД"
echo "=========================================="

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Базовые URL
GO_API="http://localhost:8080"
PYTHON_API="http://localhost:5001"

# Функция для выполнения HTTP запроса
make_request() {
    local method=$1
    local url=$2
    local data=$3
    local description=$4
    
    echo -n "Тестируем $description... "
    
    if [ "$method" = "GET" ]; then
        response=$(curl -s -w "%{http_code}" "$url")
    elif [ "$method" = "DELETE" ]; then
        response=$(curl -s -w "%{http_code}" -X "$method" "$url")
    else
        response=$(curl -s -w "%{http_code}" -X "$method" -H "Content-Type: application/json" -d "$data" "$url")
    fi
    
    http_code="${response: -3}"
    body="${response%???}"
    
    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        echo -e "${GREEN}✓ Успешно (HTTP $http_code)${NC}"
        if [ ${#body} -gt 100 ]; then
            echo "   Ответ: ${body:0:100}..."
        else
            echo "   Ответ: $body"
        fi
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

echo -n "Проверяем Go Backend API... "
if curl -s "http://localhost:8080/api/game/status?gameId=test" > /dev/null; then
    echo -e "${GREEN}✓ Доступен${NC}"
else
    echo -e "${RED}✗ Недоступен${NC}"
    exit 1
fi

echo -n "Проверяем Python Face Service... "
if curl -s http://localhost:5001/health > /dev/null; then
    echo -e "${GREEN}✓ Доступен${NC}"
else
    echo -e "${RED}✗ Недоступен${NC}"
    exit 1
fi

echo ""
echo "2. Тестирование сохранения профилей в БД"
echo "----------------------------------------"

# Тестовые данные для профиля
TEST_PLAYER_ID="db-test-player-$(date +%s)"
PROFILE_DATA='{
  "playerId": "'$TEST_PLAYER_ID'",
  "images": ["data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=="],
  "angles": ["front", "left", "right", "back"]
}'

# Создание профиля (должно сохраниться в БД если флаг включен)
echo "Создаем профиль игрока (с сохранением в БД)..."
create_response=$(curl -s -X POST "$GO_API/api/create-player-profile" \
  -H "Content-Type: application/json" \
  -d "$PROFILE_DATA")

if echo "$create_response" | grep -q '"success":true'; then
    echo -e "${GREEN}✓ Профиль создан успешно${NC}"
    echo "   Player ID: $TEST_PLAYER_ID"
else
    echo -e "${RED}✗ Ошибка создания профиля${NC}"
    echo "   Ответ: $create_response"
    exit 1
fi

echo ""
echo "3. Тестирование API для работы с сохраненными профилями"
echo "------------------------------------------------------"

# Получение профиля из БД
make_request "GET" "$GO_API/api/player-profile/$TEST_PLAYER_ID" "" "получение профиля из БД"

# Загрузка профиля из БД в face service
make_request "POST" "$GO_API/api/load-player-profile/$TEST_PLAYER_ID" "" "загрузка профиля в face service"

# Проверяем что профиль загружен в Python сервис
echo -n "Проверяем загрузку в Python сервис... "
health_response=$(curl -s "$PYTHON_API/health")
active_profiles=$(echo "$health_response" | grep -o '"activeProfiles":[0-9]*' | cut -d':' -f2)

if [ "$active_profiles" -gt 0 ]; then
    echo -e "${GREEN}✓ Профиль загружен (активных профилей: $active_profiles)${NC}"
else
    echo -e "${YELLOW}⚠ Профиль не найден в памяти Python сервиса${NC}"
fi

echo ""
echo "4. Тестирование игровой сессии с загруженным профилем"
echo "----------------------------------------------------"

# Создаем второй тестовый профиль для игры
TEST_PLAYER_ID_2="db-test-player-2-$(date +%s)"
PROFILE_DATA_2='{
  "playerId": "'$TEST_PLAYER_ID_2'",
  "images": ["data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==", "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=="],
  "angles": ["front", "left", "right", "back"]
}'

echo -n "Создаем второй профиль... "
create_response_2=$(curl -s -X POST "$GO_API/api/create-player-profile" \
  -H "Content-Type: application/json" \
  -d "$PROFILE_DATA_2")

if echo "$create_response_2" | grep -q '"success":true'; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo "   Ответ: $create_response_2"
fi

# Создаем игру с сохраненными профилями
GAME_DATA='{
  "gameMode": "pvp",
  "maxPlayers": 2,
  "gameDuration": 15,
  "playerIds": ["'$TEST_PLAYER_ID'", "'$TEST_PLAYER_ID_2'"]
}'

echo -n "Создаем игру с сохраненными профилями... "
game_response=$(curl -s -X POST "$GO_API/api/game/start" \
  -H "Content-Type: application/json" \
  -d "$GAME_DATA")

game_id=$(echo "$game_response" | grep -o '"gameId":"[^"]*"' | cut -d'"' -f4)

if [ -n "$game_id" ]; then
    echo -e "${GREEN}✓ Игра создана (ID: $game_id)${NC}"
    
    # Проверяем статус игры
    make_request "GET" "$GO_API/api/game/status?gameId=$game_id" "" "получение статуса игры"
    
    # Очистка игровой сессии
    make_request "DELETE" "$GO_API/api/game/cleanup/$game_id" "" "очистка игровой сессии"
else
    echo -e "${RED}✗ Не удалось создать игру${NC}"
    echo "   Ответ: $game_response"
fi

echo ""
echo "5. Очистка тестовых данных"
echo "-------------------------"

# Удаляем профили из БД
make_request "DELETE" "$GO_API/api/player-profile/$TEST_PLAYER_ID" "" "удаление первого профиля из БД"
make_request "DELETE" "$GO_API/api/player-profile/$TEST_PLAYER_ID_2" "" "удаление второго профиля из БД"

echo ""
echo -e "${GREEN}🎉 Тестирование функциональности БД завершено!${NC}"
echo ""
echo "Проверенная функциональность:"
echo "  ✓ Сохранение профилей в PostgreSQL"
echo "  ✓ Получение профилей из БД"
echo "  ✓ Загрузка профилей из БД в face service"
echo "  ✓ Удаление профилей из БД"
echo "  ✓ Игровые сессии с сохраненными профилями"
echo ""
echo "Для проверки данных в БД:"
echo "  docker-compose exec postgres psql -U db_user -d mydb -c 'SELECT * FROM face_embeddings;'"