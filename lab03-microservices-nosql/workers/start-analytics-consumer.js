#!/usr/bin/env node

/**
 * Script para iniciar o Analytics Consumer
 * 
 * Uso:
 *   node start-analytics-consumer.js
 *   npm run consumer:analytics
 */

const AnalyticsConsumer = require('./analyticsConsumer');

console.clear();
console.log('╔═══════════════════════════════════════════╗');
console.log('║    ANALYTICS CONSUMER - Worker Service    ║');
console.log('║    Listening to: list.checkout.#          ║');
console.log('║    Processing: Dashboard & Statistics     ║');
console.log('╚═══════════════════════════════════════════╝\n');

const consumer = new AnalyticsConsumer();

// Iniciar consumer
consumer.connect().catch(error => {
    console.error('Falha ao iniciar consumer:', error);
    process.exit(1);
});

// Comando para exibir dashboard manualmente
process.stdin.on('data', (data) => {
    const input = data.toString().trim();
    if (input === 'stats' || input === 'dashboard') {
        consumer.displayDashboard();
    } else if (input === 'help') {
        console.log('\n📋 Comandos disponíveis:');
        console.log('   stats/dashboard - Exibir dashboard atualizado');
        console.log('   help - Exibir esta ajuda');
        console.log('   Ctrl+C - Encerrar consumer\n');
    }
});

// Graceful shutdown
const shutdown = async (signal) => {
    console.log(`\n\n⚠️  Recebido ${signal}, encerrando gracefully...`);
    await consumer.close();
    console.log('✓ Analytics Consumer encerrado com sucesso');
    process.exit(0);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// Keep alive e permitir input
process.stdin.resume();
process.stdin.setEncoding('utf8');

console.log('💡 Dica: Digite "stats" para ver o dashboard ou "help" para comandos\n');