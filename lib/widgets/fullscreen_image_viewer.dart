import 'package:flutter/material.dart';

/// شاشة معاينة الصورة بملء الشاشة — خلفية داكنة، زر رجوع، وتكبير/تصغير
/// عبر InteractiveViewer، مع حالتي التحميل والخطأ.
class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;
  final String? title;

  const FullScreenImageViewer({super.key, required this.imageUrl, this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: title != null ? Text(title!) : null,
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5.0,
        child: Center(
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
            errorBuilder: (_, __, ___) => const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image_outlined,
                    color: Colors.white54, size: 64),
                SizedBox(height: 16),
                Text('تعذر تحميل الصورة',
                    style: TextStyle(color: Colors.white54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// يفتح [FullScreenImageViewer] فوق الشاشة الحالية. لا شيء يحدث إن كان
/// الرابط فارغاً.
void openFullScreenImage(BuildContext context, String imageUrl, {String? title}) {
  if (imageUrl.isEmpty) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => FullScreenImageViewer(imageUrl: imageUrl, title: title),
    ),
  );
}

/// يلفّ أي صورة بمعالج نقر يفتح معاينة ملء الشاشة لها. يُستخدم أينما ظهرت
/// صورة العرض الرئيسية (تفاصيل العرض، شاشات المالك، بطاقات "عروضي").
class TappableOfferImage extends StatelessWidget {
  final String imageUrl;
  final String? title;
  final Widget child;

  const TappableOfferImage({
    super.key,
    required this.imageUrl,
    required this.child,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: imageUrl.isEmpty
          ? null
          : () => openFullScreenImage(context, imageUrl, title: title),
      child: child,
    );
  }
}
