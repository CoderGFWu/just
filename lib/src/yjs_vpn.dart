import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart';
import 'package:just/error.dart';
import 'package:just/src/private_cookie_manager.dart';
import 'package:just/src/utils.dart';
import 'package:pedantic/pedantic.dart';

class YJS_VPN {
  static Dio _dio;
  static final cookieJar = CookieJar();

  factory YJS_VPN() => _getInstance();

  static YJS_VPN get instance => _getInstance();
  static YJS_VPN _instance;
  static const yjsBaseUrl = 'http://yjsinfo.just.edu.cn';

  YJS_VPN._internal() {
    //init
    _dio = Dio();
    (_dio.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate =
        (client) {
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        return true;
      };
    };
    _dio.interceptors.add(PrivateCookieManager(cookieJar));
    _dio.options = BaseOptions(
      contentType: 'application/x-www-form-urlencoded',
      baseUrl: 'https://vpn.just.edu.cn',
      followRedirects: false,
      connectTimeout: 10000,
      validateStatus: (status) {
        return status < 500;
      },
    );
  }

  static YJS_VPN _getInstance() {
    _instance ??= YJS_VPN._internal();
    return _instance;
  }

  ///验证VPN账号
  ///[username]VPN用户名
  ///[password]VPN密码
  Future<void> validateVPN({String username, String password}) async {
    assert(username != null);
    assert(password != null);
    Response response;
    try {
      response = await _dio.get('/dana-na/auth/url_default/welcome.cgi');
    } on DioError catch (e) {
      if (e.type == DioErrorType.CONNECT_TIMEOUT) {
        throw JustVPNError('VPN系统访问不通');
      } else {
        rethrow;
      }
    }
    var inputElements = parse(response.data).querySelectorAll('input');
    var submitData = <String, String>{};
    inputElements.forEach((element) {
      submitData
          .addAll({element.attributes['name']: element.attributes['value']});
    });
    submitData['username'] = username;
    submitData['password'] = password;
    response = await _dio.post(
      '/dana-na/auth/url_default/login.cgi',
      data: submitData,
    );
    var location = response.headers.value('location');
    if (location.contains('p=user-confirm&id=state')) {
      response = await _dio.get(location);
      var value = parse(response.data)
          .getElementById('DSIDFormDataStr')
          .attributes['value'];
      await _dio.post('/dana-na/auth/url_default/login.cgi',
          data: {'btnContinue': '继续会话', 'FormDataStr': value});
      response = await _dio.get('/dana/home/starter0.cgi?check=yes');
      await _dio.get('/dana-na/auth/logout.cgi');
      response = await _dio.post(
        '/dana-na/auth/url_default/login.cgi',
        data: submitData,
      );
    }
    var locationValue = response.headers.value('location');
    await _dio.get('/dana-na/auth/logout.cgi');
    var status = locationValue.substring(locationValue.indexOf('=') + 1);
    if (status == 'failed') {
      throw JustAccountError('VPN账号或密码错误');
    }
  }

  ///VPN登录
  ///[vpnUsername]VPN账号
  ///[vpnPassword]VPN密码
  Future<Response> vpnLogin({String vpnUsername, String vpnPassword}) async {
    assert(vpnUsername != null);
    assert(vpnPassword != null);
    Response response;
    try {
      response = await _dio.get('/dana-na/auth/url_default/welcome.cgi');
    } on DioError catch (e) {
      if (e.type == DioErrorType.CONNECT_TIMEOUT) {
        throw JustVPNError('VPN系统访问不通');
      } else {
        rethrow;
      }
    }
    var inputElements = parse(response.data).querySelectorAll('input');
    var submitData = <String, String>{};
    inputElements.forEach((element) {
      submitData
          .addAll({element.attributes['name']: element.attributes['value']});
    });
    submitData['username'] = vpnUsername;
    submitData['password'] = vpnPassword;
    response = await _dio.post('/dana-na/auth/url_default/login.cgi',
        data: submitData);
    var location = response.headers.value('location');
    if (location ==
        'https://vpn.just.edu.cn/dana-na/auth/url_default/welcome.cgi?p=failed') {
      throw JustAccountError('VPN账号或密码不正确');
    }
    if (location.contains('p=user-confirm&id=state')) {
      response = await _dio.get(location);
      var value = parse(response.data)
          .getElementById('DSIDFormDataStr')
          .attributes['value'];
      await _dio.post('/dana-na/auth/url_default/login.cgi',
          data: {'btnContinue': '继续会话', 'FormDataStr': value});
      await _dio.get('/dana/home/starter0.cgi?check=yes');
    }
    return response;
  }

