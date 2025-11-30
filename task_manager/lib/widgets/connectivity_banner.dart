import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

/// Banner animado que mostra status de conectividade
/// Aparece automaticamente quando a conexão é perdida ou restaurada
class ConnectivityBanner extends StatefulWidget {
  final Widget child;
  final Duration displayDuration;
  final bool showOnline;
  final bool showOffline;

  const ConnectivityBanner({
    super.key,
    required this.child,
    this.displayDuration = const Duration(seconds: 3),
    this.showOnline = true,
    this.showOffline = true,
  });

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  bool _showBanner = false;
  bool _isOnline = true;
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Escuta mudanças de conectividade
    ConnectivityService.instance.onConnectivityChanged.listen((isOnline) {
      _handleConnectivityChange(isOnline);
    });

    // Status inicial
    _isOnline = ConnectivityService.instance.isConnected;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleConnectivityChange(bool isOnline) {
    // Decide se deve mostrar banner
    final shouldShow = (isOnline && widget.showOnline) || 
                       (!isOnline && widget.showOffline);

    if (!shouldShow) return;

    setState(() {
      _isOnline = isOnline;
      _showBanner = true;
    });

    // Anima entrada
    _controller.forward();

    // Auto-hide após duração
    Future.delayed(widget.displayDuration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) {
            setState(() => _showBanner = false);
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showBanner)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildBanner(),
            ),
          ),
      ],
    );
  }

  Widget _buildBanner() {
    final color = _isOnline ? Colors.green : Colors.orange;
    final icon = _isOnline ? Icons.cloud_done : Icons.cloud_off;
    final message = _isOnline 
        ? 'Conectado à internet'
        : 'Modo offline - dados serão sincronizados depois';

    return Material(
      color: color,
      elevation: 4,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  _controller.reverse().then((_) {
                    if (mounted) {
                      setState(() => _showBanner = false);
                    }
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget de status inline (para AppBar ou Footer)
class ConnectivityStatusWidget extends StatefulWidget {
  final bool compact;
  final VoidCallback? onTap;

  const ConnectivityStatusWidget({
    super.key,
    this.compact = false,
    this.onTap,
  });

  @override
  State<ConnectivityStatusWidget> createState() =>
      _ConnectivityStatusWidgetState();
}

class _ConnectivityStatusWidgetState extends State<ConnectivityStatusWidget> {
  bool _isOnline = true;
  String _connectionType = '';

  @override
  void initState() {
    super.initState();
    _updateStatus();
    
    ConnectivityService.instance.onConnectivityChanged.listen((_) {
      if (mounted) _updateStatus();
    });
  }

  void _updateStatus() {
    setState(() {
      _isOnline = ConnectivityService.instance.isConnected;
      _connectionType = _getConnectionType();
    });
  }

  String _getConnectionType() {
    final result = ConnectivityService.instance.connectionType;
    return ConnectivityService.instance.isConnected
        ? result.toString().split('.').last
        : '';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 8 : 12,
          vertical: widget.compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: _isOnline
              ? Colors.green.withOpacity(0.15)
              : Colors.orange.withOpacity(0.15),
          borderRadius: BorderRadius.circular(widget.compact ? 12 : 20),
          border: Border.all(
            color: _isOnline ? Colors.green : Colors.orange,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isOnline ? Icons.wifi : Icons.wifi_off,
              size: widget.compact ? 14 : 16,
              color: _isOnline ? Colors.green : Colors.orange,
            ),
            if (!widget.compact) ...[
              const SizedBox(width: 6),
              Text(
                _isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  color: _isOnline ? Colors.green : Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Indicador de pulsação para modo offline
class OfflinePulseIndicator extends StatefulWidget {
  final double size;

  const OfflinePulseIndicator({
    super.key,
    this.size = 12,
  });

  @override
  State<OfflinePulseIndicator> createState() => _OfflinePulseIndicatorState();
}

class _OfflinePulseIndicatorState extends State<OfflinePulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(_controller);

    _isOnline = ConnectivityService.instance.isConnected;
    
    ConnectivityService.instance.onConnectivityChanged.listen((isOnline) {
      if (mounted) {
        setState(() => _isOnline = isOnline);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnline) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.orange,
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Snackbar helper para mudanças de conectividade
class ConnectivitySnackbar {
  static void show(
    BuildContext context, {
    required bool isOnline,
    String? customMessage,
  }) {
    final icon = isOnline ? '🟢' : '🔴';
    final message = customMessage ??
        (isOnline ? 'Conectado à internet' : 'Modo offline ativado');
    final color = isOnline ? Colors.green : Colors.orange;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }
}