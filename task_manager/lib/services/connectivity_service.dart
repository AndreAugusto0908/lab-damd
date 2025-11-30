import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Serviço para gerenciar e monitorar conectividade de rede
class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._init();
  
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  
  // Stream controller para notificar mudanças
  final _connectivityController = StreamController<bool>.broadcast();
  
  bool _isConnected = false;
  ConnectivityResult _lastResult = ConnectivityResult.none;

  ConnectivityService._init();

  /// Getter para status atual
  bool get isConnected => _isConnected;
  
  /// Getter para tipo de conexão
  ConnectivityResult get connectionType => _lastResult;
  
  /// Stream para ouvir mudanças de conectividade
  Stream<bool> get onConnectivityChanged => _connectivityController.stream;

  /// Inicializa o monitoramento de conectividade
  Future<void> initialize() async {
    // Verifica status inicial
    await _checkConnectivity();
    
    // Monitora mudanças
    _subscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        _updateConnectivity(results);
      },
    );
    
    print('🌐 ConnectivityService inicializado');
  }

  /// Verifica conectividade atual
  Future<void> _checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _updateConnectivity(results);
    } catch (e) {
      print('❌ Erro ao verificar conectividade: $e');
      _updateStatus(false, ConnectivityResult.none);
    }
  }

  /// Atualiza status baseado nos resultados
  void _updateConnectivity(List<ConnectivityResult> results) {
    if (results.isEmpty) {
      _updateStatus(false, ConnectivityResult.none);
      return;
    }

    // Prioridade: wifi > mobile > ethernet > outros
    ConnectivityResult primary = ConnectivityResult.none;
    
    if (results.contains(ConnectivityResult.wifi)) {
      primary = ConnectivityResult.wifi;
    } else if (results.contains(ConnectivityResult.mobile)) {
      primary = ConnectivityResult.mobile;
    } else if (results.contains(ConnectivityResult.ethernet)) {
      primary = ConnectivityResult.ethernet;
    } else {
      primary = results.first;
    }

    final isConnected = primary != ConnectivityResult.none;
    _updateStatus(isConnected, primary);
  }

  /// Atualiza status interno e notifica listeners
  void _updateStatus(bool isConnected, ConnectivityResult result) {
    final statusChanged = _isConnected != isConnected;
    final typeChanged = _lastResult != result;
    
    _isConnected = isConnected;
    _lastResult = result;

    if (statusChanged || typeChanged) {
      _connectivityController.add(_isConnected);
      _logStatusChange();
    }
  }

  /// Log de mudanças de status
  void _logStatusChange() {
    final emoji = _isConnected ? '🟢' : '🔴';
    final status = _isConnected ? 'ONLINE' : 'OFFLINE';
    final type = _getConnectionTypeString();
    
    print('$emoji Conectividade: $status ${type.isNotEmpty ? "($type)" : ""}');
  }

  /// Retorna string descritiva do tipo de conexão
  String _getConnectionTypeString() {
    switch (_lastResult) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Dados Móveis';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.vpn:
        return 'VPN';
      case ConnectivityResult.bluetooth:
        return 'Bluetooth';
      case ConnectivityResult.other:
        return 'Outra';
      case ConnectivityResult.none:
      default:
        return '';
    }
  }

  /// Retorna ícone apropriado para o tipo de conexão
  String getConnectionIcon() {
    if (!_isConnected) return '📡';
    
    switch (_lastResult) {
      case ConnectivityResult.wifi:
        return '📶';
      case ConnectivityResult.mobile:
        return '📱';
      case ConnectivityResult.ethernet:
        return '🖥️';
      case ConnectivityResult.vpn:
        return '🔒';
      default:
        return '🌐';
    }
  }

  /// Força recheck da conectividade
  Future<void> refresh() async {
    await _checkConnectivity();
  }

  /// Para o monitoramento e libera recursos
  void dispose() {
    _subscription?.cancel();
    _connectivityController.close();
    print('🔌 ConnectivityService finalizado');
  }
}

/// Model para estado de conectividade (opcional)
class ConnectivityStatus {
  final bool isConnected;
  final ConnectivityResult type;
  final DateTime timestamp;

  ConnectivityStatus({
    required this.isConnected,
    required this.type,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get displayText {
    if (!isConnected) return 'Offline';
    
    switch (type) {
      case ConnectivityResult.wifi:
        return 'Online (WiFi)';
      case ConnectivityResult.mobile:
        return 'Online (Móvel)';
      case ConnectivityResult.ethernet:
        return 'Online (Ethernet)';
      default:
        return 'Online';
    }
  }

  @override
  String toString() => displayText;
}