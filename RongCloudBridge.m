#import "RongCloudBridge.h"
#import <RongIMLib/RongIMLib.h>   // 融云 SDK

/* --- 数据模型实现 (必须实现，否则无法实例化) --- */

@implementation RCMessage
@end

@implementation RCBlockedMessageInfo
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
        NSLog(@"[RC] ❌ appKey is empty");
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
        NSLog(@"[RC] rongCloudInit: AppKey=%@, region=%@ → areaCode=%ld", appKey, regionName, (long)area);
        [[RCCoreClient sharedCoreClient] initWithAppKey:appKey option:initOption];
    });
}

void rongCloudConnect(NSString *token, id <RongCloudConnectCallback> callback) {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[RC] rongCloudConnect: token=%@", token);
        [[RCCoreClient sharedCoreClient] connectWithToken:token timeLimit:30
                                                 dbOpened:^(RCDBErrorCode dbCode) {
                                                     if (callback) [callback onDBOpened:(int32_t)dbCode];
                                                 } success:^(NSString *userId) {
                    NSLog(@"[RC] connect success: userId=%@", userId);
                    if (callback) [callback onSuccess:userId];
                } error:^(RCConnectErrorCode errorCode) {
                    NSLog(@"[RC] connect error: %ld", (long)errorCode);
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
            gDatabaseDelegate = [RongDatabaseStatusListener new];
            gDatabaseDelegate.callback = listener;
            [[RCCoreClient sharedCoreClient] addDatabaseStatusDelegate:gDatabaseDelegate];
        } else {
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
    if (self.callback) [self.callback onChanged:(int32_t)status];
}
@end

static RongConnectionStatusListener *gConnDelegate = nil;
void rongCloudAddConnectionStatusListener(id <RCConnectionStatusListener> listener) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (listener) {
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
        RCTextMessage *msgContent = [RCTextMessage messageWithContent:text];
        RCConversationType convType = (RCConversationType)type; // 假设 Kotlin 传过来的 int 已对齐

        RCMessage *rcMsg = [[RCMessage alloc] initWithType:convType targetId:targetId direction:MessageDirection_SEND content:msgContent];

        [[RCCoreClient sharedCoreClient] sendMessage:rcMsg pushContent:nil pushData:nil attached:^(RCMessage *message) {
            if (callback) {
                RCMessage *bridgeMsg = [RCMessage new];
                bridgeMsg.messageId = message.messageId;
                bridgeMsg.targetId = message.targetId;
                [callback onAttached:bridgeMsg];
            }
        } successBlock:^(RCMessage *message) {
            if (callback) {
                RCMessage *bridgeMsg = [RCMessage new];
                bridgeMsg.messageId = message.messageId;
                bridgeMsg.targetId = message.targetId;
                [callback onSuccess:bridgeMsg];
            }
        } errorBlock:^(RCErrorCode nErrorCode, RCMessage *message) {
            if (callback) {
                RCMessage *bridgeMsg = [RCMessage new];
                bridgeMsg.messageId = message.messageId;
                bridgeMsg.targetId = message.targetId;
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
    if (self.callback) {
        RCMessage *bridgeMsg = [RCMessage new];
        bridgeMsg.messageId = message.messageId;
        bridgeMsg.targetId = message.targetId;
        bridgeMsg.content = getMessageContentText(message.content);
        [self.callback onReceive:bridgeMsg];
    }
}
@end

static RongReceiveMessageListener *gReceiveDelegate = nil;
void rongCloudReceiveMessage(id <RCReceiveMessageListener> listener) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (listener) {
            gReceiveDelegate = [RongReceiveMessageListener new];
            gReceiveDelegate.callback = listener;
            [[RCCoreClient sharedCoreClient] addReceiveMessageDelegate:gReceiveDelegate];
        } else {
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
    if (self.callback && info) {
        RCBlockedMessageInfo *bridgeInfo = [RCBlockedMessageInfo new];
        bridgeInfo.conversationType = (int32_t)info.type;
        bridgeInfo.targetId = info.targetId;
        bridgeInfo.channelId = info.channelId;
        bridgeInfo.blockedMsgUId = info.blockedMsgUId;
        bridgeInfo.blockType = (int32_t)info.blockType;
        bridgeInfo.extra = info.extra;
        bridgeInfo.sentTime = info.sentTime;
        bridgeInfo.sourceType = (int32_t)info.sourceType;
        bridgeInfo.sourceContent = info.sourceContent;
        [self.callback onMessageBlock:bridgeInfo];
    }
}
@end

static RongMessageBlockListener *gBlockDelegate = nil;
void rongCloudAddMessageBlockListener(id <RCMessageBlockListener> listener) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (listener) {
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
        [[RCCoreClient sharedCoreClient] getHistoryMessages:(RCConversationType)type
                                                   targetId:targetId
                                            oldestMessageId:oldestMessageId
                                                      count:count
                                                 completion:^(NSArray<RCMessage *> *messages) {
        if (callback) {
            NSMutableArray<RCMessage *> *resultArray = [NSMutableArray array];
            for (RCMessage *msg in messages) {
                RCMessage *bridgeMsg = [RCMessage new];
                bridgeMsg.messageId = msg.messageId;
                bridgeMsg.targetId = msg.targetId;
                bridgeMsg.content = getMessageContentText(msg.content);
                [resultArray addObject:bridgeMsg];
            }
            [callback onSuccess:resultArray];
        }
    }];
    });
}