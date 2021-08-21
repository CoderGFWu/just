import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:html/parser.dart';

import '../error.dart';

class YJS {
  static late Dio _dio;
  static final cookieJar = CookieJar();

  factory YJS() => _getInstance();

  static YJS get instance => _getInstance();
  static YJS? _instance;

  YJS._internal() {
    //init
    _dio = Dio();
    (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate =
        (client) {
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        return true;
      };
    };
    _dio.interceptors.add(CookieManager(cookieJar));
    _dio.options = BaseOptions(
      contentType: 'application/x-www-form-urlencoded',
      baseUrl: 'http://yjsinfo.just.edu.cn',
      followRedirects: false,
      connectTimeout: 10000,
      validateStatus: (status) {
        if (status != null) {
          return status < 500;
        } else {
          return false;
        }
      },
    );
  }

  static YJS _getInstance() {
    _instance ??= YJS._internal();
    return _instance!;
  }

  Future<void> validate(
      {required String username, required String password}) async {
    var response = await _dio.get('/pyxx/login.aspx');
    var form = <String, String>{};
    parse(response.data).querySelectorAll('input').forEach((element) {
      form.addAll({
        element.attributes['name'] ?? '': element.attributes['value'] ?? ''
      });
    });
    form['ctl00\$txtusername'] = username;
    form['ctl00\$txtpassword'] = password;
    form['ctl00\$ImageButton1.x'] = '33';
    form['ctl00\$ImageButton1.y'] = '8';
    response = await _dio.post('/pyxx/login.aspx', data: form);
    var location = response.headers.value('location');
    if (location == null) {
      throw JustAccountError('研究生系统账号或密码不正确');
    }
  }

  Future<Response> login(
      {required String username, required String password}) async {
    var response = await _dio.get('/pyxx/login.aspx');
    var form = <String, String>{};
    parse(response.data).querySelectorAll('input').forEach((element) {
      form.addAll({
        element.attributes['name'] ?? '': element.attributes['value'] ?? ''
      });
    });
    form['ctl00\$txtusername'] = username;
    form['ctl00\$txtpassword'] = password;
    form['ctl00\$ImageButton1.x'] = '33';
    form['ctl00\$ImageButton1.y'] = '8';
    response = await _dio.post('/pyxx/login.aspx', data: form);
    var location = response.headers.value('location');
    if (location == null) {
      throw JustAccountError('研究生系统账号或密码不正确');
    }
    response = await _dio.get('/pyxx/default.aspx');
    return response;
  }

  Future<String> getCourse(
      {required String username, required String password}) async {
    await login(username: username, password: password);
    var response = await _dio.get('/pyxx/pygl/kbcx_xs.aspx');
    return response.data;
  }

  Future<String> getScore(
      {required String username, required String password}) async {
    await login(username: username, password: password);
    var response = await _dio.get('/pyxx/grgl/xskccjcx.aspx');
    return response.data;
  }

  Future<String> getCookie(
      {required String username, required String password}) async {
    var response = await login(username: username, password: password);
    var cookie = response.headers[HttpHeaders.cookieHeader]?.first ?? '';
    return cookie;
  }
}
