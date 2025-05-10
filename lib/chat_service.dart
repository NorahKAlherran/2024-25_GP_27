import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:html_unescape/html_unescape.dart';
import 'api_key.dart';

final unescape = HtmlUnescape(); // Define once globally

/// substitution feature
Future<String> getIngredientSubstitution(
  String ingredient,
  String recipeName,
  List<String> ingredients,
) async {
  final String ingredientsList = ingredients.join(", ");

  final List<String> mainIngredients =
      await _identifyMainIngredientsFromChatGPT(recipeName, ingredients);

  print("Main Ingredients Identified: $mainIngredients");

  bool isMainIngredient = mainIngredients
      .any((main) => ingredient.toLowerCase().contains(main.toLowerCase()));

  final List<Map<String, String>> messages = [
    {
      'role': 'system',
      'content': '''
You are a professional chef providing **ingredient substitutions** with **correct measurements**.
**Rules:**
- **Only list ingredient names with measurements.**
- **No additional descriptions.**
- **Use a bullet-point format.**
- **If the ingredient is essential and affects taste, add a warning at the top.**
'''
    },
    {
      'role': 'user',
      'content': '''
I am making "$recipeName" with these ingredients: $ingredientsList.
I need a substitute for "$ingredient".

If "$ingredient" is **essential and affects taste**, reply:
⚠️ Warning: '$ingredient' is essential and substitution may change the taste.

Then, list substitutions in **bullet points** with **correct measurements**.

If "$ingredient" can be substituted without affecting taste, just list alternatives as **bullet points**.
'''
    }
  ];

  try {
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $OpenAiKey',
      },
      body: jsonEncode({
        "model": "gpt-4",
        "messages": messages,
        "max_tokens": 300,
      }),
    );

    if (response.statusCode == 200) {
      final utfDecoded = utf8.decode(response.bodyBytes);
      final data = jsonDecode(utfDecoded);
      String aiResponse = data['choices'][0]['message']['content'].trim();

      aiResponse = unescape.convert(aiResponse);

      final bool hasWarningAlready = aiResponse.startsWith("⚠️");
      if (isMainIngredient && !hasWarningAlready) {
        aiResponse =
            "⚠️ Warning: '$ingredient' is essential and substitution may change the taste.\n\n$aiResponse";
      }

      aiResponse = aiResponse
          .replaceAll(RegExp(r'\r\n|\r'), '\n')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();

      return aiResponse;
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      print('Error from OpenAI: ${errorData['error']['message']}');
      return 'Error: ${errorData['error']['message']}';
    }
  } catch (e) {
    print('Error calling OpenAI API: $e');
    return 'An error occurred while calling the OpenAI API.';
  }
}

Future<String> translateToArabic(String text) async {
  const endpoint = 'https://api.openai.com/v1/chat/completions';
  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $OpenAiKey',
  };

  text = text.replaceAllMapped(
    RegExp(r'^[-•]\s+', multiLine: true),
    (match) => '::: ',
  );

  final prompt = '''
You are a professional Arabic translator.

Translate ONLY the ingredient substitution list below into Arabic, keeping the exact format.

⚠️ Very important:
- Do NOT add any explanatory or conversion sentences.
- KEEP all bullet points (`-` or `•`) — preserve them as `•`.
- KEEP the warning symbol (⚠️) and formatting intact.
- KEEP line breaks and bullet order exactly as they are.
- Do NOT summarize or explain anything.

Return ONLY the translated bullet points and warning (if exists), nothing else.

$text
''';

  final body = jsonEncode({
    'model': 'gpt-4',
    'messages': [
      {'role': 'user', 'content': prompt}
    ],
    'temperature': 0.3,
    'max_tokens': 700,
  });

  try {
    final response =
        await http.post(Uri.parse(endpoint), headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      String translated = data['choices'][0]['message']['content'].trim();

      translated = translated.replaceAll(':::', '•');

      return translated;
    } else {
      print('Error translating: ${response.body}');
      return 'تعذر الترجمة في الوقت الحالي.';
    }
  } catch (e) {
    print('Translation error: $e');
    return 'حدث خطأ أثناء الترجمة.';
  }
}

Future<List<String>> _identifyMainIngredientsFromChatGPT(
    String recipeName, List<String> ingredients) async {
  final String ingredientsList = ingredients.join(", ");

  final List<Map<String, String>> messages = [
    {
      'role': 'system',
      'content': '''
You are a skilled chef. Identify **only** the essential, non-replaceable ingredients that define a dish’s identity.

**Rules:**
- Essential ingredients define **texture, structure, or key taste**.
- Ingredients with common substitutes should NOT be considered essential.
- **Be flexible and practical.** Do not restrict substitutions unnecessarily.
- **Return only a short bullet point list.**
'''
    },
    {
      'role': 'user',
      'content': '''
I am making "$recipeName" with these ingredients: $ingredientsList.

List **only** the truly essential ingredients that define the dish.
Provide the answer as **bullet points only**.
'''
    }
  ];

  try {
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $OpenAiKey',
      },
      body: jsonEncode({
        "model": "gpt-4",
        "messages": messages,
        "max_tokens": 150,
      }),
    );

    if (response.statusCode == 200) {
      final utfDecoded = utf8.decode(response.bodyBytes);
      final data = jsonDecode(utfDecoded);
      String result = data['choices'][0]['message']['content'].trim();

      result = unescape.convert(result);

      List<String> mainIngredients = result
          .split("\n")
          .where((e) => e.trim().startsWith("-"))
          .map((e) => e.replaceFirst("-", "").trim().toLowerCase())
          .toList();

      print("Main Ingredients for '$recipeName': $mainIngredients");

      return mainIngredients;
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      print('OpenAI API Error: ${errorData['error']['message']}');
      return [];
    }
  } catch (e) {
    print('API Call Failed: $e');
    return [];
  }
}

