#import "RongCloudBridge.h"
#import <RongIMLib/RongIMLib.h>   // 融云 SDK

/* --- 数据模型实现 (必须实现，否则无法实例化) --- */

@implementation KRCMessage
@end

@implementation KRCBlockedMessageInfo
@end

@implementation KRCConversation
@end

/* --- 私有辅助方法：将融云 SDK 的消息内容转为字符串 --- */
static NSString* getMessageContentText(RCMessageContent *content) {
    if ([content isKindOfClass:[RCTextMessage class]]) {
        return ((RCTextMessage *)content).content ?: @"";
    }
    return @"[非文本消息]";
}

/* --- 核心函数实现 --- */

void rongCloudInit(NSString *appKey, NSString *region) {
    if (!appKey || appKey.length == 0) {
        NSLog(@"[RC] ❌ Init Error: appKey is empty");
        return;
    }

    NSString *regionName = region ?: @"BJ";
    NSDictionary *regionMap = @{
            @"BJ"  : @(RCAreaCodeBJ),
            @"NA"  : @(RCAreaCodeNA),
            @"SG"  : @(RCAreaCodeSG),
            @"SG_B": @(RCAreaCodeSG_B),
            @"SA"  : @(RCAreaCodeSA)
    };
    RCAreaCode area = [regionMap[regionName] integerValue] ?: RCAreaCodeBJ;

    RCInitOption *initOption = [[RCInitOption alloc] init];
    initOption.areaCode = area;

    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[RC] 🚀 rongCloudInit: AppKey=%@, region=%@, areaCode=%ld", appKey, regionName, (long)area);
        [[RCCoreClient sharedCoreClient] initWithAppKey:appKey option:initOption];
    });
}

void rongCloudConnect(NSString *token, id <RongCloudConnectCallback> callback) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[RC] 🔗 Start connecting with token: %@", token);
        [[RCCoreClient sharedCoreClient] connectWithToken:token timeLimit:30
                                                 dbOpened:^(RCDBErrorCode dbCode) {
            NSLog(@"[RC] 📂 Database opened with code: %ld", (long)dbCode);
            if (callback) [callback onDBOpened:(int32_t)dbCode];
        } success:^(NSString *userId) {
            NSLog(@"[RC] ✅ Connect success, userId: %@", userId);
            if (callback) [callback onSuccess:userId];
        } error:^(RCConnectErrorCode errorCode) {
            NSLog(@"[RC] ❌ Connect error code: %ld", (long)errorCode);
            if (callback) [callback onError:(int32_t)errorCode];
        }];
    });
}

void rongCloudDisconnect(bool allowPush) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (allowPush) {
            [[RCCoreClient sharedCoreClient] disconnect:YES];
        } else {
            [[RCCoreClient sharedCoreClient] disconnect];
        }
    });
}

void rongCloudReconnectEnable(bool enable) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[RCCoreClient sharedCoreClient] setReconnectKickEnable:enable];
    });
}

int32_t rongCloudGetConnectionStatus(void) {
    return (int32_t)[[RCCoreClient sharedCoreClient] getConnectionStatus];
}

const char *rongCloudGetSDKVersion(void) {
    // 这里依然返回 const char* 是为了方便 Kotlin 侧直接读取 version 字符串
    return [[RCCoreClient getVersion] UTF8String];
}

/* --- 监听器代理实现 --- */

// 1. 数据库状态监听
@interface RongDatabaseStatusListener : NSObject <RCDatabaseStatusDelegate>
@property (nonatomic, weak) id<RCDatabaseUpgradeCallback> callback;
@end

@implementation RongDatabaseStatusListener
- (void)databaseUpgradeWillStart { [self.callback upgradeWillStart]; }
- (void)databaseIsUpgrading:(int)progress { [self.callback upgrading:progress]; }
- (void)databaseUpgradeDidComplete:(RCErrorCode)code { [self.callback upgradeComplete:(int32_t)code]; }
@end

static RongDatabaseStatusListener *gDatabaseDelegate = nil;
void rongCloudAddDatabaseStatusListener(id <RCDatabaseUpgradeCallback> listener) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (listener) {
            NSLog(@"[RC] ➕ Adding database listener: %@", listener);
            gDatabaseDelegate = [RongDatabaseStatusListener new];
            gDatabaseDelegate.callback = listener;
            [[RCCoreClient sharedCoreClient] addDatabaseStatusDelegate:gDatabaseDelegate];
        } else {
            NSLog(@"[RC] ➖ Removing database listener");
            [[RCCoreClient sharedCoreClient] removeDatabaseStatusDelegate:gDatabaseDelegate];
            gDatabaseDelegate = nil;
        }
    });
}

