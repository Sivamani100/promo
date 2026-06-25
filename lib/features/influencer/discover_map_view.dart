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
  String _selectedFilter = 'both'; // 'both' | 'creators' | 'brands'

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
    final Map<String, LatLng> newPositions = {};
    for (final e in _entities) {
      final id = e['id'] as String?;
      if (id == null) continue;

      final prefs = e['preferences'] as Map<String, dynamic>? ?? {};
      double? lat = (prefs['latitude'] as num?)?.toDouble();
      double? lng = (prefs['longitude'] as num?)?.toDouble();

      if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
        newPositions[id] = LatLng(lat, lng);
      } else {
        // HARDENING: ui-agent 2026-06-25 - Try geocoding the profile's text location before scattering
        final location = e['location'] as String?;
        if (location != null && location.trim().isNotEmpty) {
          final coords = await _geocode(location);
          if (coords != null) {
            newPositions[id] = LatLng(coords['lat']!, coords['lng']!);
            continue;
          }
        }
        // Fallback: scatter around the current center
        final sLat = _centerLat + (rng.nextDouble() - 0.5) * 0.06;
        final sLng = _centerLng + (rng.nextDouble() - 0.5) * 0.08;
        newPositions[id] = LatLng(sLat, sLng);
      }
    }
    if (mounted) {
      setState(() {
        _entityPositionsMap.addAll(newPositions);
      });
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

    // Filtered entities based on selection
    final filteredEntities = _entities.where((e) {
      if (_selectedFilter == 'brands') {
        return e['role'] == 'brand';
      } else if (_selectedFilter == 'creators') {
        return e['role'] == 'influencer';
      }
      return true; // 'both'
    }).toList();

    // Entity markers
    final rng = Random(42);
    for (int i = 0; i < filteredEntities.length; i++) {
      final e = filteredEntities[i];
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
      final color = isBrand ? const Color(0xFF1E3A8A) : const Color(0xFF7C3AED); // Blue for brand, Purple for influencer
      final badgeIcon = isBrand ? Iconsax.briefcase : Iconsax.user;

      markers.add(
        // HARDENING: ui-agent 2026-06-25 - Show profile photo on map markers with role badges
        Marker(
          point: pos,
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () => setState(() => _selectedEntity = e),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Profile Photo container with white border and shadow
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: AppAvatar(
                      url: e['avatar_url'],
                      fallbackText: e['display_name'] ?? (isBrand ? 'B' : 'I'),
                      size: 36,
                    ),
                  ),
                ),
                // Indicator badge (bottom right)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      badgeIcon,
                      size: 8,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return markers;
  }

  // HARDENING: ui-agent 2026-06-25 - Filter chip helper
  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _selectedFilter == value;
    
    // Custom active colors matching the roles
    Color selectedColor;
    if (value == 'brands') {
      selectedColor = const Color(0xFF1E3A8A); // Sleek Brand Blue
    } else if (value == 'creators') {
      selectedColor = const Color(0xFF7C3AED); // Sleek Creator Purple
    } else {
      selectedColor = AppColors.accent; // Orange or active accent
    }

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedFilter = value;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected 
                ? selectedColor 
                : Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? selectedColor : Colors.white.withValues(alpha: 0.15),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isSelected ? 0.35 : 0.1),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: Colors.white.withValues(alpha: isSelected ? 1.0 : 0.7),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: Colors.white.withValues(alpha: isSelected ? 1.0 : 0.75),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppShimmer(
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
        ),
      );
    }

    // HARDENING: ui-agent 2026-06-25 - Force Dark Mode Map Tiles
    const tileUrl = 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png';

    return Stack(
      children: [
        // Flutter Map
        Container(
          color: const Color(0xFF111111), // HARDENING: ui-agent 2026-06-25 - Dark background under map
          child: FlutterMap(
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
        ),

        // HARDENING: ui-agent 2026-06-25 - Floating Filter Chips Overlay (top)
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Row(
            children: [
              _buildFilterChip('both', 'All Profiles', Iconsax.category),
              const SizedBox(width: 8),
              _buildFilterChip('creators', 'Creators', Iconsax.user),
              const SizedBox(width: 8),
              _buildFilterChip('brands', 'Brands', Iconsax.briefcase),
            ],
          ),
        ),

        // Profile count badge
        Positioned(
          bottom: _selectedEntity != null ? 200 : 24,
          left: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
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
              color: Colors.black.withValues(alpha: 0.12),
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
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
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
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.6),
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
