import 'dart:async';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

class PrivateCookieManager extends CookieManager {
  PrivateCookieManager(CookieJar cookieJar) : super(cookieJar);

  @override
  Future onResponse(Response response) async => _saveCookies(response);

  @override
  Future onError(DioError err) async => _saveCookies(err.response);

  void _saveCookies(Response response) {
    if (response != null && response.headers != null) {
      var cookies = response.headers[HttpHeaders.setCookieHeader];
      if (cookies != null) {
        cookieJar.saveFromResponse(
          response.request.uri,
          cookies.map((str) => _Cookie.fromSetCookieValue(str)).toList(),
        );
      }
    }
  }
}

class _Cookie implements Cookie {
  @override
  String name;
  @override
  String value;
  @override
  DateTime expires;
  @override
  int maxAge;
  @override
  String domain;
  @override
  String path;
  @override
  bool httpOnly = false;
  @override
  bool secure = false;

  _Cookie([this.name, this.value]) {
    // Default value of httponly is true.
    httpOnly = true;
    _validate();
  }

  _Cookie.fromSetCookieValue(String value) {
    // Parse the 'set-cookie' header value.
    _parseSetCookieValue(value);
  }

  // Parse a 'set-cookie' header value according to the rules in RFC 6265.
  void _parseSetCookieValue(String s) {
    var index = 0;

    bool done() => index == s.length;

    String parseName() {
      var start = index;
      while (!done()) {
        if (s[index] == '=') break;
        index++;
      }
      return s.substring(start, index).trim();
    }

    String parseValue() {
      var start = index;
      while (!done()) {
        if (s[index] == ';') break;
        index++;
      }
      return s.substring(start, index).trim();
    }

    void expect(String expected) {
      if (done()) throw HttpException('Failed to parse header value [$s]');
      if (s[index] != expected) {
        throw HttpException('Failed to parse header value [$s]');
      }
      index++;
    }

    void parseAttributes() {
      String parseAttributeName() {
        var start = index;
        while (!done()) {
          if (s[index] == '=' || s[index] == ';') break;
          index++;
        }
        return s.substring(start, index).trim().toLowerCase();
      }

      String parseAttributeValue() {
        var start = index;
        while (!done()) {
          if (s[index] == ';') break;
          index++;
        }
        return s.substring(start, index).trim().toLowerCase();
      }

      while (!done()) {
        var name = parseAttributeName();
        var value = '';
        if (!done() && s[index] == '=') {
          index++; // Skip the = character.
          value = parseAttributeValue();
        }
        if (name == 'expires') {
          expires = _parseCookieDate(value);
        } else if (name == 'max-age') {
          maxAge = int.parse(value);
        } else if (name == 'domain') {
          domain = value;
        } else if (name == 'path') {
          path = value;
        } else if (name == 'httponly') {
          httpOnly = true;
        } else if (name == 'secure') {
          secure = true;
        }
        if (!done()) index++; // Skip the ; character
      }
    }

    //ignore single httponly
    if (s.toLowerCase() == 'httponly') {
      return;
    }
    name = parseName();

    if (done() || name.isEmpty) {
      throw HttpException('Failed to parse header value [$s]');
    }
    index++; // Skip the = character.
    value = parseValue();
    _validate();
    if (done()) return;
    index++; // Skip the ; character.
    parseAttributes();
  }

  @override
  String toString() {
    var sb = StringBuffer();
    sb..write(name)..write('=')..write(value);
    if (expires != null) {
      sb..write('; Expires=')..write(HttpDate.format(expires));
    }
    if (maxAge != null) {
      sb..write('; Max-Age=')..write(maxAge);
    }
    if (domain != null) {
      sb..write('; Domain=')..write(domain);
    }
    if (path != null) {
      sb..write('; Path=')..write(path);
    }
    if (secure) sb.write('; Secure');
    if (httpOnly) sb.write('; HttpOnly');
    return sb.toString();
  }

