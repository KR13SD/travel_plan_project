import 'package:get/get.dart';
import '../models/task_model.dart';
import '../services/ai_api_service.dart';

class AiImportController extends GetxController {
  /// state
  final isGenerating = false.obs;
  final generateProgressText = ''.obs;
  final hasResultReady = false.obs;
  final errorMessage = ''.obs;

  /// AI result
  TaskModel? aiMainTask;

  final previewTasks = <Map<String, dynamic>>[].obs;
  final planPoints = <Map<String, dynamic>>[].obs;
  final hotelPoints = <Map<String, dynamic>>[].obs;

  final isOnAiImportPage = false.obs;

  /// Reset Action
  final rawResult = ''.obs;
  final selectedTaskIds = <String>{}.obs;

  void reset() {
    isGenerating.value = false;
    previewTasks.clear();
    rawResult.value = '';
    selectedTaskIds.clear();
    hotelPoints.clear();
    planPoints.clear();
  }

  // ======================
  // MAIN ACTION
  // ======================
  Future<void> generateFromText(String text) async {
    reset();
    if (isGenerating.value) return;

    isGenerating.value = true;
    errorMessage.value = '';

    try {
      final result = await AiApiService.fetchPlanAndHotels(text);

      aiMainTask = result.task;
      planPoints.assignAll(result.planPoints);
      hotelPoints.assignAll(result.hotelPoints);

      previewTasks.assignAll(
        result.task.checklist.map(_ensureTaskSchema).toList(),
      );
      hasResultReady.value = true;
    } catch (e) {
      errorMessage.value = e.toString();
      Get.snackbar('AI Error', errorMessage.value);
    } finally {
      isGenerating.value = false;
    }
  }

  // ======================
  // SCHEMA NORMALIZER (สำคัญมาก)
  // ======================
  Map<String, dynamic> _ensureTaskSchema(Map<String, dynamic> item) {
    return {
      'type': item['type'] ?? 'plan',
      'title': item['title'] ?? '',
      'description': item['description'] ?? '',

      /// time
      'time': item['time'],
      'duration': item['duration'],
      'start_date': item['start_date'] ?? item['date'],
      'end_date': item['end_date'],

      /// location
      'lat': item['lat'],
      'lng': item['lng'],
      'mapsUrl': item['mapsUrl'],

      /// media
      'image': item['image'],
      'images': item['images'] ?? const [],

      /// meta
      'priority': (item['priority'] ?? 'medium').toString().toLowerCase(),
      'note': item['note'],
      'des_warning': item['des_warning'],

      /// ui flags
      'done': item['done'] == true,
      'expanded': item['expanded'] ?? true,
      'checked': item['checked'] ?? false,
    };
  }

  // ======================
  // UPDATE HELPERS (ห้ามแก้ Map ตรง ๆ)
  // ======================
  void updateTask(int index, Map<String, dynamic> patch) {
    previewTasks[index] = {...previewTasks[index], ...patch};
  }

  void removeTask(int index) {
    previewTasks.removeAt(index);
  }

  bool get hasResult => aiMainTask != null;
}
