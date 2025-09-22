# Sistema de Lista de Compras - Microsserviços com NoSQL1

Sistema distribuído de lista de compras implementado em arquitetura de microsserviços, utilizando bancos de dados NoSQL baseados em JSON para cada serviço.

## Arquitetura

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   API Gateway   │    │  User Service   │    │  Item Service   │    │  List Service   │
│    (Port 3000)  │    │   (Port 3001)   │    │   (Port 3003)   │    │   (Port 3004)   │
│                 │    │                 │    │                 │    │                 │
│ - Roteamento    │    │ - Autenticação  │    │ - Catálogo      │    │ - Listas        │
│ - Circuit Break │    │ - Usuários      │    │ - Categorias    │    │ - Itens da Lista│
│ - Aggregação    │    │ - JWT Tokens    │    │ - Busca Items   │    │ - Resumos       │
│ - Health Checks │    │ - Validação     │    │ - CRUD Items    │    │ - Status Compra │
└─────────────────┘    └─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │                       │
         └───────────────────────┼───────────────────────┼───────────────────────┘
                                 │                       │
                        ┌─────────────────┐     ┌─────────────────┐
                        │ JSON Database   │     │ JSON Database   │
                        │  (Users Data)   │     │ (Items/Lists)   │
                        └─────────────────┘     └─────────────────┘
```

### Padrões Implementados

- **Database per Service**: Cada microsserviço possui seu próprio banco de dados
- **Service Discovery**: Registry automático de serviços
- **API Gateway**: Ponto de entrada único para todas as requisições
- **Circuit Breaker**: Proteção contra falhas em cascata
- **Health Checks**: Monitoramento da saúde dos serviços
- **Aggregated Endpoints**: Endpoints que combinam dados de múltiplos serviços

## Tecnologias

- **Runtime**: Node.js 16+
- **Framework**: Express.js
- **Banco de Dados**: JSON-NoSQL (arquivo baseado)
- **Autenticação**: JWT (JSON Web Tokens)
- **HTTP Client**: Axios
- **Process Manager**: Concurrently
- **Development**: Nodemon

## Estrutura do Projeto

```
lab03-microservices-nosql/
├── api-gateway/
│   ├── server.js           # API Gateway principal
│   └── package.json        # Dependências do gateway
├── services/
│   ├── user-service/
│   │   ├── server.js       # Serviço de usuários
│   │   ├── package.json    # Dependências
│   │   └── database/       # Banco JSON (criado automaticamente)
│   ├── item-service/
│   │   ├── server.js       # Serviço de itens
│   │   ├── package.json    # Dependências
│   │   └── database/       # Banco JSON (criado automaticamente)
│   └── list-service/
│       ├── server.js       # Serviço de listas
│       ├── package.json    # Dependências
│       └── database/       # Banco JSON (criado automaticamente)
├── shared/
│   ├── JsonDatabase.js     # Classe do banco NoSQL
│   └── serviceRegistry.js  # Registry de serviços
├── client-demo.js          # Cliente de demonstração
└── package.json            # Configuração principal
```

## Instalação e Configuração

### Pré-requisitos

- Node.js 16.0.0 ou superior
- NPM 8.0.0 ou superior

### Instalação

1. **Clone o repositório**:
   ```bash
   git clone https://github.com/aluno-pucminas/lab03-microservices-nosql.git
   cd lab03-microservices-nosql
   ```

2. **Instale todas as dependências**:
   ```bash
   npm run install:all
   ```

3. **Inicie todos os serviços**:
   ```bash
   npm run dev
   ```

## Uso

### Comandos Principais

```bash
# Iniciar todos os serviços em desenvolvimento
npm run dev

# Iniciar todos os serviços em produção
npm run start

# Executar demonstração completa
npm run demo

# Verificar saúde dos serviços
npm run health

# Instalar dependências em todos os serviços
npm run install:all

# Limpar node_modules de todos os serviços
npm run clean
```

### Comandos de Demonstração

```bash
# Demonstração completa do sistema
npm run demo

# Verificar apenas saúde dos serviços
npm run demo:health

# Listar itens disponíveis
npm run demo:items

# Buscar por "arroz"
npm run demo:search
```

### Health Checks Individuais

```bash
# Gateway
npm run health:gateway

# User Service
npm run health:user

# Item Service  
npm run health:item

