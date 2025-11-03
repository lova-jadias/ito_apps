// rejistra/lib/widgets/photo_uploader.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PhotoUploader extends StatefulWidget {
  final String? initialPhotoUrl;
  final ValueChanged<String?> onPhotoUploaded;
  final double size;

  const PhotoUploader({
    Key? key,
    this.initialPhotoUrl,
    required this.onPhotoUploaded,
    this.size = 120,
  }) : super(key: key);

  @override
  State<PhotoUploader> createState() => _PhotoUploaderState();
}

class _PhotoUploaderState extends State<PhotoUploader> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  String? _currentPhotoUrl;

  @override
  void initState() {
    super.initState();
    _currentPhotoUrl = widget.initialPhotoUrl;
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() => _isUploading = true);

      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'avatars/$fileName';

      await Supabase.instance.client.storage
          .from('avatars')
          .uploadBinary(filePath, bytes);

      final photoUrl = Supabase.instance.client.storage
          .from('avatars')
          .getPublicUrl(filePath);

      setState(() {
        _currentPhotoUrl = photoUrl;
        _isUploading = false;
      });

      widget.onPhotoUploaded(photoUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo téléversée avec succès')),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 2),
                image: _currentPhotoUrl != null
                    ? DecorationImage(
                  image: NetworkImage(_currentPhotoUrl!),
                  fit: BoxFit.cover,
                )
                    : null,
              ),
              child: _currentPhotoUrl == null
                  ? Icon(Icons.person, size: widget.size * 0.5, color: Colors.grey)
                  : null,
            ),
            if (_isUploading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black54,
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Material(
                color: Theme.of(context).colorScheme.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _isUploading ? null : _pickAndUploadImage,
                  customBorder: const CircleBorder(),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Cliquez sur l\'icône pour ajouter/modifier',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}