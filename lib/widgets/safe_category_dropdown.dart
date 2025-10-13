import 'package:flutter/material.dart';
import '../models/category.dart';
import '../constants/category_constants.dart';

/// A safer dropdown implementation that avoids layout overflow issues
class SafeCategoryDropdown extends StatefulWidget {
  final List<CategoryModel> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onChanged;
  final String labelText;
  final bool showIcons;

  const SafeCategoryDropdown({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onChanged,
    required this.labelText,
    this.showIcons = true,
  });

  @override
  State<SafeCategoryDropdown> createState() => _SafeCategoryDropdownState();
}

class _SafeCategoryDropdownState extends State<SafeCategoryDropdown> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final selectedCategory = widget.categories
        .where((cat) => cat.id == widget.selectedCategoryId)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          widget.labelText,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),

        // Dropdown Button
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: Row(
              children: [
                // Selected category display
                Expanded(
                  child: selectedCategory != null
                      ? _buildCategoryItem(selectedCategory, isSelected: true)
                      : Text(
                          'Select ${widget.labelText.toLowerCase()}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                ),
                // Dropdown arrow
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),

        // Dropdown list
        if (_isExpanded) ...[
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: widget.categories.map((category) {
                return InkWell(
                  onTap: () {
                    widget.onChanged(category.id);
                    setState(() {
                      _isExpanded = false;
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: category.id == widget.selectedCategoryId
                          ? Colors.blue.shade50
                          : Colors.transparent,
                    ),
                    child: _buildCategoryItem(category),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCategoryItem(CategoryModel category, {bool isSelected = false}) {
    if (!widget.showIcons) {
      return Text(
        category.name,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? Colors.blue.shade700 : Colors.black87,
        ),
        overflow: TextOverflow.ellipsis,
      );
    }

    return Row(
      children: [
        // Icon
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: CategoryColors.hexToColor(category.color).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            CategoryIcons.getIcon(category.icon),
            color: CategoryColors.hexToColor(category.color),
            size: 18,
          ),
        ),
        const SizedBox(width: 12),

        // Category name and type
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.blue.shade700 : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                category.type.toShortString().capitalize(),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
