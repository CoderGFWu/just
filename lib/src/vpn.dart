import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart';
import 'package:just/src/pj_course.dart';
import 'package:just/src/private_cookie_manager.dart';
import 'package:gbk2utf8/gbk2utf8.dart' as dd;
import 'error.dart';

class VPN {
  static Dio _dio;
  static const String vpnWelcomeUrl =
      'https://vpn.just.edu.cn/dana-na/auth/url_default/welcome.cgi';
  static const vpnLoginUrl =
      'https://vpn.just.edu.cn/dana-na/auth/url_default/login.cgi';
  static const String vpnLogoutUrl =
      'https://vpn.just.edu.cn/dana-na/auth/logout.cgi';
  static const String jwVpnLoginPostUrl =
      'https://vpn.just.edu.cn/jsxsd/xk/,DanaInfo=jwgl.just.edu.cn,Port=8080+LoginToXk';
  static const String jwVpnHomeUrl =
      'https://vpn.just.edu.cn/jsxsd/framework/,DanaInfo=jwgl.just.edu.cn,Port=8080+xsMain.jsp';
  static const String jwVpnSetPasswordUrl =
      'https://vpn.just.edu.cn/jsxsd/grsz/,DanaInfo=jwgl.just.edu.cn,Port=8080+grsz_xgmm_beg.do';
  static const String jwVpnScoreUrl =
      'https://vpn.just.edu.cn/jsxsd/kscj/,DanaInfo=jwgl.just.edu.cn,Port=8080+cjcx_list';
  static const experimentVpnLoginUrl =
      'https://vpn.just.edu.cn/sy/,DanaInfo=202.195.195.198+';
  static const String jwVpnCourseUrl =
      'https://vpn.just.edu.cn/jsxsd/xskb/,DanaInfo=jwgl.just.edu.cn,Port=8080+xskb_list.do';
  static const String peVpnLoginUrl =
      'https://vpn.just.edu.cn/,DanaInfo=tyxy.just.edu.cn+index1.asp';
  static final cookieJar = CookieJar();

  factory VPN() => _getInstance();

  static VPN get instance => _getInstance();
  static VPN _instance;

  VPN._internal() {
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
      followRedirects: false,
      connectTimeout: 20000,
      validateStatus: (status) {
        return status < 500;
      },
    );
  }

  static VPN _getInstance() {
    _instance ??= VPN._internal();
    return _instance;
  }

//验证VPN账号
  Future<void> validateVPN({String username, String password}) async {
    assert(username != null);
    assert(password != null);
    Response response;
    try {
      response = await _dio.get(vpnWelcomeUrl);
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
      vpnLoginUrl,
      data: submitData,
    );
    var location = response.headers.value('location');
    if (location.contains('p=user-confirm&id=state')) {
      response = await _dio.get(location);
      var value = parse(response.data)
          .getElementById('DSIDFormDataStr')
          .attributes['value'];
      await _dio.post(vpnLoginUrl,
          data: {'btnContinue': '继续会话', 'FormDataStr': value});
      response = await _dio
          .get('https://vpn.just.edu.cn/dana/home/starter0.cgi?check=yes');
      await _dio.get(vpnLogoutUrl);
      response = await _dio.post(
        vpnLoginUrl,
        data: submitData,
      );
    }
    var locationValue = response.headers.value('location');
    await _dio.get(vpnLogoutUrl);
    var status = locationValue.substring(locationValue.indexOf('=') + 1);
    if (status == 'failed') {
      throw JustAccountError('VPN账号或密码错误');
    }
  }

//VPN登录
  Future<Response> vpnLogin({String vpnUsername, String vpnPassword}) async {
    assert(vpnUsername != null);
    assert(vpnPassword != null);
    Response response;
    try {
      response = await _dio.get(vpnWelcomeUrl);
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
    response = await _dio.post(vpnLoginUrl, data: submitData);
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
      await _dio.post(vpnLoginUrl,
          data: {'btnContinue': '继续会话', 'FormDataStr': value});
      await _dio
          .get('https://vpn.just.edu.cn/dana/home/starter0.cgi?check=yes');
    }
    return response;
  }

