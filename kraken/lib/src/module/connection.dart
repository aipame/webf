import 'dart:convert';

import 'package:connectivity/connectivity.dart';
import 'package:kraken/bridge.dart';

Connectivity _connectivity;

String _toString(ConnectivityResult connectivityResult) {
  String isConnected =
      jsonEncode(ConnectivityResult.none != connectivityResult);
  String type = _parseConnectivityResult(connectivityResult);

  return '{"isConnected": $isConnected, "type": "$type"}';
}

String _parseConnectivityResult(ConnectivityResult state) {
  switch (state) {
    case ConnectivityResult.wifi:
      return 'wifi';
    case ConnectivityResult.mobile:
      return 'cellular';
    case ConnectivityResult.none:
    default:
      return 'none';
  }
}

class Connection {
  static void _initConnectivity() {
    if (_connectivity == null) {
      _connectivity = Connectivity();
    }
  }

  static void getConnectivity(callback) {
    _initConnectivity();
    _connectivity
        .checkConnectivity()
        .then((ConnectivityResult connectivityResult) {
      callback(_toString(connectivityResult));
    });
  }

  static void onConnectivityChanged() {
    _initConnectivity();
    _connectivity.onConnectivityChanged
        .listen((ConnectivityResult connectivityResul) {
      String json = _toString(connectivityResul);
      emitModuleEvent('["onConnectivityChanged", $json]');
    });
  }
}
