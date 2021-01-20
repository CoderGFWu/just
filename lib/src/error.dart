class JustAccountError extends Error {
  final Object message;

  JustAccountError([this.message = '账号或密码不正确']);

  @override
  String toString() {
    return message.toString();
  }
}

class JustVPNError extends Error {
  final Object message;

  JustVPNError([this.message]);

  @override
  String toString() {
    return message.toString();
  }
}
