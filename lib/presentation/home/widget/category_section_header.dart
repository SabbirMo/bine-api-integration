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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left Side: Image and Title
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSeeMoreTap,
              child: Row(
                children: [
                  Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[300], // Background color when no image
                      image: imagePath != null && imagePath!.isNotEmpty
                          ? DecorationImage(
                              image: imagePath!.startsWith('http')
                                  ? NetworkImage(imagePath!) as ImageProvider
                                  : AssetImage(imagePath!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: imagePath == null || imagePath!.isEmpty
                        ? const Icon(
                            Icons.image_not_supported,
                            size: 24,
                            color: Colors.grey,
                          )
                        : null,
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
          ),
          const SizedBox(width: 16),

          // Right Side: Voir plus Link
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSeeMoreTap,
            child: Row(
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
          ),
        ],
      ),
    );
  }
}
