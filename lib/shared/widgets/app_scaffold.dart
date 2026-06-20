import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/theme/app_colors.dart';
import '../../core/providers/app_providers.dart';

class AppScaffold extends ConsumerStatefulWidget {
  final String role;
  final Widget child;

  const AppScaffold({super.key, required this.role, required this.child});

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  int _currentIndex = 0;

  List<_NavItem> get _brandItems => [
        _NavItem(icon: Iconsax.home, activeIcon: Iconsax.home_1, label: 'Home', path: '/brand/home'),
        _NavItem(icon: Iconsax.cards, activeIcon: Iconsax.cards, label: 'Cards', path: '/brand/cards'),
        _NavItem(icon: Iconsax.profile_2user, activeIcon: Iconsax.profile_2user, label: 'Influencers', path: '/brand/influencers'),
        _NavItem(icon: Iconsax.message, activeIcon: Iconsax.message, label: 'Chats', path: '/brand/chats'),
        _NavItem(icon: Iconsax.profile_circle, activeIcon: Iconsax.profile_circle, label: 'Profile', path: '/brand/profile'),
      ];

  List<_NavItem> get _influencerItems => [
        _NavItem(icon: Iconsax.home, activeIcon: Iconsax.home_1, label: 'Home', path: '/influencer/home'),
        _NavItem(icon: Iconsax.discover, activeIcon: Iconsax.discover_1, label: 'Discover', path: '/influencer/discover'),
        _NavItem(icon: Iconsax.briefcase, activeIcon: Iconsax.briefcase, label: 'Applied', path: '/influencer/my-applications'),
        _NavItem(icon: Iconsax.message, activeIcon: Iconsax.message, label: 'Chats', path: '/influencer/chats'),
        _NavItem(icon: Iconsax.profile_circle, activeIcon: Iconsax.profile_circle, label: 'Profile', path: '/influencer/profile'),
      ];

  List<_NavItem> get _items => widget.role == 'brand' ? _brandItems : _influencerItems;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final location = GoRouterState.of(context).uri.path;
    for (int i = 0; i < _items.length; i++) {
      if (location.startsWith(_items[i].path)) {
        if (_currentIndex != i) setState(() => _currentIndex = i);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final unreadMessages = ref.watch(unreadMessageCountProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Dynamic Bottom Nav Colors
    final navBgColor = isDark ? Colors.white : Colors.black;
    final shadowColor = isDark ? Colors.black.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.35);
    final activePillColor = isDark ? Colors.black : Colors.white;
    final activeTextColor = isDark ? Colors.white : Colors.black;
    final inactiveIconColor = isDark ? Colors.black.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.6);

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_currentIndex != 0) {
          setState(() {
            _currentIndex = 0;
          });
          context.go(widget.role == 'brand' ? '/brand/home' : '/influencer/home');
        }
      },
      child: Scaffold(
        extendBody: true,
        body: widget.child,
      bottomNavigationBar: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: navBgColor,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(items.length, (i) {
                    final item = items[i];
                    final isActive = _currentIndex == i;
                    final showBadge = item.label == 'Chats' && unreadMessages > 0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () {
                          if (_currentIndex != i) {
                            setState(() => _currentIndex = i);
                            context.go(item.path);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          padding: isActive
                              ? const EdgeInsets.symmetric(horizontal: 14, vertical: 9)
                              : const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: isActive ? activePillColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(
                                    isActive ? item.activeIcon : item.icon,
                                    size: 20,
                                    color: isActive ? activeTextColor : inactiveIconColor,
                                  ),
                                  if (showBadge)
                                    Positioned(
                                      right: -6,
                                      top: -4,
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          color: AppColors.purple,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          unreadMessages > 9 ? '9+' : '$unreadMessages',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (isActive) ...[
                                const SizedBox(width: 8),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    color: activeTextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;

  _NavItem({required this.icon, required this.activeIcon, required this.label, required this.path});
}