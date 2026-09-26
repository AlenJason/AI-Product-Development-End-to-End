import 'dart:convert';
import 'dart:io';

// Fixture hợp đồng do backend xuất (`cd backend_api && npm run fixtures:update`) — JSON thật server trả qua HTTP.
Map<String, dynamic> loadFixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as Map<String, dynamic>;
