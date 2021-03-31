import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:gbk2utf8/gbk2utf8.dart' as dd;
import 'package:html/parser.dart';
import 'package:just/src/pj_course.dart';
import 'package:just/src/private_cookie_manager.dart';
import 'package:pedantic/pedantic.dart';

import 'error.dart';

class JUST {
  static const listOfHost = [
    'http://jwgl.just.edu.cn:8080/jsxsd/',
    'http://202.195.206.35:8080/jsxsd/',
    'http://202.195.206.36:8080/jsxsd/',
    'http://202.195.206.37:8080/jsxsd/',
    'http://202.195.206.38:8080/jsxsd/',
    'http://202.195.206.39:8080/jsxsd/'
  ];
  static const syBaseUrl = 'http://202.195.195.198';
  static Dio _dio;
  static final cookieJar = CookieJar();

  factory JUST() => _getInstance();

  static JUST get instance => _getInstance();
  static JUST _instance;

  JUST._internal() {
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
      baseUrl: 'http://jwgl.just.edu.cn:8080',
      followRedirects: false,
      connectTimeout: 10000,
      validateStatus: (status) {
        return status < 500;
      },
    );
  }

  static JUST _getInstance() {
    _instance ??= JUST._internal();
    return _instance;
  }

  void setHost(String host) {
    final uri = Uri.parse(host);
    _dio.options.baseUrl =
        uri.scheme + '://' + uri.host + ':' + uri.port.toString();
    print(_dio.options.baseUrl);
  }

  Future<void> validate({String username, String password}) async {
    assert(username != null);
    assert(password != null);
    final result = await Future.any(
      listOfHost.map(
        (host) => Future(() async {
          try {
            final response = await _dio.get(host);
            return response;
          } catch (e) {
            print(e);
            await Future.delayed(
                Duration(milliseconds: _dio.options.connectTimeout));
            throw JustAccountError('连接教务系统失败');
          }
        }),
      ),
    );
    setHost(result.request.uri.origin);
    var response = await _dio.post(
      '/jsxsd/xk/LoginToXk',
      data: {'USERNAME': username, 'PASSWORD': password},
    );
    var location = response.headers.value('location');
    if (location == null ||
        location != _dio.options.baseUrl + '/jsxsd/framework/xsMain.jsp' &&
            location != _dio.options.baseUrl + '/jsxsd/grsz/grsz_xgmm_beg.do') {
      throw JustAccountError('教务系统账号或密码不正确');
    }
  }

  Future<Response> jwLogin({String username, String password}) async {
    assert(username != null);
    assert(password != null);
    print('登录教务系统');
    final result = await Future.any(
      listOfHost.map(
        (host) => Future(() async {
          try {
            final response = await _dio.get(host);
            return response;
          } catch (e) {
            print(e);
            await Future.delayed(
                Duration(milliseconds: _dio.options.connectTimeout));
            throw JustAccountError('连接教务系统失败');
          }
        }),
      ),
    );
    setHost(result.request.uri.origin);
    var loginData = {'USERNAME': username, 'PASSWORD': password};
    var response = await _dio.post(
      '/jsxsd/xk/LoginToXk',
      data: loginData,
    );
    var location = response.headers.value('location');
    if (location == null ||
        location != _dio.options.baseUrl + '/jsxsd/framework/xsMain.jsp' &&
            location != _dio.options.baseUrl + '/jsxsd/grsz/grsz_xgmm_beg.do') {
      throw JustAccountError('教务系统账号或密码不正确');
    }
    return response;
  }

  Future<void> jwLogout() async {
    try {
      await _dio.get('/jsxsd/xk/LoginToXk', queryParameters: {
        'method': 'exit',
        'tktime': DateTime.now().millisecondsSinceEpoch
      });
    } catch (e) {
      print(e);
    }
  }

  Future<String> getCourse(
      {String username, String password, String kksj}) async {
    assert(username != null);
    assert(password != null);
    assert(kksj != null);
    await jwLogin(username: username, password: password);
    var response = await _dio.post('/jsxsd/xskb/xskb_list.do', data: {
      // 'cj0701id': '',
      // 'zc': '',
      // 'demo': '',
      'xnxq01id': kksj,
      // 'sfFD': '1',
    });
    return response.data;
  }

  Future<String> getScore(
      {String username, String password, String kksj, String xsfs}) async {
    assert(username != null);
    assert(password != null);
    assert(kksj != null);
    assert(xsfs != null);
    await jwLogin(username: username, password: password);
    var response = await _dio.post('/jsxsd/kscj/cjcx_list',
        data: {'kksj': kksj, 'kcxz': '', 'kcmc': '', 'xsfs': xsfs});
    return response.data;
  }

  Future<String> getScore2(
      {String username, String password, String kksj}) async {
    assert(username != null);
    assert(password != null);
    assert(kksj != null);
    await jwLogin(username: username, password: password);
    var response = await _dio.post(
      '/jsxsd/kscj/cjtd_add_left',
      data: {'kch': '', 'xnxq01id': kksj},
    );
    return response.data;
  }

  Future<Map<String, String>> getCookie(
      {String username, String password}) async {
    assert(username != null);
    assert(password != null);
    var response = await jwLogin(username: username, password: password);
    // var location = response.headers.value('location');
    response = await _dio.get('/jsxsd/framework/xsMain.jsp');
    String cookie = response.request.headers[HttpHeaders.cookieHeader];
    return {'location': response.request.uri.toString(), 'cookie': cookie};
  }

  Future<List<PJCourse>> getPjData({String username, String password}) async {
    assert(username != null);
    assert(password != null);
    await jwLogin(username: username, password: password);
    var response = await _dio.get('/jsxsd/xspj/xspj_find.do');
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
    response = await _dio.get(sy);
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
    response = await _dio.get(ll);
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
    unawaited(jwLogout());
    return list;
  }

  Future<Map<String, String>> getSyCookie(
      {String username, String password}) async {
    var response = await _dio.get('$syBaseUrl/sy/');
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
    response = await _dio.post('$syBaseUrl/sy/', data: submitData);
    var location = response.headers['location'][0];
    response =
        await _dio.get("$syBaseUrl${response.headers.value("location")}");
    String cookie = response.request.headers[HttpHeaders.cookieHeader];
    return {'location': location, 'cookie': cookie};
  }

  Future<void> validateSy({String username, String password}) async {
    var response = await _dio.get('$syBaseUrl/sy/');
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
    response = await _dio.post('$syBaseUrl/sy/', data: submitData);
    if (response.headers.value('location') == null) {
      throw JustAccountError('实验系统账号或密码错误');
    }
    response =
        await _dio.get("$syBaseUrl${response.headers.value("location")}");
  }

  Future<void> validatePe({String username, String password}) async {
    _dio.transformer = RemoveTransformer();
    var response = await _dio.post('http://tyxy.just.edu.cn/index1.asp',
        data: {'username': username, 'password': password, 'chkuser': 'true'},
        options: Options(responseDecoder: gbk2Utf8Decoder));
    _dio.transformer = DefaultTransformer();
    var info = parse(response.data).querySelector('#autonumber2 p');
    if ('密码或用户名不正确，请返回重输！' == info?.text) {
      throw JustAccountError('体育账号或密码不正确');
    }
  }

  Future<String> getSportScore({String username, String password}) async {
    _dio.transformer = RemoveTransformer();
    var resp = await _dio.post('http://tyxy.just.edu.cn/index1.asp',
        data: {'username': username, 'password': password, 'chkuser': 'true'});
    _dio.transformer = DefaultTransformer();
    resp = await _dio.get('http://tyxy.just.edu.cn/xsgl/cjcx.asp',
        options: Options(responseDecoder: gbk2Utf8Decoder));
    return resp.data;
  }

  Future<String> getSportClub({String username, String password}) async {
    _dio.transformer = RemoveTransformer();
    var resp = await _dio.post('http://tyxy.just.edu.cn/index1.asp',
        data: {'username': username, 'password': password, 'chkuser': 'true'});
    _dio.transformer = DefaultTransformer();
    resp = await _dio.get(
        'http://tyxy.just.edu.cn/zcgl/xskwcx.asp?action=jlbcx',
        options: Options(responseDecoder: gbk2Utf8Decoder));
    return resp.data;
  }

  Future<String> getSportMorning({String username, String password}) async {
    _dio.transformer = RemoveTransformer();
    var resp = await _dio.post('http://tyxy.just.edu.cn/index1.asp',
        data: {'username': username, 'password': password, 'chkuser': 'true'});
    _dio.transformer = DefaultTransformer();
    resp = await _dio.get('http://tyxy.just.edu.cn/zcgl/xskwcx.asp?action=zccx',
        options: Options(responseDecoder: gbk2Utf8Decoder));
    return resp.data;
  }

  Future<Map<String, String>> getSportMorningCookie(
      {String username, String password}) async {
    _dio.transformer = RemoveTransformer();
    var resp = await _dio.post('http://tyxy.just.edu.cn/index1.asp',
        data: {'username': username, 'password': password, 'chkuser': 'true'});
    _dio.transformer = DefaultTransformer();
    resp = await _dio.get('http://tyxy.just.edu.cn/zcgl/xskwcx.asp?action=zccx',
        options: Options(responseDecoder: gbk2Utf8Decoder));
    String cookie = resp.request.headers[HttpHeaders.cookieHeader];
    return {'location': resp.request.uri.toString(), 'cookie': cookie};
  }

  Future<Map<String, String>> getSportClubCookie(
      {String username, String password}) async {
    _dio.transformer = RemoveTransformer();
    var resp = await _dio.post('http://tyxy.just.edu.cn/index1.asp',
        data: {'username': username, 'password': password, 'chkuser': 'true'});
    _dio.transformer = DefaultTransformer();
    resp = await _dio.get(
        'http://tyxy.just.edu.cn/zcgl/xskwcx.asp?action=jlbcx',
        options: Options(responseDecoder: gbk2Utf8Decoder));
    String cookie = resp.request.headers[HttpHeaders.cookieHeader];
    return {'location': resp.request.uri.toString(), 'cookie': cookie};
  }

  Future<bool> resetPassword({String user, String idCard}) async {
    var response = await _dio.post('/jsxsd/system/resetPasswd.do',
        data: {'account': user, 'sfzjh': idCard});
    var regExp = RegExp(r"alert\('(.*)'\)");
    var value = regExp.firstMatch(response.data)?.group(1);
    if (value != '密码已重置为身份证号的后六位') {
      return false;
    } else {
      return true;
    }
  }

  Future<bool> changePassword(
      {String account, String oldPassword, String newPassword}) async {
    var flag = true;
    await validate(username: account, password: oldPassword);
    var form = {
      'id': '',
      'oldpassword': oldPassword,
      'password1': newPassword,
      'password2': newPassword,
      'button1': '保存',
      'upt': '1'
    };
    await _dio.post('/jsxsd/grsz/grsz_xgmm_beg.do', data: form);
    try {
      await validate(username: account, password: newPassword);
    } catch (e) {
      flag = false;
    }
    return flag;
  }
}

class RemoveTransformer extends DefaultTransformer {
  @override
  Future transformResponse(
      RequestOptions options, ResponseBody response) async {
    var cookies = response.headers['set-cookie'];
    cookies?.removeLast();
    return super.transformResponse(options, response);
  }
}

ResponseDecoder gbk2Utf8Decoder = (List<int> responseBytes,
    RequestOptions options, ResponseBody responseBody) {
  var rs = dd.gbk2unicode(responseBytes);
  return utf8.decode(dd.unicode2utf8(rs));
};