//VPN登出
  Future<void> vpnLogout() async {
    await _dio.get(vpnLogoutUrl).catchError((error) => print(error));
  }

//验证教务系统账号
  Future<void> validateJw(
      {String username,
      String password,
      String vpnUsername,
      String vpnPassword}) async {
    assert(username != null);
    assert(password != null);
    assert(vpnUsername != null);
    assert(vpnPassword != null);
    await vpnLogin(vpnUsername: vpnUsername, vpnPassword: vpnPassword);
    var loginData = {'USERNAME': username, 'PASSWORD': password};
    var response = await _dio.post(
      jwVpnLoginPostUrl,
      data: loginData,
    );
    var location = response.headers.value('location');
    if (location == 'https://vpn.just.edu.cn/dana-na/auth/welcome.cgi') {
      throw JustVPNError('教务系统访问不通');
    }
    if (location != jwVpnHomeUrl && location != jwVpnSetPasswordUrl) {
      throw JustAccountError('教务系统账号或密码不正确');
    }
    vpnLogout();
    return response;
  }

  Future<void> validateSy(
      {String username,
      String password,
      String vpnUsername,
      String vpnPassword}) async {
    assert(username != null);
    assert(password != null);
    assert(vpnUsername != null);
    assert(vpnPassword != null);
    await vpnLogin(vpnUsername: vpnUsername, vpnPassword: vpnPassword);
    var response = await _dio.get(experimentVpnLoginUrl);
    String data = response.data;
    var inputElements = parse(data).querySelectorAll('input');
    var submitData = <String, String>{};
    inputElements.forEach((element) {
      submitData
          .addAll({element.attributes['name']: element.attributes['value']});
    });
    submitData['Login1\$UserName'] = username;
    submitData['Login1\$PassWord'] = password;
    submitData['Login1\$ImageButton1.x'] = '26';
    submitData['Login1\$ImageButton1.y'] = '9';
    response = await _dio.post(experimentVpnLoginUrl, data: submitData);
    if (response.headers.value('location') == null) {
      throw JustAccountError('实验系统账号或密码错误');
    }
    response = await _dio
        .get("https://vpn.just.edu.cn${response.headers.value("location")}");
    vpnLogout();
  }

  Future<void> validatePe(
      {String username,
      String password,
      String vpnUsername,
      String vpnPassword}) async {
    assert(username != null);
    assert(password != null);
    assert(vpnUsername != null);
    assert(vpnPassword != null);
    await vpnLogin(vpnUsername: vpnUsername, vpnPassword: vpnPassword);
    var response = await _dio.post(peVpnLoginUrl,
        data: {'username': username, 'password': password, 'chkuser': 'true'},
        options: Options(responseDecoder: gbk2Utf8Decoder));
    var info = parse(response.data).querySelector('#autonumber2 p');
    if ('密码或用户名不正确，请返回重输！' == info?.text) {
      throw JustAccountError('体育账号或密码不正确');
    }
  }

//教务系统登录
  Future<Response> jwVpnLogin(
      {String username,
      String password,
      String vpnUsername,
      String vpnPassword}) async {
    assert(username != null);
    assert(password != null);
    assert(vpnUsername != null);
    assert(vpnPassword != null);
    await vpnLogin(vpnUsername: vpnUsername, vpnPassword: vpnPassword);
    var loginData = {'USERNAME': username, 'PASSWORD': password};
    var response = await _dio.post(
      jwVpnLoginPostUrl,
      data: loginData,
    );
    var location = response.headers.value('location');
    if (location == 'https://vpn.just.edu.cn/dana-na/auth/welcome.cgi') {
      throw JustVPNError('教务系统访问不通');
    }
    if (location != jwVpnHomeUrl && location != jwVpnSetPasswordUrl) {
      throw JustAccountError('教务系统账号或密码不正确');
    }
    return response;
  }

