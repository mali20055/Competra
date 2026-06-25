import 'package:flutter/material.dart';

class AvatarFrame {
  final String id;
  final String name;
  final bool isPremium;
  final Color primaryColor;
  final Color? secondaryColor;
  final String description;
  final String priceLabel;

  const AvatarFrame({
    required this.id,
    required this.name,
    required this.isPremium,
    required this.primaryColor,
    this.secondaryColor,
    required this.description,
    required this.priceLabel,
  });

  static const Map<String, AvatarFrame> frames = {
    'default': AvatarFrame(
      id: 'default',
      name: 'Varsayılan',
      isPremium: false,
      primaryColor: Colors.transparent,
      description: 'Sade ve klasik oyuncu görünümü.',
      priceLabel: 'Ücretsiz',
    ),
    'gold': AvatarFrame(
      id: 'gold',
      name: 'Altın Çerçeve',
      isPremium: true,
      primaryColor: Color(0xFFFFD700),
      description: 'Competra Pro veya özel satın alımla kullanılabilir parlak altın çerçeve.',
      priceLabel: '₺14.99',
    ),
    'champion': AvatarFrame(
      id: 'champion',
      name: 'Şampiyon Çerçevesi',
      isPremium: false,
      primaryColor: Color(0xFFFFC107),
      secondaryColor: Color(0xFFFF8F00),
      description: 'Turnuva kazananlarının sahip olduğu şampiyonluk tacı ile kupa ikonu.',
      priceLabel: 'Kazanım / Premium',
    ),
    'flame': AvatarFrame(
      id: 'flame',
      name: 'Alev Çerçevesi',
      isPremium: true,
      primaryColor: Color(0xFFFF3D00),
      secondaryColor: Color(0xFFFFB300),
      description: 'Ateşli rekabeti temsil eden premium alev gradyanı.',
      priceLabel: '₺14.99',
    ),
  };

  static AvatarFrame getFrame(String id) {
    return frames[id] ?? frames['default']!;
  }
}
