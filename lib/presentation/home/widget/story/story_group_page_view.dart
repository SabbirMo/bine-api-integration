import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:binetatour/providers/story_provider.dart';
import 'package:binetatour/providers/story_detail_provider.dart';
import 'package:binetatour/presentation/home/widget/story/story_models.dart';
import 'package:binetatour/presentation/home/widget/story/story_detail_content.dart';

class StoryGroupPageView extends StatefulWidget {
  final StoryGroup group;
  final bool isActive;
  final VoidCallback onNextCategory;
  final VoidCallback onPrevCategory;
  final VoidCallback onClose;

  const StoryGroupPageView({
    super.key,
    required this.group,
    required this.isActive,
    required this.onNextCategory,
    required this.onPrevCategory,
    required this.onClose,
  });

  @override
  State<StoryGroupPageView> createState() => _StoryGroupPageViewState();
}

class _StoryGroupPageViewState extends State<StoryGroupPageView> {
  late StoryDetailProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = StoryDetailProvider(
      stories: widget.group.stories,
      storyProvider: context.read<StoryProvider>(),
      autoStart: widget.isActive,
      onFinished: widget.onNextCategory,
      onPreviousAtStart: widget.onPrevCategory,
    );
  }

  @override
  void didUpdateWidget(covariant StoryGroupPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _provider.startOrResumeStory();
      } else {
        _provider.pauseStory();
      }
    }
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StoryDetailProvider>.value(
      value: _provider,
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
