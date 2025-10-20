#import "RongCloudBridge.h"
#import <RongIMLib/RongIMLib.h>   // 融云 SDK

void rongCloudInit(const char *appKey, const char *region) {
    if (!appKey) {
        NSLog(@"[RC] ❌ appKey is NULL");
        return;
    }
    NSString *key = [NSString stringWithUTF8String:appKey];
    NSString *regionName = region ? [NSString stringWithUTF8String:region] : @"BJ"; // 默认北京
    /* 映射表：新增地区只加一行 */
    NSDictionary *regionMap = @{
            @"BJ"  : @(RCAreaCodeBJ),
            @"NA"  : @(RCAreaCodeNA),
            @"SG"  : @(RCAreaCodeSG),
            @"SG_B": @(RCAreaCodeSG_B),
            @"SA"  : @(RCAreaCodeSA)
    };
    RCAreaCode area = [regionMap[regionName] integerValue] ?: RCAreaCodeBJ; // 兜底北京
    RCInitOption *initOption = [[RCInitOption alloc] init];
    initOption.areaCode = area;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[RC] rongCloudInit: AppKey=%@, region=%@ → areaCode=%ld",
                key, regionName, (long)area);
        [[RCCoreClient sharedCoreClient] initWithAppKey:key option:initOption];
    });
}

void rongCloudConnect(const char *token, id <RongCloudConnectCallback> callback) {
    NSString *tk = [NSString stringWithUTF8String:token ?: ""];
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"[RC] rongCloudConnect connectWithToken token=%@ timeLimit:30", tk);
        // 30 秒连接超时
        [[RCCoreClient sharedCoreClient] connectWithToken:tk timeLimit:30
                                                 dbOpened:^(RCDBErrorCode dbCode) {
                                                     NSLog(@"[RC] dbOpened -> dbCode=%ld", (long) dbCode);
                                                     [callback onDBOpened:(int32_t) dbCode];
                                                 }
                                                  success:^(NSString *userId) {
                                                      NSLog(@"[RC] connect success -> userId=%@", userId);
                                                      [callback onSuccess:[userId UTF8String]];
                                                  }
                                                    error:^(RCConnectErrorCode errorCode) {
                                                        NSLog(@"[RC] connect error -> errorCode=%ld", (long) errorCode);
                                                        if (errorCode == RC_CONN_TOKEN_INCORRECT) {
                                                            //Token 错误，可检查客户端 SDK 初始化与 App 服务端获取 Token 时所使用的 App Key 是否一致
                                                            NSLog(@"[RC] errorCode=%ld Token 错误，可检查客户端 SDK 初始化与 App 服务端获取 Token 时所使用的 App Key 是否一致", (long) errorCode);
                                                        } else if(errorCode == RC_CONNECT_TIMEOUT) {
                                                            //连接超时，弹出提示，可以引导用户等待网络正常的时候再次点击进行连接
                                                            NSLog(@"[RC] errorCode=%ld 连接超时，弹出提示，可以引导用户等待网络正常的时候再次点击进行连接", (long) errorCode);
                                                        } else {
                                                            //无法连接 IM 服务器，请根据相应的错误码作出对应处理
                                                            NSLog(@"[RC] errorCode=%ld 无法连接 IM 服务器，请根据相应的错误码作出对应处理", (long) errorCode);
                                                        }
                                                        [callback onError:(int32_t) errorCode];
                                                    }
        ];
    });
}

void rongCloudDisconnect(bool allowPush) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (allowPush) {
            [[RCCoreClient sharedCoreClient] disconnect:YES];   // 接收离线推送
        } else {
            [[RCCoreClient sharedCoreClient] disconnect];       // 停止推送
        }
    });
}

void rongCloudReconnectEnable(bool enable) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (enable) {
            [[RCCoreClient sharedCoreClient] setReconnectKickEnable:YES];
        } else {
            [[RCCoreClient sharedCoreClient] setReconnectKickEnable:NO];
        }
    });
}

/* 把 RCConnectionStatus 映射成 Kotlin 可读的 int32_t */
int32_t rongCloudGetConnectionStatus(void) {
    int32_t status = (int32_t)[[RCCoreClient sharedCoreClient] getConnectionStatus];
    NSLog(@"[RC] getConnectionStatus -> %d", status);
    return status;
}

id <RCDatabaseUpgradeCallback> gRcDatabaseUpgradeCallback = NULL;

@interface RongDatabaseStatusListener : NSObject <RCDatabaseStatusDelegate>
@end

@implementation RongDatabaseStatusListener
- (void)databaseUpgradeWillStart {
    if (gRcDatabaseUpgradeCallback) {
        [gRcDatabaseUpgradeCallback upgradeWillStart];
    }
}

- (void)databaseIsUpgrading:(int)progress {
    if (gRcDatabaseUpgradeCallback) {
        [gRcDatabaseUpgradeCallback upgrading:(int32_t) progress];
    }
}

- (void)databaseUpgradeDidComplete:(RCErrorCode)code {
    if (gRcDatabaseUpgradeCallback) {
        [gRcDatabaseUpgradeCallback upgradeComplete:(int32_t) code];
    }
}

@end

