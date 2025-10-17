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

void rongCloudConnect(const char *token, id<RongCloudConnectCallback> callback) {
    NSString *tk = [NSString stringWithUTF8String:token ?: ""];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[RCCoreClient sharedCoreClient]
                connectWithToken:tk
                        dbOpened:^(RCDBErrorCode dbCode) {
                            [callback onDBOpened:(int32_t)dbCode];
                        }
                         success:^(NSString *userId) {
                             [callback onSuccess:[userId UTF8String]];
                         }
                           error:^(RCConnectErrorCode connCode) {
                               [callback onError:(int32_t)connCode];
                           }];
    });
}