import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

enum PhotoFilter {
  none,
  grayscale,
  sepia,
  vintage,
  cool,
  warm,
  highContrast,
  invert,
  blur,
}

class PhotoFilterService {
  static final PhotoFilterService instance = PhotoFilterService._init();
  PhotoFilterService._init();

  /// Aplica filtro em uma imagem e retorna o caminho da nova imagem
  Future<String> applyFilter({
    required String imagePath,
    required PhotoFilter filter,
  }) async {
    try {
      print('🎨 Aplicando filtro: ${filter.name}');
      
      // Carregar imagem
      final bytes = await File(imagePath).readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('Não foi possível decodificar a imagem');
      }

      // Aplicar filtro
      img.Image filtered;
      switch (filter) {
        case PhotoFilter.none:
          filtered = image;
          break;
        case PhotoFilter.grayscale:
          filtered = _applyGrayscale(image);
          break;
        case PhotoFilter.sepia:
          filtered = _applySepia(image);
          break;
        case PhotoFilter.vintage:
          filtered = _applyVintage(image);
          break;
        case PhotoFilter.cool:
          filtered = _applyCool(image);
          break;
        case PhotoFilter.warm:
          filtered = _applyWarm(image);
          break;
        case PhotoFilter.highContrast:
          filtered = _applyHighContrast(image);
          break;
        case PhotoFilter.invert:
          filtered = _applyInvert(image);
          break;
        case PhotoFilter.blur:
          filtered = _applyBlur(image);
          break;
      }

      // Salvar imagem filtrada
      final filteredBytes = img.encodeJpg(filtered, quality: 85);
      await File(imagePath).writeAsBytes(filteredBytes);
      
      print('✅ Filtro aplicado com sucesso');
      return imagePath;
    } catch (e) {
      print('❌ Erro ao aplicar filtro: $e');
      rethrow;
    }
  }

  /// Gera preview do filtro (menor qualidade/resolução para performance)
  Future<Uint8List> generatePreview({
    required String imagePath,
    required PhotoFilter filter,
  }) async {
    try {
      // Carregar e redimensionar para preview
      final bytes = await File(imagePath).readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) {
        throw Exception('Não foi possível decodificar a imagem');
      }

      // Redimensionar para preview (max 800px)
      if (image.width > 800) {
        image = img.copyResize(image, width: 800);
      }

      // Aplicar filtro
      img.Image filtered;
      switch (filter) {
        case PhotoFilter.none:
          filtered = image;
          break;
        case PhotoFilter.grayscale:
          filtered = _applyGrayscale(image);
          break;
        case PhotoFilter.sepia:
          filtered = _applySepia(image);
          break;
        case PhotoFilter.vintage:
          filtered = _applyVintage(image);
          break;
        case PhotoFilter.cool:
          filtered = _applyCool(image);
          break;
        case PhotoFilter.warm:
          filtered = _applyWarm(image);
          break;
        case PhotoFilter.highContrast:
          filtered = _applyHighContrast(image);
          break;
        case PhotoFilter.invert:
          filtered = _applyInvert(image);
          break;
        case PhotoFilter.blur:
          filtered = _applyBlur(image);
          break;
      }

      return Uint8List.fromList(img.encodeJpg(filtered, quality: 70));
    } catch (e) {
      print('❌ Erro ao gerar preview: $e');
      rethrow;
    }
  }

  // ========== FILTROS ==========

  img.Image _applyGrayscale(img.Image image) {
    return img.grayscale(image);
  }

  img.Image _applySepia(img.Image image) {
    return img.sepia(image);
  }

  img.Image _applyVintage(img.Image image) {
    // Sépia + vinheta + contraste reduzido
    img.Image result = img.sepia(image);
    result = img.contrast(result, contrast: 110);
    result = img.vignette(result);
    return result;
  }

img.Image _applyCool(img.Image image) {  
  // Um pouco mais de azul (+12) e um pouco menos de vermelho (-8)  
  return img.colorOffset(image, red: -8, green: 0, blue: 12);  
}  
  
img.Image _applyWarm(img.Image image) {  
  // Mais vermelho (+12), verde (+8), menos azul (-8)  
  return img.colorOffset(image, red: 12, green: 8, blue: -8);  
}

  img.Image _applyHighContrast(img.Image image) {
    return img.contrast(image, contrast: 140);
  }

  img.Image _applyInvert(img.Image image) {
    return img.invert(image);
  }

  img.Image _applyBlur(img.Image image) {
    return img.gaussianBlur(image, radius: 3);
  }

  // ========== HELPERS ==========

  String getFilterName(PhotoFilter filter) {
    switch (filter) {
      case PhotoFilter.none:
        return 'Original';
      case PhotoFilter.grayscale:
        return 'P&B';
      case PhotoFilter.sepia:
        return 'Sépia';
      case PhotoFilter.vintage:
        return 'Vintage';
      case PhotoFilter.cool:
        return 'Frio';
      case PhotoFilter.warm:
        return 'Quente';
      case PhotoFilter.highContrast:
        return 'Contraste';
      case PhotoFilter.invert:
        return 'Invertido';
      case PhotoFilter.blur:
        return 'Desfoque';
    }
  }

  String getFilterEmoji(PhotoFilter filter) {
    switch (filter) {
      case PhotoFilter.none:
        return '📷';
      case PhotoFilter.grayscale:
        return '⚫';
      case PhotoFilter.sepia:
        return '🟤';
      case PhotoFilter.vintage:
        return '📜';
      case PhotoFilter.cool:
        return '🧊';
      case PhotoFilter.warm:
        return '🔥';
      case PhotoFilter.highContrast:
        return '⚡';
      case PhotoFilter.invert:
        return '🔄';
      case PhotoFilter.blur:
        return '🌫️';
    }
  }
}