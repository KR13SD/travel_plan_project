import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task_model.dart';

class AiApiService {
  static const String baseUrl = "https://a3b93207a567.ngrok-free.app";

  static Future<TaskModel> fetchTaskFromAi(String input) async {
    final response = await http.post(
      Uri.parse("$baseUrl/plan"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"input": input}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // สำหรับ debug raw data
      print("Raw AI response: $data");

      final plan = data['plan'];

      // แปลง priority
      final priorityMap = {'สูง': 'High', 'ต่ำ': 'Low', 'กลาง': 'Medium'};
      String priority =
          priorityMap[plan['priority']] ?? plan['priority'] ?? 'Medium';

      // แปลงวัน
      DateTime? parseDate(String? date) =>
          date != null ? DateTime.tryParse(date) : null;

      final startDate = parseDate(plan['start_date']) ?? DateTime.now();
      final endDate =
          parseDate(plan['end_date']) ??
          DateTime.now().add(const Duration(days: 7));

      // แปลง checklist/subtasks
      final checklist = (plan['subtasks'] ?? []).map<Map<String, dynamic>>((
        st,
      ) {
        if (st is Map<String, dynamic>) {
          return {
            'title': st['name'] ?? '', // แปลง name → title
            'description': st['description'] ?? '', // description
            'done': false,
            'expanded': true,
            'priority': 'medium', // default
            'start_date': null,
            'end_date': null,
          };
        } else {
          return {
            'title': st.toString(),
            'description': '',
            'done': false,
            'expanded': true,
            'priority': 'medium',
            'start_date': null,
            'end_date': null,
          };
        }
      }).toList();

      return TaskModel(
        id: '', // กำหนดตอนบันทึก
        uid: '',
        title: plan['task_name'] ?? 'Untitled',
        priority: priority,
        startDate: startDate,
        endDate: endDate,
        status: 'todo',
        checklist: checklist,
      );
    } else {
      throw Exception("AI API Error: ${response.body}");
    }
  }
}
