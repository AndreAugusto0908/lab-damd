const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const jwt = require('jsonwebtoken');
const axios = require('axios');

// Importar banco NoSQL e service registry
const JsonDatabase = require('../../shared/JsonDatabase');
const serviceRegistry = require('../../shared/serviceRegistry');

class ListService {
    constructor() {
        this.app = express();
        this.port = process.env.PORT || 3002;
        this.serviceName = 'list-service';
        this.serviceUrl = `http://localhost:${this.port}`;
        this.itemServiceUrl = process.env.ITEM_SERVICE_URL || 'http://localhost:3003';
        
        this.setupDatabase();
        this.setupMiddleware();
        this.setupRoutes();
        this.setupErrorHandling();
        this.seedInitialData();
    }

    setupDatabase() {
        const dbPath = path.join(__dirname, 'database');
        this.listsDb = new JsonDatabase(dbPath, 'lists');
        console.log('List Service: Banco NoSQL inicializado');
    }

    async seedInitialData() {
        // Aguardar inicialização e criar listas de exemplo se não existirem
        setTimeout(async () => {
            try {
                const existingLists = await this.listsDb.find();
                
                if (existingLists.length === 0) {
                    const sampleLists = [
                        {
                            id: uuidv4(),
                            userId: 'sample-user-1',
                            name: 'Lista de Compras - Casa',
                            description: 'Itens essenciais para casa',
                            status: 'active',
                            items: [
                                {
                                    itemId: 'sample-item-1',
                                    itemName: 'Arroz Branco Tipo 1',
                                    quantity: 2,
                                    unit: 'kg',
                                    estimatedPrice: 15.00,
                                    purchased: false,
                                    notes: 'Comprar o tipo 1',
                                    addedAt: new Date().toISOString()
                                },
                                {
                                    itemId: 'sample-item-2',
                                    itemName: 'Feijão Carioca',
                                    quantity: 1,
                                    unit: 'kg',
                                    estimatedPrice: 8.90,
                                    purchased: true,
                                    notes: '',
                                    addedAt: new Date().toISOString()
                                }
                            ],
                            summary: {
                                totalItems: 2,
                                purchasedItems: 1,
                                estimatedTotal: 23.90
                            },
                            createdAt: new Date().toISOString(),
                            updatedAt: new Date().toISOString()
                        },
                        {
                            id: uuidv4(),
                            userId: 'sample-user-1',
                            name: 'Lista de Limpeza',
                            description: 'Produtos de limpeza para o mês',
                            status: 'active',
                            items: [
                                {
                                    itemId: 'sample-item-3',
                                    itemName: 'Detergente Líquido',
                                    quantity: 3,
                                    unit: 'un',
                                    estimatedPrice: 8.97,
                                    purchased: false,
                                    notes: 'Preferir o neutro',
                                    addedAt: new Date().toISOString()
                                }
                            ],
                            summary: {
                                totalItems: 1,
                                purchasedItems: 0,
                                estimatedTotal: 8.97
                            },
                            createdAt: new Date().toISOString(),
                            updatedAt: new Date().toISOString()
                        }
                    ];

                    // Inserir listas de exemplo
                    for (const list of sampleLists) {
                        await this.listsDb.create(list);
                    }

                    console.log(`${sampleLists.length} listas de exemplo criadas`);
                }
            } catch (error) {
                console.error('Erro ao criar dados iniciais:', error);
            }
        }, 1000);
    }

    setupMiddleware() {
        this.app.use(helmet());
        this.app.use(cors());
        this.app.use(morgan('combined'));
        this.app.use(express.json());
        this.app.use(express.urlencoded({ extended: true }));

        // Service info headers
        this.app.use((req, res, next) => {
            res.setHeader('X-Service', this.serviceName);
            res.setHeader('X-Service-Version', '1.0.0');
            res.setHeader('X-Database', 'JSON-NoSQL');
            next();
        });
    }