// 2. 连接状态监听
@interface RongConnectionStatusListener : NSObject <RCConnectionStatusChangeDelegate>
@property (nonatomic, weak) id<RCConnectionStatusListener> callback;
@end

@implementation RongConnectionStatusListener
- (void)onConnectionStatusChanged:(RCConnectionStatus)status {
    /** https://doc.rongcloud.cn/apidoc/imlibcore-ios/latest/zh_CN/documentation/rongimlibcore/rcconnectionstatus?language=objc */
    NSLog(@"[RC] onConnectionStatusChanged rawCode = %ld", (long)status);
    switch (status) {
        case ConnectionStatus_Connected:
            NSLog(@"[RC] ✅ 连接成功");
            break;
        case ConnectionStatus_Connecting:
            NSLog(@"[RC] ⏳ 连接中...");
            break;
        case ConnectionStatus_DISCONN_EXCEPTION:
            NSLog(@"[RC] ❌ 与服务器的连接已断开，用户被封禁");
            break;
        case ConnectionStatus_KICKED_OFFLINE_BY_OTHER_CLIENT:
            NSLog(@"[RC] 🚪 当前用户在其他设备登录，此设备被踢下线");
            break;
        case ConnectionStatus_NETWORK_UNAVAILABLE:
            NSLog(@"[RC] 📡 网络不可用，SDK 会自动重连");
            break;
        case ConnectionStatus_PROXY_UNAVAILABLE:
            NSLog(@"[RC] 🧱 Proxy 不可用，需要检查代理后手动重连");
            break;
        case ConnectionStatus_SignOut:
            NSLog(@"[RC] 🚪 已登出");
            break;
        case ConnectionStatus_Suspend:
            NSLog(@"[RC] ⏸️ 连接被挂起（网络抖动），SDK 会自动重连");
            break;
        case ConnectionStatus_TOKEN_INCORRECT:
            NSLog(@"[RC] 🔑 Token 无效/过期，需重新获取");
            break;
        case ConnectionStatus_Timeout:
            NSLog(@"[RC] ⏱️ 自动连接超时，需手动重连");
            break;
        case ConnectionStatus_UNKNOWN:
            NSLog(@"[RC] ❓ 未知临时状态，SDK 会自动重连");
            break;
        case ConnectionStatus_USER_ABANDON:
            NSLog(@"[RC] 🗑️ 用户账号已销户，不再连接");
            break;
        case ConnectionStatus_Unconnected:
            NSLog(@"[RC] 🔌 连接失败或未连接");
            break;
        default:
            NSLog(@"[RC] ⚠️ 未映射状态 code=%ld", (long)status);
            break;
    }
    if (self.callback) [self.callback onChanged:(int32_t)status];
}
@end

static RongConnectionStatusListener *gConnDelegate = nil;
void rongCloudAddConnectionStatusListener(id <RCConnectionStatusListener> listener) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (listener) {
            NSLog(@"[RC] ➕ Adding connection status listener");
            gConnDelegate = [RongConnectionStatusListener new];
            gConnDelegate.callback = listener;
            [[RCCoreClient sharedCoreClient] addConnectionStatusChangeDelegate:gConnDelegate];
        } else {
            [[RCCoreClient sharedCoreClient] removeConnectionStatusChangeDelegate:gConnDelegate];
            gConnDelegate = nil;
        }
    });
}

