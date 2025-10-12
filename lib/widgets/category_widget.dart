import 'package:flutter/material.dart';
import 'package:org_wallet/models/category.dart';
import 'package:org_wallet/constants/category_constants.dart';

class CategoryDisplayWidget extends StatelessWidget {
  final CategoryModel category;
  final double? iconSize;
  final double? fontSize;
  final bool showType;
  final EdgeInsets? padding;

  const CategoryDisplayWidget({
    super.key,
    required this.category,
    this.iconSize,
    this.fontSize,
    this.showType = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      constraints: const BoxConstraints(
        minHeight: 24.0,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconSize ?? 24,
            height: iconSize ?? 24,
            decoration: BoxDecoration(
              color: CategoryColors.hexToColor(category.color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              CategoryIcons.getIcon(category.icon),
              color: CategoryColors.hexToColor(category.color),
              size: (iconSize ?? 24) * 0.6,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            fit: FlexFit.loose,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  category.name,
                  style: TextStyle(
                    fontSize: fontSize ?? 14,
                    fontWeight: FontWeight.w500,
                    height: 1.2, // Reduced line height to prevent overflow
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (showType)
                  Text(
                    category.type.toShortString().capitalize(),
                    style: TextStyle(
                      fontSize: (fontSize ?? 14) - 2,
                      color: Colors.grey.shade600,
                      height: 1.2, // Reduced line height to prevent overflow
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryDropdownWidget extends StatelessWidget {
  final List<CategoryModel> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onChanged;
  final String? labelText;
  final bool showIcons;

  const CategoryDropdownWidget({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onChanged,
    this.labelText = 'Category',
    this.showIcons = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 68.0, // Even more increased minimum height
      ),
      child: DropdownButtonFormField<String>(
        value: selectedCategoryId,
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        isExpanded: true,
        items: categories.map((category) {
          return DropdownMenuItem<String>(
            value: category.id,
            child: showIcons
                ? CategoryDisplayWidget(
                    category: category,
                    iconSize: 20,
                    fontSize: 14,
                  )
                : Text(
                    category.name,
                    overflow: TextOverflow.ellipsis,
                  ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

extension _StringCap on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
