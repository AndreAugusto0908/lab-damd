const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const jwt = require('jsonwebtoken');

// Importar banco NoSQL e service registry
const JsonDatabase = require('../../shared/JsonDatabase');
const serviceRegistry = require('../../shared/serviceRegistry');

class ItemService {
    constructor() {
        this.app = express();
        this.port = process.env.PORT || 3003;
        this.serviceName = 'item-service';
        this.serviceUrl = `http://localhost:${this.port}`;
        
        this.setupDatabase();
        this.setupMiddleware();
        this.setupRoutes();
        this.setupErrorHandling();
        this.seedInitialData();
    }

    setupDatabase() {
        const dbPath = path.join(__dirname, 'database');
        this.itemsDb = new JsonDatabase(dbPath, 'items');
        console.log('Item Service: Banco NoSQL inicializado');
    }

    async seedInitialData() {
        // Aguardar inicialização e criar itens iniciais se não existirem
        setTimeout(async () => {
            try {
                const existingItems = await this.itemsDb.find();
                
                if (existingItems.length === 0) {
                    const initialItems = [
                        // Alimentos
                        {
                            id: uuidv4(),
                            name: 'Arroz Branco Tipo 1',
                            category: 'Alimentos',
                            brand: 'Tio João',
                            unit: 'kg',
                            averagePrice: 7.50,
                            barcode: '7891000100001',
                            description: 'Arroz branco tipo 1, grãos longos, pacote de 1kg',
                            active: true,
                            createdAt: new Date().toISOString()
                        },
                        {
                            id: uuidv4(),
                            name: 'Feijão Carioca',
                            category: 'Alimentos',
                            brand: 'Kicaldo',
                            unit: 'kg',
                            averagePrice: 8.90,
                            barcode: '7891000100002',
                            description: 'Feijão carioca tipo 1, pacote de 1kg',
                            active: true,
                            createdAt: new Date().toISOString()
                        },
                        {
                            id: uuidv4(),
                            name: 'Óleo de Soja',
                            category: 'Alimentos',
                            brand: 'Liza',
                            unit: 'litro',
                            averagePrice: 5.99,
                            barcode: '7891000100003',
                            description: 'Óleo de soja refinado, garrafa de 900ml',
                            active: true,
                            createdAt: new Date().toISOString()
                        },
                        {
                            id: uuidv4(),
                            name: 'Açúcar Cristal',
                            category: 'Alimentos',
                            brand: 'União',
                            unit: 'kg',
                            averagePrice: 4.20,
                            barcode: '7891000100004',
                            description: 'Açúcar cristal especial, pacote de 1kg',
                            active: true,
                            createdAt: new Date().toISOString()
                        },
                        {
                            id: uuidv4(),
                            name: 'Sal Refinado',
                            category: 'Alimentos',
                            brand: 'Cisne',
                            unit: 'kg',
                            averagePrice: 2.10,
                            barcode: '7891000100005',
                            description: 'Sal refinado iodado, pacote de 1kg',
                            active: true,
                            createdAt: new Date().toISOString()
                        },

                        // Limpeza
                        {
                            id: uuidv4(),
                            name: 'Detergente Líquido',
                            category: 'Limpeza',
                            brand: 'Ypê',
                            unit: 'un',
                            averagePrice: 2.99,
                            barcode: '7891000200001',
                            description: 'Detergente líquido neutro, frasco de 500ml',
                            active: true,
                            createdAt: new Date().toISOString()
                        },
                        {
                            id: uuidv4(),
                            name: 'Água Sanitária',
                            category: 'Limpeza',
                            brand: 'Q-Boa',
                            unit: 'litro',
                            averagePrice: 3.50,
                            barcode: '7891000200002',
                            description: 'Água sanitária 2% cloro ativo, garrafa de 1 litro',
                            active: true,
                            createdAt: new Date().toISOString()
                        },
                        {
                            id: uuidv4(),
                            name: 'Sabão em Pó',
                            category: 'Limpeza',
                            brand: 'OMO',
                            unit: 'kg',
                            averagePrice: 12.90,
                            barcode: '7891000200003',
                            description: 'Sabão em pó concentrado, caixa de 1kg',
                            active: true,
                            createdAt: new Date().toISOString()
                        },
                        {
                            id: uuidv4(),
                            name: 'Desinfetante Pinho',
                            category: 'Limpeza',
                            brand: 'Pinho Sol',
                            unit: 'litro',
                            averagePrice: 4.80,
                            barcode: '7891000200004',
                            description: 'Desinfetante concentrado pinho, frasco de 1 litro',
                            active: true,
                            createdAt: new Date().toISOString()
                        },
                        {
                            id: uuidv4(),
                            name: 'Esponja de Limpeza',
                            category: 'Limpeza',
                            brand: 'Scotch-Brite',
                            unit: 'un',
                            averagePrice: 1.50,
                            barcode: '7891000200005',
                            description: 'Esponja dupla face para limpeza geral',
                            active: true,
                            createdAt: new Date().toISOString()
                        },

                        // Higiene
                        {
                            id: uuidv4(),
                            name: 'Pasta de Dente',
                            category: 'Higiene',
                            brand: 'Colgate',
                            unit: 'un',
                            averagePrice: 3.99,
                            barcode: '7891000300001',
                            description: 'Pasta de dente total 12, tubo de 90g',
                            active: true,
                            createdAt: new Date().toISOString()
                        },
                        {
                            id: uuidv4(),
                            name: 'Sabonete',
                            category: 'Higiene',
                            brand: 'Dove',
                            unit: 'un',
                            averagePrice: 2.50,
                            barcode: '7891000300002',
                            description: 'Sabonete hidratante, barra de 90g',
                            active: true,
                            createdAt: new Date().toISOString()
                        },
                        {
                            id: uuidv4(),
                            name: 'Shampoo',
                            category: 'Higiene',
                            brand: 'Pantene',
                            unit: 'un',
                            averagePrice: 8.90,
                            barcode: '7891000300003',
                            description: 'Shampoo hidratação intensa, frasco de 400ml',
                            active: true,
                            createdAt: new Date().toISOString()
                        },
                        {
                            id: uuidv4(),
                            name: 'Papel Higiênico',
                            category: 'Higiene',
                            brand: 'Personal',
                            unit: 'un',
                            averagePrice: 12.50,
                            barcode: '7891000300004',
                            description: 'Papel higiênico folha dupla, pacote com 12 rolos',
                            active: true,
                            createdAt: new Date().toISOString()
                        },
                        {
                            id: uuidv4(),
                            name: 'Desodorante',
                            category: 'Higiene',
                            brand: 'Rexona',
                            unit: 'un',
                            averagePrice: 6.99,
                            barcode: '7891000300005',
                            description: 'Desodorante aerosol masculino, frasco de 150ml',
                            active: true,
                            createdAt: new Date().toISOString()
                        },

                        // Bebidas
                        {
                            id: uuidv4(),
                            name: 'Refrigerante Cola',
                            category: 'Bebidas',
                            brand: 'Coca-Cola',
                            unit: 'litro',
                            averagePrice: 4.50,
                            barcode: '7891000400001',
                            description: 'Refrigerante de cola, garrafa PET 2 litros',
                            active: true,
                            createdAt: new Date().toISOString()
                        },
                        {
                            id: uuidv4(),
                            name: 'Suco de Laranja',
                            category: 'Bebidas',
                            brand: 'Del Valle',
                            unit: 'litro',
                            averagePrice: 3.99,
                            barcode: '7891000400002',
                            description: 'Suco de laranja integral, caixa de 1 litro',
                            active: true,
                            createdAt: new Date().toISOString()
                        },
                        {
                            id: uuidv4(),
                            name: 'Água Mineral',
                            category: 'Bebidas',
                            brand: 'Crystal',
                            unit: 'litro',
                            averagePrice: 1.50,
                            barcode: '7891000400003',
                            description: 'Água mineral natural, garrafa de 1,5 litros',
                            active: true,
                            createdAt: new Date().toISOString()
                        },
                        {
                            id: uuidv4(),
                            name: 'Café em Pó',
                            category: 'Bebidas',
                            brand: '3 Corações',
                            unit: 'kg',
                            averagePrice: 15.90,
                            barcode: '7891000400004',
                            description: 'Café torrado e moído tradicional, pacote de 500g',
                            active: true,
                            createdAt: new Date().toISOString()
                        },

                        // Padaria
                        {
                            id: uuidv4(),
                            name: 'Pão Francês',
                            category: 'Padaria',
                            brand: 'Padaria Local',
                            unit: 'kg',
                            averagePrice: 8.00,
                            barcode: '7891000500001',
                            description: 'Pão francês fresco, vendido por quilograma',
                            active: true,
                            createdAt: new Date().toISOString()
                        },
                        {
                            id: uuidv4(),
                            name: 'Pão de Açúcar',
                            category: 'Padaria',
                            brand: 'Wickbold',
                            unit: 'un',
                            averagePrice: 4.50,
                            barcode: '7891000500002',
                            description: 'Pão de açúcar fatiado, pacote de 500g',
                            active: true,
                            createdAt: new Date().toISOString()
                        }
                    ];

                    // Inserir todos os itens
                    for (const item of initialItems) {
                        await this.itemsDb.create(item);
                    }

                    console.log(`${initialItems.length} itens iniciais criados no catálogo`);
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
                const itemCount = await this.itemsDb.count();
                const activeItems = await this.itemsDb.count({ active: true });
                const categories = await this.getUniqueCategories();
                
                res.json({
                    service: this.serviceName,
                    status: 'healthy',
                    timestamp: new Date().toISOString(),
                    uptime: process.uptime(),
                    version: '1.0.0',
                    database: {
                        type: 'JSON-NoSQL',
                        totalItems: itemCount,
                        activeItems: activeItems,
                        categories: categories.length
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
                service: 'Item Service',
                version: '1.0.0',
                description: 'Microsserviço para gerenciamento de catálogo de itens/produtos com NoSQL',
                database: 'JSON-NoSQL',
                endpoints: [
                    'GET /items',
                    'GET /items/:id',
                    'POST /items',
                    'PUT /items/:id',
                    'GET /categories',
                    'GET /search?q=termo'
                ]
            });
        });

        // Public routes
        this.app.get('/items', this.getItems.bind(this));
        this.app.get('/items/:id', this.getItem.bind(this));
        this.app.get('/categories', this.getCategories.bind(this));
        this.app.get('/search', this.searchItems.bind(this));

        // Protected routes (require authentication)
        this.app.post('/items', this.authMiddleware.bind(this), this.createItem.bind(this));
        this.app.put('/items/:id', this.authMiddleware.bind(this), this.updateItem.bind(this));
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
            console.error('Item Service Error:', error);
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

    // Get items with filters and pagination
    async getItems(req, res) {
        try {
            const { 
                page = 1, 
                limit = 20, 
                category, 
                name, 
                active = 'true',
                sortBy = 'name',
                sortOrder = 'asc'
            } = req.query;

            const skip = (page - 1) * parseInt(limit);

            // Build filter object
            const filter = {};
            if (category) filter.category = category;
            if (name) filter.name = { $regex: name, $options: 'i' }; // Case insensitive search
            if (active !== 'all') filter.active = active === 'true';

            // Sort options
            const sortOptions = {};
            sortOptions[sortBy] = sortOrder === 'desc' ? -1 : 1;

            const items = await this.itemsDb.find(filter, {
                skip: skip,
                limit: parseInt(limit),
                sort: sortOptions
            });

            const total = await this.itemsDb.count(filter);

            res.json({
                success: true,
                data: items,
                pagination: {
                    page: parseInt(page),
                    limit: parseInt(limit),
                    total: total,
                    pages: Math.ceil(total / parseInt(limit))
                },
                filters: {
                    category,
                    name,
                    active,
                    sortBy,
                    sortOrder
                }
            });
        } catch (error) {
            console.error('Erro ao buscar itens:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do servidor'
            });
        }
    }

    // Get item by ID
    async getItem(req, res) {
        try {
            const { id } = req.params;
            const item = await this.itemsDb.findById(id);

            if (!item) {
                return res.status(404).json({
                    success: false,
                    message: 'Item não encontrado'
                });
            }

            res.json({
                success: true,
                data: item
            });
        } catch (error) {
            console.error('Erro ao buscar item:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do servidor'
            });
        }
    }

    // Create new item (requires authentication)
    async createItem(req, res) {
        try {
            const { name, category, brand, unit, averagePrice, barcode, description } = req.body;

            // Validações básicas
            if (!name || !category || !unit || !averagePrice) {
                return res.status(400).json({
                    success: false,
                    message: 'Nome, categoria, unidade e preço médio são obrigatórios'
                });
            }

            // Verificar se item com mesmo código de barras já existe
            if (barcode) {
                const existingItem = await this.itemsDb.findOne({ barcode });
                if (existingItem) {
                    return res.status(409).json({
                        success: false,
                        message: 'Já existe um item com este código de barras'
                    });
                }
            }

            const newItem = await this.itemsDb.create({
                id: uuidv4(),
                name,
                category,
                brand: brand || null,
                unit,
                averagePrice: parseFloat(averagePrice),
                barcode: barcode || null,
                description: description || null,
                active: true,
                createdAt: new Date().toISOString(),
                createdBy: req.user.id
            });

            res.status(201).json({
                success: true,
                message: 'Item criado com sucesso',
                data: newItem
            });
        } catch (error) {
            console.error('Erro ao criar item:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do servidor'
            });
        }
    }

    // Update item (requires authentication)
    async updateItem(req, res) {
        try {
            const { id } = req.params;
            const { name, category, brand, unit, averagePrice, barcode, description, active } = req.body;

            const item = await this.itemsDb.findById(id);
            if (!item) {
                return res.status(404).json({
                    success: false,
                    message: 'Item não encontrado'
                });
            }

            // Verificar se barcode já existe em outro item
            if (barcode && barcode !== item.barcode) {
                const existingItem = await this.itemsDb.findOne({ 
                    barcode,
                    id: { $ne: id }
                });
                if (existingItem) {
                    return res.status(409).json({
                        success: false,
                        message: 'Já existe outro item com este código de barras'
                    });
                }
            }

            // Build update object
            const updates = {
                updatedAt: new Date().toISOString(),
                updatedBy: req.user.id
            };

            if (name !== undefined) updates.name = name;
            if (category !== undefined) updates.category = category;
            if (brand !== undefined) updates.brand = brand;
            if (unit !== undefined) updates.unit = unit;
            if (averagePrice !== undefined) updates.averagePrice = parseFloat(averagePrice);
            if (barcode !== undefined) updates.barcode = barcode;
            if (description !== undefined) updates.description = description;
            if (active !== undefined) updates.active = Boolean(active);

            const updatedItem = await this.itemsDb.update(id, updates);

            res.json({
                success: true,
                message: 'Item atualizado com sucesso',
                data: updatedItem
            });
        } catch (error) {
            console.error('Erro ao atualizar item:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do servidor'
            });
        }
    }