  ///VPN登出
  Future<void> vpnLogout() async {
    await _dio
        .get('/dana-na/auth/logout.cgi')
        .catchError((error) => print(error));
  }

  Future<void> validate({
    String username,
    String password,
    String vpnUsername,
    String vpnPassword,
  }) async {
    assert(username != null);
    assert(password != null);
    assert(vpnUsername != null);
    assert(vpnPassword != null);
    await vpnLogin(vpnUsername: vpnUsername, vpnPassword: vpnPassword);
    var response =
        await _dio.get(Utils.convert2vpnUrl('${yjsBaseUrl}/pyxx/login.aspx'));
    var form = <String, String>{};
    parse(response.data).querySelectorAll('input').forEach((element) {
      form.addAll({element.attributes['name']: element.attributes['value']});
    });
    form['ctl00\$txtusername'] = username;
    form['ctl00\$txtpassword'] = password;
    form['ctl00\$ImageButton1.x'] = '33';
    form['ctl00\$ImageButton1.y'] = '8';
    response = await _dio.post(
        Utils.convert2vpnUrl('${yjsBaseUrl}/pyxx/login.aspx'),
        data: form);
    var location = response.headers.value('location');
    if (location == null) {
      throw JustAccountError('研究生系统账号或密码不正确');
    }
    unawaited(vpnLogout());
  }

  Future<Response> login({
    String username,
    String password,
    String vpnUsername,
    String vpnPassword,
  }) async {
    assert(username != null);
    assert(password != null);
    assert(vpnUsername != null);
    assert(vpnPassword != null);
    await vpnLogin(vpnUsername: vpnUsername, vpnPassword: vpnPassword);
    var response =
        await _dio.get(Utils.convert2vpnUrl('${yjsBaseUrl}/pyxx/login.aspx'));
    var form = <String, String>{};
    parse(response.data).querySelectorAll('input').forEach((element) {
      form.addAll({element.attributes['name']: element.attributes['value']});
    });
    form['ctl00\$txtusername'] = username;
    form['ctl00\$txtpassword'] = password;
    form['ctl00\$ImageButton1.x'] = '33';
    form['ctl00\$ImageButton1.y'] = '8';
    response = await _dio.post(
        Utils.convert2vpnUrl('${yjsBaseUrl}/pyxx/login.aspx'),
        data: form);
    var location = response.headers.value('location');
    if (location == null) {
      throw JustAccountError('研究生系统账号或密码不正确');
    }
    response =
        await _dio.get(Utils.convert2vpnUrl('${yjsBaseUrl}/pyxx/default.aspx'));
    return response;
  }

  Future<String> getCourse({
    String username,
    String password,
    String vpnUsername,
    String vpnPassword,
  }) async {
    assert(username != null);
    assert(password != null);
    assert(vpnUsername != null);
    assert(vpnPassword != null);
    await vpnLogin(vpnUsername: vpnUsername, vpnPassword: vpnPassword);
    await login(
        username: username,
        password: password,
        vpnUsername: vpnUsername,
        vpnPassword: vpnPassword);
    var response = await _dio
        .get(Utils.convert2vpnUrl('${yjsBaseUrl}/pyxx/pygl/kbcx_xs.aspx'));
    unawaited(vpnLogout());
    return response.data;
  }

  Future<String> getScore({
    String username,
    String password,
    String vpnUsername,
    String vpnPassword,
  }) async {
    assert(username != null);
    assert(password != null);
    assert(vpnUsername != null);
    assert(vpnPassword != null);
    await vpnLogin(vpnUsername: vpnUsername, vpnPassword: vpnPassword);
    await login(
        username: username,
        password: password,
        vpnUsername: vpnUsername,
        vpnPassword: vpnPassword);
    var response = await _dio
        .get(Utils.convert2vpnUrl('${yjsBaseUrl}/pyxx/grgl/xskccjcx.aspx'));
    return response.data;
  }

  Future<String> getCookie({
    String username,
    String password,
    String vpnUsername,
    String vpnPassword,
  }) async {
    assert(username != null);
    assert(password != null);
    assert(vpnUsername != null);
    assert(vpnPassword != null);
    await vpnLogin(vpnUsername: vpnUsername, vpnPassword: vpnPassword);
    var response = await login(
        username: username,
        password: password,
        vpnUsername: vpnUsername,
        vpnPassword: vpnPassword);
    String cookie = response.request.headers[HttpHeaders.cookieHeader];
    return cookie;
  }
}
