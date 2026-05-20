import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../models/pet.dart';

class AnimalifeApi {
  static const _tokenKey = 'animalife_jwt';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  // Step 1 — send OTP to email
  static Future<void> sendOtp(String email) async {
    final res = await http.post(
      Uri.parse('$kApiBase/auth/email/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'lang': 'ru'}),
    );
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['error'] ?? 'Ошибка отправки кода');
    }
  }

  // Step 2 — verify OTP → returns JWT
  static Future<String> verifyOtp(String email, String code) async {
    final res = await http.post(
      Uri.parse('$kApiBase/auth/email/verify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );
    final body = jsonDecode(res.body);
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? 'Неверный код');
    }
    final token = body['token'] as String;
    await saveToken(token);
    return token;
  }

  // GET /pets — list user's pets
  static Future<List<Pet>> fetchPets() async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');
    final res = await http.get(
      Uri.parse('$kApiBase/pets'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) throw Exception('Failed to load pets');
    final List<dynamic> list = jsonDecode(res.body);
    return list.map((j) => Pet.fromJson(j as Map<String, dynamic>)).toList();
  }
}
