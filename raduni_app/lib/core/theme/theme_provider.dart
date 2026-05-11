import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Palette disponibili — sincronizzate con tokens.css del design.
const Map<String, ({Color accent, Color soft, String label})> accentPalettes = {
  'forest': (accent: Color(0xFF1B4332), soft: Color(0xFFE6EEE9), label: 'Foresta'),
  'rosso':  (accent: Color(0xFF9A2A2A), soft: Color(0xFFF5E5E3), label: 'Rosso'),
  'cobalt': (accent: Color(0xFF1E3A8A), soft: Color(0xFFE2E8F4), label: 'Cobalto'),
  'amber':  (accent: Color(0xFFB5651D), soft: Color(0xFFF4E9D8), label: 'Ambra'),
  'ink':    (accent: Color(0xFF0E1410), soft: Color(0xFFEFEDE6), label: 'Inchiostro'),
};

/// Palette selezionata (chiave stringa).
final accentPaletteProvider = StateProvider<String>((ref) => 'forest');