    setupRoutes() {
        // Health check
        this.app.get('/health', async (req, res) => {
            try {
                const listCount = await this.listsDb.count();
                const activeLists = await this.listsDb.count({ status: 'active' });
                
                res.json({
                    service: this.serviceName,
                    status: 'healthy',
                    timestamp: new Date().toISOString(),
                    uptime: process.uptime(),
                    version: '1.0.0',
                    database: {
                        type: 'JSON-NoSQL',
                        totalLists: listCount,
                        activeLists: activeLists
                    },
                    externalServices: {
                        itemService: this.itemServiceUrl
                    }
                });
            } catch (error) {
                res.status(503).json({
                    service: this.serviceName,
                    status: 'unhealthy',
                    error: error.message
                });
            }
        });

        // Service info
        this.app.get('/', (req, res) => {
            res.json({
                service: 'List Service',
                version: '1.0.0',
                description: 'Microsserviço para gerenciamento de listas de compras com NoSQL',
                database: 'JSON-NoSQL',
                endpoints: [
                    'POST /lists',
                    'GET /lists',
                    'GET /lists/:id',
                    'PUT /lists/:id',
                    'DELETE /lists/:id',
                    'POST /lists/:id/items',
                    'PUT /lists/:id/items/:itemId',
                    'DELETE /lists/:id/items/:itemId',
                    'GET /lists/:id/summary'
                ]
            });
        });

        // All routes require authentication
        this.app.use(this.authMiddleware.bind(this));

        // List routes
        this.app.post('/lists', this.createList.bind(this));
        this.app.get('/lists', this.getLists.bind(this));
        this.app.get('/lists/:id', this.getList.bind(this));
        this.app.put('/lists/:id', this.updateList.bind(this));
        this.app.delete('/lists/:id', this.deleteList.bind(this));

        // List items routes
        this.app.post('/lists/:id/items', this.addItemToList.bind(this));
        this.app.put('/lists/:id/items/:itemId', this.updateListItem.bind(this));
        this.app.delete('/lists/:id/items/:itemId', this.removeItemFromList.bind(this));

        // Summary route
        this.app.get('/lists/:id/summary', this.getListSummary.bind(this));
    }

