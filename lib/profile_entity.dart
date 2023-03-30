// To parse this JSON data, do
//
//     final profiles = profilesFromJson(jsonString);

import 'dart:convert';

Profiles profilesFromJson(String str) {
  final jsonData = json.decode(str);
  return Profiles.fromJson(jsonData);
}

String profilesToJson(Profiles data) {
  final dyn = data.toJson();
  return json.encode(dyn);
}

class Profiles {
  String name;
  String color;
  String usser;
  String pass;
  String localPort;
  String localProxy;
  String upstreamProxy;
  String upstreamProxyPort;
  String domain;
  List<String> noProxy;
  bool gateway;

  Profiles({
    required this.name,
    required this.color,
    required this.usser,
    required this.pass,
    required this.localPort,
    required this.localProxy,
    required this.upstreamProxy,
    required this.upstreamProxyPort,
    required this.domain,
    required this.noProxy,
    required this.gateway,
  });

  factory Profiles.fromJson(Map<String, dynamic> json) => Profiles(
        name: json["name"],
        color: json["color"],
        usser: json["usser"],
        pass: json["pass"],
        localPort: json["local_port"],
        localProxy: json["local_proxy"],
        upstreamProxy: json["upstream_proxy"],
        upstreamProxyPort: json["upstream_proxy_port"],
        domain: json["domain"],
        noProxy: List<String>.from(json["no_proxy"].map((x) => x)),
        gateway: json["gateway"],
      );

  Map<String, dynamic> toJson() => {
        "name": name,
        "color": color,
        "usser": usser,
        "pass": pass,
        "local_port": localPort,
        "local_proxy": localProxy,
        "upstream_proxy": upstreamProxy,
        "upstream_proxy_port": upstreamProxyPort,
        "domain": domain,
        "no_proxy": List<dynamic>.from(noProxy.map((x) => x)),
        "gateway": gateway,
      };
}
