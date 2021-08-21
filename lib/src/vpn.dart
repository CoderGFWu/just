import 'package:dio/dio.dart';
import 'package:just/src/pj_course.dart';

class VPN {
  factory VPN() => _getInstance();

  static VPN get instance => _getInstance();
  static VPN? _instance;

  VPN._internal();

  static VPN _getInstance() {
    _instance ??= VPN._internal();
    return _instance!;
  }

  Future<void> validateVPN(
      {required String username, required String password}) async {}

  Future<Response> vpnLogin(
          {required String vpnUsername, required String vpnPassword}) async =>
      Response(requestOptions: RequestOptions(path: ''));

  Future<void> vpnLogout() async {}

  Future<void> validateJw(
      {required String username,
      required String password,
      required String vpnUsername,
      required String vpnPassword}) async {}

  Future<void> validateSy(
      {required String username,
      required String password,
      required String vpnUsername,
      required String vpnPassword}) async {}

  Future<void> validatePe(
      {required String username,
      required String password,
      required String vpnUsername,
      required String vpnPassword}) async {}

  Future<Response> jwVpnLogin(
          {required String username,
          required String password,
          required String vpnUsername,
          required String vpnPassword}) async =>
      Response(requestOptions: RequestOptions(path: ''));

  Future<void> jwVpnLogout() async {}

  Future<String> getScore(
          {required String username,
          required String password,
          required String vpnUsername,
          required String vpnPassword,
          required String kksj,
          required String xsfs}) async =>
      '';

  Future<String> getScore2(
          {required String username,
          required String password,
          required String vpnUsername,
          required String vpnPassword,
          required String kksj}) async =>
      '';

  Future<String> getSportScore(
          {required String username,
          required String password,
          required String vpnUsername,
          required String vpnPassword}) async =>
      '';

  Future<String> getSportClub(
          {required String vpnUsername,
          required String vpnPassword,
          required String username,
          required String password}) async =>
      '';

  Future<String> getSportMorning(
          {required String vpnUsername,
          required String vpnPassword,
          required String username,
          required String password}) async =>
      '';

  Future<Map<String, String>> getSportMorningCookie(
          {required String vpnUsername,
          required String vpnPassword,
          required String username,
          required String password}) async =>
      {};

  Future<Map<String, String>> getSportClubCookie(
          {required String vpnUsername,
          required String vpnPassword,
          required String username,
          required String password}) async =>
      {};

  Future<Map<String, String>> getSyCookie(
          {required String username,
          required String password,
          required String vpnUsername,
          required String vpnPassword}) async =>
      {};

  Future<String> getCookie(
          {required String username,
          required String password,
          required String vpnUsername,
          required String vpnPassword}) async =>
      '';

  Future<String> getCourse(
          {required String username,
          required String password,
          required String vpnUsername,
          required String vpnPassword,
          required String kksj}) async =>
      '';

  Future<List<PJCourse>> getPjData(
          {required String username,
          required String password,
          required String vpnUsername,
          required String vpnPassword}) async =>
      [];
}
