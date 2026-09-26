import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:opennutritracker/core/data/data_source/config_data_source.dart';
import 'package:opennutritracker/core/data/dbo/config_dbo.dart';
import 'package:opennutritracker/core/utils/hive_db_provider.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/core/utils/app_locale.dart';
import 'package:opennutritracker/features/add_meal/data/data_sources/sp_food_data_source.dart';
import 'package:opennutritracker/features/add_meal/data/dto/sp/sp_const.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/hive_test_setup.dart';

class _TestHiveDBProvider extends HiveDBProvider {
  final Box<ConfigDBO> shared;
  final Box<ConfigDBO> profile;
  _TestHiveDBProvider(this.shared, this.profile);

  @override
  Box<ConfigDBO> get appConfigBox => shared;

  @override
  Box<ConfigDBO> get configBox => profile;
}

class _MockClient extends http.BaseClient {
  final Map<String, List<Map<String, dynamic>>> responses;
  _MockClient(this.responses);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final urlStr = request.url.toString();
    List<Map<String, dynamic>> responseData = [];

    if (urlStr.contains('search_food_translation')) {
      responseData = responses['search_food_translation'] ?? [];
    } else if (urlStr.contains('food_summary_by_ids')) {
      responseData = responses['food_summary_by_ids'] ?? [];
    } else if (urlStr.contains('portion_labels_by_food_ids')) {
      responseData = [];
    } else if (urlStr.contains('portions_by_food_ids')) {
      responseData = [];
    }

    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(responseData))),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
      request: request,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Box<ConfigDBO> appConfigBox;
  late Box<ConfigDBO> profileConfigBox;

  setUp(() async {
    Hive.init('.');
    registerHiveAdaptersOnce();
    final tag = DateTime.now().microsecondsSinceEpoch;
    appConfigBox = await Hive.openBox<ConfigDBO>('sp_reg_app_$tag');
    profileConfigBox = await Hive.openBox<ConfigDBO>('sp_reg_cfg_$tag');

    if (locator.isRegistered<SupabaseClient>()) {
      locator.unregister<SupabaseClient>();
    }
    if (locator.isRegistered<ConfigDataSource>()) {
      locator.unregister<ConfigDataSource>();
    }

    locator.registerSingleton<ConfigDataSource>(
      ConfigDataSource(_TestHiveDBProvider(appConfigBox, profileConfigBox)),
    );
  });

  tearDown(() async {
    locator.unregister<SupabaseClient>();
    locator.unregister<ConfigDataSource>();
    await Hive.deleteFromDisk();
  });

  test('AI resolver drops BLS matches when FDC is disabled in a translated locale (Issue #1272)', () async {
    // Generate 20 FDC survey rows with portions
    final List<Map<String, dynamic>> translationRows = [
      for (var i = 1; i <= 20; i++)
        {
          SPConst.translationFoodId: i,
          SPConst.translationDescription: 'Synthetic FDC Item $i',
          SPConst.translationSource: 'machine',
          SPConst.translationHasPortion: true,
        }
    ];

    // Add 1 BLS row without a portion.
    translationRows.add({
      SPConst.translationFoodId: 99,
      SPConst.translationDescription: 'Synthetic BLS Match',
      SPConst.translationSource: 'human',
      SPConst.translationHasPortion: false,
    });

    final client = _MockClient({
      'search_food_translation': translationRows,
      'food_summary_by_ids': [
        // Simulate enabledSources = ['bls'] filtering on the backend
        // So ONLY the BLS row summary is returned.
        {
          SPConst.foodId: 99,
          SPConst.foodSource: 'bls',
          SPConst.foodSourceCode: '99',
          SPConst.foodName: 'Synthetic BLS Match',
          SPConst.servingSize: '100',
          SPConst.servingGramWeight: 100.0,
        }
      ]
    });

    locator.registerSingleton<SupabaseClient>(
      SupabaseClient('http://backend.invalid', 'test-key', httpClient: client),
    );

    // Mock locale to 'de' temporarily
    AppLocale.select('de');

    final dataSource = SpFoodDataSource();
    // The backend response for food_summary_by_ids has exactly the bls item.
    final results = await dataSource.fetchSearchWordResults('Synthetic', forResolution: true);

    AppLocale.reset();

    expect(results.length, 1);
    expect(results.first.foodId, 99);
    expect(results.first.source, 'bls');
  });
}
