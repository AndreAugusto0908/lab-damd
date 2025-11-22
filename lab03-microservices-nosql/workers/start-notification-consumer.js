#!/usr/bin/env node

/**
 * Script para iniciar o Notification Consumer
 * 
 * Uso:
 *   node start-notification-consumer.js
 *   npm run consumer:notification
 */

const NotificationConsumer = require('./notificationConsumer');

console.clear();
console.log('╔═══════════════════════════════════════════╗');
console.log('║   NOTIFICATION CONSUMER - Worker Service  ║');
console.log('║   Listening to: list.checkout.#          ║');
console.log('╚═══════════════════════════════════════════╝\n');

const consumer = new NotificationConsumer();

// Iniciar consumer
consumer.connect().catch(error => {
    console.error('Falha ao iniciar consumer:', error);
    process.exit(1);
});

// Graceful shutdown
const shutdown = async (signal) => {
    console.log(`\n\n⚠️  Recebido ${signal}, encerrando gracefully...`);
    await consumer.close();
    console.log('✓ Consumer encerrado com sucesso');
    process.exit(0);
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

// Keep alive
process.stdin.resume();