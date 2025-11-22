const amqp = require('amqplib');
const fs = require('fs').promises;
const path = require('path');

class AnalyticsConsumer {
    constructor() {
        this.exchange = 'shopping_events';
        this.queueName = 'analytics_queue';
        this.routingKey = 'list.checkout.#';
        this.rabbitUrl = process.env.RABBITMQ_URL || 'amqp://localhost:5672';
        this.connection = null;
        this.channel = null;
        
        // Armazenar estatísticas em memória
        this.stats = {
            totalCheckouts: 0,
            totalSpent: 0,
            totalItems: 0,
            totalItemsPurchased: 0,
            checkoutsByUser: {},
            itemsFrequency: {},
            lastUpdate: null
        };
        
        this.analyticsFile = path.join(__dirname, 'analytics-data.json');
    }

    async connect() {
        try {
            console.log('=====================================');
            console.log('Analytics Consumer iniciando...');
            console.log(`RabbitMQ URL: ${this.rabbitUrl}`);
            console.log('=====================================\n');

            // Carregar dados anteriores se existirem
            await this.loadPreviousData();

            // Conectar ao RabbitMQ
            this.connection = await amqp.connect(this.rabbitUrl);
            this.channel = await this.connection.createChannel();

            // Declarar o exchange
            await this.channel.assertExchange(this.exchange, 'topic', {
                durable: true
            });

            // Declarar a fila (diferente da notification)
            await this.channel.assertQueue(this.queueName, {
                durable: true
            });

            // Vincular a fila ao exchange com a routing key
            await this.channel.bindQueue(
                this.queueName,
                this.exchange,
                this.routingKey
            );

            console.log(`✓ Conectado ao RabbitMQ`);
            console.log(`✓ Exchange: ${this.exchange}`);
            console.log(`✓ Queue: ${this.queueName}`);
            console.log(`✓ Routing Key: ${this.routingKey}`);
            console.log('\n📊 Aguardando eventos para análise...\n');

            // Exibir estatísticas atuais
            this.displayDashboard();

            // Configurar prefetch
            await this.channel.prefetch(1);

            // Consumir mensagens
            await this.channel.consume(this.queueName, async (msg) => {
                if (msg !== null) {
                    await this.processMessage(msg);
                }
            }, {
                noAck: false
            });

            // Handlers de erro
            this.connection.on('error', (err) => {
                console.error('❌ Erro na conexão RabbitMQ:', err.message);
                setTimeout(() => this.connect(), 5000);
            });

            this.connection.on('close', () => {
                console.log('⚠️  Conexão RabbitMQ fechada. Reconectando...');
                setTimeout(() => this.connect(), 5000);
            });

        } catch (error) {
            console.error('❌ Erro ao conectar no RabbitMQ:', error.message);
            console.log('⏳ Tentando reconectar em 5 segundos...\n');
            setTimeout(() => this.connect(), 5000);
        }
    }

    async loadPreviousData() {
        try {
            const data = await fs.readFile(this.analyticsFile, 'utf8');
            this.stats = JSON.parse(data);
            console.log('✓ Dados analíticos anteriores carregados\n');
        } catch (error) {
            // Arquivo não existe ainda, usar dados padrão
            console.log('ℹ️  Iniciando nova base de dados analíticos\n');
        }
    }

    async saveData() {
        try {
            await fs.writeFile(
                this.analyticsFile,
                JSON.stringify(this.stats, null, 2),
                'utf8'
            );
        } catch (error) {
            console.error('Erro ao salvar dados:', error.message);
        }
    }

    async processMessage(msg) {
        try {
            const content = JSON.parse(msg.content.toString());
            
            console.log('\n═══════════════════════════════════════');
            console.log('📈 Novo evento para análise!');
            console.log('───────────────────────────────────────');
            console.log(`Event Type: ${content.eventType}`);
            console.log(`Message ID: ${content.messageId}`);
            console.log(`Timestamp: ${content.timestamp}`);
            console.log('───────────────────────────────────────');

            if (content.eventType === 'list.checkout.completed') {
                await this.processCheckout(content.data);
            }

            console.log('═══════════════════════════════════════\n');

            // Acknowledge da mensagem
            this.channel.ack(msg);

        } catch (error) {
            console.error('❌ Erro ao processar mensagem:', error.message);
            this.channel.nack(msg, false, true);
        }
    }

