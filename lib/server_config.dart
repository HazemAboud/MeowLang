

const String androidServerIp = '';
const String serverPort = '5000';

String serverUrl(String endpoint) {
  String host='198.18.7.18';
  return 'http://$host:$serverPort$endpoint';
}
