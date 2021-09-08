import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:gbk2utf8/gbk2utf8.dart' as dd;
import 'package:html/parser.dart';
import 'package:just/src/pj_course.dart';
import 'package:pedantic/pedantic.dart';

import 'error.dart';

class JUST {
  static const listOfHost = [
    // 'http://jwgl.just.edu.cn:8080',
    'http://202.195.206.35:8080',
    'http://202.195.206.36:8080',
    'http://202.195.206.37:8080',
    'http://202.195.206.38:8080',
    'http://202.195.206.39:8080'
  ];
  static const syBaseUrl = 'http://202.195.195.198';
  static late Dio _dio;
  static final cookieJar = CookieJar();

  factory JUST() => _getInstance();

  static JUST get instance => _getInstance();
  static JUST? _instance;

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

    var cookieManager = CookieManager(cookieJar);
    _dio.interceptors.add(cookieManager);
    _dio.options = BaseOptions(
      contentType: 'application/x-www-form-urlencoded',
      baseUrl: 'http://jwgl.just.edu.cn:8080',
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

  static JUST _getInstance() {
    _instance ??= JUST._internal();
    return _instance!;
  }

  void setHost(String host) {
    final uri = Uri.parse(host);
    _dio.options.baseUrl =
        uri.scheme + '://' + uri.host + ':' + uri.port.toString();
    print(_dio.options.baseUrl);
  }

  ///优先使用 http://jwgl.just.edu.cn:8080进行验证
  ///此地址验证成功直接返回，验证失败尝试其它host
  Future<void> validate(
      {required String username, required String password}) async {
    try {
      print('try host: default');
      await _dio.get('/jsxsd');
      var response = await _dio.post(
        '/jsxsd/xk/LoginToXk',
        data: {'USERNAME': username, 'PASSWORD': password},
      );
      var location = response.headers.value('location');
      print('location: $location');
      if (location == null ||
          location !=
                  'http://jwgl.just.edu.cn:8080/jsxsd/framework/xsMain.jsp' &&
              location !=
                  'http://jwgl.just.edu.cn:8080/jsxsd/grsz/grsz_xgmm_beg.do') {
        throw JustAccountError('教务系统账号或密码不正确');
      }
      return;
    } catch (e) {
      print('默认host登录失败: $e');
    }
    await Future.any(listOfHost.map((host) => Future(() async {
          try {
            print('try host: $host');
            await _dio.get('$host/jsxsd');
            var response = await _dio.post(
              '$host/jsxsd/xk/LoginToXk',
              data: {'USERNAME': username, 'PASSWORD': password},
            );
            var location = response.headers.value('location');
            print('location: $location');
            if (location == null ||
                location != '$host/jsxsd/framework/xsMain.jsp' &&
                    location != '$host/jsxsd/grsz/grsz_xgmm_beg.do') {
              throw JustAccountError('教务系统账号或密码不正确');
            }
          } on JustAccountError {
            rethrow;
          } catch (e) {
            await Future.delayed(
                Duration(milliseconds: _dio.options.connectTimeout));
            rethrow;
          }
        })));
  }

  Future<Response> jwLogin(
      {required String username, required String password}) async {
    print('登录教务系统');
    try {
      print('try host: default');
      await _dio.get('/jsxsd');
      var response = await _dio.post(
        '/jsxsd/xk/LoginToXk',
        data: {'USERNAME': username, 'PASSWORD': password},
      );
      var location = response.headers.value('location');
      print('location: $location');
      if (location == null ||
          location !=
                  'http://jwgl.just.edu.cn:8080/jsxsd/framework/xsMain.jsp' &&
              location !=
                  'http://jwgl.just.edu.cn:8080/jsxsd/grsz/grsz_xgmm_beg.do') {
        throw JustAccountError('教务系统账号或密码不正确');
      }
      return response;
    } catch (e) {
      print('默认host登录失败: $e');
    }
    var response = await Future.any(listOfHost.map((host) => Future(() async {
          try {
            print('try host: $host');
            await _dio.get('$host/jsxsd');
            var response = await _dio.post(
              '$host/jsxsd/xk/LoginToXk',
              data: {'USERNAME': username, 'PASSWORD': password},
            );
            var location = response.headers.value('location');
            print('location: $location');
            if (location == null ||
                location != '$host/jsxsd/framework/xsMain.jsp' &&
                    location != '$host/jsxsd/grsz/grsz_xgmm_beg.do') {
              throw JustAccountError('教务系统账号或密码不正确');
            }
            setHost(host);
            return response;
          } on JustAccountError {
            rethrow;
          } catch (e) {
            await Future.delayed(
                Duration(milliseconds: _dio.options.connectTimeout));
            rethrow;
          }
        })));
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
      {required String username,
      required String password,
      required String kksj}) async {
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
      {required String username,
      required String password,
      required String kksj,
      required String xsfs}) async {
    await jwLogin(username: username, password: password);
    var response = await _dio.post('/jsxsd/kscj/cjcx_list',
        data: {'kksj': kksj, 'kcxz': '', 'kcmc': '', 'xsfs': xsfs});
    return response.data;
  }

  Future<String> getScore2(
      {required String username,
      required String password,
      required String kksj}) async {
    await jwLogin(username: username, password: password);
    var response = await _dio.post(
      '/jsxsd/kscj/cjtd_add_left',
      data: {'kch': '', 'xnxq01id': kksj},
    );
    return response.data;
  }

  Future<Map<String, String>> getCookie(
      {required String username, required String password}) async {
    var response = await jwLogin(username: username, password: password);
    response = await _dio.get('/jsxsd/framework/xsMain.jsp');
    var cookies = await cookieJar.loadForRequest(response.realUri);
    var cookieString =
        cookies.map((cookie) => '${cookie.name}=${cookie.value}').join(' ');
    return {'location': response.realUri.toString(), 'cookie': cookieString};
  }

  Future<List<PJCourse>> getPjData(
      {required String username, required String password}) async {
    await jwLogin(username: username, password: password);
    var response = await _dio.get('/jsxsd/xspj/xspj_find.do');
    var result = parse(response.data)
        .querySelector('#Form1 tbody')
        ?.children[1]
        .querySelectorAll('a');
    if (result == null) {
      return [];
    }
    var list = <PJCourse>[];
    //实验教学评价链接
    var sy = result[0].attributes['href'] ?? '';
    //理论教学评价链接
    var ll = result[1].attributes['href'] ?? '';
    //全部
    var all = result[2].attributes['href'] ?? '';
    response = await _dio.get(sy);
    var syData =
        parse(response.data).querySelector('#dataList')?.querySelectorAll('tr');
    syData?.removeAt(0);
    syData?.forEach((element) {
      var l = element.querySelectorAll('td');
      var regExp = RegExp(r"'(.*)'");
      var m =
          regExp.firstMatch(l[7].querySelector('a')?.attributes['href'] ?? '');
      list.add(PJCourse(l[0].text, l[1].text, l[2].text, l[3].text, l[4].text,
          l[5].text, l[6].text, m?.group(1) ?? ''));
    });
    response = await _dio.get(ll);
    var llData =
        parse(response.data).querySelector('#dataList')?.querySelectorAll('tr');
    llData?.removeAt(0);
    llData?.forEach((element) {
      var l = element.querySelectorAll('td');
      var regExp = RegExp(r"'(.*)'");
      var m =
          regExp.firstMatch(l[7].querySelector('a')?.attributes['href'] ?? '');
      list.add(PJCourse(l[0].text, l[1].text, l[2].text, l[3].text, l[4].text,
          l[5].text, l[6].text, m?.group(1) ?? ''));
    });
    unawaited(jwLogout());
    return list;
  }

  Future<Map<String, String>> getSyCookie(
      {required String username, required String password}) async {
    var response = await _dio.get('$syBaseUrl/sy/');
    String data = response.data;
    var inputElements = parse(data).querySelectorAll('input');
    var submitData = <String, String>{};
    inputElements.forEach((element) {
      submitData.addAll({
        element.attributes['name'] ?? '': element.attributes['value'] ?? ''
      });
    });
    submitData['Login1\$UserName'] = username;
    submitData['Login1\$PassWord'] = password;
    submitData['Login1\$ImageButton1.x'] = '26';
    submitData['Login1\$ImageButton1.y'] = '9';
    response = await _dio.post('$syBaseUrl/sy/', data: submitData);
    var location = response.headers['location']?[0];
    response =
        await _dio.get("$syBaseUrl${response.headers.value("location")}");
    var cookies = await cookieJar.loadForRequest(response.realUri);
    var cookieString =
        cookies.map((cookie) => '${cookie.name}=${cookie.value}').join(' ');
    return {'location': location ?? '', 'cookie': cookieString};
  }

  Future<void> validateSy(
      {required String username, required String password}) async {
    var response = await _dio.get('$syBaseUrl/sy/');
    String data = response.data;
    var inputElements = parse(data).querySelectorAll('input');
    var submitData = <String, String>{};
    inputElements.forEach((element) {
      submitData.addAll({
        element.attributes['name'] ?? '': element.attributes['value'] ?? ''
      });
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

  Future<void> validatePe(
      {required String username, required String password}) async {
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

  Future<String> getSportScore(
      {required String username, required String password}) async {
    _dio.transformer = RemoveTransformer();
    var resp = await _dio.post('http://tyxy.just.edu.cn/index1.asp',
        data: {'username': username, 'password': password, 'chkuser': 'true'});
    _dio.transformer = DefaultTransformer();
    resp = await _dio.get('http://tyxy.just.edu.cn/xsgl/cjcx.asp',
        options: Options(responseDecoder: gbk2Utf8Decoder));
    return resp.data;
  }

  Future<String> getSportClub(
      {required String username, required String password}) async {
    _dio.transformer = RemoveTransformer();
    var resp = await _dio.post('http://tyxy.just.edu.cn/index1.asp',
        data: {'username': username, 'password': password, 'chkuser': 'true'});
    _dio.transformer = DefaultTransformer();
    resp = await _dio.get(
        'http://tyxy.just.edu.cn/zcgl/xskwcx.asp?action=jlbcx',
        options: Options(responseDecoder: gbk2Utf8Decoder));
    return resp.data;
  }

  Future<String> getSportMorning(
      {required String username, required String password}) async {
    _dio.transformer = RemoveTransformer();
    var resp = await _dio.post('http://tyxy.just.edu.cn/index1.asp',
        data: {'username': username, 'password': password, 'chkuser': 'true'});
    _dio.transformer = DefaultTransformer();
    resp = await _dio.get('http://tyxy.just.edu.cn/zcgl/xskwcx.asp?action=zccx',
        options: Options(responseDecoder: gbk2Utf8Decoder));
    return resp.data;
  }

  Future<Map<String, String>> getSportMorningCookie(
      {required String username, required String password}) async {
    _dio.transformer = RemoveTransformer();
    var resp = await _dio.post('http://tyxy.just.edu.cn/index1.asp',
        data: {'username': username, 'password': password, 'chkuser': 'true'});
    _dio.transformer = DefaultTransformer();
    resp = await _dio.get('http://tyxy.just.edu.cn/zcgl/xskwcx.asp?action=zccx',
        options: Options(responseDecoder: gbk2Utf8Decoder));
    var cookies = await cookieJar.loadForRequest(resp.realUri);
    var cookieString =
        cookies.map((cookie) => '${cookie.name}=${cookie.value}').join(' ');
    return {'location': resp.realUri.toString(), 'cookie': cookieString};
  }

  Future<Map<String, String>> getSportClubCookie(
      {required String username, required String password}) async {
    _dio.transformer = RemoveTransformer();
    var resp = await _dio.post('http://tyxy.just.edu.cn/index1.asp',
        data: {'username': username, 'password': password, 'chkuser': 'true'});
    _dio.transformer = DefaultTransformer();
    resp = await _dio.get(
        'http://tyxy.just.edu.cn/zcgl/xskwcx.asp?action=jlbcx',
        options: Options(responseDecoder: gbk2Utf8Decoder));
    var cookies = await cookieJar.loadForRequest(resp.realUri);
    var cookieString =
        cookies.map((cookie) => '${cookie.name}=${cookie.value}').join(' ');
    return {'location': resp.realUri.toString(), 'cookie': cookieString};
  }

  Future<bool> resetPassword(
      {required String user, required String idCard}) async {
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
      {required String account,
      required String oldPassword,
      required String newPassword}) async {
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
