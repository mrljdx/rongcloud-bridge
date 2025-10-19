#import "RongCloudBridge.h"
#import <RongIMLib/RongIMLib.h>   // 融云 SDK

void rongCloudInit(const char *appKey, const char *region) {
    NSString *key = [NSString stringWithUTF8String:appKey];
    NSString *regionName = [NSString stringWithUTF8String:region];
    RCInitOption *option = [[RCInitOption alloc] init];
    /* 字符串 → RCAreaCode */
    if ([regionName isEqualToString:@"BJ"]) {
        option.areaCode = RCAreaCodeBJ;
    } else if ([regionName isEqualToString:@"NA"]) {
        option.areaCode = RCAreaCodeNA;
    } else if ([regionName isEqualToString:@"SG"]) {
        option.areaCode = RCAreaCodeSG;
    } else if ([regionName isEqualToString:@"SG_B"]) {
        option.areaCode = RCAreaCodeSG_B;
    } else if ([regionName isEqualToString:@"SA"]) {
        option.areaCode = RCAreaCodeSA;
    } else {
        /* 默认兜底 */
        option.areaCode = RCAreaCodeSG; // 新加坡节点
    }
    [[RCCoreClient sharedCoreClient] initWithAppKey:key option:option];
}

void rongCloudConnect(const char *token, id <RongCloudConnectCallback> callback) {
    NSString *tk = [NSString stringWithUTF8String:token ?: ""];
    NSLog(@"[RC] rongCloudConnect begin, token=%@", tk);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[RCCoreClient sharedCoreClient] connectWithToken:tk
                                                 dbOpened:^(RCDBErrorCode dbCode) {
                                                     NSLog(@"[RC] dbOpened -> code=%ld", (long) dbCode);
                                                     [callback onDBOpened:(int32_t) dbCode];
                                                 }
                                                  success:^(NSString *userId) {
                                                      NSLog(@"[RC] connect success -> userId=%@", userId);
                                                      [callback onSuccess:[userId UTF8String]];
                                                  }
                                                    error:^(RCConnectErrorCode errorCode) {
                                                        NSLog(@"[RC] connect error -> code=%ld", (long) errorCode);
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
    return (int32_t)
    [[RCCoreClient sharedCoreClient] getConnectionStatus];
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