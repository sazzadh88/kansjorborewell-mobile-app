import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/core/api_client.dart';
import 'package:core/core.dart';
import 'package:mobile/core/providers.dart';

class _FakeTokenStore implements TokenStore {
  String? token;

  @override
  Future<String?> read({required String key}) async => token;

  @override
  Future<void> write({required String key, required String value}) async {
    token = value;
  }

  @override
  Future<void> delete({required String key}) async {
    token = null;
  }
}

class FakeApiClient extends ApiClient {
  FakeApiClient({this.shouldFail = false})
    : super(baseUrl: 'http://localhost/api', storage: _FakeTokenStore());

  final bool shouldFail;

  @override
  Future<bool> hasToken() async => false;

  @override
  Future<Map<String, dynamic>> login(String mobile, String password) async {
    if (shouldFail) {
      throw DioException(
        requestOptions: RequestOptions(path: '/login'),
        response: Response(
          requestOptions: RequestOptions(path: '/login'),
          statusCode: 422,
          data: {'message': 'Invalid mobile or password.'},
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return {
      'token': 'test-token',
      'user': {
        'id': 1,
        'name': 'System Admin',
        'mobile': mobile,
        'role': {'name': 'admin'},
      },
    };
  }
}

void main() {
  test(
    'invalid credentials produce an auth error instead of hanging',
    () async {
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(FakeApiClient(shouldFail: true)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authProvider.future);
      await container.read(authProvider.notifier).login('9999999999', 'wrong');

      final state = container.read(authProvider);
      expect(state.hasError, isTrue);
      expect(apiErrorMessage(state.error!), 'Invalid mobile or password.');
    },
  );

  test('dispatch decimal strings parse into a valid record', () {
    final record = DispatchRecord.fromJson({
      'id': 1,
      'dispatch_date': '2026-08-12',
      'brick_type': {'id': 1, 'name': 'Paver Block 60mm'},
      'party': {'id': 1, 'name': 'Buyer'},
      'vehicle': {'id': 1, 'registration_number': 'UP-01'},
      'driver': null,
      'quantity_loaded': 500,
      'freight_amount': '0.00',
      'freight_paid': false,
    });

    expect(record.quantity, 500);
    expect(record.freightAmount, 0);
  });

  test('valid credentials transition auth state to the user', () async {
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(FakeApiClient())],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    await container.read(authProvider.notifier).login('9999999999', 'password');

    expect(container.read(authProvider).value, isA<UserModel>());
    expect(container.read(authProvider).value?.role, 'admin');
  });
}