# List Service
npm run health:list
```

## API Endpoints

### Autenticação (via Gateway)

- `POST /api/auth/register` - Registrar novo usuário
- `POST /api/auth/login` - Fazer login
- `POST /api/auth/validate` - Validar token

### Usuários (via Gateway)

- `GET /api/users` - Listar usuários (autenticado)
- `GET /api/users/:id` - Buscar usuário específico
- `PUT /api/users/:id` - Atualizar usuário
- `GET /api/users/search` - Buscar usuários

### Itens (via Gateway)

- `GET /api/items` - Listar itens com filtros
- `GET /api/items/:id` - Buscar item específico
- `POST /api/items` - Criar novo item (autenticado)
- `PUT /api/items/:id` - Atualizar item (autenticado)
- `GET /api/items/categories` - Listar categorias

### Listas (via Gateway)

- `POST /api/lists` - Criar nova lista (autenticado)
- `GET /api/lists` - Listar listas do usuário (autenticado)
- `GET /api/lists/:id` - Buscar lista específica (autenticado)
- `PUT /api/lists/:id` - Atualizar lista (autenticado)
- `DELETE /api/lists/:id` - Deletar lista (autenticado)
- `POST /api/lists/:id/items` - Adicionar item à lista (autenticado)
- `PUT /api/lists/:id/items/:itemId` - Atualizar item na lista (autenticado)
- `DELETE /api/lists/:id/items/:itemId` - Remover item da lista (autenticado)
- `GET /api/lists/:id/summary` - Resumo da lista (autenticado)

### Endpoints Agregados

- `GET /api/dashboard` - Dashboard com dados de todos os serviços (autenticado)
- `GET /api/search?q=termo` - Busca global entre serviços
- `GET /health` - Health check do gateway
- `GET /registry` - Status de todos os serviços

## Schemas de Dados

### Usuário
```json
{
  "id": "uuid",
  "email": "string",
  "username": "string", 
  "password": "string (hash)",
  "firstName": "string",
  "lastName": "string",
  "role": "user|admin",
  "status": "active|inactive",
  "profile": {
    "bio": "string",
    "avatar": "string",
    "preferences": {
      "theme": "string",
      "language": "string"
    }
  },
  "metadata": {
    "registrationDate": "timestamp",
    "lastLogin": "timestamp",
    "loginCount": "number"
  }
}
```

### Item
```json
{
  "id": "uuid",
  "name": "string",
  "category": "string",
  "brand": "string",
  "unit": "string",
  "averagePrice": "number",
  "barcode": "string",
  "description": "string",
  "active": "boolean",
  "createdAt": "timestamp"
}
```

### Lista
```json
{
  "id": "uuid",
  "userId": "string",
  "name": "string",
  "description": "string",
  "status": "active|completed|archived",
  "items": [
    {
      "itemId": "string",
      "itemName": "string",
      "quantity": "number",
      "unit": "string",
      "estimatedPrice": "number",
      "purchased": "boolean",
      "notes": "string",
      "addedAt": "timestamp"
    }
  ],
  "summary": {
    "totalItems": "number",
    "purchasedItems": "number",
    "estimatedTotal": "number"
  },
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

## Dados Iniciais

O sistema cria automaticamente dados de exemplo:

### User Service
- **Usuário Admin**: `admin@microservices.com` / `admin123`

### Item Service  
- **21 itens** distribuídos em 5 categorias:
  - Alimentos (5 itens)
  - Limpeza (5 itens)
  - Higiene (5 itens)
  - Bebidas (4 itens)
  - Padaria (2 itens)

### List Service
- **2 listas de exemplo** com itens para demonstração

## Desenvolvimento

### Estrutura dos Serviços

Cada microsserviço segue a estrutura:

```javascript
class ServiceName {
  constructor() {
    this.setupDatabase();    // Configurar banco NoSQL
    this.setupMiddleware();  // Express middleware
    this.setupRoutes();      // Definir endpoints
    this.setupErrorHandling(); // Tratamento de erros
    this.seedInitialData();  // Dados iniciais
  }
  
  // Registrar no service registry
  registerWithRegistry() { ... }
  
  // Health checks periódicos
  startHealthReporting() { ... }
}
```

### Banco de Dados NoSQL

Cada serviço utiliza a classe `JsonDatabase` que implementa:

- Operações CRUD básicas
- Busca com filtros complexos
- Full-text search
- Paginação automática
- Índices simples
- Persistência em arquivos JSON

### Service Discovery

O `serviceRegistry` gerencia automaticamente:

- Registro de serviços na inicialização
- Health checks periódicos
- Descoberta de serviços para comunicação inter-service
- Remoção de serviços offline

## Monitoramento

### URLs de Health Check

- Gateway: http://localhost:3000/health
- User Service: http://localhost:3001/health  
- Item Service: http://localhost:3003/health
- List Service: http://localhost:3004/health
- Registry: http://localhost:3000/registry

### Logs

Cada serviço gera logs detalhados no console, incluindo:

- Requisições HTTP (via Morgan)
- Erros de sistema
- Operações de banco de dados
- Circuit breaker events
- Service discovery events

## Troubleshooting

### Problemas Comuns

1. **Erro "Cannot find module"**:
   ```bash
   npm run install:all
   ```

2. **Porta já em uso**:
   ```bash
   npm run stop
   ```

3. **Serviços não se comunicam**:
   - Verifique se todos estão rodando: `npm run health`
   - Verifique o registry: http://localhost:3000/registry

4. **Banco de dados corrompido**:
   ```bash
   npm run clean:db
   ```

### Debug

Para debug detalhado, acesse:
- http://localhost:3000/debug/services - Status detalhado dos serviços
- Logs individuais de cada serviço no console

## Contribuição

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/nova-feature`)
3. Commit suas mudanças (`git commit -am 'Adiciona nova feature'`)
4. Push para a branch (`git push origin feature/nova-feature`)
5. Crie um Pull Request

## Licença

MIT License - Veja [LICENSE](LICENSE) para detalhes.

## Autor

André Augusto Silva Carvalho - Aluno PUC Minas - Sistemas Distribuídos

---

**Nota**: Este projeto foi desenvolvido para fins educacionais como parte do curso de Sistemas Distribuídos da PUC Minas, demonstrando conceitos de arquitetura de microsserviços com bancos de dados NoSQL distribuídos.