#import <Foundation/Foundation.h>

/* Kotlin 调用的 C 接口 */
void rongCloudInit(const char *appKey, const char *region);

/* Kotlin 侧定义的回调接口 */
@protocol RongCloudConnectCallback <NSObject>
- (void)onDBOpened:(int32_t)dbErrorCode;      // RCDBErrorCode
- (void)onSuccess:(const char *)userId;

- (void)onError:(int32_t)connectErrorCode;    // RCConnectErrorCode
@end

/** 连接融云 **/
void rongCloudConnect(const char *token, _Nullable id <RongCloudConnectCallback> callback);

/** 断开连接 **/
void rongCloudDisconnect(bool allowPush);

/** 重连机制与重连互踢 **/
void rongCloudReconnectEnable(bool enable);

/** 获取当前连接状态，返回映射后的整数 **/
int32_t rongCloudGetConnectionStatus(void);

/* Kotlin 侧定义的回调接口 */
@protocol RCDatabaseUpgradeCallback <NSObject>
- (void)upgradeWillStart;

- (void)upgrading:(int32_t)progress;

- (void)upgradeComplete:(int32_t)code;
@end

void rongCloudAddDatabaseStatusListener(id <RCDatabaseUpgradeCallback> listener);

/** 获取当前 SDK 版本号 **/
const char *rongCloudGetSDKVersion(void);

/* Kotlin 侧定义的回调接口 */
@protocol RCConnectionStatusListener <NSObject>
- (void)onChanged:(int32_t)status;
@end

/** 添加连接状态的监听 **/
void rongCloudAddConnectionStatusListener(id <RCConnectionStatusListener> listener);

/**
 * 定义参考Kotlin RCMessage
 */
typedef struct {
    int64_t messageId;
    const char *_Nonnull targetId;
    const char *_Nonnull content;
} RCMessageStruct;

@protocol RCSendMessageCallback <NSObject>
- (void)onAttached:(RCMessageStruct)message;

- (void)onSuccess:(RCMessageStruct)message;

- (void)onError:(RCMessageStruct)message
        errorCode:(int32_t)errorCode;
@end

/***
 * 发送一条消息
 * @param type : 1 private
 * @param targetId : 目标用户ID
 * @param text : 文本内容
 */
void rongCloudSendMessage(int type, const char *targetId, const char *text, id <RCSendMessageCallback> callback);

@protocol RCReceiveMessageListener <NSObject>
- (void)onReceive:(RCMessageStruct)message;
@end

void rongCloudReceiveMessage(id <RCReceiveMessageListener> listener);

/**
 * 定义参考Kotlin RCBlockedMessageInfo
 * 消息被拦截时的信息
 */
typedef struct {
    int32_t conversationType;  // 会话类型
    const char *_Nullable targetId;  // 会话ID
    const char *_Nullable channelId;  // 频道ID，可选
    const char *_Nullable blockedMsgUId;  // 被拦截的消息UID
    int32_t blockType;  // 拦截类型：1-全局敏感词，2-自定义敏感词，3-第三方审核
    const char *_Nullable extra;  // 附加信息
    long long sentTime;  // 消息发送时间
    int32_t sourceType;  // 消息源触发类型
    const char *_Nullable sourceContent;  // 源内容JSON字符串
} RCBlockedMessageInfoStruct;

@protocol RCMessageBlockListener <NSObject>
- (void)onMessageBlock:(RCBlockedMessageInfoStruct)info;
@end

/***
 * 添加消息拦截监听
 * @param listener : Kotlin侧实现的监听器
 */
void rongCloudAddMessageBlockListener(id <RCMessageBlockListener> listener);

