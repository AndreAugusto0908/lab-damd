# 🐇 Roteiro de Demonstração RabbitMQ - Sala de Aula

---

## 🚀 SETUP RÁPIDO (5 minutos)

### 1. Iniciar RabbitMQ
```bash
docker run -d --name rabbitmq -p 5672:5672 -p 15672:15672 rabbitmq:3-management
```

### 2. Abrir RabbitMQ Management
**Navegador:** http://localhost:15672  
**Login:** guest / guest

### 3. Iniciar Microsserviços

```bash
# Terminal 1 - User Service
cd services/user-service && npm start

# Terminal 2 - Item Service  
cd services/item-service && npm start

# Terminal 3 - List Service
cd services/list-service && npm start

# Terminal 4 - API Gateway
cd api-gateway && npm start

# Terminal 5 - Consumers (DEIXE VISÍVEL!)
cd workers && npm start
```

---

## 🎬 DEMONSTRAÇÃO (10 minutos)

### PASSO 1: Mostrar RabbitMQ Zerado

Abra o **RabbitMQ Management** no navegador:
- Vá em **Queues and Streams** → Mostre que está vazio
- Vá em **Exchanges** → Mostre que não existe `shopping_events` ainda

---

### PASSO 2: Requisições no Postman

**2.1 Cadastrar usuário**
- Endpoint: `POST http://localhost:3000/api/users/register`
- Body:
```json
{
  "name": "João Demo",
  "email": "joao@demo.com",
  "password": "senha123"
}
```

**2.2 Fazer Login**
- Endpoint: `POST http://localhost:3000/api/users/login`
- Body:
```json
{
  "email": "joao@demo.com",
  "password": "senha123"
}
```
- **⚠️ COPIE O TOKEN** da resposta!

**2.3 Criar Lista**
- Endpoint: `POST http://localhost:3000/api/lists`
- Header: `Authorization: Bearer SEU_TOKEN`
- Body:
```json
{
  "name": "Lista Demo RabbitMQ",
  "description": "Demonstração em sala"
}
```
- **⚠️ COPIE O ID DA LISTA**

**2.4 Listar Itens Disponíveis**
- Endpoint: `GET http://localhost:3000/api/items?limit=5`
- Header: `Authorization: Bearer SEU_TOKEN`
- **⚠️ COPIE IDs DE ALGUNS ITENS**

**2.5 Adicionar Itens à Lista** (faça 2-3 vezes)
- Endpoint: `POST http://localhost:3000/api/lists/LIST_ID/items`
- Header: `Authorization: Bearer SEU_TOKEN`
- Body:
```json
{
  "itemId": "ITEM_ID",
  "quantity": 2,
  "notes": "Observação"
}
```

**2.6 Ver Lista Completa**
- Endpoint: `GET http://localhost:3000/api/lists/LIST_ID`
- Header: `Authorization: Bearer SEU_TOKEN`

---

### PASSO 3: 🎯 MOMENTO CRÍTICO - CHECKOUT

**👀 ANTES DE EXECUTAR:**
1. Posicione o **Terminal 5** (consumers) bem visível
2. Abra o **RabbitMQ Management** no navegador
3. Prepare para observar tudo acontecer simultaneamente

**🚀 Execute no Postman:**
- Endpoint: `POST http://localhost:3000/api/lists/LIST_ID/checkout`
- Header: `Authorization: Bearer SEU_TOKEN`

**✅ Observe:**
- ⚡ Resposta **202 Accepted** instantânea
- 📺 Terminal dos consumers imprimindo mensagens
- 📊 RabbitMQ Management mostrando filas ativas

---

## 📺 O QUE MOSTRAR NOS CONSOLES

### Terminal Consumer A (Notification):
```
═══════════════════════════════════════
📨 Nova mensagem recebida!
───────────────────────────────────────
📧 Enviando comprovante da lista [xyz-123] para o usuário [joao@demo.com]

📋 Detalhes da Lista:
   Nome: Lista Demo RabbitMQ
   Total de itens: 3
   Valor estimado: R$ 45.90

🛒 Itens da lista:
   1. [✗] Arroz Branco - 2 kg - R$ 15.00
   2. [✗] Feijão Carioca - 1 kg - R$ 8.90
   3. [✗] Detergente - 3 un - R$ 22.00

✉️  Email enviado com sucesso!
═══════════════════════════════════════
```

### Terminal Consumer B (Analytics):
```
═══════════════════════════════════════
📈 Novo evento para análise!
───────────────────────────────────────
💰 Total gasto nesta lista: R$ 45.90
📦 Itens comprados: 0/3

╔═══════════════════════════════════════════════╗
║           📊 DASHBOARD ANALYTICS              ║
╚═══════════════════════════════════════════════╝

📈 ESTATÍSTICAS GERAIS:
   Total de checkouts: 1
   Gasto total: R$ 45.90
   Total de itens: 3
   Média por checkout: R$ 45.90

🔥 TOP 5 ITENS MAIS FREQUENTES:
   1. Arroz Branco - 1x (2 unidades)
   2. Feijão Carioca - 1x (1 unidades)
   3. Detergente - 1x (3 unidades)
═══════════════════════════════════════
```

---

## 🐰 O QUE MOSTRAR NO RABBITMQ MANAGEMENT

### Aba "Exchanges":
- Clique em `shopping_events`
- Mostre: Type = **topic**, Durability = **Durable**
- Mostre os **Bindings** (2 filas conectadas)

### Aba "Queues and Streams":
- `notification_queue` → Messages processed
- `analytics_queue` → Messages processed
- Clique em cada fila e mostre os **gráficos** de mensagens

### Aba "Overview":
- Mostre o **gráfico** de message rates
- Mostre conexões ativas

---

## 🎯 PONTOS-CHAVE PARA DESTACAR

1. **⚡ API Responde Rápido** - 202 Accepted imediato, não espera processamento
2. **🔄 Processamento Assíncrono** - Consumers trabalham em paralelo
3. **📢 Pub/Sub Pattern** - 1 mensagem → múltiplos consumers
4. **🔌 Desacoplamento** - Producer não conhece consumers
5. **✅ Confiabilidade** - Mensagens persistentes + ACK manual

---

## 🔄 TESTE MÚLTIPLOS CHECKOUTS (Opcional)

Faça 3-4 checkouts seguidos (criar listas diferentes) e mostre:
- Analytics **acumulando** dados
- Dashboard atualizando com estatísticas
- RabbitMQ processando múltiplas mensagens

---

## 🧹 LIMPEZA

```bash
# Parar services
pkill -f node

# Remover RabbitMQ
docker stop rabbitmq && docker rm rabbitmq
```

---

## 📌 CHECKLIST FINAL

- [ ] RabbitMQ rodando (porta 15672 acessível)
- [ ] Postman configurado com requests
- [ ] Token obtido e salvo
- [ ] Lista criada com itens
- [ ] Terminal de consumers visível
- [ ] RabbitMQ Management aberto no navegador