import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_application_1/services/db_helper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:photo_manager/photo_manager.dart';

class NoteView extends StatefulWidget {
  const NoteView({super.key, this.noteId});
  final int? noteId;

  @override
  State<NoteView> createState() => _NoteViewState();
}

class _NoteViewState extends State<NoteView> {
  final deviceInfo = DeviceInfoPlugin();
  DatabaseHelper noteDatabase = DatabaseHelper.instance;
  File? _image;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Automatically trigger image picker when the view is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickImage();
    });
  }

  Future<void> _pickImage() async {
    PermissionStatus status;
    
    if (Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        status = await Permission.photos.request();
      } else {
        status = await Permission.storage.request();
      }
    } else {
      status = await Permission.photos.request();
    }

    if (status.isGranted) {
      try {
        List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
          type: RequestType.image,
        );
        if (albums.isNotEmpty) {
          List<AssetEntity> media = await albums[0].getAssetListRange(
            start: 0,
            end: 1,
          );
          if (media.isNotEmpty) {
            File? file = await media[0].file;
            if (file != null) {
              setState(() {
                _image = file;
              });
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching image: $e');
        }
      }
    } else if (status.isPermanentlyDenied) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permission Required'),
          content: const Text('Please enable storage permission in settings to pick images'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.pop(context);
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(247, 250, 252, 1.0),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(94, 114, 228, 1.0),
        elevation: 0.0,
        title: const Text('Photo View'),
      ),
      body: Center(
        child: _image != null
            ? Image.file(
                _image!,
                fit: BoxFit.cover,
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}