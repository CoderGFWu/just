import 'package:dio/dio.dart';
import 'package:just/src/pj_course.dart';

class VPN2 {
  factory VPN2() => _getInstance();

  static VPN2 get instance => _getInstance();
  static VPN2? _instance;

  VPN2._internal();

  static VPN2 _getInstance() {
    _instance ??= VPN2._internal();
    return _instance!;
  }

  Future<void> validate(
      {required String username, required String password}) async {}

  Future<Response> vpnLogin(
          {required String username, required String password}) async =>
      Response(requestOptions: RequestOptions(path: ''));

  Future<void> vpnLogout() async {}

  Future<Response> jwLogin(
          {required String username, required String password}) async =>
      Response(requestOptions: RequestOptions(path: ''));

  Future<String> getScore(
          String username, String password, String kksj, String xsfs) async =>
      '';

  Future<String> getScore2(
          String username, String password, String kksj) async =>
      '';

  Future<String> getCourse(
          String username, String password, String kksj) async =>
      '';

  Future<String> getCookie(
          {required String username, required String password}) async =>
      '';

  Future<String> getVPNCookie(
          {required String username, required String password}) async =>
      '';

  Future<List<PJCourse>> getPjData(
          {required String username, required String password}) async =>
      [];

  Future<Map<String, String>> getSyCookie(
          {required String username,
          required String password,
          required String syUsername,
          required String syPassword}) async =>
      {};

  Future<void> validateSy(
      {required String username,
      required String password,
      required String syUsername,
      required String syPassword}) async {}
}
