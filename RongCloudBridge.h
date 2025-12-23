#import <Foundation/Foundation.h>
/* --- 数据模型定义 --- */

/**
 * 将结构体改为类，以便在 NSArray 中使用
 * Kotlin 侧会自动将其识别为类对象
 */
@interface KRCMessage : NSObject
@property (nonatomic, assign) int64_t messageId;
@property (nonatomic, copy, nonnull) NSString *targetId;
@property (nonatomic, copy, nonnull) NSString *messageUId;
@property (nonatomic, copy, nonnull) NSString *senderUserId;
@property (nonatomic, copy, nonnull) NSString *content;
@property (nonatomic, assign) int64_t sendTime;
@property (nonatomic, assign) int64_t receivedTime;
@end

@interface KRCBlockedMessageInfo : NSObject
@property (nonatomic, assign) int32_t conversationType;
@property (nonatomic, copy, nullable) NSString *targetId;
@property (nonatomic, copy, nullable) NSString *channelId;
@property (nonatomic, copy, nullable) NSString *blockedMsgUId;
@property (nonatomic, assign) int32_t blockType;
@property (nonatomic, copy, nullable) NSString *extra;
@property (nonatomic, assign) long long sentTime;
@property (nonatomic, assign) int32_t sourceType;
@property (nonatomic, copy, nullable) NSString *sourceContent;
@end

/* --- 回调接口定义 --- */

@protocol RongCloudConnectCallback <NSObject>
- (void)onDBOpened:(int32_t)dbErrorCode;
- (void)onSuccess:(NSString *_Nonnull)userId;
- (void)onError:(int32_t)connectErrorCode;
@end

@protocol RCDatabaseUpgradeCallback <NSObject>
- (void)upgradeWillStart;
- (void)upgrading:(int32_t)progress;
- (void)upgradeComplete:(int32_t)code;
@end

@protocol RCConnectionStatusListener <NSObject>
- (void)onChanged:(int32_t)status;
@end

@protocol RCSendMessageCallback <NSObject>
- (void)onAttached:(KRCMessage *_Nonnull)message;
- (void)onSuccess:(KRCMessage *_Nonnull)message;
- (void)onError:(KRCMessage *_Nonnull)message errorCode:(int32_t)errorCode;
@end

@protocol RCReceiveMessageListener <NSObject>
- (void)onReceive:(KRCMessage *_Nonnull)message;
@end

@protocol RCMessageBlockListener <NSObject>
- (void)onMessageBlock:(KRCBlockedMessageInfo *_Nonnull)info;
@end

@protocol RCHistoryMessagesCallback <NSObject>
// 现在 NSArray 可以正确持有 KRCMessage 对象了
- (void)onSuccess:(NSArray<KRCMessage *> *_Nonnull)messages;
- (void)onError:(int32_t)errorCode;
@end

@protocol RCUnreadCountCallback <NSObject>
- (void)onSuccess:(int32_t)count;
- (void)onError:(int32_t)errorCode;
@end

/* --- C 接口函数 --- */

// 初始化
void rongCloudInit(NSString *_Nonnull appKey, NSString *_Nonnull region);

// 连接与断开
void rongCloudConnect(NSString *_Nonnull token, id<RongCloudConnectCallback> _Nullable callback);
void rongCloudDisconnect(bool allowPush);

// 重连与状态
void rongCloudReconnectEnable(bool enable);
int32_t rongCloudGetConnectionStatus(void);
const char *_Nonnull rongCloudGetSDKVersion(void);

// 监听器注册
void rongCloudAddDatabaseStatusListener(id<RCDatabaseUpgradeCallback> _Nonnull listener);
void rongCloudAddConnectionStatusListener(id<RCConnectionStatusListener> _Nonnull listener);
void rongCloudAddMessageBlockListener(id<RCMessageBlockListener> _Nonnull listener);

// 消息操作
void rongCloudSendMessage(int type, NSString *_Nonnull targetId, NSString *_Nonnull text, id<RCSendMessageCallback> _Nullable callback);
void rongCloudReceiveMessage(id<RCReceiveMessageListener> _Nonnull listener);

// 获取历史消息
// 注意：oldestMessageId 和 count 改为传值，避免指针管理麻烦
void rongCloudHistoryMessages(int type, NSString *_Nonnull targetId, int64_t oldestMessageId, int32_t count, id<RCHistoryMessagesCallback> _Nullable callback);

void rongCloudTotalUnreadCount(id<RCUnreadCountCallback> _Nullable callback);

void rongCloudUnreadCount(int type, NSString *_Nonnull targetId, id<RCUnreadCountCallback> _Nullable callback);