//教务系统登出
  Future<void> jwVpnLogout() async {
    try {
      await _dio.get(jwVpnLoginPostUrl, queryParameters: {
        'method': 'exit',
        'tktime': DateTime.now().millisecondsSinceEpoch
      });
    } catch (e) {
      print(e);
    }
  }

//获取成绩
  Future<String> getScore(
      {String username,
      String password,
      String vpnUsername,
      String vpnPassword,
      String kksj,
      String xsfs}) async {
    assert(username != null);
    assert(password != null);
    assert(vpnUsername != null);
    assert(vpnPassword != null);
    assert(kksj != null);
    assert(xsfs != null);
    await jwVpnLogin(
        username: username,
        password: password,
        vpnUsername: vpnUsername,
        vpnPassword: vpnPassword);
    var response = await _dio.post(jwVpnScoreUrl,
        data: {'kksj': kksj, 'kcxz': '', 'kcmc': '', 'xsfs': xsfs});
    jwVpnLogout().then((value) => vpnLogout());
    return response.data;
  }

//获取成绩替代的成绩
  Future<String> getScore2(
      {String username,
      String password,
      String vpnUsername,
      String vpnPassword,
      String kksj}) async {
    assert(username != null);
    assert(password != null);
    assert(vpnUsername != null);
    assert(vpnPassword != null);
    assert(kksj != null);
    await jwVpnLogin(
        username: username,
        password: password,
        vpnUsername: vpnUsername,
        vpnPassword: vpnPassword);
    var data = {'kch': '', 'xnxq01id': kksj};
    var response = await _dio.post(
      'https://vpn.just.edu.cn/jsxsd/kscj/,DanaInfo=jwgl.just.edu.cn,Port=8080+cjtd_add_left',
      data: data,
    );
    jwVpnLogout().then((value) => vpnLogout());
    return response.data;
  }

  Future<String> getSportScore(
      {String username,
      String password,
      String vpnUsername,
      String vpnPassword}) async {
    assert(username != null);
    assert(password != null);
    assert(vpnUsername != null);
    assert(vpnPassword != null);
    await vpnLogin(vpnUsername: vpnUsername, vpnPassword: vpnPassword);
    var response = await _dio.post(peVpnLoginUrl,
        data: {'username': username, 'password': password, 'chkuser': 'true'});
    response = await _dio.get(
        'https://vpn.just.edu.cn/xsgl/,DanaInfo=tyxy.just.edu.cn+cjcx.asp',
        options: Options(responseDecoder: gbk2Utf8Decoder));
    var location = response.headers['location'];
    if (location != null &&
        location.isNotEmpty &&
        location[0] == 'https://vpn.just.edu.cn/dana-na/auth/welcome.cgi') {
      throw JustVPNError('VPN系统访问不通');
    }
    vpnLogout();
    return response.data;
  }

