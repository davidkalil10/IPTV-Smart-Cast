import 'package:flutter/material.dart';

class CategoryListItem extends StatefulWidget {
  final String title;
  final String count;
  final bool isSelected;
  final VoidCallback onTap;
  final FocusNode? focusNode;

  const CategoryListItem({
    super.key,
    required this.title,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.focusNode,
  });

  @override
  State<CategoryListItem> createState() => _CategoryListItemState();
}

class _CategoryListItemState extends State<CategoryListItem> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      focusNode: widget.focusNode,
      onTap: widget.onTap,
      onFocusChange: (value) => setState(() => _isFocused = value),
      child: Container(
        decoration: BoxDecoration(
          color: widget.isSelected
              ? const Color(0xFF00838F) // Selected color
              : _isFocused
              ? Colors.white.withOpacity(0.1) // Focus color
              : Colors.transparent,
          border: _isFocused
              ? Border.all(color: Colors.white, width: 2) // Focus border
              : Border.all(color: Colors.transparent, width: 2),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: TextStyle(
                  color: widget.isSelected || _isFocused
                      ? Colors.white
                      : Colors.grey[300],
                  fontWeight: widget.isSelected
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
            if (widget.count.isNotEmpty && widget.count != '0')
              Text(
                widget.count,
                style: TextStyle(
                  color: widget.isSelected || _isFocused
                      ? Colors.white
                      : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
