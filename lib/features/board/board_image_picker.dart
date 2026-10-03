import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'board_repository.dart';

/// Recovered files are never uploaded without a fresh, explicit confirmation.
Future<Uint8List?> pickBoardPhoto({
  required Future<bool> Function() confirmRecovery,
}) async {
  final picker = ImagePicker();
  XFile? image;
  if (Platform.isAndroid) {
    final recovered = await picker.retrieveLostData();
    if (recovered.exception != null) {
      throw const BoardException('이전 사진 선택을 복구하지 못했습니다. 사진을 다시 선택해 주세요.');
    }
    if (recovered.files?.isNotEmpty == true && await confirmRecovery()) {
      image = recovered.files!.first;
    }
  }
  image ??= await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 1920,
    maxHeight: 1920,
    imageQuality: 85,
    requestFullMetadata: false,
  );
  if (image == null) return null;
  if (await image.length() > 1572864) {
    throw const BoardException('사진은 파일당 1.5MiB 이하만 첨부할 수 있습니다.');
  }
  final bytes = await image.readAsBytes();
  BoardRepository.imageMimeType(bytes);
  return bytes;
}