//获取实验系统的Cookie
  Future<Map<String, String>> getSyCookie(
      {String username,
      String password,
      String vpnUsername,
      String vpnPassword}) async {
    assert(username != null);
    assert(password != null);
    assert(vpnUsername != null);
    assert(vpnPassword != null);
    await vpnLogin(vpnUsername: vpnUsername, vpnPassword: vpnPassword);
    var response = await _dio.get(experimentVpnLoginUrl);
    String data = response.data;
    var inputElements = parse(data).querySelectorAll('input');
    var submitData = <String, String>{};
    inputElements.forEach((element) {
      submitData
          .addAll({element.attributes['name']: element.attributes['value']});
    });
    submitData['Login1\$UserName'] = username;
    submitData['Login1\$PassWord'] = password;
    submitData['Login1\$ImageButton1.x'] = '26';
    submitData['Login1\$ImageButton1.y'] = '9';
    response = await _dio.post(experimentVpnLoginUrl, data: submitData);
    var location = response.headers['location'][0];
    response = await _dio
        .get("https://vpn.just.edu.cn${response.headers.value("location")}");
    String cookie = response.request.headers[HttpHeaders.cookieHeader];
    return {'location': response.request.uri.toString(), 'cookie': cookie};
  }

  Future<String> getCookie(
      {String username,
      String password,
      String vpnUsername,
      String vpnPassword}) async {
    assert(username != null);
    assert(password != null);
    assert(vpnUsername != null);
    assert(vpnPassword != null);
    var response = await jwVpnLogin(
        username: username,
        password: password,
        vpnUsername: vpnUsername,
        vpnPassword: vpnPassword);
    String cookie = response.request.headers[HttpHeaders.cookieHeader];
    return cookie;
  }

  Future<String> getCourse(
      {String username,
      String password,
      String vpnUsername,
      String vpnPassword,
      String kksj}) async {
    assert(username != null);
    assert(password != null);
    assert(vpnUsername != null);
    assert(vpnPassword != null);
    assert(kksj != null);
    await jwVpnLogin(
        username: username,
        password: password,
        vpnUsername: vpnUsername,
        vpnPassword: vpnPassword);
    var response = await _dio.post(jwVpnCourseUrl, data: {
      // 'cj0701id': '',
      // 'zc': '',
      // 'demo': '',
      'xnxq01id': kksj,
      // 'sfFD': '1',
    });
    jwVpnLogout().then((value) => vpnLogout());
    return response.data;
  }

  Future<List<PJCourse>> getPjData(
      {String username,
      String password,
      String vpnUsername,
      String vpnPassword}) async {
    assert(username != null);
    assert(password != null);
    assert(vpnUsername != null);
    assert(vpnPassword != null);
    await jwVpnLogin(
        username: username,
        password: password,
        vpnUsername: vpnUsername,
        vpnPassword: vpnPassword);
    var response = await _dio.get(
        'https://vpn.just.edu.cn/jsxsd/xspj/,DanaInfo=jwgl.just.edu.cn,Port=8080+xspj_find.do');
    var result = parse(response.data)
        .querySelector('#Form1 tbody')
        .children[1]
        .querySelectorAll('a');
    var list = <PJCourse>[];
    //实验教学评价链接
    var sy = result[0].attributes['href'];
    //理论教学评价链接
    var ll = result[1].attributes['href'];
    //全部
    String all = result[2].attributes['href'];
    response = await _dio.get('https://vpn.just.edu.cn' + sy);
    var syData =
        parse(response.data).querySelector('#dataList').querySelectorAll('tr');
    syData.removeAt(0);
    syData.forEach((element) {
      var l = element.querySelectorAll('td');
      var regExp = RegExp(r"'(.*)'");
      var m = regExp.firstMatch(l[7].querySelector('a').attributes['href']);
      list.add(PJCourse(l[0].text, l[1].text, l[2].text, l[3].text, l[4].text,
          l[5].text, l[6].text, m.group(1)));
    });
    response = await _dio.get('https://vpn.just.edu.cn' + ll);
    var llData =
        parse(response.data).querySelector('#dataList').querySelectorAll('tr');
    llData.removeAt(0);
    llData.forEach((element) {
      var l = element.querySelectorAll('td');
      var regExp = RegExp(r"'(.*)'");
      var m = regExp.firstMatch(l[7].querySelector('a').attributes['href']);
      list.add(PJCourse(l[0].text, l[1].text, l[2].text, l[3].text, l[4].text,
          l[5].text, l[6].text, m.group(1)));
    });
    jwVpnLogout().then((value) => vpnLogout());
    return list;
  }

  ResponseDecoder gbk2Utf8Decoder = (List<int> responseBytes,
      RequestOptions options, ResponseBody responseBody) {
    var rs = dd.gbk2unicode(responseBytes);
    return utf8.decode(dd.unicode2utf8(rs));
  };
}
