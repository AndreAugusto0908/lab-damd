import 'dart:async';
import 'dart:math' show cos, sqrt, asin, pi;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/task.dart';
import 'sync_queue_service.dart';
import 'connectivity_service.dart';

/// Serviço de persistência local usando SQLite
class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  /// Getter lazy do banco de dados
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasks.db');
    return _database!;
  }

  /// Inicializa o banco de dados
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    
    return await openDatabase(
      path,
      version: 5,  // ← INCREMENTAR VERSÃO (era 4, agora 5)
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// Cria a estrutura inicial do banco
  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';

    // Tabela de tarefas
    await db.execute('''
      CREATE TABLE tasks (
        id $idType,
        title $textType,
        description $textType,
        priority $textType,
        completed $intType,
        createdAt $textType,
        photoPath TEXT,
        completedAt TEXT,
        completedBy TEXT,
        latitude REAL,
        longitude REAL,
        locationName TEXT,
        syncedToApi INTEGER DEFAULT 0,
        lastModified TEXT
      )
    ''');

    // ==================== NOVA TABELA: SYNC_QUEUE ====================
    await db.execute('''
      CREATE TABLE sync_queue (
        id $idType,
        operation $textType,
        tableName $textType,
        entityId $intType,
        payload TEXT,
        createdAt $textType,
        attempts INTEGER DEFAULT 0,
        lastError TEXT,
        status TEXT DEFAULT 'pending'
      )
    ''');

    // Índices para tasks
    await db.execute('CREATE INDEX idx_completed ON tasks(completed)');
    await db.execute('CREATE INDEX idx_priority ON tasks(priority)');
    await db.execute('CREATE INDEX idx_location ON tasks(latitude, longitude)');
    await db.execute('CREATE INDEX idx_synced ON tasks(syncedToApi)');

    // Índices para sync_queue
    await db.execute('CREATE INDEX idx_queue_status ON sync_queue(status)');
    await db.execute('CREATE INDEX idx_queue_entity ON sync_queue(tableName, entityId)');

    print('✅ Banco de dados criado com sucesso (v$version)');
    
    // Injetar referência do banco no SyncQueueService
    SyncQueueService.instance.setDatabase(db);
  }

  /// Migração incremental entre versões
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('🔄 Migrando banco de v$oldVersion para v$newVersion');

    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tasks ADD COLUMN photoPath TEXT');
      print('  ✓ Adicionada coluna photoPath');
    }
    
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE tasks ADD COLUMN completedAt TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN completedBy TEXT');
      print('  ✓ Adicionadas colunas de conclusão');
    }
    
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE tasks ADD COLUMN latitude REAL');
      await db.execute('ALTER TABLE tasks ADD COLUMN longitude REAL');
      await db.execute('ALTER TABLE tasks ADD COLUMN locationName TEXT');
      await db.execute('ALTER TABLE tasks ADD COLUMN syncedToApi INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE tasks ADD COLUMN lastModified TEXT');
      
      await db.execute('CREATE INDEX idx_completed ON tasks(completed)');
      await db.execute('CREATE INDEX idx_priority ON tasks(priority)');
      await db.execute('CREATE INDEX idx_location ON tasks(latitude, longitude)');
      await db.execute('CREATE INDEX idx_synced ON tasks(syncedToApi)');
      
      print('  ✓ Adicionadas colunas de localização e sincronização');
    }

    // ==================== NOVA MIGRAÇÃO: v5 ====================
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE sync_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          operation TEXT NOT NULL,
          tableName TEXT NOT NULL,
          entityId INTEGER NOT NULL,
          payload TEXT,
          createdAt TEXT NOT NULL,
          attempts INTEGER DEFAULT 0,
          lastError TEXT,
          status TEXT DEFAULT 'pending'
        )
      ''');
      
      await db.execute('CREATE INDEX idx_queue_status ON sync_queue(status)');
      await db.execute('CREATE INDEX idx_queue_entity ON sync_queue(tableName, entityId)');
      
      print('  ✓ Criada tabela sync_queue');
      
      // Injetar referência do banco
      SyncQueueService.instance.setDatabase(db);
    }

    print('✅ Migração concluída com sucesso');
  }

  // ==================== CRUD OPERATIONS COM FILA ====================

  /// Cria uma nova tarefa no banco
  Future<Task> create(Task task) async {
    final db = await instance.database;
    
    try {
      final taskWithTimestamp = task.copyWith(
        createdAt: task.createdAt ?? DateTime.now(),
      );
      
      final id = await db.insert(
        'tasks', 
        taskWithTimestamp.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      
      final createdTask = taskWithTimestamp.copyWith(id: id);
      
      // ✅ ADICIONAR À FILA SE OFFLINE
      if (!ConnectivityService.instance.isConnected) {
        await SyncQueueService.instance.enqueueCreate(
          'tasks',
          id,
          createdTask.toMap(),
        );
      }
      
      print('✅ Tarefa criada: ID $id');
      return createdTask;
    } catch (e) {
      print('❌ Erro ao criar tarefa: $e');
      rethrow;
    }
  }

  /// Atualiza uma tarefa existente
  Future<int> update(Task task) async {
    final db = await instance.database;
    
    try {
      final result = await db.update(
        'tasks',
        task.toMap(),
        where: 'id = ?',
        whereArgs: [task.id],
      );
      
      if (result > 0) {
        // ✅ ADICIONAR À FILA SE OFFLINE
        if (!ConnectivityService.instance.isConnected) {
          await SyncQueueService.instance.enqueueUpdate(
            'tasks',
            task.id!,
            task.toMap(),
          );
        }
        
        print('✅ Tarefa atualizada: ID ${task.id}');
      }
      return result;
    } catch (e) {
      print('❌ Erro ao atualizar tarefa ${task.id}: $e');
      return 0;
    }
  }

  /// Deleta uma tarefa por ID
  Future<int> delete(int id) async {
    final db = await instance.database;
    
    try {
      final result = await db.delete(
        'tasks',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (result > 0) {
        // ✅ ADICIONAR À FILA SE OFFLINE
        if (!ConnectivityService.instance.isConnected) {
          await SyncQueueService.instance.enqueueDelete('tasks', id);
        }
        
        print('✅ Tarefa deletada: ID $id');
      }
      return result;
    } catch (e) {
      print('❌ Erro ao deletar tarefa $id: $e');
      return 0;
    }
  }

  // ==================== READ OPERATIONS (SEM MUDANÇAS) ====================

  Future<Task?> read(int id) async {
    final db = await instance.database;
    
    try {
      final maps = await db.query(
        'tasks',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (maps.isNotEmpty) {
        return Task.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('❌ Erro ao ler tarefa $id: $e');
      return null;
    }
  }

  Future<List<Task>> readAll() async {
    final db = await instance.database;
    
    try {
      const orderBy = 'createdAt DESC';
      final result = await db.query('tasks', orderBy: orderBy);
      return result.map((json) => Task.fromMap(json)).toList();
    } catch (e) {
      print('❌ Erro ao ler todas as tarefas: $e');
      return [];
    }
  }

  Future<List<Task>> readByStatus({required bool completed}) async {
    final db = await instance.database;
    
    try {
      final result = await db.query(
        'tasks',
        where: 'completed = ?',
        whereArgs: [completed ? 1 : 0],
        orderBy: 'createdAt DESC',
      );
      return result.map((json) => Task.fromMap(json)).toList();
    } catch (e) {
      print('❌ Erro ao filtrar tarefas: $e');
      return [];
    }
  }

  Future<List<Task>> readByPriority(String priority) async {
    final db = await instance.database;
    
    try {
      final result = await db.query(
        'tasks',
        where: 'priority = ?',
        whereArgs: [priority],
        orderBy: 'createdAt DESC',
      );
      return result.map((json) => Task.fromMap(json)).toList();
    } catch (e) {
      print('❌ Erro ao filtrar por prioridade: $e');
      return [];
    }
  }

  Future<int> deleteAll() async {
    final db = await instance.database;
    
    try {
      final result = await db.delete('tasks');
      print('✅ $result tarefas deletadas');
      return result;
    } catch (e) {
      print('❌ Erro ao deletar todas as tarefas: $e');
      return 0;
    }
  }

  // ==================== LOCATION-BASED QUERIES ====================

  Future<List<Task>> getTasksNearLocation({
    required double latitude,
    required double longitude,
    double radiusInMeters = 1000,
  }) async {
    final allTasks = await readAll();
    
    return allTasks.where((task) {
      if (!task.hasLocation) return false;
      
      final distance = _calculateDistance(
        latitude,
        longitude,
        task.latitude!,
        task.longitude!,
      );
      
      return distance <= radiusInMeters;
    }).toList();
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = (sin(dLat / 2) * sin(dLat / 2)) +
        (cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2));
    
    final c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * (pi / 180);

  // ==================== SYNC OPERATIONS ====================

  Future<void> markAsSynced(int id) async {
    final db = await instance.database;
    
    try {
      await db.update(
        'tasks',
        {
          'syncedToApi': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      print('✅ Tarefa $id marcada como sincronizada');
    } catch (e) {
      print('❌ Erro ao marcar tarefa $id como sincronizada: $e');
    }
  }

  Future<List<Task>> getUnsyncedTasks() async {
    final db = await instance.database;
    
    try {
      final result = await db.query(
        'tasks',
        where: 'syncedToApi = ?',
        whereArgs: [0],
        orderBy: 'createdAt ASC',
      );
      return result.map((json) => Task.fromMap(json)).toList();
    } catch (e) {
      print('❌ Erro ao buscar tarefas não sincronizadas: $e');
      return [];
    }
  }

  // ==================== STATISTICS ====================

  Future<Map<String, dynamic>> getStatistics() async {
    final db = await instance.database;
    
    try {
      final total = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM tasks'),
      ) ?? 0;
      
      final completed = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM tasks WHERE completed = 1'),
      ) ?? 0;
      
      final pending = total - completed;
      
      final withLocation = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM tasks WHERE latitude IS NOT NULL',
        ),
      ) ?? 0;
      
      final unsynced = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM tasks WHERE syncedToApi = 0'),
      ) ?? 0;

      // ✅ ESTATÍSTICAS DA FILA
      final queueStats = await SyncQueueService.instance.getStatistics();
      
      return {
        'total': total,
        'completed': completed,
        'pending': pending,
        'withLocation': withLocation,
        'unsynced': unsynced,
        'queuePending': queueStats['pending'] ?? 0,
        'queueFailed': queueStats['failed'] ?? 0,
        'completionRate': total > 0 ? (completed / total * 100).toStringAsFixed(1) : '0.0',
      };
    } catch (e) {
      print('❌ Erro ao calcular estatísticas: $e');
      return {};
    }
  }

  // ==================== UTILITY METHODS ====================

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
    _database = null;
    print('🔒 Conexão com banco de dados fechada');
  }

  Future<void> resetDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'tasks.db');
    
    await deleteDatabase(path);
    _database = null;
    
    print('🔄 Banco de dados resetado');
  }
}

// Funções matemáticas
double sin(double x) => x - (x * x * x) / 6 + (x * x * x * x * x) / 120;
double cos(double x) => 1 - (x * x) / 2 + (x * x * x * x) / 24;
double sqrt(double x) => x > 0 ? x / 2 : 0;
double asin(double x) => x + (x * x * x) / 6;