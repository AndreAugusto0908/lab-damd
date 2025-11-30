import '../models/task.dart';
import 'database_service.dart';

/// Serviço de resolução de conflitos usando estratégia Last-Write-Wins (LWW)
class ConflictResolver {
  static final ConflictResolver instance = ConflictResolver._init();
  
  ConflictResolver._init();

  /// Resolve conflito entre tarefa local e servidor usando LWW
  /// Retorna a tarefa vencedora e um booleano indicando se deve fazer upload
  Future<ConflictResolutionResult> resolve({
    required Task localTask,
    required Task serverTask,
  }) async {
    // Obter timestamps de modificação
    final localTimestamp = _getLastModified(localTask);
    final serverTimestamp = _getLastModified(serverTask);

    // Comparar timestamps
    if (serverTimestamp.isAfter(localTimestamp)) {
      // Servidor mais recente - sobrescreve local
      print('🔄 Conflito resolvido: Servidor vence (${serverTask.id})');
      await _updateLocal(serverTask);
      
      return ConflictResolutionResult(
        winnerTask: serverTask,
        shouldUpload: false,
        reason: 'Servidor possui versão mais recente',
      );
    } else {
      // Local mais recente - sobe para servidor
      print('🔄 Conflito resolvido: Local vence (${localTask.id})');
      
      return ConflictResolutionResult(
        winnerTask: localTask,
        shouldUpload: true,
        reason: 'Local possui versão mais recente',
      );
    }
  }

  /// Extrai timestamp de última modificação
  DateTime _getLastModified(Task task) {
    // Prioridade: completedAt > createdAt
    if (task.completedAt != null) {
      return task.completedAt!;
    }
    return task.createdAt ?? DateTime.now();
  }

  /// Atualiza tarefa local com dados do servidor
  Future<void> _updateLocal(Task serverTask) async {
    try {
      await DatabaseService.instance.update(serverTask);
      print('✅ Tarefa local atualizada com dados do servidor');
    } catch (e) {
      print('❌ Erro ao atualizar local: $e');
      rethrow;
    }
  }

  /// Verifica se há conflito entre duas tarefas
  bool hasConflict(Task local, Task server) {
    // Se timestamps são diferentes, há potencial conflito
    final localTimestamp = _getLastModified(local);
    final serverTimestamp = _getLastModified(server);
    
    return localTimestamp != serverTimestamp;
  }

  /// Resolve lote de conflitos
  Future<List<ConflictResolutionResult>> resolveBatch({
    required Map<int, Task> localTasks,
    required Map<int, Task> serverTasks,
  }) async {
    final results = <ConflictResolutionResult>[];

    for (final entry in localTasks.entries) {
      final taskId = entry.key;
      final localTask = entry.value;
      final serverTask = serverTasks[taskId];

      if (serverTask != null && hasConflict(localTask, serverTask)) {
        final result = await resolve(
          localTask: localTask,
          serverTask: serverTask,
        );
        results.add(result);
      }
    }

    print('✅ Resolvidos ${results.length} conflitos');
    return results;
  }
}

/// Resultado da resolução de conflito
class ConflictResolutionResult {
  final Task winnerTask;
  final bool shouldUpload;
  final String reason;

  ConflictResolutionResult({
    required this.winnerTask,
    required this.shouldUpload,
    required this.reason,
  });

  @override
  String toString() => 'ConflictResolution(id: ${winnerTask.id}, upload: $shouldUpload, reason: $reason)';
}