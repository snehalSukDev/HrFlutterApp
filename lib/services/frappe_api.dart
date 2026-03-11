import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';

import 'cache_manager.dart';

class FrappeApi {
  static String _baseUrl = '';
  static final Dio _dio = Dio();
  static String? _cookieHeader;

  static String get baseUrl => _baseUrl;
  static String? get cookieHeader => _cookieHeader;

  static void setCookieHeader(String? cookie) {
    _cookieHeader = cookie;
  }

  static String _normalizeBaseUrl(String input) {
    final raw = input.trim();
    if (raw.isEmpty) {
      throw ArgumentError('Frappe URL is required');
    }
    final withProtocol = raw.startsWith('http://') || raw.startsWith('https://')
        ? raw
        : 'https://$raw';
    final uri = Uri.parse(withProtocol);
    final origin =
        '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
    return origin.replaceAll(RegExp(r'/+$'), '');
  }

  static String? _extractServerMessages(dynamic serverMessages) {
    if (serverMessages is! String || serverMessages.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(serverMessages);
      if (decoded is! List) {
        return null;
      }
      final messages = <String>[];
      for (final item in decoded) {
        if (item is String) {
          try {
            final inner = jsonDecode(item);
            if (inner is Map<String, dynamic>) {
              final msg = inner['message']?.toString().trim();
              if (msg != null && msg.isNotEmpty) {
                messages.add(msg);
              }
            }
          } catch (_) {
            final msg = item.trim();
            if (msg.isNotEmpty) {
              messages.add(msg);
            }
          }
        } else if (item is Map) {
          final msg = item['message']?.toString().trim();
          if (msg != null && msg.isNotEmpty) {
            messages.add(msg);
          }
        }
      }
      if (messages.isEmpty) {
        return null;
      }
      return messages.join('\n');
    } catch (_) {
      return null;
    }
  }

  static String _extractErrorMessageFromBody(
    int status,
    Map<String, dynamic> body,
  ) {
    final serverMessages = _extractServerMessages(body['_server_messages']);
    if (serverMessages != null && serverMessages.isNotEmpty) {
      return serverMessages;
    }

    final rawMessage = body['message'];
    if (rawMessage is String && rawMessage.trim().isNotEmpty) {
      return rawMessage.trim();
    }
    if (rawMessage is Map<String, dynamic>) {
      final msg = rawMessage['message']?.toString().trim();
      if (msg != null && msg.isNotEmpty) {
        return msg;
      }
    }

    if (body['exc_type'] == 'PermissionError') {
      return 'Permission Error: You do not have access to this resource.';
    }
    if (body['exception'] != null) {
      String raw = body['exception'].toString();
      if (raw.contains(':')) {
        raw = raw.substring(raw.indexOf(':') + 1).trim();
      } else {
        raw = raw.split('.').last;
      }
      return raw.replaceAll(RegExp(r'<[^>]*>'), '');
    }

    return 'Request failed with status $status';
  }

  static void setBaseUrl(String url) {
    final normalized = _normalizeBaseUrl(url);
    final changed = normalized != _baseUrl;
    _baseUrl = normalized;
    if (changed) {
      _cookieHeader = null;
    }
    _dio.options = BaseOptions(
      baseUrl: '$_baseUrl/',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      followRedirects: true,
      // Let us handle all HTTP statuses (including 5xx) ourselves,
      // so we can parse _server_messages and return meaningful errors.
      validateStatus: (status) =>
          status != null && status >= 100 && status < 600,
    );
  }

