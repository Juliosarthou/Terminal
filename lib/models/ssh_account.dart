class SSHAccount {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;

  SSHAccount({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    this.password,
    this.privateKey,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'username': username,
        'password': password,
        'privateKey': privateKey,
      };

  factory SSHAccount.fromJson(Map<String, dynamic> json) => SSHAccount(
        id: json['id'],
        name: json['name'],
        host: json['host'],
        port: json['port'] ?? 22,
        username: json['username'],
        password: json['password'],
        privateKey: json['privateKey'],
      );
}
