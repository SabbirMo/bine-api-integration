import 'package:flutter_test/flutter_test.dart';
import 'package:binetatour/core/video/smart_video_controller.dart';

void main() {
  group('SmartVideoController Unit Tests', () {
    test('SmartVideoConfig has optimal defaults for adaptive streaming', () {
      const config = SmartVideoConfig();
      expect(config.cacheSecs, 45);
      expect(config.demuxerReadaheadSecs, 30);
      expect(config.demuxerMaxBytes, 50 * 1024 * 1024);
      expect(config.demuxerMaxBackBytes, 20 * 1024 * 1024);
      expect(config.networkTimeoutSecs, 15);
      expect(config.maxRetries, 5);
      expect(config.autoPlay, isTrue);
      expect(config.loop, isFalse);
      expect(config.initialVolume, 100.0);
      expect(config.initialMuted, isFalse);
    });

    test('VideoQuality.auto is the default quality configuration', () {
      expect(VideoQuality.auto.label, 'Auto');
      expect(VideoQuality.auto.maxRes, isNull);
    });

    test('SmartVideoConfig does not require static thumbnail URLs', () {
      const config = SmartVideoConfig(cacheSecs: 30, demuxerReadaheadSecs: 20);
      expect(config.cacheSecs, 30);
      expect(config.demuxerReadaheadSecs, 20);
    });

    test(
      'formatResolution maps resolutions to human-readable quality labels accurately',
      () {
        // Landscape (horizontal)
        expect(SmartVideoController.formatResolution(1920, 1080), '1080p');
        expect(SmartVideoController.formatResolution(1280, 720), '720p');
        expect(SmartVideoController.formatResolution(854, 480), '480p');
        expect(SmartVideoController.formatResolution(640, 360), '360p');
        expect(SmartVideoController.formatResolution(426, 240), '240p');

        // Portrait / Vertical (Shorts/Stories)
        expect(SmartVideoController.formatResolution(1080, 1920), '1080p');
        expect(SmartVideoController.formatResolution(720, 1280), '720p');
        expect(SmartVideoController.formatResolution(480, 854), '480p');
        expect(SmartVideoController.formatResolution(360, 640), '360p');
        expect(SmartVideoController.formatResolution(240, 426), '240p');
      },
    );
  });
}
