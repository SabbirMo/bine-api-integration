import 'package:binetatour/presentation/home/home_page.dart';
import 'package:binetatour/presentation/home/widget/dashboard_border_pointer.dart';
import 'package:flutter/material.dart';

class CircularStoryAvatar extends StatelessWidget {
  final StoryItem item;

  const CircularStoryAvatar({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 80,
                height: 80,
                padding: const EdgeInsets.all(
                  4,
                ), // Space between border and image
                child: CustomPaint(
                  painter: DashedBorderPainter(itemCount: item.storyCount),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: ClipOval(
                        child: item.imagePath.startsWith('http')
                            ? Image.network(
                                item.imagePath,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.error),
                              )
                            : Image.asset(item.imagePath, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),
              // Play Icon for Video stories (like "Tech")
              if (item.isVideo)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF6900),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
              // Audio Icon for Audio stories
              if (item.isAudio)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF6900),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF2B2B2B),
            ),
          ),
        ],
      ),
    );
  }
}
