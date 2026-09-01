import 'package:flutter/material.dart';

class CategorySectionHeader extends StatelessWidget {
  final String title;
  final String? imagePath;
  final VoidCallback? onSeeMoreTap;

  const CategorySectionHeader({
    super.key,
    required this.title,
    this.imagePath,
    this.onSeeMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSeeMoreTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left Side: Image and Title
            Expanded(
              child: Row(
                children: [
                  Container(
                    height: 50,
                    width: 50,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFFF1E6),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child:
                        imagePath != null &&
                            imagePath!.isNotEmpty &&
                            imagePath!.startsWith('http')
                        ? Image.network(
                            imagePath!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.category_outlined,
                                  size: 24,
                                  color: Color(0xFFFF6900),
                                ),
                          )
                        : const Icon(
                            Icons.category_outlined,
                            size: 24,
                            color: Color(0xFFFF6900),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF2B2B2B),
                        fontSize: 22,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        height: 1.29,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Right Side: Voir plus Link
            Row(
              children: [
                const Text(
                  'Voir plus',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFFF6900),
                    fontSize: 16,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Color(0xFFFF6900),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