    // Get unique categories
    async getUniqueCategories() {
        try {
            const items = await this.itemsDb.find({}, { fields: ['category'] });
            const categories = [...new Set(items.map(item => item.category))].sort();
            return categories;
        } catch (error) {
            throw error;
        }
    }

    // Get categories endpoint
    async getCategories(req, res) {
        try {
            const categories = await this.getUniqueCategories();
            
            // Get item count per category
            const categoriesWithCount = await Promise.all(
                categories.map(async (category) => {
                    const count = await this.itemsDb.count({ category, active: true });
                    return { name: category, itemCount: count };
                })
            );

            res.json({
                success: true,
                data: categoriesWithCount
            });
        } catch (error) {
            console.error('Erro ao buscar categorias:', error);
            res.status(500).json({
                success: false,
                message: 'Erro interno do servidor'
            });
        }
    }

    // Search items
    async searchItems(req, res) {
        try {
            const { q, limit = 20, category } = req.query;

            if (!q) {
                return res.status(400).json({
                    success: false,
                    message: 'Parâmetro de busca "q" é obrigatório'
                });
            }

            // Build search filter
            let items = await this.itemsDb.search(q, ['name', 'description', 'brand']);
            
            // Apply additional filters
            items = items.filter(item => {
                if (!item.active) return false;
                if (category && item.category !== category) return false;
                return true;
            });

            // Limit results
            items = items.slice(0, parseInt(limit));

            res.json({
                success: true,
                data: {
                    query: q,
                    category: category || null,
                    results: items,
                    total: items.length
                }
            });
        } catch (error) {
            console.error('Erro na busca de itens:', error);
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
            endpoints: ['/health', '/items', '/categories', '/search']
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
            console.log(`Item Service iniciado na porta ${this.port}`);
            console.log(`URL: ${this.serviceUrl}`);
            console.log(`Health: ${this.serviceUrl}/health`);
            console.log(`Database: JSON-NoSQL`);
            console.log('=====================================');
            
            // Register with service registry
            this.registerWithRegistry();
            this.startHealthReporting();
        });
    }
}

// Start service
if (require.main === module) {
    const itemService = new ItemService();
    itemService.start();

    // Graceful shutdown
    process.on('SIGTERM', () => {
        serviceRegistry.unregister('item-service');
        process.exit(0);
    });
    process.on('SIGINT', () => {
        serviceRegistry.unregister('item-service');
        process.exit(0);
    });
}

module.exports = ItemService;