static RongDatabaseStatusListener *gDatabaseStatusDelegate = nil;
void rongCloudAddDatabaseStatusListener(id <RCDatabaseUpgradeCallback> listener) {
    dispatch_async(dispatch_get_main_queue(), ^{
        gRcDatabaseUpgradeCallback = listener;
        if (listener && !gDatabaseStatusDelegate) {
            gDatabaseStatusDelegate = [RongDatabaseStatusListener new];
            [[RCCoreClient sharedCoreClient] addDatabaseStatusDelegate:gDatabaseStatusDelegate];
        } else if (!listener && gDatabaseStatusDelegate) {
            [[RCCoreClient sharedCoreClient] removeDatabaseStatusDelegate:gDatabaseStatusDelegate];
            gDatabaseStatusDelegate = nil;
        }
    });
}

const char *rongCloudGetSDKVersion(void) {
    // NSString → UTF-8
    return [[RCCoreClient getVersion] UTF8String];
}

id <RCConnectionStatusListener> gRcConnectionStatusListener = NULL;

@interface RongConnectionStatusListener : NSObject <RCConnectionStatusChangeDelegate>
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

    /* 回传 Kotlin */
    if (gRcConnectionStatusListener) {
        NSLog(@"[RC] connect status -> code=%ld", (long) status);
        [gRcConnectionStatusListener onChanged:(int32_t) status];
    }
}
@end

static RongConnectionStatusListener *gConnectionStatusDelegate = nil;

void rongCloudAddConnectionStatusListener(id <RCConnectionStatusListener> listener) {
    dispatch_async(dispatch_get_main_queue(), ^{
        gRcConnectionStatusListener = listener;
        if (listener && !gConnectionStatusDelegate) {
            gConnectionStatusDelegate = [RongConnectionStatusListener new];
            [[RCCoreClient sharedCoreClient] addConnectionStatusChangeDelegate:gConnectionStatusDelegate];
        } else if (!listener && gConnectionStatusDelegate) {
            [[RCCoreClient sharedCoreClient] removeConnectionStatusChangeDelegate:gConnectionStatusDelegate];
            gConnectionStatusDelegate = nil;
        }
    });
}

void rongCloudSendMessage(int type, const char *targetId, const char *text, id <RCReceiveMessageListener> listener) {
    NSString *targetUserId = targetId ? [NSString stringWithUTF8String:targetId]
            : @"";
    NSString *content = text ? [NSString stringWithUTF8String:text]
            : @"";

    NSLog(@"[RC] input: type=%d, target=%@, text=%@", type, targetUserId, content);
    if (targetUserId.length == 0 || content.length == 0) {
        NSLog(@"[RC] ⚠️ targetId or text is empty, abort send!");
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        RCTextMessage *msgContent = [RCTextMessage messageWithContent:content];
        RCConversationType convType;
        switch (type) {
            case 1:  convType = ConversationType_PRIVATE;   break;
            case 2:  convType = ConversationType_DISCUSSION;    break;
            case 3:  convType = ConversationType_GROUP; break;
            case 4:  convType = ConversationType_CHATROOM; break;
            case 5:  convType = ConversationType_CUSTOMERSERVICE;   break;
            case 6:  convType = ConversationType_SYSTEM;   break;
            case 7:  convType = ConversationType_APPSERVICE; break;
            case 8:  convType = ConversationType_PUBLICSERVICE; break;
            case 9:  convType = ConversationType_PUSHSERVICE; break;
            case 10:  convType = ConversationType_ULTRAGROUP; break;
            case 11:  convType = ConversationType_Encrypted; break;
            case 12:  convType = ConversationType_RTC; break;
            default: convType = ConversationType_INVALID;   break;
        }
        RCMessage *message = [[RCMessage alloc] initWithType:convType
                                                    targetId:targetUserId
                                                   direction:MessageDirection_SEND
                                                     content:msgContent];
        NSLog(@"[RC] sendMessage start: type=%d, target=%@, text=%@", type, targetUserId, content);
        // 发送消息
        [[RCCoreClient sharedCoreClient]
                sendMessage:message
                pushContent:nil
                   pushData:nil
                   attached:^(RCMessage *successMessage) {
                       //入库成功
                       NSLog(@"[RC] sendMessage attached (db ok) -> messageId=%ld",
                               successMessage.messageId);
                       if (listener) {
                           RCMessageStruct s = {
                                   .messageId = successMessage.messageId,
                                   .targetId  = [successMessage.targetId UTF8String]   // 临时指针，block 内安全
                           };
                           [listener onAttached:s];
                       }

                   }
               successBlock:^(RCMessage *successMessage) {
                      //成功
                   NSLog(@"[RC] sendMessage success -> messageId=%ld",
                           successMessage.messageId);
                   if (listener) {
                       RCMessageStruct s = {
                               .messageId = successMessage.messageId,
                               .targetId  = [successMessage.targetId UTF8String]
                       };
                       [listener onSuccess:s];
                   }
               }
                 errorBlock:^(RCErrorCode nErrorCode, RCMessage *errorMessage) {
                     //失败
                     NSLog(@"[RC] sendMessage error -> code=%ld, messageId=%ld",
                             (long)nErrorCode, errorMessage.messageId);
                     if (listener) {
                         RCMessageStruct s = {
                                 .messageId = errorMessage.messageId,
                                 .targetId  = [errorMessage.targetId UTF8String]
                         };
                         [listener onError:s errorCode:(int32_t)nErrorCode];
                     }
                 }];
    });
}
