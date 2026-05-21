import 'package:dio/dio.dart';
import 'package:mnd_delivery_app/core/config/env_config.dart';
import 'package:mnd_delivery_app/core/constants/app_constants.dart';

class ApiClient {
  ApiClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: EnvConfig.baseUrl,
            connectTimeout: AppConstants.apiTimeout,
            receiveTimeout: AppConstants.apiTimeout,
          ),
        );

  final Dio _dio;

  Dio get instance => _dio;
}
