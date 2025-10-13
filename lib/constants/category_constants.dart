import 'package:flutter/material.dart';

// Available icons for categories
class CategoryIcons {
  static const Map<String, IconData> icons = {
    'food': Icons.restaurant,
    'transport': Icons.directions_car,
    'shopping': Icons.shopping_bag,
    'entertainment': Icons.movie,
    'health': Icons.local_hospital,
    'education': Icons.school,
    'utilities': Icons.electrical_services,
    'travel': Icons.flight,
    'gift': Icons.card_giftcard,
    'donation': Icons.favorite,
    'salary': Icons.account_balance_wallet,
    'freelance': Icons.work,
    'investment': Icons.trending_up,
    'rent': Icons.home,
    'insurance': Icons.security,
    'subscription': Icons.subscriptions,
    'fuel': Icons.local_gas_station,
    'phone': Icons.phone,
    'internet': Icons.wifi,
    'clothing': Icons.checkroom,
    'sports': Icons.sports_soccer,
    'books': Icons.book,
    'electronics': Icons.devices,
    'furniture': Icons.chair,
    'maintenance': Icons.build,
    'tax': Icons.receipt,
    'groups': Icons.groups,
    'miscellaneous': Icons.category,
    'category': Icons.category,
  };

  static IconData getIcon(String iconName) {
    return icons[iconName] ?? Icons.category;
  }

  static List<String> getIconNames() {
    return icons.keys.toList();
  }
}

// Available colors for categories
class CategoryColors {
  static const List<Color> colors = [
    Color(0xFF6366F1), // Indigo
    Color(0xFF8B5CF6), // Violet
    Color(0xFFEC4899), // Pink
    Color(0xFFEF4444), // Red
    Color(0xFFF97316), // Orange
    Color(0xFFEAB308), // Yellow
    Color(0xFF22C55E), // Green
    Color(0xFF10B981), // Emerald
    Color(0xFF06B6D4), // Cyan
    Color(0xFF3B82F6), // Blue
    Color(0xFF84CC16), // Lime
    Color(0xFFF59E0B), // Amber
    Color(0xFFDC2626), // Red-600
    Color(0xFF7C3AED), // Violet-600
    Color(0xFF059669), // Emerald-600
    Color(0xFF0D9488), // Teal-600
    Color(0xFF2563EB), // Blue-600
    Color(0xFF9333EA), // Purple-600
    Color(0xFFDB2777), // Pink-600
    Color(0xFFEA580C), // Orange-600
  ];

  static String colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  static Color hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFF6366F1); // Default indigo
    }
  }

  static List<String> getColorHexes() {
    return colors.map((color) => colorToHex(color)).toList();
  }
}
