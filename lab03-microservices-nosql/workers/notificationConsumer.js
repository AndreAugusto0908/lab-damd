const amqp = require('amqplib');

class NotificationConsumer {
    constructor() {
        this.exchange = 'shopping_events';
        this.queueName = 'notification_queue';
        this.routingKey = 'list.checkout.#';
        this.rabbitUrl = process.env.RABBITMQ_URL || 'amqp://localhost:5672';
        this.connection = null;
        this.channel = null;
    }

    async connect() {
        try {
            console.log('=====================================');
            console.log('Notification Consumer iniciando...');
            console.log(`RabbitMQ URL: ${this.rabbitUrl}`);
            console.log('=====================================\n');

            // Conectar ao RabbitMQ
            this.connection = await amqp.connect(this.rabbitUrl);
            this.channel = await this.connection.createChannel();

            // Declarar o exchange (caso ainda não exista)
            await this.channel.assertExchange(this.exchange, 'topic', {
                durable: true
            });

            // Declarar a fila
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
            console.log('\n🔊 Aguardando mensagens...\n');

            // Configurar prefetch (processar 1 mensagem por vez)
            await this.channel.prefetch(1);

            // Consumir mensagens
            await this.channel.consume(this.queueName, async (msg) => {
                if (msg !== null) {
                    await this.processMessage(msg);
                }
            }, {
                noAck: false // Requer acknowledgment manual
            });

            // Handlers de erro e reconexão
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

    async processMessage(msg) {
        try {
            const content = JSON.parse(msg.content.toString());
            
            console.log('═══════════════════════════════════════');
            console.log('📨 Nova mensagem recebida!');
            console.log('───────────────────────────────────────');
            console.log(`Event Type: ${content.eventType}`);
            console.log(`Message ID: ${content.messageId}`);
            console.log(`Timestamp: ${content.timestamp}`);
            console.log('───────────────────────────────────────');

            // Processar baseado no tipo de evento
            if (content.eventType === 'list.checkout.completed') {
                await this.handleCheckoutCompleted(content.data);
            }

            console.log('═══════════════════════════════════════\n');

            // Acknowledge da mensagem (confirmar processamento)
            this.channel.ack(msg);

        } catch (error) {
            console.error('❌ Erro ao processar mensagem:', error.message);
            
            // Rejeitar mensagem e recolocar na fila (ou enviar para DLQ)
            this.channel.nack(msg, false, true);
        }
    }

    async handleCheckoutCompleted(data) {
        const { listId, userId, listName, items, summary } = data;

        // Simular busca de email do usuário (em produção, buscaria do User Service)
        const userEmail = await this.getUserEmail(userId);

        // LOG PRINCIPAL - Conforme solicitado
        console.log(`📧 Enviando comprovante da lista [${listId}] para o usuário [${userEmail}]`);
        
        // Informações adicionais
        console.log(`\n📋 Detalhes da Lista:`);
        console.log(`   Nome: ${listName}`);
        console.log(`   Total de itens: ${summary.totalItems}`);
        console.log(`   Itens comprados: ${summary.purchasedItems}`);
        console.log(`   Valor estimado: R$ ${summary.estimatedTotal.toFixed(2)}`);
        
        if (items && items.length > 0) {
            console.log(`\n🛒 Itens da lista:`);
            items.forEach((item, index) => {
                const status = item.purchased ? '✓' : '✗';
                console.log(`   ${index + 1}. [${status}] ${item.itemName} - ${item.quantity} ${item.unit} - R$ ${item.estimatedPrice.toFixed(2)}`);
            });
        }

        // Simular envio de email/notificação
        await this.simulateEmailSending(userEmail, listId, listName);
    }

    async getUserEmail(userId) {
        // Em produção, faria uma chamada HTTP ao User Service
        // Por enquanto, retorna um email simulado
        return `user-${userId}@example.com`;
    }

    async simulateEmailSending(email, listId, listName) {
        // Simular delay de envio de email
        await new Promise(resolve => setTimeout(resolve, 500));
        
        console.log(`\n✉️  Email enviado com sucesso!`);
        console.log(`   Para: ${email}`);
        console.log(`   Assunto: Comprovante - ${listName}`);
        console.log(`   Status: Entregue`);
    }

    async close() {
        try {
            if (this.channel) await this.channel.close();
            if (this.connection) await this.connection.close();
            console.log('\n👋 Notification Consumer desconectado');
        } catch (error) {
            console.error('Erro ao fechar conexão:', error.message);
        }
    }
}

// Iniciar o consumer
if (require.main === module) {
    const consumer = new NotificationConsumer();
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

module.exports = NotificationConsumer;