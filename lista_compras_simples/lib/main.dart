import 'package:flutter/material.dart';

void main() {
  runApp(const MeuApp());
}

class MeuApp extends StatelessWidget {
  const MeuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lista de Compras',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const PaginaInicial(),
    );
  }
}

class PaginaInicial extends StatefulWidget {
  const PaginaInicial({super.key});

  @override
  State<PaginaInicial> createState() => _PaginaInicialState();
}

class ItemCompra {
  String nome;
  String categoria;
  bool comprado;

  ItemCompra({
    required this.nome,
    required this.categoria,
    this.comprado = false,
  });
}

class _PaginaInicialState extends State<PaginaInicial> {
  List<ItemCompra> itensCompra = [];
  TextEditingController controladorTexto = TextEditingController();
  String categoriaSelecionada = 'Alimentos';

  // Categorias disponíveis com ícones e cores
  final Map<String, Map<String, dynamic>> categorias = {
    'Alimentos': {'icone': Icons.restaurant, 'cor': Colors.orange},
    'Bebidas': {'icone': Icons.local_drink, 'cor': Colors.blue},
    'Limpeza': {'icone': Icons.cleaning_services, 'cor': Colors.green},
    'Higiene': {'icone': Icons.soap, 'cor': Colors.purple},
    'Padaria': {'icone': Icons.bakery_dining, 'cor': Colors.brown},
    'Açougue': {'icone': Icons.set_meal, 'cor': Colors.red},
    'Hortifruti': {'icone': Icons.eco, 'cor': Colors.lightGreen},
    'Outros': {'icone': Icons.shopping_basket, 'cor': Colors.grey},
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Lista de Compras'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: limparLista,
            tooltip: 'Limpar lista',
          ),
        ],
      ),
      
      body: Column(
        children: [
          // Área para adicionar itens
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controladorTexto,
                        decoration: const InputDecoration(
                          hintText: 'Digite um item para comprar...',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.add_shopping_cart),
                        ),
                        onSubmitted: (texto) => adicionarItem(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: adicionarItem,
                      icon: const Icon(Icons.add),
                      label: const Text('Adicionar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Seletor de categoria
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        categorias[categoriaSelecionada]!['icone'],
                        color: categorias[categoriaSelecionada]!['cor'],
                      ),
                      const SizedBox(width: 8),
                      const Text('Categoria: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      Expanded(
                        child: DropdownButton<String>(
                          value: categoriaSelecionada,
                          isExpanded: true,
                          underline: Container(),
                          items: categorias.keys.map((String categoria) {
                            return DropdownMenuItem<String>(
                              value: categoria,
                              child: Row(
                                children: [
                                  Icon(
                                    categorias[categoria]!['icone'],
                                    size: 20,
                                    color: categorias[categoria]!['cor'],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(categoria),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (String? novaCategoria) {
                            setState(() {
                              categoriaSelecionada = novaCategoria!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Estatísticas rápidas
          if (itensCompra.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _criarEstatistica(
                    'Total', 
                    '${itensCompra.length}', 
                    Icons.list, 
                    Colors.blue
                  ),
                  _criarEstatistica(
                    'Comprados', 
                    '${itensCompra.where((item) => item.comprado).length}', 
                    Icons.check_circle, 
                    Colors.green
                  ),
                  _criarEstatistica(
                    'Restantes', 
                    '${itensCompra.where((item) => !item.comprado).length}', 
                    Icons.pending, 
                    Colors.orange
                  ),
                ],
              ),
            ),
          
          // Lista de itens agrupados por categoria
          Expanded(
            child: itensCompra.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_cart_outlined, 
                             size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text(
                          'Sua lista está vazia!',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          'Adicione itens para começar suas compras',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(8),
                    children: _construirListaPorCategoria(),
                  ),
          ),
        ],
      ),
    );
  }

  // Constrói a lista agrupada por categoria
  List<Widget> _construirListaPorCategoria() {
    List<Widget> widgets = [];
    
    // Agrupa itens por categoria
    Map<String, List<ItemCompra>> itensPorCategoria = {};
    for (var item in itensCompra) {
      if (!itensPorCategoria.containsKey(item.categoria)) {
        itensPorCategoria[item.categoria] = [];
      }
      itensPorCategoria[item.categoria]!.add(item);
    }

    // Cria widgets para cada categoria
    itensPorCategoria.forEach((categoria, itens) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 8, top: 16, bottom: 8),
          child: Row(
            children: [
              Icon(
                categorias[categoria]!['icone'],
                color: categorias[categoria]!['cor'],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                categoria,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: categorias[categoria]!['cor'],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: categorias[categoria]!['cor'].withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${itens.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: categorias[categoria]!['cor'],
                  ),
                ),
              ),
            ],
          ),
        ),
      );

      // Adiciona os itens da categoria
      for (var item in itens) {
        int indice = itensCompra.indexOf(item);
        widgets.add(
          Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              leading: Checkbox(
                value: item.comprado,
                onChanged: (valor) => marcarComoComprado(indice, valor ?? false),
              ),
              title: Text(
                item.nome,
                style: TextStyle(
                  decoration: item.comprado ? TextDecoration.lineThrough : null,
                  color: item.comprado ? Colors.grey : Colors.black,
                  fontSize: 16,
                ),
              ),
              subtitle: Row(
                children: [
                  Icon(
                    categorias[item.categoria]!['icone'],
                    size: 14,
                    color: categorias[item.categoria]!['cor'].withOpacity(0.7),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    item.categoria,
                    style: TextStyle(
                      fontSize: 12,
                      color: categorias[item.categoria]!['cor'].withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => mostrarConfirmacaoRemocao(indice),
              ),
              tileColor: item.comprado ? Colors.green[50] : null,
            ),
          ),
        );
      }
    });

    return widgets;
  }

  Widget _criarEstatistica(String titulo, String valor, IconData icone, Color cor) {
    return Column(
      children: [
        Icon(icone, color: cor, size: 24),
        const SizedBox(height: 4),
        Text(
          valor,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: cor),
        ),
        Text(titulo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  void adicionarItem() {
    String novoItem = controladorTexto.text.trim();
    
    if (novoItem.isNotEmpty) {
      // Verificar se item já existe
      if (itensCompra.any((item) => item.nome.toLowerCase() == novoItem.toLowerCase())) {
        _mostrarMensagem('Este item já está na sua lista!');
        return;
      }
      
      setState(() {
        itensCompra.add(ItemCompra(
          nome: novoItem,
          categoria: categoriaSelecionada,
        ));
        controladorTexto.clear();
      });
      
      _mostrarMensagem('Item "$novoItem" adicionado em $categoriaSelecionada!');
    }
  }

  void removerItem(int indice) {
    String itemRemovido = itensCompra[indice].nome;
    setState(() {
      itensCompra.removeAt(indice);
    });
    _mostrarMensagem('Item "$itemRemovido" removido!');
  }

  void marcarComoComprado(int indice, bool comprado) {
    setState(() {
      itensCompra[indice].comprado = comprado;
    });
    
    String mensagem = comprado ? 'Item comprado!' : 'Item desmarcado!';
    _mostrarMensagem(mensagem);
  }

  void limparLista() {
    if (itensCompra.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Limpar Lista'),
          content: const Text('Tem certeza que deseja remover todos os itens?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  itensCompra.clear();
                });
                Navigator.of(context).pop();
                _mostrarMensagem('Lista limpa!');
              },
              child: const Text('Limpar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void mostrarConfirmacaoRemocao(int indice) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remover Item'),
          content: Text('Remover "${itensCompra[indice].nome}" da lista?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                removerItem(indice);
                Navigator.of(context).pop();
              },
              child: const Text('Remover', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _mostrarMensagem(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    controladorTexto.dispose();
    super.dispose();
  }
}