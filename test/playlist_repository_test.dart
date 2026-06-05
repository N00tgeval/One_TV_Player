import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_tv_player/src/models/playlist_source.dart';
import 'package:one_tv_player/src/services/playlist_repository.dart';

void main() {
  test('merges enabled sources and removes duplicate channels by tvg-id',
      () async {
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
    expect(channels.map((channel) => channel.tvgId),
        containsAll(['npo1.nl', 'npo2.nl']));
    expect(
        channels.firstWhere((channel) => channel.tvgId == 'npo1.nl').sourceId,
        'one');
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

  test('deduplicates Samsung TV Plus country variants by channel name',
      () async {
    final client = MockClient((request) async {
      return http.Response(
        '''
#EXTM3U
#EXTINF:-1 tvg-id="CA-xite-80s" tvg-name="XITE 80s Flashback" group-title="Canada",XITE 80s Flashback
https://example.com/ca/xite-80s.m3u8
#EXTINF:-1 tvg-id="US-xite-80s" tvg-name="XITE 80s Flashback" group-title="United States",XITE 80s Flashback
https://example.com/us/xite-80s.m3u8
#EXTINF:-1 tvg-id="US-xite-90s" tvg-name="XITE 90s Throwback" group-title="United States",XITE 90s Throwback
https://example.com/us/xite-90s.m3u8
''',
        200,
      );
    });

    final repository = PlaylistRepository(client: client);

    final channels = await repository.loadChannels([
      const PlaylistSource(
        id: 'samsung-tv-plus',
        name: 'Samsung TV Plus',
        url: 'https://example.com/samsung.m3u',
        type: PlaylistSourceType.fastPreset,
      ),
    ]);

    expect(channels.map((channel) => channel.name), [
      'XITE 80s Flashback',
      'XITE 90s Throwback',
    ]);
  });

  test('detects Xtream credentials from a get.php playlist url', () {
    final input = XtreamSourceInput.tryParse(
      'http://panel.example.com:8080/get.php?username=user&password=pass&type=m3u_plus',
    );

    expect(input, isNotNull);
    expect(input!.serverUrl, 'http://panel.example.com:8080');
    expect(input.username, 'user');
    expect(input.password, 'pass');
  });

  test('does not serialize Xtream passwords into source json', () {
    const source = PlaylistSource(
      id: 'xtream',
      name: 'Xtream',
      url: 'http://panel.example.com:8080',
      type: PlaylistSourceType.xtream,
      username: 'user',
      password: 'secret',
    );

    expect(source.toJson().containsKey('password'), isFalse);
  });

  test('loads Xtream live channels from the fastest working server url',
      () async {
    final requests = <String>[];
    final client = MockClient((request) async {
      requests.add(request.url.toString());
      if (request.url.host == 'offline.example.com') {
        return http.Response('Not found', 404);
      }
      if (request.url.queryParameters['action'] == null) {
        return http.Response(
          '{"user_info":{"auth":1,"status":"Active"}}',
          200,
        );
      }
      if (request.url.queryParameters['action'] == 'get_live_categories') {
        return http.Response(
          '[{"category_id":"10","category_name":"News"}]',
          200,
        );
      }
      if (request.url.queryParameters['action'] == 'get_live_streams') {
        return http.Response(
          '[{"stream_id":42,"name":"Example News","category_id":"10","stream_icon":"https://example.com/logo.png","epg_channel_id":"example.news"}]',
          200,
        );
      }
      return http.Response('[]', 200);
    });

    final repository = PlaylistRepository(client: client);

    final channels = await repository.loadChannels([
      const PlaylistSource(
        id: 'xtream',
        name: 'Xtream',
        url: 'http://offline.example.com:8080',
        type: PlaylistSourceType.xtream,
        serverUrls: [
          'http://offline.example.com:8080',
          'http://working.example.com:8080',
        ],
        username: 'user',
        password: 'pass',
      ),
    ]);

    expect(channels, hasLength(1));
    expect(channels.single.name, 'Example News');
    expect(channels.single.group, 'News');
    expect(
      channels.single.url,
      'http://working.example.com:8080/live/user/pass/42.m3u8',
    );
    expect(channels.single.streamUrls, [
      'http://working.example.com:8080/live/user/pass/42.m3u8',
    ]);
    expect(
      requests,
      contains(
        'http://working.example.com:8080/player_api.php?username=user&password=pass&action=get_live_streams',
      ),
    );
  });

  test('tests an M3U source and reports parsed channel count', () async {
    final client = MockClient((request) async {
      return http.Response(
        '''
#EXTM3U
#EXTINF:-1 tvg-id="one" tvg-name="One",One
https://example.com/one.m3u8
''',
        200,
      );
    });

    final repository = PlaylistRepository(client: client);
    final result = await repository.testSource(
      const PlaylistSource(
        id: 'm3u',
        name: 'M3U',
        url: 'https://example.com/list.m3u',
        type: PlaylistSourceType.m3uUrl,
      ),
    );

    expect(result.success, isTrue);
    expect(result.message, 'Playlist OK. 1 channels found.');
    expect(result.latency, isNotNull);
  });

  test('tests Xtream server urls individually', () async {
    final client = MockClient((request) async {
      if (request.url.host == 'working.example.com') {
        return http.Response(
          '{"user_info":{"auth":1,"status":"Active"}}',
          200,
        );
      }
      return http.Response('Not found', 404);
    });

    final repository = PlaylistRepository(client: client);
    final result = await repository.testSource(
      const PlaylistSource(
        id: 'xtream',
        name: 'Xtream',
        url: 'http://offline.example.com:8080',
        type: PlaylistSourceType.xtream,
        serverUrls: [
          'http://offline.example.com:8080',
          'http://working.example.com:8080',
        ],
        username: 'user',
        password: 'pass',
      ),
    );

    expect(result.success, isTrue);
    expect(result.message, '1 of 2 server URLs work.');
    expect(result.servers, hasLength(2));
    expect(result.servers.first.success, isFalse);
    expect(result.servers.last.success, isTrue);
  });
}