    async processCheckout(data) {
        const { listId, userId, listName, items, summary } = data;

        console.log(`\n🔍 Processando checkout da lista: ${listName} [${listId}]`);
        console.log(`   Usuário: ${userId}`);

        // Atualizar estatísticas globais
        this.stats.totalCheckouts++;
        this.stats.totalSpent += summary.estimatedTotal;
        this.stats.totalItems += summary.totalItems;
        this.stats.totalItemsPurchased += summary.purchasedItems;
        this.stats.lastUpdate = new Date().toISOString();

        // Estatísticas por usuário
        if (!this.stats.checkoutsByUser[userId]) {
            this.stats.checkoutsByUser[userId] = {
                checkouts: 0,
                totalSpent: 0,
                totalItems: 0
            };
        }
        this.stats.checkoutsByUser[userId].checkouts++;
        this.stats.checkoutsByUser[userId].totalSpent += summary.estimatedTotal;
        this.stats.checkoutsByUser[userId].totalItems += summary.totalItems;

        // Frequência de itens
        items.forEach(item => {
            if (!this.stats.itemsFrequency[item.itemName]) {
                this.stats.itemsFrequency[item.itemName] = {
                    count: 0,
                    totalQuantity: 0,
                    totalSpent: 0
                };
            }
            this.stats.itemsFrequency[item.itemName].count++;
            this.stats.itemsFrequency[item.itemName].totalQuantity += item.quantity;
            this.stats.itemsFrequency[item.itemName].totalSpent += item.estimatedPrice;
        });

        console.log(`\n💰 Total gasto nesta lista: R$ ${summary.estimatedTotal.toFixed(2)}`);
        console.log(`📦 Itens comprados: ${summary.purchasedItems}/${summary.totalItems}`);

        // Salvar dados
        await this.saveData();

        // Exibir dashboard atualizado
        console.log('\n' + '─'.repeat(50));
        this.displayDashboard();
        console.log('─'.repeat(50));
    }

    displayDashboard() {
        console.log('\n╔═══════════════════════════════════════════════╗');
        console.log('║           📊 DASHBOARD ANALYTICS              ║');
        console.log('╚═══════════════════════════════════════════════╝');
        
        console.log('\n📈 ESTATÍSTICAS GERAIS:');
        console.log(`   Total de checkouts: ${this.stats.totalCheckouts}`);
        console.log(`   Gasto total: R$ ${this.stats.totalSpent.toFixed(2)}`);
        console.log(`   Total de itens: ${this.stats.totalItems}`);
        console.log(`   Itens comprados: ${this.stats.totalItemsPurchased}`);
        
        if (this.stats.totalCheckouts > 0) {
            const avgPerCheckout = this.stats.totalSpent / this.stats.totalCheckouts;
            const avgItemsPerCheckout = this.stats.totalItems / this.stats.totalCheckouts;
            console.log(`   Média por checkout: R$ ${avgPerCheckout.toFixed(2)}`);
            console.log(`   Média de itens/checkout: ${avgItemsPerCheckout.toFixed(1)}`);
        }

        // Top usuários
        const topUsers = Object.entries(this.stats.checkoutsByUser)
            .sort((a, b) => b[1].totalSpent - a[1].totalSpent)
            .slice(0, 5);

        if (topUsers.length > 0) {
            console.log('\n👥 TOP 5 USUÁRIOS (por gasto):');
            topUsers.forEach(([userId, data], index) => {
                console.log(`   ${index + 1}. User ${userId.substring(0, 8)}... - R$ ${data.totalSpent.toFixed(2)} (${data.checkouts} checkouts)`);
            });
        }

        // Itens mais populares
        const topItems = Object.entries(this.stats.itemsFrequency)
            .sort((a, b) => b[1].count - a[1].count)
            .slice(0, 5);

        if (topItems.length > 0) {
            console.log('\n🔥 TOP 5 ITENS MAIS FREQUENTES:');
            topItems.forEach(([itemName, data], index) => {
                console.log(`   ${index + 1}. ${itemName} - ${data.count}x (${data.totalQuantity} unidades)`);
            });
        }

        if (this.stats.lastUpdate) {
            console.log(`\n⏱️  Última atualização: ${new Date(this.stats.lastUpdate).toLocaleString('pt-BR')}`);
        }
        
        console.log('');
    }

    getAnalytics() {
        return {
            ...this.stats,
            computed: {
                averagePerCheckout: this.stats.totalCheckouts > 0 
                    ? this.stats.totalSpent / this.stats.totalCheckouts 
                    : 0,
                averageItemsPerCheckout: this.stats.totalCheckouts > 0 
                    ? this.stats.totalItems / this.stats.totalCheckouts 
                    : 0,
                purchaseRate: this.stats.totalItems > 0 
                    ? (this.stats.totalItemsPurchased / this.stats.totalItems) * 100 
                    : 0
            }
        };
    }

    async close() {
        try {
            await this.saveData();
            if (this.channel) await this.channel.close();
            if (this.connection) await this.connection.close();
            console.log('\n👋 Analytics Consumer desconectado');
        } catch (error) {
            console.error('Erro ao fechar conexão:', error.message);
        }
    }
}

// Iniciar o consumer
if (require.main === module) {
    const consumer = new AnalyticsConsumer();
    consumer.connect();

    // Graceful shutdown
    process.on('SIGTERM', async () => {
        console.log('\n⚠️  Recebido SIGTERM, encerrando...');
        await consumer.close();
        process.exit(0);
    });

    process.on('SIGINT', async () => {
        console.log('\n⚠️  Recebido SIGINT, encerrando...');
        await consumer.close();
        process.exit(0);
    });
}

module.exports = AnalyticsConsumer;