    setupErrorHandling() {
        this.app.use('*', (req, res) => {
            res.status(404).json({
                success: false,
                message: 'Endpoint não encontrado',
                service: this.serviceName
            });
        });

        this.app.use((error, req, res, next) => {
            console.error('List Service Error:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do serviço',
                service: this.serviceName
            });
        });
    }

    // Auth middleware
    authMiddleware(req, res, next) {
        const authHeader = req.header('Authorization');
        
        if (!authHeader?.startsWith('Bearer ')) {
            return res.status(401).json({
                success: false,
                message: 'Token obrigatório'
            });
        }

        const token = authHeader.replace('Bearer ', '');
        
        try {
            const decoded = jwt.verify(token, process.env.JWT_SECRET || 'user-secret');
            req.user = decoded;
            next();
        } catch (error) {
            res.status(401).json({
                success: false,
                message: 'Token inválido'
            });
        }
    }

    // Helper function to get item data from Item Service
    async getItemData(itemId) {
        try {
            const response = await axios.get(`${this.itemServiceUrl}/items/${itemId}`);
            if (response.data.success) {
                return response.data.data;
            }
            return null;
        } catch (error) {
            console.error('Erro ao buscar item no Item Service:', error.message);
            return null;
        }
    }

    // Helper function to calculate list summary
    calculateSummary(items) {
        return {
            totalItems: items.length,
            purchasedItems: items.filter(item => item.purchased).length,
            estimatedTotal: items.reduce((total, item) => total + (item.estimatedPrice || 0), 0)
        };
    }

    // Create new list
    async createList(req, res) {
        try {
            const { name, description } = req.body;

            if (!name) {
                return res.status(400).json({
                    success: false,
                    message: 'Nome da lista é obrigatório'
                });
            }

            const newList = await this.listsDb.create({
                id: uuidv4(),
                userId: req.user.id,
                name,
                description: description || '',
                status: 'active',
                items: [],
                summary: {
                    totalItems: 0,
                    purchasedItems: 0,
                    estimatedTotal: 0
                },
                createdAt: new Date().toISOString(),
                updatedAt: new Date().toISOString()
            });

            res.status(201).json({
                success: true,
                message: 'Lista criada com sucesso',
                data: newList
            });
        } catch (error) {
            console.error('Erro ao criar lista:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do servidor'
            });
        }
    }

    // Get user's lists
    async getLists(req, res) {
        try {
            const { page = 1, limit = 10, status } = req.query;
            const skip = (page - 1) * parseInt(limit);

            const filter = { userId: req.user.id };
            if (status) filter.status = status;

            const lists = await this.listsDb.find(filter, {
                skip: skip,
                limit: parseInt(limit),
                sort: { updatedAt: -1 }
            });

            const total = await this.listsDb.count(filter);

            res.json({
                success: true,
                data: lists,
                pagination: {
                    page: parseInt(page),
                    limit: parseInt(limit),
                    total: total,
                    pages: Math.ceil(total / parseInt(limit))
                }
            });
        } catch (error) {
            console.error('Erro ao buscar listas:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do servidor'
            });
        }
    }

    // Get specific list
    async getList(req, res) {
        try {
            const { id } = req.params;
            const list = await this.listsDb.findById(id);

            if (!list) {
                return res.status(404).json({
                    success: false,
                    message: 'Lista não encontrada'
                });
            }

            // Verificar se a lista pertence ao usuário
            if (list.userId !== req.user.id) {
                return res.status(403).json({
                    success: false,
                    message: 'Acesso negado - lista não pertence ao usuário'
                });
            }

            res.json({
                success: true,
                data: list
            });
        } catch (error) {
            console.error('Erro ao buscar lista:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do servidor'
            });
        }
    }

    // Update list (name, description, status)
    async updateList(req, res) {
        try {
            const { id } = req.params;
            const { name, description, status } = req.body;

            const list = await this.listsDb.findById(id);
            if (!list) {
                return res.status(404).json({
                    success: false,
                    message: 'Lista não encontrada'
                });
            }

            if (list.userId !== req.user.id) {
                return res.status(403).json({
                    success: false,
                    message: 'Acesso negado'
                });
            }

            const updates = {
                updatedAt: new Date().toISOString()
            };

            if (name !== undefined) updates.name = name;
            if (description !== undefined) updates.description = description;
            if (status !== undefined) {
                if (!['active', 'completed', 'archived'].includes(status)) {
                    return res.status(400).json({
                        success: false,
                        message: 'Status inválido. Use: active, completed ou archived'
                    });
                }
                updates.status = status;
            }

            const updatedList = await this.listsDb.update(id, updates);

            res.json({
                success: true,
                message: 'Lista atualizada com sucesso',
                data: updatedList
            });
        } catch (error) {
            console.error('Erro ao atualizar lista:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do servidor'
            });
        }
    }

    // Delete list
    async deleteList(req, res) {
        try {
            const { id } = req.params;
            const list = await this.listsDb.findById(id);

            if (!list) {
                return res.status(404).json({
                    success: false,
                    message: 'Lista não encontrada'
                });
            }

            if (list.userId !== req.user.id) {
                return res.status(403).json({
                    success: false,
                    message: 'Acesso negado'
                });
            }

            await this.listsDb.delete(id);

            res.json({
                success: true,
                message: 'Lista deletada com sucesso'
            });
        } catch (error) {
            console.error('Erro ao deletar lista:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do servidor'
            });
        }
    }

    // Add item to list
    async addItemToList(req, res) {
        try {
            const { id } = req.params;
            const { itemId, quantity, notes } = req.body;

            if (!itemId || !quantity) {
                return res.status(400).json({
                    success: false,
                    message: 'ItemId e quantidade são obrigatórios'
                });
            }

            const list = await this.listsDb.findById(id);
            if (!list) {
                return res.status(404).json({
                    success: false,
                    message: 'Lista não encontrada'
                });
            }

            if (list.userId !== req.user.id) {
                return res.status(403).json({
                    success: false,
                    message: 'Acesso negado'
                });
            }

            // Buscar dados do item no Item Service
            const itemData = await this.getItemData(itemId);
            if (!itemData) {
                return res.status(404).json({
                    success: false,
                    message: 'Item não encontrado no catálogo'
                });
            }

            // Verificar se item já existe na lista
            const existingItemIndex = list.items.findIndex(item => item.itemId === itemId);
            if (existingItemIndex !== -1) {
                return res.status(409).json({
                    success: false,
                    message: 'Item já existe na lista'
                });
            }

            const newItem = {
                itemId,
                itemName: itemData.name,
                quantity: parseInt(quantity),
                unit: itemData.unit,
                estimatedPrice: itemData.averagePrice * parseInt(quantity),
                purchased: false,
                notes: notes || '',
                addedAt: new Date().toISOString()
            };

            const updatedItems = [...list.items, newItem];
            const summary = this.calculateSummary(updatedItems);

            const updatedList = await this.listsDb.update(id, {
                items: updatedItems,
                summary: summary,
                updatedAt: new Date().toISOString()
            });

            res.status(201).json({
                success: true,
                message: 'Item adicionado à lista com sucesso',
                data: updatedList
            });
        } catch (error) {
            console.error('Erro ao adicionar item à lista:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do servidor'
            });
        }
    }

    // Update item in list
    async updateListItem(req, res) {
        try {
            const { id, itemId } = req.params;
            const { quantity, purchased, notes } = req.body;

            const list = await this.listsDb.findById(id);
            if (!list) {
                return res.status(404).json({
                    success: false,
                    message: 'Lista não encontrada'
                });
            }

            if (list.userId !== req.user.id) {
                return res.status(403).json({
                    success: false,
                    message: 'Acesso negado'
                });
            }

            const itemIndex = list.items.findIndex(item => item.itemId === itemId);
            if (itemIndex === -1) {
                return res.status(404).json({
                    success: false,
                    message: 'Item não encontrado na lista'
                });
            }

            const updatedItems = [...list.items];
            const item = updatedItems[itemIndex];

            // Atualizar campos fornecidos
            if (quantity !== undefined) {
                item.quantity = parseInt(quantity);
                // Recalcular preço estimado baseado na quantidade
                const itemData = await this.getItemData(itemId);
                if (itemData) {
                    item.estimatedPrice = itemData.averagePrice * parseInt(quantity);
                }
            }
            if (purchased !== undefined) item.purchased = Boolean(purchased);
            if (notes !== undefined) item.notes = notes;

            const summary = this.calculateSummary(updatedItems);

            const updatedList = await this.listsDb.update(id, {
                items: updatedItems,
                summary: summary,
                updatedAt: new Date().toISOString()
            });

            res.json({
                success: true,
                message: 'Item atualizado com sucesso',
                data: updatedList
            });
        } catch (error) {
            console.error('Erro ao atualizar item da lista:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do servidor'
            });
        }
    }

    // Remove item from list
    async removeItemFromList(req, res) {
        try {
            const { id, itemId } = req.params;

            const list = await this.listsDb.findById(id);
            if (!list) {
                return res.status(404).json({
                    success: false,
                    message: 'Lista não encontrada'
                });
            }

            if (list.userId !== req.user.id) {
                return res.status(403).json({
                    success: false,
                    message: 'Acesso negado'
                });
            }

            const itemExists = list.items.some(item => item.itemId === itemId);
            if (!itemExists) {
                return res.status(404).json({
                    success: false,
                    message: 'Item não encontrado na lista'
                });
            }

            const updatedItems = list.items.filter(item => item.itemId !== itemId);
            const summary = this.calculateSummary(updatedItems);

            const updatedList = await this.listsDb.update(id, {
                items: updatedItems,
                summary: summary,
                updatedAt: new Date().toISOString()
            });

            res.json({
                success: true,
                message: 'Item removido da lista com sucesso',
                data: updatedList
            });
        } catch (error) {
            console.error('Erro ao remover item da lista:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do servidor'
            });
        }
    }

    // Get list summary
    async getListSummary(req, res) {
        try {
            const { id } = req.params;
            const list = await this.listsDb.findById(id);

            if (!list) {
                return res.status(404).json({
                    success: false,
                    message: 'Lista não encontrada'
                });
            }

            if (list.userId !== req.user.id) {
                return res.status(403).json({
                    success: false,
                    message: 'Acesso negado'
                });
            }

            // Recalcular resumo em tempo real
            const summary = this.calculateSummary(list.items);
            
            // Estatísticas adicionais
            const categoryStats = {};
            list.items.forEach(item => {
                // Usar uma categoria padrão se não conseguir obter do item service
                const category = 'Geral';
                if (!categoryStats[category]) {
                    categoryStats[category] = { count: 0, total: 0, purchased: 0 };
                }
                categoryStats[category].count++;
                categoryStats[category].total += item.estimatedPrice || 0;
                if (item.purchased) categoryStats[category].purchased++;
            });

            res.json({
                success: true,
                data: {
                    listId: id,
                    listName: list.name,
                    summary: summary,
                    progress: summary.totalItems > 0 ? 
                        Math.round((summary.purchasedItems / summary.totalItems) * 100) : 0,
                    categoryStats: categoryStats,
                    lastUpdated: list.updatedAt
                }
            });
        } catch (error) {
            console.error('Erro ao buscar resumo da lista:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do servidor'
            });
        }
    }

    // Register with service registry
    registerWithRegistry() {
        serviceRegistry.register(this.serviceName, {
            url: this.serviceUrl,
            version: '1.0.0',
            database: 'JSON-NoSQL',
            endpoints: ['/health', '/lists', '/lists/:id/items', '/lists/:id/summary']
        });
    }

    // Start health check reporting
    startHealthReporting() {
        setInterval(() => {
            serviceRegistry.updateHealth(this.serviceName, true);
        }, 30000);
    }

    start() {
        this.app.listen(this.port, () => {
            console.log('=====================================');
            console.log(`List Service iniciado na porta ${this.port}`);
            console.log(`URL: ${this.serviceUrl}`);
            console.log(`Health: ${this.serviceUrl}/health`);
            console.log(`Database: JSON-NoSQL`);
            console.log(`Item Service: ${this.itemServiceUrl}`);
            console.log('=====================================');
            
            // Register with service registry
            this.registerWithRegistry();
            this.startHealthReporting();
        });
    }
}

// Start service
if (require.main === module) {
    const listService = new ListService();
    listService.start();

    // Graceful shutdown
    process.on('SIGTERM', () => {
        serviceRegistry.unregister('list-service');
        process.exit(0);
    });
    process.on('SIGINT', () => {
        serviceRegistry.unregister('list-service');
        process.exit(0);
    });
}

module.exports = ListService;