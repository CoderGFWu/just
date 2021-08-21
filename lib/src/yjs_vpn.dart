import 'package:dio/dio.dart';

class YJS_VPN {
  factory YJS_VPN() => _getInstance();

  static YJS_VPN get instance => _getInstance();
  static YJS_VPN? _instance;

  YJS_VPN._internal();

  static YJS_VPN _getInstance() {
    _instance ??= YJS_VPN._internal();
    return _instance!;
  }

  ///验证VPN账号
  ///[username]VPN用户名
  ///[password]VPN密码
  Future<void> validateVPN(
      {required String username, required String password}) async {}

  ///VPN登录
  ///[vpnUsername]VPN账号
  ///[vpnPassword]VPN密码
  Future<Response> vpnLogin(
          {required String vpnUsername, required String vpnPassword}) async =>
      Response(requestOptions: RequestOptions(path: ''));

  ///VPN登出
  Future<void> vpnLogout() async {}

  Future<void> validate({
    required String username,
    required String password,
    required String vpnUsername,
    required String vpnPassword,
  }) async {}

  Future<Response> login({
    required String username,
    required String password,
    required String vpnUsername,
    required String vpnPassword,
  }) async =>
      Response(requestOptions: RequestOptions(path: ''));

  Future<String> getCourse({
    required String username,
    required String password,
    required String vpnUsername,
    required String vpnPassword,
  }) async =>
      '';

  Future<String> getScore({
    required String username,
    required String password,
    required String vpnUsername,
    required String vpnPassword,
  }) async =>
      '';

  Future<String> getCookie({
    required String username,
    required String password,
    required String vpnUsername,
    required String vpnPassword,
  }) async =>
      '';
}
