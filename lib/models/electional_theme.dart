import 'package:flutter/material.dart';

class ElectionalTheme {
  final String key;
  final String label;
  final String description;
  final IconData icon;
  final bool isPro;

  const ElectionalTheme({
    required this.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.isPro,
  });
}

const kElectionalThemes = [
  ElectionalTheme(
    key: 'love_relationships',
    label: 'Love & Relationships',
    description: 'Romance, attraction, and partnership',
    icon: Icons.favorite_border,
    isPro: false,
  ),
  ElectionalTheme(
    key: 'travel',
    label: 'Travel',
    description: 'Journeys, movement, and new horizons',
    icon: Icons.explore_outlined,
    isPro: false,
  ),
  ElectionalTheme(
    key: 'business_career',
    label: 'Business & Career',
    description: 'Work, money, and professional action',
    icon: Icons.star_outline,
    isPro: true,
  ),
  ElectionalTheme(
    key: 'health_body',
    label: 'Health & Body',
    description: 'Vitality, treatment, and physical matters',
    icon: Icons.wb_sunny_outlined,
    isPro: true,
  ),
  ElectionalTheme(
    key: 'spiritual_learning',
    label: 'Spiritual & Learning',
    description: 'Study, wisdom, and sacred practice',
    icon: Icons.menu_book_outlined,
    isPro: true,
  ),
  ElectionalTheme(
    key: 'home_family',
    label: 'Home & Family',
    description: 'Domestic life, property, and family matters',
    icon: Icons.home_outlined,
    isPro: true,
  ),
];
