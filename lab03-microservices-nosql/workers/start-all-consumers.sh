#!/bin/bash

# Script para iniciar todos os consumers em terminais separados
# Uso: ./start-all-consumers.sh

echo "╔════════════════════════════════════════════╗"
echo "║  Iniciando todos os consumers RabbitMQ     ║"
echo "╚════════════════════════════════════════════╝"
echo ""

# Verificar se está na pasta workers
if [ ! -f "notificationConsumer.js" ]; then
    echo "❌ Execute este script dentro da pasta 'workers'"
    exit 1
fi

# Verificar se node_modules existe
if [ ! -d "node_modules" ]; then
    echo "⚠️  Dependências não encontradas. Instalando..."
    npm install
fi

echo "🚀 Iniciando consumers..."
echo ""

# Iniciar com concurrently (ambos no mesmo terminal)
npm start

# Alternativa: iniciar em terminais separados (descomente se preferir)
# osascript -e 'tell app "Terminal" to do script "cd '"$PWD"' && npm run notification"'
# osascript -e 'tell app "Terminal" to do script "cd '"$PWD"' && npm run analytics"'