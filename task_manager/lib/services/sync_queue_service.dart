import 'dart:convert';
import 'package:sqflite/sqflite.dart';

/// Model para item da fila de sincronização
class SyncQueueItem {
  final int? id;
  final String operation; // 'CREATE', 'UPDATE', 'DELETE'
  final String tableName; // 'tasks'
  final int entityId; // ID da tarefa
  final String? payload; // JSON com dados completos
  final DateTime createdAt;
  final int attempts; // Número de tentativas
  final String? lastError; // Último erro
  final String status; // 'pending', 'processing', 'failed'

  SyncQueueItem({
    this.id,
    required this.operation,
    required this.tableName,
    required this.entityId,
    this.payload,
    DateTime? createdAt,
    this.attempts = 0,
    this.lastError,
    this.status = 'pending',
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'operation': operation,
      'tableName': tableName,
      'entityId': entityId,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
      'attempts': attempts,
      'lastError': lastError,
      'status': status,
    };
  }

  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    return SyncQueueItem(
      id: map['id'],
      operation: map['operation'],
      tableName: map['tableName'],
      entityId: map['entityId'],
      payload: map['payload'],
      createdAt: DateTime.parse(map['createdAt']),
      attempts: map['attempts'] ?? 0,
      lastError: map['lastError'],
      status: map['status'] ?? 'pending',
    );
  }

  SyncQueueItem copyWith({
    int? id,
    String? operation,
    String? tableName,
    int? entityId,
    String? payload,
    DateTime? createdAt,
    int? attempts,
    String? lastError,
    String? status,
  }) {
    return SyncQueueItem(
      id: id ?? this.id,
      operation: operation ?? this.operation,
      tableName: tableName ?? this.tableName,
      entityId: entityId ?? this.entityId,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      status: status ?? this.status,
    );
  }

  @override
  String toString() => 'SyncQueueItem(id: $id, op: $operation, entity: $entityId, status: $status)';
}

/// Serviço para gerenciar fila de sincronização
class SyncQueueService {
  static final SyncQueueService instance = SyncQueueService._init();
  Database? _database;

  SyncQueueService._init();

  /// Injeta referência do banco de dados
  void setDatabase(Database db) {
    _database = db;
  }

  Database get _db {
    if (_database == null) {
      throw Exception('Database não inicializado! Chame setDatabase() primeiro.');
    }
    return _database!;
  }

  // ==================== QUEUE OPERATIONS ====================

  /// Adiciona operação CREATE à fila
  Future<void> enqueueCreate(String tableName, int entityId, Map<String, dynamic> data) async {
    await _enqueue(
      operation: 'CREATE',
      tableName: tableName,
      entityId: entityId,
      payload: jsonEncode(data),
    );
  }

  /// Adiciona operação UPDATE à fila
  Future<void> enqueueUpdate(String tableName, int entityId, Map<String, dynamic> data) async {
    await _enqueue(
      operation: 'UPDATE',
      tableName: tableName,
      entityId: entityId,
      payload: jsonEncode(data),
    );
  }

  /// Adiciona operação DELETE à fila
  Future<void> enqueueDelete(String tableName, int entityId) async {
    await _enqueue(
      operation: 'DELETE',
      tableName: tableName,
      entityId: entityId,
    );
  }

