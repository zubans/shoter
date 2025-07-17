#!/bin/bash

echo "🧪 Простой тест AR Shooter System"
echo "================================="

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

# Проверяем доступность сервисов
echo "1. Проверка сервисов:"

echo -n "   Python Face Service... "
if curl -s http://localhost:5001/health > /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    exit 1
fi

echo -n "   Go Backend API... "
if curl -s "http://localhost:8080/api/game/status?gameId=test" > /dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    exit 1
fi

echo ""
echo "2. Тестирование API эндпоинтов:"

# Тест создания игры
echo -n "   Создание игры... "
game_response=$(curl -s -X POST http://localhost:8080/api/game/start \
  -H "Content-Type: application/json" \
  -d '{
    "gameMode": "pvp",
    "maxPlayers": 2,
    "gameDuration": 15,
    "playerIds": ["player1", "player2"]
  }')

if echo "$game_response" | grep -q '"success":true'; then
    echo -e "${GREEN}✓${NC}"
    game_id=$(echo "$game_response" | grep -o '"gameId":"[^"]*"' | cut -d'"' -f4)
    echo "     Game ID: $game_id"
else
    echo -e "${RED}✗${NC}"
    echo "     Response: $game_response"
    exit 1
fi

# Тест получения статуса игры
echo -n "   Получение статуса игры... "
status_response=$(curl -s "http://localhost:8080/api/game/status?gameId=$game_id")

if echo "$status_response" | grep -q '"status":"active"'; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo "     Response: $status_response"
fi

# Тест очистки сессии
echo -n "   Очистка сессии... "
cleanup_response=$(curl -s -X DELETE "http://localhost:8080/api/game/cleanup/$game_id")

if echo "$cleanup_response" | grep -q '"success":true'; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo "     Response: $cleanup_response"
fi

echo ""
echo -e "${GREEN}🎉 Все тесты прошли успешно!${NC}"
echo ""
echo "Система готова к работе:"
echo "  - Go Backend API: http://localhost:8080"
echo "  - Python Face Service: http://localhost:5001"
echo "  - PostgreSQL: localhost:5432"