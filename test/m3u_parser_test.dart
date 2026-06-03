import 'package:flutter_test/flutter_test.dart';
import 'package:one_tv_player/src/models/channel.dart';
import 'package:one_tv_player/src/services/m3u_parser.dart';

void main() {
  test('parses channel metadata and stream url', () {
    const playlist = '''
#EXTM3U
#EXTINF:-1 tvg-id="npo1.nl" tvg-name="NPO 1" tvg-logo="https://example.com/logo.png" group-title="Netherlands",NPO 1
https://example.com/live/npo1.m3u8
''';

    final channels = M3uParser().parse(playlist, sourceId: 'test');

    expect(channels, hasLength(1));
    expect(channels.single.name, 'NPO 1');
    expect(channels.single.group, 'Netherlands');
    expect(channels.single.tvgId, 'npo1.nl');
    expect(channels.single.url, 'https://example.com/live/npo1.m3u8');
  });

  test('infers movie and series content types from clear group metadata', () {
    const playlist = '''
#EXTM3U
#EXTINF:-1 group-title="Movies",Example Movie
https://example.com/movie.mp4
#EXTINF:-1 group-title="Series",Example Episode
https://example.com/series.mp4
''';

    final channels = M3uParser().parse(playlist);

    expect(channels[0].contentType, ContentType.movie);
    expect(channels[1].contentType, ContentType.series);
  });
}