// 3. 消息发送
void rongCloudSendMessage(int type, NSString *targetId, NSString *text, id <RCSendMessageCallback> callback) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[RC] ✉️ Sending message to: %@", targetId);
        RCTextMessage *msgContent = [RCTextMessage messageWithContent:text];
        RCMessage *rcMsg = [[RCMessage alloc] initWithType:(RCConversationType)type targetId:targetId direction:MessageDirection_SEND content:msgContent];

        [[RCCoreClient sharedCoreClient] sendMessage:rcMsg pushContent:nil pushData:nil attached:^(RCMessage *message) {
            NSLog(@"[RC] 📝 Message attached: id=%ld", message.messageId);
            if (callback) {
                KRCMessage *bridgeMsg = [KRCMessage new];
                bridgeMsg.messageId = message.messageId;
                bridgeMsg.messageUId = message.messageUId;
                bridgeMsg.targetId = message.targetId;
                bridgeMsg.senderUserId = message.senderUserId;
                bridgeMsg.content = getMessageContentText(message.content);
                bridgeMsg.sendTime = message.sentTime;
                bridgeMsg.receivedTime = message.receivedTime;
                [callback onAttached:bridgeMsg];
            }
        } successBlock:^(RCMessage *message) {
            NSLog(@"[RC] ✅ Message send success: id=%ld", message.messageId);
            if (callback) {
                KRCMessage *bridgeMsg = [KRCMessage new];
                bridgeMsg.messageId = message.messageId;
                bridgeMsg.messageUId = message.messageUId;
                bridgeMsg.targetId = message.targetId;
                bridgeMsg.senderUserId = message.senderUserId;
                bridgeMsg.content = getMessageContentText(message.content);
                bridgeMsg.sendTime = message.sentTime;
                bridgeMsg.receivedTime = message.receivedTime;
                [callback onSuccess:bridgeMsg];
            }
        } errorBlock:^(RCErrorCode nErrorCode, RCMessage *message) {
            NSLog(@"[RC] ❌ Message send error: %ld", (long)nErrorCode);
            if (callback) {
                KRCMessage *bridgeMsg = [KRCMessage new];
                bridgeMsg.messageId = message.messageId;
                bridgeMsg.messageUId = message.messageUId;
                bridgeMsg.targetId = message.targetId;
                bridgeMsg.senderUserId = message.senderUserId;
                bridgeMsg.content = getMessageContentText(message.content);
                bridgeMsg.sendTime = message.sentTime;
                bridgeMsg.receivedTime = message.receivedTime;
                [callback onError:bridgeMsg errorCode:(int32_t)nErrorCode];
            }
        }];
    });
}

// 4. 消息接收
@interface RongReceiveMessageListener : NSObject <RCIMClientReceiveMessageDelegate>
@property (nonatomic, weak) id<RCReceiveMessageListener> callback;
@end

@implementation RongReceiveMessageListener
- (void)onReceived:(RCMessage *)message left:(int)nLeft object:(id)object offline:(BOOL)offline hasPackage:(BOOL)hasPackage {
    NSLog(@"[RC] 📥 Native Received Message, id: %ld, left: %d", message.messageId, nLeft);
    if (!self.callback) {
        NSLog(@"[RC] ⚠️ Critical Error: Receive callback is NIL! Kotlin instance might be destroyed.");
    }
    if (self.callback) {
        KRCMessage *bridgeMsg = [KRCMessage new];
        bridgeMsg.messageId = message.messageId;
        bridgeMsg.messageUId = message.messageUId;
        bridgeMsg.targetId = message.targetId;
        bridgeMsg.senderUserId = message.senderUserId;
        bridgeMsg.content = getMessageContentText(message.content);
        bridgeMsg.sendTime = message.sentTime;
        bridgeMsg.receivedTime = message.receivedTime;
        [self.callback onReceive:bridgeMsg];
    }
}
@end

static RongReceiveMessageListener *gReceiveDelegate = nil;
void rongCloudReceiveMessage(id <RCReceiveMessageListener> listener) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (listener) {
            NSLog(@"[RC] ➕ Registering Receive Delegate");
            gReceiveDelegate = [RongReceiveMessageListener new];
            gReceiveDelegate.callback = listener;
            [[RCCoreClient sharedCoreClient] addReceiveMessageDelegate:gReceiveDelegate];
        } else {
            NSLog(@"[RC] ➖ Removing Receive Delegate");
            [[RCCoreClient sharedCoreClient] removeReceiveMessageDelegate:gReceiveDelegate];
            gReceiveDelegate = nil;
        }
    });
}

// 5. 消息拦截监听
@interface RongMessageBlockListener : NSObject <RCMessageBlockDelegate>
@property (nonatomic, weak) id<RCMessageBlockListener> callback;
@end

@implementation RongMessageBlockListener
- (void)messageDidBlock:(RCBlockedMessageInfo *)info {
    NSLog(@"[RC] 🛡 Message blocked, targetId: %@", info.targetId);
    if (self.callback) {
        KRCBlockedMessageInfo *bridgeInfo = [KRCBlockedMessageInfo new];
        bridgeInfo.blockType = (int32_t)info.blockType;
        bridgeInfo.targetId = info.targetId;
        bridgeInfo.blockedMsgUId = info.blockedMsgUId;
        bridgeInfo.extra = info.extra;
        bridgeInfo.sourceContent = info.sourceContent;
        bridgeInfo.sourceType = (int32_t)info.sourceType;
        bridgeInfo.conversationType = (int32_t)info.type;
        bridgeInfo.channelId = info.channelId;
        [self.callback onMessageBlock:bridgeInfo];
    }
}
@end