//////------------------------------------------------------------------------------------------
// Function to generate recipe tags
Future<List<String>> generateRecipeTags(
    String name, String description, List<String> ingredients) async {
  const String apiUrl = "https://api.openai.com/v1/chat/completions";

  final List<Map<String, String>> messages = [
    {
      'role': 'system',
      'content':
          'You are an AI that generates relevant food-related tags for recipes.'
    },
    {
      'role': 'user',
      'content': '''
Generate a set of relevant, context-specific tags for the following recipe. 
The tags should reflect the recipe's *cuisine type, **dietary preferences, **meal type*, and any other notable features. 
For example, tags like: "Italian," "Vegan," "Gluten-Free," "Quick," "Dessert," "Healthy," etc.
Do *not* just include ingredients as tags. Focus on *descriptive, meaningful tags* that categorize the recipe based on its *attributes*.

- Recipe Name: $name
- Recipe Description: $description
- Ingredients: ${ingredients.join(", ")}

Return the tags as a JSON array of strings.
'''
    }
  ];

  try {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $OpenAiKey",
      },
      body: jsonEncode({
        "model": "gpt-4",
        "messages": messages,
        "max_tokens": 100,
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      String tagJson = responseData["choices"][0]["message"]["content"];
      List<String> tags = List<String>.from(jsonDecode(tagJson));
      return tags;
    } else {
      final errorData = jsonDecode(response.body);
      print('Error from OpenAI: ${errorData['error']['message']}');
      return [];
    }
  } catch (e) {
    print('Error calling OpenAI API: $e');
    return [];
  }
}

////// translation feature req
Future<Map<String, dynamic>> translateWholeRecipe({
  required String title,
  required String difficulty,
  required String description,
  required List<String> ingredients,
  required List<String> steps,
  required dynamic cookingTime,
  required List<String> tags,
}) async {
  const endpoint = 'https://api.openai.com/v1/chat/completions';

  final headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $OpenAiKey',
  };

  final cookingTimeJson =
      (cookingTime is String) ? '"$cookingTime"' : jsonEncode(cookingTime);

  String enforceArabicTimeFormat(dynamic time) {
    if (time is String && RegExp(r'\d+[hms]').hasMatch(time)) {
      return "Translate the cookingTime into Arabic like '١ ساعة ٢ دقيقة'. Do not return it in the original English format.";
    }
    return "";
  }

  final timeInstruction = enforceArabicTimeFormat(cookingTime);

  final prompt = '''
Translate this recipe into Arabic. Respond only with JSON between triple backticks like ```json { ... } ```.

Ensure the response is valid JSON, including arrays and objects. If the cookingTime is an object, don't wrap it in quotes.
Translate all numbers into Arabic numerals (e.g., 1 → ١, 2 → ٢).
$timeInstruction
{
  "title": "$title",
  "difficulty": "$difficulty",
  "description": "$description",
  "ingredients": ${jsonEncode(ingredients)},
  "steps": ${jsonEncode(steps)},
  "cookingTime": $cookingTimeJson,
  "tags": ${jsonEncode(tags)}
}
''';

  final body = jsonEncode({
    'model': 'gpt-4-0613',
    'messages': [
      {'role': 'user', 'content': prompt}
    ],
    'temperature': 0.7,
    'max_tokens': 3000,
  });

  try {
    final response =
        await http.post(Uri.parse(endpoint), headers: headers, body: body);

    final utfDecodedBody = utf8.decode(response.bodyBytes);
    final data = jsonDecode(utfDecodedBody);

    print("Full API Response: $data");

    if (data == null ||
        data['choices'] == null ||
        (data['choices'] as List).isEmpty) {
      print('Invalid API response format: $data');
      return {};
    }

    final content = data['choices'][0]['message']['content'] as String;

    final regex =
        RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', caseSensitive: false);
    final match = regex.firstMatch(content);

    String rawJson;
    if (match != null) {
      rawJson = match.group(1)!.trim();
      if (rawJson.toLowerCase().startsWith('json')) {
        rawJson = rawJson.substring(4).trim();
      }
    } else {
      print(' Could not extract JSON from response:\n$content');
      return {};
    }

    print("Raw JSON Extracted: $rawJson");

    try {
      final parsed = jsonDecode(rawJson);

      // Normalize cookingTime
      final cookingTimeRaw = parsed['cookingTime'];
      if (cookingTimeRaw is Map<String, dynamic>) {
        final hours = cookingTimeRaw['hours'] ?? 0;
        final minutes = cookingTimeRaw['minutes'] ?? 0;
        parsed['cookingTime'] = '$hours h $minutes m';
      }

      print("Ingredients: ${parsed['ingredients']}");
      print("Steps: ${parsed['steps']}");

      return parsed;
    } catch (e) {
      print('Error parsing final JSON: $e\nRaw JSON:\n$rawJson');
      return {};
    }
  } catch (e) {
    print('Error calling OpenAI: $e');
    return {};
  }
}
