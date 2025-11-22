const amqp = require('amqplib');

class RabbitMQPublisher {
    constructor() {
        this.connection = null;
        this.channel = null;
        this.exchange = 'shopping_events';
        this.rabbitUrl = process.env.RABBITMQ_URL || 'amqp://localhost:5672';
    }

    async connect() {
        try {
            this.connection = await amqp.connect(this.rabbitUrl);
            this.channel = await this.connection.createChannel();
            
            // Declarar exchange do tipo topic
            await this.channel.assertExchange(this.exchange, 'topic', {
                durable: true
            });

            console.log('RabbitMQ Publisher conectado com sucesso');
            
            // Reconectar em caso de erro
            this.connection.on('error', (err) => {
                console.error('RabbitMQ connection error:', err);
                setTimeout(() => this.connect(), 5000);
            });

            this.connection.on('close', () => {
                console.log('RabbitMQ connection closed, reconnecting...');
                setTimeout(() => this.connect(), 5000);
            });

        } catch (error) {
            console.error('Erro ao conectar no RabbitMQ:', error.message);
            setTimeout(() => this.connect(), 5000);
        }
    }

    async publish(routingKey, message) {
        try {
            if (!this.channel) {
                throw new Error('Canal RabbitMQ não está conectado');
            }

            const messageBuffer = Buffer.from(JSON.stringify(message));
            
            const published = this.channel.publish(
                this.exchange,
                routingKey,
                messageBuffer,
                {
                    persistent: true,
                    contentType: 'application/json',
                    timestamp: Date.now()
                }
            );

            if (published) {
                console.log(`Mensagem publicada: ${routingKey}`, {
                    messageId: message.messageId,
                    eventType: message.eventType
                });
                return true;
            }

            return false;

        } catch (error) {
            console.error('Erro ao publicar mensagem:', error.message);
            throw error;
        }
    }

    async publishListCheckout(listData) {
        const message = {
            messageId: require('uuid').v4(),
            eventType: 'list.checkout.completed',
            timestamp: new Date().toISOString(),
            data: {
                listId: listData.id,
                userId: listData.userId,
                listName: listData.name,
                items: listData.items.map(item => ({
                    itemId: item.itemId,
                    itemName: item.itemName,
                    quantity: item.quantity,
                    unit: item.unit,
                    estimatedPrice: item.estimatedPrice,
                    purchased: item.purchased
                })),
                summary: listData.summary,
                completedAt: new Date().toISOString()
            }
        };

        return await this.publish('list.checkout.completed', message);
    }

    async close() {
        try {
            if (this.channel) await this.channel.close();
            if (this.connection) await this.connection.close();
            console.log('RabbitMQ Publisher desconectado');
        } catch (error) {
            console.error('Erro ao fechar conexão RabbitMQ:', error.message);
        }
    }
}

module.exports = RabbitMQPublisher;