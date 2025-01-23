import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_key.dart';

Future<String> getIngredientSubstitution(String ingredient) async {
  final List<Map<String, String>> messages = [
    {
      'role': 'system',
      'content':
          'You are a helpful assistant providing cooking ingredient substitutions.'
    },
    {
      'role': 'user',
      'content':
          'What can I use instead of $ingredient? answer with bullet points '
    }
  ];

  try {
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $OpenAiKey',
      },
      body: jsonEncode(
          {"model": "gpt-3.5-turbo", "messages": messages, "max_tokens": 50}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'].trim();
    } else {
      final errorData = jsonDecode(response.body);
      print('Error from OpenAI: ${errorData['error']['message']}');
      return 'Error: ${errorData['error']['message']}';
    }
  } catch (e) {
    print('Error calling OpenAI API: $e');
    return 'An error occurred while calling the OpenAI API.';
}
}
