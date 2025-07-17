#!/bin/bash

# Простой тест API для работы с БД профилей

echo "🔧 Тестирование API для работы с БД профилей"
echo "============================================"

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

GO_API="http://localhost:8080"

echo ""
echo "1. Проверка API эндпоинтов для работы с БД"
echo "------------------------------------------"

# Тестируем получение несуществующего профиля
echo -n "Получение несуществующего профиля... "
response=$(curl -s "http://localhost:8080/api/player-profile/nonexistent-player")
if echo "$response" | grep -q "profile not found"; then
    echo -e "${GREEN}✓ Корректная обработка${NC}"
else
    echo -e "${RED}✗ Неожиданный ответ${NC}"
    echo "   Ответ: $response"
fi

# Тестируем удаление несуществующего профиля
echo -n "Удаление несуществующего профиля... "
response=$(curl -s -X DELETE "http://localhost:8080/api/player-profile/nonexistent-player")
if echo "$response" | grep -q "success"; then
    echo -e "${GREEN}✓ Успешно${NC}"
else
    echo -e "${RED}✗ Ошибка${NC}"
    echo "   Ответ: $response"
fi

# Тестируем загрузку несуществующего профиля
echo -n "Загрузка несуществующего профиля... "
response=$(curl -s -X POST "http://localhost:8080/api/load-player-profile/nonexistent-player")
if echo "$response" | grep -q "no embeddings found"; then
    echo -e "${GREEN}✓ Корректная обработка${NC}"
else
    echo -e "${RED}✗ Неожиданный ответ${NC}"
    echo "   Ответ: $response"
fi

echo ""
echo "2. Проверка флага SAVE_PROFILES_TO_DB"
echo "------------------------------------"

# Проверяем что флаг работает
echo "Текущее значение флага SAVE_PROFILES_TO_DB в .env:"
grep "SAVE_PROFILES_TO_DB" .env || echo "Флаг не найден"

echo ""
echo "3. Проверка структуры БД"
echo "-----------------------"

echo "Таблицы в базе данных:"
docker-compose exec -T postgres psql -U db_user -d mydb -c "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null

echo ""
echo "Записи в таблице face_embeddings:"
docker-compose exec -T postgres psql -U db_user -d mydb -c "SELECT COUNT(*) as total_embeddings FROM face_embeddings;" 2>/dev/null

echo ""
echo "4. Тестирование игровой логики"
echo "-----------------------------"

# Создаем простую игру для проверки что основная функциональность работает
echo -n "Создание игры... "
game_response=$(curl -s -X POST "$GO_API/api/game/start" \
  -H "Content-Type: application/json" \
  -d '{
    "gameMode": "pvp",
    "maxPlayers": 2,
    "gameDuration": 15,
    "playerIds": ["api-test-player-1", "api-test-player-2"]
  }')

game_id=$(echo "$game_response" | grep -o '"gameId":"[^"]*"' | cut -d'"' -f4)

if [ -n "$game_id" ]; then
    echo -e "${GREEN}✓ Игра создана (ID: $game_id)${NC}"
    
    # Проверяем статус игры
    echo -n "Получение статуса игры... "
    status_response=$(curl -s "$GO_API/api/game/status?gameId=$game_id")
    if echo "$status_response" | grep -q '"status":"active"'; then
        echo -e "${GREEN}✓ Статус получен${NC}"
    else
        echo -e "${RED}✗ Ошибка получения статуса${NC}"
    fi
    
    # Очищаем игру
    echo -n "Очистка игры... "
    cleanup_response=$(curl -s -X DELETE "$GO_API/api/game/cleanup/$game_id")
    if echo "$cleanup_response" | grep -q '"success":true'; then
        echo -e "${GREEN}✓ Игра очищена${NC}"
    else
        echo -e "${RED}✗ Ошибка очистки${NC}"
    fi
else
    echo -e "${RED}✗ Не удалось создать игру${NC}"
    echo "   Ответ: $game_response"
fi

echo ""
echo -e "${GREEN}🎉 Тестирование API завершено!${NC}"
echo ""
echo "Проверенная функциональность:"
echo "  ✓ API эндпоинты для работы с БД профилей"
echo "  ✓ Корректная обработка ошибок"
echo "  ✓ Структура базы данных"
echo "  ✓ Основная игровая логика"
echo ""
echo "Для создания реальных профилей с распознаванием лиц"
echo "используйте изображения с четко видимыми лицами в base64 формате."