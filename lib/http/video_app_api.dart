import 'package:PiliPlus/http/constants.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/models/video/play/url.dart';
import 'package:PiliPlus/utils/app_sign.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:dio/dio.dart';

/// APP API视频取流，用于解锁高画质
/// 仅在用户开启"解锁高画质"功能后使用
abstract final class VideoAppApi {
  // 视频取流专用appkey列表，按优先级排序
  static const List<(String appkey, String appsec)> _videoAppKeys = [
    // iOS端，优先使用
    ('YvirImLGlLANCLvM', 'JNlZNgfNGKZEpaDTkCdPQVXntXhuiJEM'),
    // Android旧版，备用
    ('iVGUTjsxvpLeuDCf', 'aHRmhWMLkdeMuILqORnYZocwMBpMEOdt'),
  ];

  /// 通过APP API获取视频流URL
  /// 
  /// 用于获取高画质视频流（如1080P 60fps），当Web API无法获取时使用
  /// 会尝试多个appkey直到成功
  static Future<LoadingState<PlayUrlModel>> getVideoUrl({
    int? aid,
    String? bvid,
    required int cid,
    int qn = 116, // 默认1080P 60帧
  }) async {
    // 确保有视频标识
    if (aid == null && bvid != null) {
      aid = IdUtils.bv2av(bvid);
    }
    if (aid == null) {
      return const Error('缺少视频标识');
    }

    // 尝试不同的appkey
    for (final (appkey, appsec) in _videoAppKeys) {
      final result = await _tryGetVideoUrl(
        aid: aid,
        cid: cid,
        qn: qn,
        appkey: appkey,
        appsec: appsec,
      );
      
      if (result.isSuccess) {
        return result;
      }
    }
    
    return const Error('APP API取流失败，请使用Web API');
  }

  static Future<LoadingState<PlayUrlModel>> _tryGetVideoUrl({
    required int aid,
    required int cid,
    required int qn,
    required String appkey,
    required String appsec,
  }) async {
    // 构建请求参数
    final params = <String, dynamic>{
      'aid': aid.toString(),
      'cid': cid.toString(),
      'qn': qn.toString(),
      'fnval': '4048', // 包含所有格式能力
      'fnver': '0',
      'fourk': '1',    // 允许4K
      'platform': 'ios',
      'build': '14000000',
      'mobi_app': 'iphone',
      'otype': 'json',
      'device': 'phone',
    };
    
    // 使用APP签名
    AppSign.appSign(params, appkey: appkey, appsec: appsec);
    
    try {
      // 发送请求
      final res = await Request().get(
        '${HttpString.appBaseUrl}/x/v2/playurl',
        queryParameters: params,
        options: Options(
          headers: {
            'User-Agent': 'bili-universal/70900300 CFNetwork/1410.0.3 Darwin/22.6.0 os/iOS model/iPhone 12 mobi_app/iphone osVer/16.6.1 network/2',
            'Buvid': 'XYBA4F8EF8E5B76B89577EA948FB9D8113183',
          },
        ),
      );
      
      if (res.data['code'] == 0) {
        // 解析响应数据
        final data = res.data['data'] ?? res.data;
        return Success(PlayUrlModel.fromJson(data));
      } else {
        return Error('请求失败(${res.data['code']}): ${res.data['message']}');
      }
    } catch (e) {
      return Error('请求异常: $e');
    }
  }
}