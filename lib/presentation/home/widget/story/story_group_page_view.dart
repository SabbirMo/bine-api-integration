import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/story_provider.dart';
import 'package:binetatour/providers/story_detail_provider.dart';
import 'package:binetatour/presentation/home/widget/story/story_models.dart';
import 'package:binetatour/presentation/home/widget/story/story_detail_content.dart';

class StoryGroupPageView extends StatefulWidget {
  final StoryGroup group;
  final int categoryIndex;
  final bool isActive;
  final VoidCallback onNextCategory;
  final VoidCallback onPrevCategory;
  final VoidCallback onClose;

  const StoryGroupPageView({
    super.key,
    required this.group,
    this.categoryIndex = 0,
    required this.isActive,
    required this.onNextCategory,
    required this.onPrevCategory,
    required this.onClose,
  });

  @override
  State<StoryGroupPageView> createState() => _StoryGroupPageViewState();
}

class _StoryGroupPageViewState extends State<StoryGroupPageView> {
  StoryDetailProvider? _provider;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _activate();
    }
  }

  void _activate() {
    _provider?.dispose();
    _provider = StoryDetailProvider(
      stories: widget.group.stories,
      categoryIndex: widget.categoryIndex,
      storyProvider: context.read<StoryProvider>(),
      onFinished: widget.onNextCategory,
      onPreviousAtStart: widget.onPrevCategory,
    );
    _provider!.loadCurrentStory(play: true);
  }

  void _deactivate() {
    _provider?.dispose();
    _provider = null;
  }

  @override
  void didUpdateWidget(covariant StoryGroupPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _activate();
      } else {
        _deactivate();
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _deactivate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If not active, render clean poster thumbnail or category image without allocating any player
    if (_provider == null || !widget.isActive) {
      final thumb = (widget.group.stories.isNotEmpty &&
              widget.group.stories.first.thumbnailUrl != null &&
              widget.group.stories.first.thumbnailUrl!.trim().isNotEmpty)
          ? widget.group.stories.first.thumbnailUrl!
          : widget.group.categoryImage;

      return Scaffold(
        backgroundColor: Colors.black,
        body: thumb.isNotEmpty && thumb.startsWith('http')
            ? Image.network(
                thumb,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, e, s) => Container(color: Colors.black),
              )
            : Container(color: Colors.black),
      );
    }

    return ChangeNotifierProvider<StoryDetailProvider>.value(
      value: _provider!,
      child: StoryDetailContent(
        userName: widget.group.categoryName,
        userProfile: widget.group.categoryImage,
        onNextCategory: widget.onNextCategory,
        onPrevCategory: widget.onPrevCategory,
        onClose: widget.onClose,
      ),
    );
  }
}