  /// Adiciona item à fila (método interno)
  Future<void> _enqueue({
    required String operation,
    required String tableName,
    required int entityId,
    String? payload,
  }) async {
    try {
      // Verificar se já existe operação pendente para mesma entidade
      final existing = await _db.query(
        'sync_queue',
        where: 'tableName = ? AND entityId = ? AND status = ?',
        whereArgs: [tableName, entityId, 'pending'],
      );

      if (existing.isNotEmpty) {
        // Atualizar operação existente
        final item = SyncQueueItem.fromMap(existing.first);
        
        await _db.update(
          'sync_queue',
          {
            'operation': operation,
            'payload': payload,
            'createdAt': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [item.id],
        );
        
        print('🔄 Operação atualizada na fila: $operation - $tableName:$entityId');
      } else {
        // Inserir nova operação
        final item = SyncQueueItem(
          operation: operation,
          tableName: tableName,
          entityId: entityId,
          payload: payload,
        );

        await _db.insert('sync_queue', item.toMap());
        print('➕ Adicionado à fila: $operation - $tableName:$entityId');
      }
    } catch (e) {
      print('❌ Erro ao adicionar à fila: $e');
      rethrow;
    }
  }

  /// Retorna todos os itens pendentes da fila
  Future<List<SyncQueueItem>> getPendingItems() async {
    try {
      final result = await _db.query(
        'sync_queue',
        where: 'status = ?',
        whereArgs: ['pending'],
        orderBy: 'createdAt ASC',
      );

      return result.map((map) => SyncQueueItem.fromMap(map)).toList();
    } catch (e) {
      print('❌ Erro ao buscar itens pendentes: $e');
      return [];
    }
  }

  /// Retorna itens com falha que podem ser retentados
  Future<List<SyncQueueItem>> getRetryableItems({int maxAttempts = 3}) async {
    try {
      final result = await _db.query(
        'sync_queue',
        where: 'status = ? AND attempts < ?',
        whereArgs: ['failed', maxAttempts],
        orderBy: 'createdAt ASC',
      );

      return result.map((map) => SyncQueueItem.fromMap(map)).toList();
    } catch (e) {
      print('❌ Erro ao buscar itens para retry: $e');
      return [];
    }
  }

  /// Marca item como processando
  Future<void> markAsProcessing(int id) async {
    try {
      await _db.update(
        'sync_queue',
        {'status': 'processing'},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('❌ Erro ao marcar como processando: $e');
    }
  }

  /// Marca item como concluído e remove da fila
  Future<void> markAsCompleted(int id) async {
    try {
      await _db.delete(
        'sync_queue',
        where: 'id = ?',
        whereArgs: [id],
      );
      print('✅ Item $id removido da fila (concluído)');
    } catch (e) {
      print('❌ Erro ao remover item da fila: $e');
    }
  }

  /// Marca item como falho e incrementa tentativas
  Future<void> markAsFailed(int id, String error) async {
    try {
      final item = await _getItemById(id);
      if (item == null) return;

      await _db.update(
        'sync_queue',
        {
          'status': 'failed',
          'attempts': item.attempts + 1,
          'lastError': error,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      
      print('⚠️ Item $id marcado como falho (tentativa ${item.attempts + 1})');
    } catch (e) {
      print('❌ Erro ao marcar como falho: $e');
    }
  }

  /// Busca item por ID
  Future<SyncQueueItem?> _getItemById(int id) async {
    try {
      final result = await _db.query(
        'sync_queue',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (result.isEmpty) return null;
      return SyncQueueItem.fromMap(result.first);
    } catch (e) {
      print('❌ Erro ao buscar item: $e');
      return null;
    }
  }

  /// Limpa itens que excederam limite de tentativas
  Future<int> cleanupFailedItems({int maxAttempts = 5}) async {
    try {
      final count = await _db.delete(
        'sync_queue',
        where: 'status = ? AND attempts >= ?',
        whereArgs: ['failed', maxAttempts],
      );
      
      if (count > 0) {
        print('🗑️ $count itens com falha permanente removidos');
      }
      return count;
    } catch (e) {
      print('❌ Erro ao limpar itens falhos: $e');
      return 0;
    }
  }

  /// Limpa toda a fila (usar com cautela!)
  Future<int> clearAll() async {
    try {
      final count = await _db.delete('sync_queue');
      print('🗑️ Fila limpa: $count itens removidos');
      return count;
    } catch (e) {
      print('❌ Erro ao limpar fila: $e');
      return 0;
    }
  }

  // ==================== STATISTICS ====================

  /// Retorna estatísticas da fila
  Future<Map<String, int>> getStatistics() async {
    try {
      final total = Sqflite.firstIntValue(
        await _db.rawQuery('SELECT COUNT(*) FROM sync_queue'),
      ) ?? 0;

      final pending = Sqflite.firstIntValue(
        await _db.rawQuery(
          'SELECT COUNT(*) FROM sync_queue WHERE status = ?',
          ['pending'],
        ),
      ) ?? 0;

      final processing = Sqflite.firstIntValue(
        await _db.rawQuery(
          'SELECT COUNT(*) FROM sync_queue WHERE status = ?',
          ['processing'],
        ),
      ) ?? 0;

      final failed = Sqflite.firstIntValue(
        await _db.rawQuery(
          'SELECT COUNT(*) FROM sync_queue WHERE status = ?',
          ['failed'],
        ),
      ) ?? 0;

      return {
        'total': total,
        'pending': pending,
        'processing': processing,
        'failed': failed,
      };
    } catch (e) {
      print('❌ Erro ao calcular estatísticas: $e');
      return {};
    }
  }

  /// Conta itens por operação
  Future<Map<String, int>> getOperationCounts() async {
    try {
      final result = await _db.rawQuery('''
        SELECT operation, COUNT(*) as count 
        FROM sync_queue 
        WHERE status = 'pending'
        GROUP BY operation
      ''');

      final counts = <String, int>{
        'CREATE': 0,
        'UPDATE': 0,
        'DELETE': 0,
      };

      for (var row in result) {
        counts[row['operation'] as String] = row['count'] as int;
      }

      return counts;
    } catch (e) {
      print('❌ Erro ao contar operações: $e');
      return {'CREATE': 0, 'UPDATE': 0, 'DELETE': 0};
    }
  }

  /// Verifica se há itens pendentes
  Future<bool> hasPendingItems() async {
    try {
      final count = Sqflite.firstIntValue(
        await _db.rawQuery(
          'SELECT COUNT(*) FROM sync_queue WHERE status = ?',
          ['pending'],
        ),
      ) ?? 0;

      return count > 0;
    } catch (e) {
      print('❌ Erro ao verificar itens pendentes: $e');
      return false;
    }
  }

  /// Retorna próximo item para processar
  Future<SyncQueueItem?> getNextItem() async {
    try {
      final result = await _db.query(
        'sync_queue',
        where: 'status = ?',
        whereArgs: ['pending'],
        orderBy: 'createdAt ASC',
        limit: 1,
      );

      if (result.isEmpty) return null;
      return SyncQueueItem.fromMap(result.first);
    } catch (e) {
      print('❌ Erro ao buscar próximo item: $e');
      return null;
    }
  }
}