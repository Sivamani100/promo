// HARDENING: devops-agent 2026-06-24
import 'dart:collection';

class CacheEntry<T> {
  final T value;
  final DateTime expiry;

  CacheEntry({required this.value, required this.expiry});

  bool get isExpired => DateTime.now().isAfter(expiry);
}

class AppCache {
  final Map<String, CacheEntry<dynamic>> _cache = HashMap();

  static final AppCache _instance = AppCache._internal();

  factory AppCache() => _instance;

  AppCache._internal();

  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    
    if (entry.isExpired) {
      _cache.remove(key);
      return null;
    }
    
    try {
      return entry.value as T;
    } catch (_) {
      return null;
    }
  }

  void set<T>(String key, T value, {Duration ttl = const Duration(minutes: 5)}) {
    _cache[key] = CacheEntry(
      value: value,
      expiry: DateTime.now().add(ttl),
    );
  }

  void invalidate(String key) {
    _cache.remove(key);
  }

  void invalidatePattern(String pattern) {
    _cache.removeWhere((key, _) => key.contains(pattern));
  }

  void clear() {
    _cache.clear();
  }
}
