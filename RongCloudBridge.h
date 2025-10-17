#import <Foundation/Foundation.h>

/* Kotlin 调用的 C 接口 */
void rongCloudInit(const char *appKey, const char *region);

/* Kotlin 侧定义的回调接口 */
@protocol RongCloudConnectCallback <NSObject>
- (void)onDBOpened:(int32_t)dbErrorCode;      // RCDBErrorCode
- (void)onSuccess:(const char *)userId;
- (void)onError:(int32_t)connectErrorCode;    // RCConnectErrorCode
@end

/* 供 Kotlin 调用的 C 接口 */
void rongCloudConnect(const char *token, _Nullable id<RongCloudConnectCallback> callback);