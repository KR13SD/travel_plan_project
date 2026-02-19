import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/ai_import_controller.dart';
import '../pages/ai_import_page.dart';

const double kAiBannerHeight = 64;

class AiGeneratingOverlay extends StatelessWidget {
  const AiGeneratingOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AiImportController>(
      builder: (aiCtrl) {
        final isOnAiImportPage = aiCtrl.isOnAiImportPage.value;
        final isGenerating = aiCtrl.isGenerating.value;
        final hasResult = aiCtrl.hasResultReady.value;

        if (!isGenerating && (!hasResult || isOnAiImportPage)) {
          return const SizedBox.shrink();
        }

        return Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            child: Container(
              height: kAiBannerHeight,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isGenerating
                    ? Colors.deepPurple.shade600
                    : Colors.green.shade600,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: isGenerating
                    ? null
                    : () {
                        aiCtrl.hasResultReady.value = false;
                        aiCtrl.update();
                        Get.to(() => const AiImportPage());
                      },
                child: Row(
                  children: [
                    isGenerating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                          ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isGenerating
                            ? 'AI กำลังสร้างแผน… ท่านสามารถไปหน้าอื่นได้'
                            : 'สร้างแผนเสร็จแล้ว • แตะเพื่อไปดู',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!isGenerating)
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