  void _validate() {
    const separators = [
      '(',
      ')',
      '<',
      '>',
      '@',
      ',',
      ';',
//      ":",
      '\\',
      '"',
      '/',
//      "[",
//      "]",
      '?',
      '=',
      '{',
      '}'
    ];
    for (var i = 0; i < name.length; i++) {
      var codeUnit = name.codeUnits[i];
      if (codeUnit <= 32 || codeUnit >= 127 || separators.contains(name[i])) {
        throw FormatException(
            "Invalid character in cookie name, code unit: '$codeUnit'",
            name,
            i);
      }
    }

    // Per RFC 6265, consider surrounding "" as part of the value, but otherwise
    // double quotes are not allowed.
    var start = 0;
    var end = value.length;
    if (2 <= value.length &&
        value.codeUnits[start] == 0x22 &&
        value.codeUnits[end - 1] == 0x22) {
      start++;
      end--;
    }

    for (var i = start; i < end; i++) {
      var codeUnit = value.codeUnits[i];
      if (!(codeUnit == 0x21 ||
          (codeUnit >= 0x23 && codeUnit <= 0x2B) ||
          (codeUnit >= 0x2D && codeUnit <= 0x3A) ||
          (codeUnit >= 0x3C && codeUnit <= 0x5B) ||
          (codeUnit >= 0x5D && codeUnit <= 0x7E))) {
        throw FormatException(
            "Invalid character in cookie value, code unit: '$codeUnit'",
            value,
            i);
      }
    }
  }

  // Parse a cookie date string.
  static DateTime _parseCookieDate(String date) {
    const monthsLowerCase = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec'
    ];

    var position = 0;

    void error() {
      throw HttpException('Invalid cookie date $date');
    }

    bool isEnd() => position == date.length;

    bool isDelimiter(String s) {
      var char = s.codeUnitAt(0);
      if (char == 0x09) return true;
      if (char >= 0x20 && char <= 0x2F) return true;
      if (char >= 0x3B && char <= 0x40) return true;
      if (char >= 0x5B && char <= 0x60) return true;
      if (char >= 0x7B && char <= 0x7E) return true;
      return false;
    }

    bool isNonDelimiter(String s) {
      var char = s.codeUnitAt(0);
      if (char >= 0x00 && char <= 0x08) return true;
      if (char >= 0x0A && char <= 0x1F) return true;
      if (char >= 0x30 && char <= 0x39) return true; // Digit
      if (char == 0x3A) return true; // ':'
      if (char >= 0x41 && char <= 0x5A) return true; // Alpha
      if (char >= 0x61 && char <= 0x7A) return true; // Alpha
      if (char >= 0x7F && char <= 0xFF) return true; // Alpha
      return false;
    }

    bool isDigit(String s) {
      var char = s.codeUnitAt(0);
      if (char > 0x2F && char < 0x3A) return true;
      return false;
    }

    int getMonth(String month) {
      if (month.length < 3) return -1;
      return monthsLowerCase.indexOf(month.substring(0, 3));
    }

    int toInt(String s) {
      var index = 0;
      for (; index < s.length && isDigit(s[index]); index++) {}
      return int.parse(s.substring(0, index));
    }

    var tokens = [];
    while (!isEnd()) {
      while (!isEnd() && isDelimiter(date[position])) {
        position++;
      }
      var start = position;
      while (!isEnd() && isNonDelimiter(date[position])) {
        position++;
      }
      tokens.add(date.substring(start, position).toLowerCase());
      while (!isEnd() && isDelimiter(date[position])) {
        position++;
      }
    }

    String timeStr;
    String dayOfMonthStr;
    String monthStr;
    String yearStr;

    for (var token in tokens) {
      if (token.length < 1) continue;
      if (timeStr == null &&
          token.length >= 5 &&
          isDigit(token[0]) &&
          (token[1] == ':' || (isDigit(token[1]) && token[2] == ':'))) {
        timeStr = token;
      } else if (dayOfMonthStr == null && isDigit(token[0])) {
        dayOfMonthStr = token;
      } else if (monthStr == null && getMonth(token) >= 0) {
        monthStr = token;
      } else if (yearStr == null &&
          token.length >= 2 &&
          isDigit(token[0]) &&
          isDigit(token[1])) {
        yearStr = token;
      }
    }

    if (timeStr == null ||
        dayOfMonthStr == null ||
        monthStr == null ||
        yearStr == null) {
      error();
    }

    var year = toInt(yearStr);
    if (year >= 70 && year <= 99) {
      year += 1900;
    } else if (year >= 0 && year <= 69) year += 2000;
    if (year < 1601) error();

    var dayOfMonth = toInt(dayOfMonthStr);
    if (dayOfMonth < 1 || dayOfMonth > 31) error();

    var month = getMonth(monthStr) + 1;

    var timeList = timeStr.split(':');
    if (timeList.length != 3) error();
    var hour = toInt(timeList[0]);
    var minute = toInt(timeList[1]);
    var second = toInt(timeList[2]);
    if (hour > 23) error();
    if (minute > 59) error();
    if (second > 59) error();

    return DateTime.utc(year, month, dayOfMonth, hour, minute, second, 0);
  }
}
