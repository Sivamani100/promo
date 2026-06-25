// HARDENING: ui-agent 2026-06-25 - Fullscreen Map Screen
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'discover_map_view.dart';

class DiscoverMapScreen extends StatelessWidget {
  const DiscoverMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Maps',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: const DiscoverMapView(),
    );
  }
}
