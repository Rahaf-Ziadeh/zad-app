import 'package:flutter/material.dart';

/// Full-screen image viewer — dark background, back button, pinch-zoom via InteractiveViewer,
/// with loading and error states.
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

/// Pushes [FullScreenImageViewer] over the current screen. No-op if imageUrl is empty.
void openFullScreenImage(BuildContext context, String imageUrl, {String? title}) {
  if (imageUrl.isEmpty) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => FullScreenImageViewer(imageUrl: imageUrl, title: title),
    ),
  );
}

/// Wraps any image with a tap handler that opens full-screen preview. Used wherever the main
/// offer image appears (offer details, owner screens, "my offers" cards).
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