  static Future<Map<String, dynamic>> _request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? data,
    Map<String, dynamic>? query,
  }) async {
    final safeData = data == null ? null : Map<String, dynamic>.from(data);
    if (safeData != null && safeData.containsKey('pwd')) {
      safeData['pwd'] = '***';
    }
    try {
      final options = Options(
        method: method,
        extra: {
          'withCredentials': true,
        },
      );
      if (_cookieHeader != null && _cookieHeader!.isNotEmpty) {
        options.headers = {
          ...?options.headers,
          'Cookie': _cookieHeader!,
        };
        // ignore: avoid_print
        print(
          '[FrappeApi] Cookies attached path=$path header=$_cookieHeader',
        );
      } else {
        // ignore: avoid_print
        print('[FrappeApi] No cookies found for path=$path');
      }
      // request log
      // ignore: avoid_print
      print(
        '[FrappeApi] Request method=$method path=$path '
        'query=${query != null ? jsonEncode(query) : 'null'} '
        'data=${safeData != null ? jsonEncode(safeData) : 'null'}',
      );
      final response = await _dio.request(
        path,
        data: data,
        queryParameters: query,
        options: options,
      );
      final status = response.statusCode ?? 500;
      final value = response.data;
      if (status >= 200 && status < 300) {
        // response success log
        // ignore: avoid_print
        print(
          '[FrappeApi] Response OK method=$method path=$path '
          'status=$status',
        );
        if (value is Map<String, dynamic>) {
          // print('[FrappeApi] Response Data: $value');
          return value;
        }
        if (value is String) {
          // print('[FrappeApi] Response String: $value');
          return jsonDecode(value) as Map<String, dynamic>;
        }
        return {'data': value};
      }
      // response error log
      // ignore: avoid_print
      print(
        '[FrappeApi] Response Error method=$method path=$path '
        'status=$status body=${value is String ? value : jsonEncode(value)}',
      );
      final dataBody = value;
      String message = 'Request failed with status $status';
      if (dataBody is Map<String, dynamic>) {
        message = _extractErrorMessageFromBody(status, dataBody);
      }
      throw Exception(message);
    } catch (e) {
      // ignore: avoid_print
      print(
        '[FrappeApi] Request Exception method=$method path=$path '
        'error=$e',
      );
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> loginUser(
    String email,
    String password,
  ) async {
    final payload = {
      'usr': email,
      'pwd': password,
    };
    final safePayload = Map<String, dynamic>.from(payload);
    safePayload['pwd'] = '***';
    try {
      // ignore: avoid_print
      print(
        '[FrappeApi] Login request path=api/method/login '
        'data=${jsonEncode(safePayload)}',
      );
      final response = await _dio.post(
        'api/method/login',
        data: payload,
        options: Options(
          extra: {
            'withCredentials': true,
          },
        ),
      );
      final status = response.statusCode ?? 500;
      final value = response.data;
      if (status >= 200 && status < 300) {
        // capture cookies from set-cookie headers
        final headerMap = response.headers.map;
        final setCookieList =
            headerMap['set-cookie'] ?? headerMap['Set-Cookie'];
        if (setCookieList != null && setCookieList.isNotEmpty) {
          final cookiePairs = <String>[];
          for (final raw in setCookieList) {
            final parts = raw.split(';');
            if (parts.isEmpty) {
              continue;
            }
            final pair = parts.first.trim();
            if (pair.isEmpty) {
              continue;
            }
            cookiePairs.add(pair);
          }
          if (cookiePairs.isNotEmpty) {
            _cookieHeader = cookiePairs.join('; ');
            // ignore: avoid_print
            print(
              '[FrappeApi] Login cookies stored header=$_cookieHeader',
            );
          }
        }
        if (value is Map<String, dynamic>) {
          return value;
        }
        if (value is String) {
          return jsonDecode(value) as Map<String, dynamic>;
        }
        return {'data': value};
      }
      final message = value is Map<String, dynamic>
          ? (value['message']?.toString() ?? 'Login failed with status $status')
          : 'Login failed with status $status';
      throw Exception(message);
    } catch (e) {
      // ignore: avoid_print
      print('[FrappeApi] Login exception error=$e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> resetPassword(String email) async {
    return _request(
      'api/method/tbui_backend_core.api.reset_password',
      method: 'POST',
      data: {
        'email': email,
      },
    );
  }

  static Future<Map<String, dynamic>> getCurrentUser() async {
    final res = await _request(
      'api/method/frappe.auth.get_logged_user',
    );
    return res;
  }

  static Future<Map<String, dynamic>?> fetchEmployeeDetails(
    String identifier, {
    bool byEmail = true,
  }) async {
    final cacheKey = 'employee_${identifier}_${byEmail ? 1 : 0}';
    final cached = await CacheManager.get(cacheKey);
    if (cached is Map<String, dynamic>) {
      return cached;
    }
    final filters = byEmail
        ? [
            ['user_id', '=', identifier]
          ]
        : [
            ['name', '=', identifier]
          ];
    final fields = [
      'name',
      'employee_name',
      'user_id',
      'designation',
      'department',
      'cell_number',
      'date_of_joining',
      'gender',
      'blood_group',
      'image',
      'employment_type',
      'person_to_be_contacted',
      'emergency_phone_number',
      'company',
      'leave_approver',
      'expense_approver',
    ];
    final query = {
      'filters': jsonEncode(filters),
      'fields': jsonEncode(fields),
    };
    final res = await _request(
      'api/resource/Employee',
      query: query,
    );
    final data = res['data'];
    if (data is List && data.isNotEmpty && data.first is Map<String, dynamic>) {
      final first = data.first as Map<String, dynamic>;
      await CacheManager.set(cacheKey, first);
      return first;
    }
    return null;
  }

  static Future<List<dynamic>> getResourceList(
    String doctype, {
    Map<String, dynamic>? params,
    bool cache = false,
    Duration? cacheTtl,
    bool forceRefresh = false,
  }) async {
    final safeParams = params ?? {};
    final cacheKey = 'list_${doctype}_${jsonEncode(safeParams)}';
    if (cache && !forceRefresh) {
      final cached = await CacheManager.get(cacheKey);
      if (cached is List) {
        return cached;
      }
    }
    final query = Map<String, dynamic>.from(safeParams);
    final encodedDoctype = Uri.encodeComponent(doctype);

    // Convert complex params to JSON strings if they are not already
    // Frappe expects filters and fields to be JSON strings
    if (query.containsKey('filters') && query['filters'] is! String) {
      query['filters'] = jsonEncode(query['filters']);
    }
    if (query.containsKey('fields') && query['fields'] is! String) {
      query['fields'] = jsonEncode(query['fields']);
    }

    final res = await _request(
      'api/resource/$encodedDoctype',
      query: query,
    );
    final data = res['data'];
    if (cache && data is List) {
      await CacheManager.set(cacheKey, data, cacheTtl);
    }
    if (data is List) {
      return data;
    }
    return const [];
  }

  static Future<Map<String, dynamic>> getResource(
    String doctype,
    String name, {
    bool cache = false,
    Duration? cacheTtl,
    bool forceRefresh = false,
  }) async {
    final cacheKey = 'resource_${doctype}_$name';
    if (cache && !forceRefresh) {
      final cached = await CacheManager.get(cacheKey);
      if (cached is Map<String, dynamic>) {
        return cached;
      }
    }
    final encodedDoctype = Uri.encodeComponent(doctype);
    final encodedName = Uri.encodeComponent(name);
    final res = await _request(
      'api/resource/$encodedDoctype/$encodedName',
    );
    final data = res['data'];
    if (cache && data is Map<String, dynamic>) {
      await CacheManager.set(cacheKey, data, cacheTtl);
    }
    if (data is Map<String, dynamic>) {
      return data;
    }
    return {};
  }

  static Future<Map<String, dynamic>> callMethod(
    String method, {
    Map<String, dynamic>? args,
  }) async {
    final res = await _request(
      'api/method/$method',
      method: 'POST',
      data: args,
    );
    return res;
  }

  static Future<void> logoutUser() async {
    await _request(
      'api/method/logout',
    );
  }

  static Future<Position> getCurrentPosition() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission not granted');
    }
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
    return position;
  }

  static Future<Map<String, dynamic>> getMetaData(String doctype) async {
    final res = await _request(
      'api/method/frappe.desk.form.load.getdoctype',
      query: {'doctype': doctype},
    );
    return res;
  }
}
