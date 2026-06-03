import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_tv_player/src/models/playlist_source.dart';
import 'package:one_tv_player/src/services/playlist_repository.dart';

void main() {
  test('merges enabled sources and removes duplicate channels by tvg-id', () async {
    final client = MockClient((request) async {
      if (request.url.toString().contains('one')) {
        return http.Response(
          '''
#EXTM3U
#EXTINF:-1 tvg-id="npo1.nl" group-title="Netherlands",NPO 1
https://example.com/source-one/npo1.m3u8
''',
          200,
        );
      }

      return http.Response(
        '''
#EXTM3U
#EXTINF:-1 tvg-id="npo1.nl" group-title="Dutch",NPO 1 HD
https://example.com/source-two/npo1.m3u8
#EXTINF:-1 tvg-id="npo2.nl" group-title="Dutch",NPO 2
https://example.com/source-two/npo2.m3u8
''',
        200,
      );
    });

    final repository = PlaylistRepository(client: client);

    final channels = await repository.loadChannels([
      const PlaylistSource(
        id: 'one',
        name: 'One',
        url: 'https://example.com/one.m3u',
        type: PlaylistSourceType.m3uUrl,
      ),
      const PlaylistSource(
        id: 'two',
        name: 'Two',
        url: 'https://example.com/two.m3u',
        type: PlaylistSourceType.m3uUrl,
      ),
    ]);

    expect(channels, hasLength(2));
    expect(channels.map((channel) => channel.tvgId), containsAll(['npo1.nl', 'npo2.nl']));
    expect(channels.firstWhere((channel) => channel.tvgId == 'npo1.nl').sourceId, 'one');
  });

  test('ignores disabled sources', () async {
    final client = MockClient((request) async {
      return http.Response(
        '''
#EXTM3U
#EXTINF:-1 group-title="Live",Enabled Channel
https://example.com/enabled.m3u8
''',
        200,
      );
    });

    final repository = PlaylistRepository(client: client);

    final channels = await repository.loadChannels([
      const PlaylistSource(
        id: 'enabled',
        name: 'Enabled',
        url: 'https://example.com/enabled.m3u',
        type: PlaylistSourceType.m3uUrl,
      ),
      const PlaylistSource(
        id: 'disabled',
        name: 'Disabled',
        url: 'https://example.com/disabled.m3u',
        type: PlaylistSourceType.m3uUrl,
        enabled: false,
      ),
    ]);

    expect(channels, hasLength(1));
    expect(channels.single.name, 'Enabled Channel');
  });
}