static RongMessageBlockListener *gBlockDelegate = nil;
void rongCloudAddMessageBlockListener(id <RCMessageBlockListener> listener) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (listener) {
            NSLog(@"[RC] ➕ Adding Message Block Delegate");
            gBlockDelegate = [RongMessageBlockListener new];
            gBlockDelegate.callback = listener;
            [[RCCoreClient sharedCoreClient] setMessageBlockDelegate:gBlockDelegate];
        } else {
            [[RCCoreClient sharedCoreClient] setMessageBlockDelegate:nil];
            gBlockDelegate = nil;
        }
    });
}

// 6. 历史消息
void rongCloudHistoryMessages(int type, NSString *targetId, int64_t oldestMessageId, int32_t count, id <RCHistoryMessagesCallback> callback) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[RC] 📖 Fetching history messages for target: %@", targetId);
        [[RCCoreClient sharedCoreClient] getHistoryMessages:(RCConversationType)type
                                                   targetId:targetId
                                            oldestMessageId:oldestMessageId
                                                      count:count
                                                 completion:^(NSArray<RCMessage *> *messages) {
            NSLog(@"[RC] 📖 History fetch completed, count: %lu", (unsigned long)messages.count);
            if (callback) {
                NSMutableArray<KRCMessage *> *resultArray = [NSMutableArray array];
                for (RCMessage *msg in messages) {
                    KRCMessage *bridgeMsg = [KRCMessage new];
                    bridgeMsg.messageId = msg.messageId;
                    bridgeMsg.messageUId = msg.messageUId;
                    bridgeMsg.targetId = msg.targetId;
                    bridgeMsg.senderUserId = msg.senderUserId;
                    bridgeMsg.content = getMessageContentText(msg.content);
                    bridgeMsg.sendTime = msg.sentTime;
                    bridgeMsg.receivedTime = msg.receivedTime;
                    [resultArray addObject:bridgeMsg];
                }
                [callback onSuccess:resultArray];
            }
        }];
    });
}

// 获取所有会话未读消息数
void rongCloudTotalUnreadCount(id <RCUnreadCountCallback> callback) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[RCCoreClient sharedCoreClient] getTotalUnreadCountWith:^(int unreadCount) {
            NSLog(@"[RC] 🔢 Total unread count: %d", unreadCount);
            if (callback) {
                [callback onSuccess:(int32_t)unreadCount];
            }
        }];
    });
}

// 获取指定会话的总未读消息数
void rongCloudUnreadCount(int type, NSString *targetId, id <RCUnreadCountCallback> callback) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[RCCoreClient sharedCoreClient] getUnreadCount:(RCConversationType)type
                                               targetId:targetId
                                             completion:^(int count) {
             if (callback) {
                 [callback onSuccess:(int32_t)count];
             }
        }];
    });
}

// 7. 获取会话列表
void rongCloudGetConversationList(NSArray<NSNumber *> *_Nullable conversationTypeList, int32_t count, int64_t startTime, bool topPriority, id<RCConversationCallback> _Nullable callback) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[RC] 💬 Fetching conversation list, count: %d, startTime: %lld, topPriority: %d", count, startTime, topPriority);

        // 如果没有指定会话类型，获取所有会话类型
        NSArray<NSNumber *> *types = conversationTypeList;

        [[RCCoreClient sharedCoreClient] getConversationList:types
                                                       count:count
                                                   startTime:startTime
                                                 topPriority:topPriority
                                                  completion:^(NSArray<RCConversation *> *conversationList) {
            NSLog(@"[RC] 💬 Conversation list fetched, count: %lu", (unsigned long)conversationList.count);
            if (callback) {
                NSMutableArray<KRCConversation *> *resultArray = [NSMutableArray array];
                for (RCConversation *conv in conversationList) {
                    KRCConversation *bridgeConv = [KRCConversation new];
                    bridgeConv.conversationType = (int32_t)conv.conversationType;
                    bridgeConv.targetId = conv.targetId;
                    bridgeConv.channelId = conv.channelId;
                    bridgeConv.conversationTitle = conv.conversationTitle;
                    bridgeConv.portraitUrl = @"";
                    bridgeConv.unreadMessageCount = (int32_t)conv.unreadMessageCount;
                    bridgeConv.isTop = conv.isTop;
                    bridgeConv.isTopForTag = conv.isTopForTag;
                    bridgeConv.operationTime = conv.operationTime;
                    bridgeConv.senderUserName = @"";
                    bridgeConv.senderUserId = conv.senderUserId;
                    bridgeConv.draft = conv.draft;
                    [resultArray addObject:bridgeConv];
                }
                [callback onSuccess:resultArray];
            }
        }];
    });
}