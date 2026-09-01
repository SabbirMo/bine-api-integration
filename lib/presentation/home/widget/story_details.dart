import 'dart:math';
import 'package:flutter/material.dart';
import 'package:binetatour/core/story/story_hls_preloader.dart';
import 'package:binetatour/core/story/story_preloader.dart';
import 'package:binetatour/presentation/home/widget/story/story_models.dart';
import 'package:binetatour/presentation/home/widget/story/story_group_page_view.dart';

// Re-export models for backwards compatibility
export 'package:binetatour/presentation/home/widget/story/story_models.dart';
export 'package:binetatour/presentation/home/widget/story/story_audio_wave.dart';
export 'package:binetatour/presentation/home/widget/story/story_detail_content.dart';
export 'package:binetatour/presentation/home/widget/story/story_group_page_view.dart';

/// Multi-Category Instagram/Facebook 3D Cube Story Viewer
class StoryDetailScreen extends StatefulWidget {
  final List<StoryGroup>? storyGroups;
  final int initialGroupIndex;

  // Backwards compatibility for single-category invocation
  final List<StoryContent>? stories;
  final String userName;
  final String userProfile;

  const StoryDetailScreen({
    super.key,
    this.storyGroups,
    this.initialGroupIndex = 0,
    this.stories,
    this.userName = "User Name",
    this.userProfile = "",
  });

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  late PageController _pageController;
  late List<StoryGroup> _effectiveGroups;
  late int _currentGroupIndex;
  bool _isPageAnimating = false;

  @override
  void initState() {
    super.initState();
    if (widget.storyGroups != null && widget.storyGroups!.isNotEmpty) {
      _effectiveGroups = widget.storyGroups!;
      _currentGroupIndex = widget.initialGroupIndex.clamp(
        0,
        _effectiveGroups.length - 1,
      );
    } else if (widget.stories != null && widget.stories!.isNotEmpty) {
      _effectiveGroups = [
        StoryGroup(
          categoryId: 0,
          categoryName: widget.userName,
          categoryImage: widget.userProfile,
          stories: widget.stories!,
        ),
      ];
      _currentGroupIndex = 0;
    } else {
      _effectiveGroups = [];
      _currentGroupIndex = 0;
    }

    _pageController = PageController(initialPage: _currentGroupIndex);

    // Eagerly precache all category images and first stories in background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final group in _effectiveGroups) {
        if (group.categoryImage.isNotEmpty &&
            group.categoryImage.startsWith('http')) {
          precacheImage(
            NetworkImage(group.categoryImage),
            context,
          ).catchError((_) {});
        }
        if (group.stories.isNotEmpty) {
          StoryPreloader.preloadNextStory(group.stories.first, context);
        }
      }
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentGroupIndex = index;
    });
    _isPageAnimating = false;

    // Silently prefetch category N+1 first story in background
    if (index + 1 < _effectiveGroups.length && mounted) {
      StoryPreloader.preloadCategoryFirstStory(_effectiveGroups[index + 1], context);
    }
  }

  void _goToNextCategory() {
    if (!mounted || _isPageAnimating) return;
    if (!_pageController.hasClients) return;
    if (_currentGroupIndex < _effectiveGroups.length - 1) {
      _isPageAnimating = true;
      _pageController
          .animateToPage(
            _currentGroupIndex + 1,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          )
          .then((_) {
            if (mounted) _isPageAnimating = false;
          })
          .catchError((_) {
            if (mounted) _isPageAnimating = false;
          });
    } else {
      _isPageAnimating = false;
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  void _goToPrevCategory() {
    if (!mounted || _isPageAnimating) return;
    if (!_pageController.hasClients) return;
    if (_currentGroupIndex > 0) {
      _isPageAnimating = true;
      _pageController
          .animateToPage(
            _currentGroupIndex - 1,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
          )
          .then((_) {
            if (mounted) _isPageAnimating = false;
          })
          .catchError((_) {
            if (mounted) _isPageAnimating = false;
          });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    StoryHlsPreloader.instance.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_effectiveGroups.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text(
            "No stories available",
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _pageController,
        builder: (context, _) {
          return PageView.builder(
            controller: _pageController,
            itemCount: _effectiveGroups.length,
            onPageChanged: _onPageChanged,
            physics: const SnappyStoryScrollPhysics(),
            itemBuilder: (context, index) {
              final group = _effectiveGroups[index];

              double pageOffset = 0.0;
              if (_pageController.position.haveDimensions &&
                  _pageController.position.viewportDimension > 0) {
                pageOffset =
                    (_pageController.page ?? _currentGroupIndex.toDouble()) -
                    index;
              } else {
                pageOffset = (_currentGroupIndex - index).toDouble();
              }

              // True Facebook 3D Cube 90-degree perspective rotation
              final double angle = (pageOffset * (pi / 2)).clamp(
                -pi / 2,
                pi / 2,
              );
              final isLeaving = pageOffset > 0;
              final matrix = Matrix4.identity()
                ..setEntry(3, 2, 0.001) // 3D perspective depth
                ..rotateY(angle);

              final double shadowOpacity = (pageOffset.abs() * 0.5).clamp(
                0.0,
                0.6,
              );

              return Transform(
                transform: matrix,
                alignment: isLeaving
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    StoryGroupPageView(
                      key: ValueKey('story_group_${group.categoryId}_$index'),
                      group: group,
                      categoryIndex: index,
                      isActive: (index == _currentGroupIndex),
                      onNextCategory: _goToNextCategory,
                      onPrevCategory: _goToPrevCategory,
                      onClose: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    // 3D Cube face shadow overlay
                    if (shadowOpacity > 0.01)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Container(
                            color: Colors.black.withValues(
                              alpha: shadowOpacity,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
