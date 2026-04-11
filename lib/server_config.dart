

const String androidServerIp = '';
const String serverPort = '5000';

String serverUrl(String endpoint) {
  String host='198.18.6.160';
  return 'http://$host:$serverPort$endpoint';
}
