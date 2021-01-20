import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart';
import 'package:just/src/pj_course.dart';
import 'package:just/src/private_cookie_manager.dart';

import 'error.dart';

class VPN2 {
  static Dio _dio;
  static final cookieJar = CookieJar();

  factory VPN2() => _getInstance();

  static VPN2 get instance => _getInstance();
  static VPN2 _instance;
  static const postUrl =
      'https://cas.v.just.edu.cn/cas/login?service=https://ids.v.just.edu.cn%2F';
  static const homeUrl = 'https://ids.v.just.edu.cn/_s2/students_sy/main.psp';
  static const logoutUrl =
      'https://cas.v.just.edu.cn/cas/logout?service=http://my.just.edu.cn%2F';
  static const jwBaseUrl =
      'https://54a22a8aad6e5ffd02eb5278924100b5cas.v.just.edu.cn';
  static const experimentUrl = 'https://sjjx.v.just.edu.cn/sy';

  VPN2._internal() {
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

  static VPN2 _getInstance() {
    _instance ??= VPN2._internal();
    return _instance;
  }

  // String getCookie(Response response) {
  //   var cookies = response.headers[HttpHeaders.setCookieHeader];
  //   return cookies.join('; ');
  // }
  //
  // Options setCookie(String cookie) {
  //   return Options(headers: {HttpHeaders.cookieHeader: cookie});
  // }

  Future<void> validate({String username, String password}) async {
    assert(username != null);
    assert(password != null);
    var response = await _dio.get(postUrl);
    var form = <String, String>{};
    parse(response.data).querySelectorAll('input').forEach((element) {
      form.addAll({element.attributes['name']: element.attributes['value']});
    });
    form['username'] = username;
    form['password'] = password;
    form['rememberUsername'] = 'on';
    form['rememberPassword'] = 'on';
    form['loginType'] = '1';
    form.remove('smscode');
    response = await _dio.post(
      postUrl,
      data: form,
    );
    var location = response.headers['location'];
    if (location == null) {
      throw JustAccountError('服务大厅账号或密码错误');
    }
    response = await _dio.get(
      location[0],
    );
    response = await _dio.get(
      homeUrl,
    );
    response = await _dio.get('$jwBaseUrl:4443/sso.jsp');
  }

  Future<Response> vpnLogin({String username, String password}) async {
    assert(username != null);
    assert(password != null);
    var response = await _dio.get(postUrl);
    if (response.statusCode == 302) {
      while (response.statusCode == 302) {
        var location = response.headers['location'][0];
        print('location $location');
        response = await _dio.get(location);
      }
      print('302 redirect');
      return response;
    }
    print('get vpn2 login page');
    var form = <String, String>{};
    parse(response.data).querySelectorAll('input').forEach((element) {
      form.addAll({element.attributes['name']: element.attributes['value']});
    });
    form['username'] = username;
    form['password'] = password;
    form['rememberUsername'] = 'on';
    form['rememberPassword'] = 'on';
    form['loginType'] = '1';
    form.remove('smscode');
    response = await _dio.post(postUrl, data: form);
    var location = response.headers['location'];
    if (location == null) {
      throw JustAccountError('服务大厅账号或密码不正确');
    }
    response = await _dio.get(
      location[0],
    );
    return response;
    // var location2 = response.headers['location'][0].split(';')[1].toUpperCase();
    // cookieJar.saveFromResponse(Uri.parse('https://my.v.just.edu.cn:4443'),
    //     [Cookie.fromSetCookieValue(location2)]);
    // cookieJar.saveFromResponse(
    //     Uri.parse(
    //         'https://54a22a8aad6e5ffd02eb5278924100b5my.v.just.edu.cn:4443'),
    //     [Cookie.fromSetCookieValue(location2)]);
  }

  Future<void> vpnLogout() async {
    await _dio.get(logoutUrl);
  }

  Future<Response> jwLogin({String username, String password}) async {
    assert(username != null);
    assert(password != null);
    await vpnLogin(username: username, password: password);
    // var response = await _dio.get(
    //   'https://cas.v.just.edu.cn/cas/login?service=http://jwgl.just.edu.cn:8080%2Fsso.jsp',
    // );
    var response = await _dio.get(
      'https://54a22a8aad6e5ffd02eb5278924100b5cas.v.just.edu.cn/sso.jsp',
    );
    print(response.headers);
    var location3 = response.headers['location'][0];
    response = await _dio.get(location3);
    print(response.headers);
    response = await _dio.get('$jwBaseUrl/jsxsd/framework/xsMain.jsp');
    return response;
  }

  Future<String> getScore(
      String username, String password, String kksj, String xsfs) async {
    assert(username != null);
    assert(password != null);
    assert(kksj != null);
    assert(xsfs != null);
    await jwLogin(username: username, password: password);
    var response = await _dio.post('$jwBaseUrl/jsxsd/kscj/cjcx_list',
        data: {'kksj': kksj, 'kcxz': '', 'kcmc': '', 'xsfs': xsfs});
    return response.data;
  }

  Future<String> getScore2(
      String username, String password, String kksj) async {
    assert(username != null);
    assert(password != null);
    assert(kksj != null);
    await jwLogin(username: username, password: password);
    var response = await _dio.post(
      '$jwBaseUrl/jsxsd/kscj/cjtd_add_left',
      data: {'kch': '', 'xnxq01id': kksj},
    );
    return response.data;
  }

  Future<String> getCourse(
      String username, String password, String kksj) async {
    assert(username != null);
    assert(password != null);
    assert(kksj != null);
    await jwLogin(username: username, password: password);
    var response = await _dio.post('$jwBaseUrl/jsxsd/xskb/xskb_list.do', data: {
      // 'cj0701id': '',
      // 'zc': '',
      // 'demo': '',
      'xnxq01id': kksj,
      // 'sfFD': 1
    });
    return response.data;
  }

  Future<String> getCookie({String username, String password}) async {
    assert(username != null);
    assert(password != null);
    var response = await jwLogin(username: username, password: password);
    return response.request.headers[HttpHeaders.cookieHeader];
  }

  Future<String> getVPNCookie({String username, String password}) async {
    assert(username != null);
    assert(password != null);
    await vpnLogin(username: username, password: password);
    var response = await _dio.get(homeUrl);
    return response.request.headers[HttpHeaders.cookieHeader];
  }

  Future<List<PJCourse>> getPjData({String username, String password}) async {
    assert(username != null);
    assert(password != null);
    await jwLogin(username: username, password: password);
    var response = await _dio.get('$jwBaseUrl/jsxsd/xspj/xspj_find.do');
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
    var all = result[2].attributes['href'];
    response = await _dio.get(jwBaseUrl + sy);
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
    response = await _dio.get(jwBaseUrl + ll);
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
    return list;
  }

  Future<Map<String, String>> getSyCookie(
      {String username,
      String password,
      String syUsername,
      String syPassword}) async {
    assert(username != null);
    assert(password != null);
    assert(syUsername != null);
    assert(syPassword != null);
    await vpnLogin(username: username, password: password);
    var response = await _dio.get('$experimentUrl/index.aspx');
    String data = response.data;
    var inputElements = parse(data).querySelectorAll('input');
    var submitData = <String, String>{};
    inputElements.forEach((element) {
      submitData
          .addAll({element.attributes['name']: element.attributes['value']});
    });
    submitData['Login1\$UserName'] = syUsername;
    submitData['Login1\$PassWord'] = syPassword;
    submitData['Login1\$ImageButton1.x'] = '26';
    submitData['Login1\$ImageButton1.y'] = '9';
    response = await _dio.post('$experimentUrl/index.aspx', data: submitData);
    var location = response.headers.value('location');
    response =
        await _dio.get("$experimentUrl${response.headers.value("location")}");
    String cookie = response.request.headers[HttpHeaders.cookieHeader];
    return {'location': location, 'cookie': cookie};
  }

  Future<void> validateSy(
      {String username,
      String password,
      String syUsername,
      String syPassword}) async {
    assert(username != null);
    assert(password != null);
    assert(syUsername != null);
    assert(syPassword != null);
    await vpnLogin(username: username, password: password);
    var response = await _dio.get('$experimentUrl/index.aspx');
    String data = response.data;
    var inputElements = parse(data).querySelectorAll('input');
    var submitData = <String, String>{};
    inputElements.forEach((element) {
      submitData
          .addAll({element.attributes['name']: element.attributes['value']});
    });
    submitData['Login1\$UserName'] = syUsername;
    submitData['Login1\$PassWord'] = syPassword;
    submitData['Login1\$ImageButton1.x'] = '26';
    submitData['Login1\$ImageButton1.y'] = '9';
    response = await _dio.post('$experimentUrl/index.aspx', data: submitData);
    if (response.headers.value('location') == null) {
      throw JustAccountError('实验系统账号或密码错误');
    }
    response = await _dio
        .get("https://vpn.just.edu.cn${response.headers.value("location")}");
  }
}
