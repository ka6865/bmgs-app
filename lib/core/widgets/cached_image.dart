import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

/// 서버 이미지를 기기 디스크에 저장해 다음 실행부터 네트워크 없이 그린다.
ImageProvider cachedImageProvider(String url, {int? cacheWidth}) =>
    ResizeImage.resizeIfNeeded(
      cacheWidth,
      null,
      CachedNetworkImageProvider(url),
    );
