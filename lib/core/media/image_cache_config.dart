import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AppCacheManager {
  AppCacheManager._();

  static final CacheManager instance = CacheManager(
    Config(
      'promo_image_cache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 150,
    ),
  );
}
