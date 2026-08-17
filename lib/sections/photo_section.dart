import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';

import '../providers/api_student_form_provider.dart';

class PhotoSection extends StatelessWidget {
  const PhotoSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiStudentFormProvider>(
      builder: (context, provider, _) {
        final photo = provider.selectedPhoto;

        return Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Student Photo',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 24),

                Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: photo == null
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.photo_camera,
                                size: 52,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Upload a student photo',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: FutureBuilder<Uint8List>(
                            future: photo.readAsBytes(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (snapshot.hasError || snapshot.data == null) {
                                return const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    size: 52,
                                    color: Colors.grey,
                                  ),
                                );
                              }

                              return Image.memory(
                                snapshot.data!,
                                width: double.infinity,
                                height: 180,
                                fit: BoxFit.contain,
                              );
                            },
                          ),
                        ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: provider.saving ? null : provider.pickPhoto,
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      photo == null ? 'Upload Photo' : 'Change Photo',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
