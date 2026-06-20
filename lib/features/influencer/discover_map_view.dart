import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/profile_service.dart';
import '../../core/services/chat_service.dart';
import '../../core/providers/app_providers.dart';
import '../../shared/widgets/shared_widgets.dart';

class DiscoverMapView extends ConsumerStatefulWidget {
  const DiscoverMapView({super.key});

  @override
  ConsumerState<DiscoverMapView> createState() => _DiscoverMapViewState();
}

class _DiscoverMapViewState extends ConsumerState<DiscoverMapView> {
  List<Map<String, dynamic>> _entities = [];
  bool _loading = true;
  bool _searchingLocation = false;
  Map<String, dynamic>? _selectedEntity;

  final MapController _mapController = MapController();

  // Map center (defaults to London)
  double _centerLat = 51.505;
  double _centerLng = -0.09;
  String _currentLocationLabel = '';
  bool _hasLocationPermission = false;

  // Entity marker positions map (profile ID -> LatLng)
  final Map<String, LatLng> _entityPositionsMap = {};

  // Search controller
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    try {
      // Fetch entities from database
      final results = await Future.wait([
        ProfileService().getBrands(limit: 30),
        ProfileService().getInfluencers(limit: 30),
      ]);
      final brands = results[0];
      final creators = results[1];
      _entities = [...brands, ...creators];

      // Request location permission and get current location
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        if (serviceEnabled) {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          _centerLat = position.latitude;
          _centerLng = position.longitude;
          _currentLocationLabel = 'Current Location';
          _hasLocationPermission = true;
        }
      } else {
        // Permission denied, fallback to profile location if available
        final profile = ref.read(authProvider).profile;
        final prefs = profile?['preferences'] as Map<String, dynamic>? ?? {};
        double? lat = (prefs['latitude'] as num?)?.toDouble();
        double? lng = (prefs['longitude'] as num?)?.toDouble();
        
        if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
          _centerLat = lat;
          _centerLng = lng;
          _currentLocationLabel = profile?['location'] ?? 'Profile Location';
        } else {
          final userLocation = profile?['location'] as String?;
          if (userLocation != null && userLocation.isNotEmpty) {
            final coords = await _geocode(userLocation);
            if (coords != null) {
              _centerLat = coords['lat']!;
              _centerLng = coords['lng']!;
              _currentLocationLabel = userLocation;
            }
          }
        }
        _hasLocationPermission = false;
      }

      // Pre-populate with scattered positions around _centerLat/_centerLng
      final rng = Random(42);
      for (final e in _entities) {
        final id = e['id'] as String?;
        if (id == null) continue;
        final sLat = _centerLat + (rng.nextDouble() - 0.5) * 0.06;
        final sLng = _centerLng + (rng.nextDouble() - 0.5) * 0.08;
        _entityPositionsMap[id] = LatLng(sLat, sLng);
      }

      // Load positions for all entities (uses actual DB coords first, falls back to geocoding, falls back to scattering)
      _loadEntityPositions();

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint('[MAP] Error loading map data: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadEntityPositions() async {
    final rng = Random(42);
    for (final e in _entities) {
      final id = e['id'] as String?;
      if (id == null) continue;

      final prefs = e['preferences'] as Map<String, dynamic>? ?? {};
      double? lat = (prefs['latitude'] as num?)?.toDouble();
      double? lng = (prefs['longitude'] as num?)?.toDouble();

      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        if (mounted) {
          setState(() {
            _entityPositionsMap[id] = LatLng(lat, lng);
          });
        }
      } else {
        // Fallback 1: try to geocode the location string
        final loc = e['location'] as String?;
        if (loc != null && loc.isNotEmpty) {
          // Add a short delay to respect Nominatim rate limit (300ms)
          await Future.delayed(const Duration(milliseconds: 300));
          final coords = await _geocode(loc);
          if (coords != null && mounted) {
            setState(() {
              _entityPositionsMap[id] = LatLng(coords['lat']!, coords['lng']!);
            });
            continue;
          }
        }

        // Fallback 2: scatter around the current center
        final sLat = _centerLat + (rng.nextDouble() - 0.5) * 0.06;
        final sLng = _centerLng + (rng.nextDouble() - 0.5) * 0.08;
        if (mounted) {
          setState(() {
            _entityPositionsMap[id] = LatLng(sLat, sLng);
          });
        }
      }
    }
  }

  void _updateScatteredPositions() {
    final rng = Random(42);
    for (final e in _entities) {
      final id = e['id'] as String?;
      if (id == null) continue;

      final prefs = e['preferences'] as Map<String, dynamic>? ?? {};
      double? lat = (prefs['latitude'] as num?)?.toDouble();
      double? lng = (prefs['longitude'] as num?)?.toDouble();

      if (lat == null || lng == null || lat == 0.0 || lng == 0.0) {
        final loc = e['location'] as String?;
        if (loc == null || loc.isEmpty) {
          final sLat = _centerLat + (rng.nextDouble() - 0.5) * 0.06;
          final sLng = _centerLng + (rng.nextDouble() - 0.5) * 0.08;
          if (mounted) {
            setState(() {
              _entityPositionsMap[id] = LatLng(sLat, sLng);
            });
          }
        }
      }
    }
  }

  /// Geocode a location string via OSM Nominatim
  Future<Map<String, double>?> _geocode(String query) async {
    try {
      String cleanQuery = query.trim();
      if (cleanQuery.toLowerCase().contains('rajamundry')) {
        cleanQuery = cleanQuery.replaceAll(RegExp('rajamundry', caseSensitive: false), 'Rajahmundry');
      }
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cleanQuery)}&format=json&limit=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'BrandApp/1.0',
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        if (data.isNotEmpty) {
          return {
            'lat': double.parse(data[0]['lat']),
            'lng': double.parse(data[0]['lon']),
          };
        }
      }
    } catch (e) {
      debugPrint('[MAP] Geocode error: $e');
    }
    return null;
  }

  /// Fly the map to a new location
  Future<void> _flyToLocation(String locationQuery) async {
    if (locationQuery.trim().isEmpty) return;
    setState(() => _searchingLocation = true);

    final coords = await _geocode(locationQuery);
    if (coords != null && mounted) {
      _centerLat = coords['lat']!;
      _centerLng = coords['lng']!;
      _currentLocationLabel = locationQuery;

      _mapController.move(LatLng(_centerLat, _centerLng), 13.0);

      // Update scattered positions for entities that don't have database coordinates
      _updateScatteredPositions();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location "$locationQuery" not found'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    if (mounted) setState(() => _searchingLocation = false);
  }

  List<Marker> _buildMarkers() {
    final markers = <Marker>[];

    // User location marker
    if (_hasLocationPermission) {
      markers.add(
        Marker(
          point: LatLng(_centerLat, _centerLng),
          width: 30,
          height: 30,
          child: _UserLocationDot(),
        ),
      );
    }

    // Entity markers
    final rng = Random(42);
    for (int i = 0; i < _entities.length; i++) {
      final e = _entities[i];
      final id = e['id'] as String?;
      if (id == null) continue;

      LatLng? pos = _entityPositionsMap[id];
      if (pos == null) {
        // If not loaded yet, generate a temporary scattered position around center
        final sLat = _centerLat + (rng.nextDouble() - 0.5) * 0.06;
        final sLng = _centerLng + (rng.nextDouble() - 0.5) * 0.08;
        pos = LatLng(sLat, sLng);
      }

      final isBrand = e['role'] == 'brand';
      final color = isBrand ? const Color(0xFF1E3A8A) : const Color(0xFF7C3AED);
      final icon = isBrand ? '💼' : '👤';

      markers.add(
        Marker(
          point: pos,
          width: 36,
          height: 36,
          child: GestureDetector(
            onTap: () => setState(() => _selectedEntity = e),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: 14)),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.accent, strokeWidth: 2),
            const SizedBox(height: 16),
            Text('Loading map...', style: AppTextStyles.captionSm),
          ],
        ),
      );
    }

    final isDark = AppColors.isDarkMode;
    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';

    return Stack(
      children: [
        // Flutter Map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(_centerLat, _centerLng),
            initialZoom: 13.0,
            maxZoom: 19.0,
            onTap: (_, __) {
              if (_selectedEntity != null) {
                setState(() => _selectedEntity = null);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: tileUrl,
              subdomains: const ['a', 'b', 'c'],
              userAgentPackageName: 'com.brand.app',
            ),
            MarkerLayer(markers: _buildMarkers()),
          ],
        ),

        // Search Bar Overlay (top)
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Icon(Iconsax.search_normal, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: _currentLocationLabel.isEmpty
                          ? 'Search location...'
                          : _currentLocationLabel,
                      hintStyle: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onSubmitted: (val) {
                      _flyToLocation(val);
                      _searchCtrl.clear();
                    },
                  ),
                ),
                if (_searchingLocation)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    ),
                  )
                else
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        if (_searchCtrl.text.isNotEmpty) {
                          _flyToLocation(_searchCtrl.text);
                          _searchCtrl.clear();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Profile count badge
        Positioned(
          bottom: _selectedEntity != null ? 200 : 24,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF7C3AED),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${_entities.length} profiles',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Detail popup card overlay at the bottom
        if (_selectedEntity != null)
          Positioned(
            left: AppSpacing.pageMarginHorizontal,
            right: AppSpacing.pageMarginHorizontal,
            bottom: AppSpacing.bottomScreenPadding + 16,
            child: _buildEntityCard(_selectedEntity!),
          ),
      ],
    );
  }

  Widget _buildEntityCard(Map<String, dynamic> e) {
    final isBrand = e['role'] == 'brand';
    final user = ref.read(authProvider).user;

    return Dismissible(
      key: Key(e['id'] ?? ''),
      direction: DismissDirection.down,
      onDismissed: (_) => setState(() => _selectedEntity = null),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Slide indicator
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    final id = e['id'];
                    if (id != null) {
                      if (isBrand) {
                        context.push('/influencer/brands/$id');
                      }
                    }
                  },
                  child: AppAvatar(
                    url: e['avatar_url'],
                    fallbackText: e['display_name'] ?? 'B',
                    size: 48,
                    onTap: () {
                      final id = e['id'];
                      if (id != null) {
                        if (isBrand) {
                          context.push('/influencer/brands/$id');
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              e['display_name'] ?? '',
                              style: AppTextStyles.label.copyWith(fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (e['is_verified'] == true) ...[
                            const SizedBox(width: 4),
                            const VerificationBadge(size: 14),
                          ]
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isBrand ? (e['company_name'] ?? 'Company') : 'Content Creator',
                        style: AppTextStyles.captionSm,
                      ),
                      if (e['location'] != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Iconsax.location, size: 12, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(e['location'], style: AppTextStyles.captionSm.copyWith(fontSize: 10)),
                          ],
                        ),
                      ]
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => setState(() => _selectedEntity = null),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (e['bio'] != null)
              Text(
                e['bio'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.captionSm.copyWith(height: 1.4),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: isBrand ? 'View Profile' : 'View Creator',
                    isPrimary: false,
                    onTap: () {
                      final id = e['id'];
                      if (isBrand) {
                        context.push('/influencer/brands/$id');
                      } else {
                        context.push('/search');
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Message',
                    icon: Iconsax.message,
                    onTap: () async {
                      if (user == null) return;
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const Center(child: CircularProgressIndicator()),
                      );
                      try {
                        final room = await ChatService().getOrCreate1to1Room(
                          brandId: isBrand ? e['id'] : user.id,
                          influencerId: isBrand ? user.id : e['id'],
                        );
                        if (mounted) {
                          Navigator.pop(context);
                          context.push('/influencer/chats/${room['id']}');
                        }
                      } catch (err) {
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to open chat: $err')),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pulsing blue dot for the user's current location
class _UserLocationDot extends StatefulWidget {
  @override
  State<_UserLocationDot> createState() => _UserLocationDotState();
}

class _UserLocationDotState extends State<_UserLocationDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _scaleAnimation = Tween<double>(begin: 0.8, end: 2.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse ring
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF3B82F6).withOpacity(0.15),
                    ),
                  ),
                ),
              );
            },
          ),
          // Core dot
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF3B82F6),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.6),
                  blurRadius: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
