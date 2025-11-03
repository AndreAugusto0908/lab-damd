import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../services/photo_filter_service.dart'; // ajuste o caminho conforme sua estrutura
// Se o enum PhotoFilter estiver em outro arquivo, importe-o também.

class PhotoFilterScreen extends StatefulWidget {
  final String imagePath;

  const PhotoFilterScreen({super.key, required this.imagePath});

  @override
  State<PhotoFilterScreen> createState() => _PhotoFilterScreenState();
}

class _PhotoFilterScreenState extends State<PhotoFilterScreen> {
  final _service = PhotoFilterService.instance;

  PhotoFilter _selected = PhotoFilter.none;
  bool _isApplying = false;
  bool _isLoadingPreviews = true;

  // Previews em memória para rapidez
  final Map<PhotoFilter, Uint8List> _previews = {};

  @override
  void initState() {
    super.initState();
    _generateAllPreviews();
  }

  Future<void> _generateAllPreviews() async {
    setState(() => _isLoadingPreviews = true);

    try {
      // Gera as miniaturas em paralelo
      final futures = <Future<void>>[];

      for (final f in PhotoFilter.values) {
        futures.add(_generatePreviewFor(f));
      }

      await Future.wait(futures);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar previews: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingPreviews = false);
    }
  }

  Future<void> _generatePreviewFor(PhotoFilter filter) async {
    try {
      final bytes = await _service.generatePreview(
        imagePath: widget.imagePath,
        filter: filter,
      );
      _previews[filter] = bytes;
    } catch (_) {
      // Em caso de erro em um filtro, apenas ignore o preview dele
    }
  }

  Future<void> _applySelectedFilter() async {
    setState(() => _isApplying = true);
    try {
      final newPath = await _service.applyFilter(
        imagePath: widget.imagePath,
        filter: _selected,
      );
      if (!mounted) return;
      Navigator.pop(context, newPath);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao aplicar filtro: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filters = PhotoFilter.values;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Filtros'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isApplying ? null : _applySelectedFilter,
            child: _isApplying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Aplicar',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Preview grande da imagem com o filtro selecionado (usando preview se existir)
          Expanded(
            child: Container(
              color: Colors.black,
              alignment: Alignment.center,
              child: _buildMainPreview(),
            ),
          ),

          // Grade com miniaturas dos filtros
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _isLoadingPreviews
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : SizedBox(
                    height: 120,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (_, index) {
                        final f = filters[index];
                        return _FilterThumbnail(
                          label: PhotoFilterService.instance.getFilterName(f),
                          emoji: PhotoFilterService.instance.getFilterEmoji(f),
                          bytes: _previews[f],
                          isSelected: f == _selected,
                          onTap: () => setState(() => _selected = f),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemCount: filters.length,
                    ),
                  ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMainPreview() {
    // Se temos preview do filtro selecionado, usa-o; senão, mostra a imagem original
    final bytes = _previews[_selected];
    if (bytes != null) {
      return InteractiveViewer(
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
        ),
      );
    }

    // Fallback para imagem original enquanto preview não carrega
    return InteractiveViewer(
      child: Image.file(
        File(widget.imagePath),
        fit: BoxFit.contain,
      ),
    );
  }
}

class _FilterThumbnail extends StatelessWidget {
  final String label;
  final String emoji;
  final Uint8List? bytes;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterThumbnail({
    required this.label,
    required this.emoji,
    required this.bytes,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isSelected ? Colors.blue : Colors.grey.shade300;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          Container(
            width: 90,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
              color: Colors.grey.shade200,
            ),
            clipBehavior: Clip.antiAlias,
            child: bytes != null
                ? Image.memory(bytes!, fit: BoxFit.cover)
                : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 90,
            child: Text(
              '$emoji $label',
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}