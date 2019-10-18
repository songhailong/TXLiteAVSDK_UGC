//
//  RoomMsgMgr.m
//  TXLiteAVDemo
//
//  Created by lijie on 2017/11/1.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import "RoomMsgMgr.h"
#import "ImSDK/ImSDK.h"

#define CMD_PUSHER_CHANGE      @"notifyPusherChange"
#define CMD_CUSTOM_TEXT_MSG    @"CustomTextMsg"

@implementation RoomMsgMgrConfig
@end


@interface RoomMsgMgr() <TIMMessageListener> {
    RoomMsgMgrConfig     *_config;
    dispatch_queue_t     _queue;
    
    NSString             *_groupID;           // 群ID
    TIMConversation      *_roomConversation;  // 群会话上下文
}

@property (nonatomic, assign) BOOL     isOwner;  // 是否是群主
@property (nonatomic, copy) NSString   *ownerGroupID;

@end

@implementation RoomMsgMgr

- (instancetype)initWithConfig:(RoomMsgMgrConfig *)config {
    if (self = [super init]) {
        _config = config;
        _queue = dispatch_queue_create("RoomMsgMgrQueue", DISPATCH_QUEUE_SERIAL);
        
        TIMSdkConfig *sdkConfig = [[TIMSdkConfig alloc] init];
        sdkConfig.sdkAppId = config.appID;
        sdkConfig.accountType = config.accountType;
        
        [[TIMManager sharedInstance] initSdk:sdkConfig];
        [[TIMManager sharedInstance] addMessageListener:self];
        
        _isOwner = NO;
    }
    return self;
}

- (void)dealloc {
    [[TIMManager sharedInstance] removeMessageListener:self];
}

typedef void (^block)();
- (void)asyncRun:(block)block {
    dispatch_async(_queue, ^{
        block();
    });
}

- (void)syncRun:(block)block {
    dispatch_sync(_queue, ^{
        block();
    });
}

- (void)switchRoom:(NSString *)groupID {
    _groupID = groupID;
    _roomConversation = [[TIMManager sharedInstance] getConversation:TIM_GROUP receiver:groupID];
}

- (void)login:(IRoomMsgMgrCompletion)completion {
    [self asyncRun:^{
        TIMLoginParam *param = [[TIMLoginParam alloc] init];
        param.identifier = _config.userID;
        param.userSig = _config.userSig;
        param.appidAt3rd = [NSString stringWithFormat:@"%d", _config.appID];
        
        [[TIMManager sharedInstance] login:param succ:^{
            if (completion) {
                completion(0, nil);
            }
        } fail:^(int code, NSString *msg) {
            if (completion) {
                completion(code, msg);
            }
        }];
    }];
}

- (void)logout:(IRoomMsgMgrCompletion)completion {
    [self asyncRun:^{
        [[TIMManager sharedInstance] logout:^{
            if (completion) {
                completion(0, nil);
            }
        } fail:^(int code, NSString *msg) {
            if (completion) {
                completion(code, msg);
            }
        }];
    }];
}

- (void)createRoom:(NSString *)groupID groupName:(NSString *)groupName completion:(IRoomMsgMgrCompletion)completion {
    [self asyncRun:^{
        __weak __typeof(self) weakSelf = self;
        [[TIMGroupManager sharedInstance] createGroup:@"AVChatRoom" groupId:groupID groupName:groupName succ:^(NSString *groupId) {
            weakSelf.isOwner = YES;
            weakSelf.ownerGroupID = groupID;
            
            if (completion) {
                completion(0, nil);
            }
        } fail:^(int code, NSString *msg) {
            if (completion) {
                completion(code, msg);
            }
        }];
    }];
}

- (void)enterRoom:(NSString *)groupID completion:(IRoomMsgMgrCompletion)completion {
    [self asyncRun:^{
        __weak __typeof(self) weakSelf = self;
        [[TIMGroupManager sharedInstance] joinGroup:groupID msg:nil succ:^{
            //切换群会话的上下文环境
            [weakSelf switchRoom:groupID];
            
            if (completion) {
                completion(0, nil);
            }
            
        } fail:^(int code, NSString *msg) {
            if (completion) {
                completion(code, msg);
            }
        }];
    }];
}

- (void)leaveRoom:(NSString *)groupID completion:(IRoomMsgMgrCompletion)completion {
    [self asyncRun:^{
        // 如果是群主，那么就解散该群，如果不是群主，那就退出该群
        if (_isOwner && [_ownerGroupID isEqualToString:groupID]) {
            [[TIMGroupManager sharedInstance] deleteGroup:groupID succ:^{
                if (completion) {
                    completion(0, nil);
                }
            } fail:^(int code, NSString *msg) {
                if (completion) {
                    completion(code, msg);
                }
            }];
            
        } else {
            [[TIMGroupManager sharedInstance] quitGroup:groupID succ:^{
                if (completion) {
                    completion(0, nil);
                }
            } fail:^(int code, NSString *msg) {
                if (completion) {
                    completion(code, msg);
                }
            }];
        }
    }];
}

- (void)sendCustomMessage:(NSData *)data {
    [self asyncRun:^{
        TIMCustomElem *elem = [[TIMCustomElem alloc] init];
        [elem setData:data];
        
        TIMMessage *msg = [[TIMMessage alloc] init];
        [msg addElem:elem];
        
        if (_roomConversation) {
            [_roomConversation sendMessage:msg succ:^{
                NSLog(@"sendCustomMessage success");
            } fail:^(int code, NSString *msg) {
                NSLog(@"sendCustomMessage failed, data[%@]", data);
            }];
        }
    }];
}

// 一条消息两个Elem：CustomElem{“cmd”:”CustomTextMsg”, “data”:{nickName:“xx”, headPic:”xx”}} + TextElem
- (void)sendRoomTextMsg:(NSString *)textMsg {
    [self asyncRun:^{
        TIMCustomElem *msgHead = [[TIMCustomElem alloc] init];
        NSDictionary *userInfo = @{@"nickName": _config.nickName, @"headPic": _config.headPicUrl};
        NSDictionary *headData = @{@"cmd": CMD_CUSTOM_TEXT_MSG, @"data": userInfo};
        msgHead.data = [self dictionary2JsonData:headData];
        
        TIMTextElem *msgBody = [[TIMTextElem alloc] init];
        msgBody.text = textMsg;
        
        TIMMessage *msg = [[TIMMessage alloc] init];
        [msg addElem:msgHead];
        [msg addElem:msgBody];
        
        if (_roomConversation) {
            [_roomConversation sendMessage:msg succ:^{
                NSLog(@"sendRoomTextMsg success");
            } fail:^(int code, NSString *msg) {
                NSLog(@"sendRoomTextMsg failed, textMsg[%@]", textMsg);
            }];
        }
    }];
}


#pragma mark - TIMMessageListener

- (void)onNewMessage:(NSArray*)msgs {
    [self asyncRun:^{
        for (TIMMessage *msg in msgs) {
            TIMConversationType type = msg.getConversation.getType;
            switch (type) {
                case TIM_C2C:
                    break;
                    
                case TIM_SYSTEM:
                    [self onRecvSystemMsg:msg];
                    break;
                    
                case TIM_GROUP:
                    // 目前只处理当前群消息
                    if ([[msg.getConversation getReceiver] isEqualToString:_groupID]) {
                        [self onRecvGroupMsg:msg];
                    }
                    break;
                    
                default:
                    break;
            }
        }
    }];
}

- (void)onRecvSystemMsg:(TIMMessage *)msg {
    for (int idx = 0; idx < [msg elemCount]; ++idx) {
        TIMElem *elem = [msg getElem:idx];
        
        if ([elem isKindOfClass:[TIMGroupSystemElem class]]) {
            TIMGroupSystemElem *sysElem = (TIMGroupSystemElem *)elem;
            if ([sysElem.group isEqualToString:_groupID]) {
                if (sysElem.type == TIM_GROUP_SYSTEM_DELETE_GROUP_TYPE) {  // 群被解散
                    if (_delegate) {
                        [_delegate onGroupDelete:_groupID];
                    }
                }
                else if (sysElem.type == TIM_GROUP_SYSTEM_CUSTOM_INFO) {  // 用户自定义通知(默认全员接收)
                    NSDictionary *dict = [self jsonData2Dictionary:sysElem.userData];
                    if (dict == nil) {
                        break;
                    }
                    
                    NSString *cmd = dict[@"cmd"];
                    if (cmd == nil) {
                        break;
                    }
                    
                    // 群成员有变化
                    if ([cmd isEqualToString:CMD_PUSHER_CHANGE]) {
                        if (_delegate) {
                            [_delegate onMemberChange:_groupID];
                        }
                    }
                }
            }
        }
    }
}

- (void)onRecvGroupMsg:(TIMMessage *)msg {
    NSString *cmd = nil;
    id data = nil;
    
    for (int idx = 0; idx < [msg elemCount]; ++idx) {
        TIMElem *elem = [msg getElem:idx];
        
        if ([elem isKindOfClass:[TIMCustomElem class]]) {
            TIMCustomElem *customElem = (TIMCustomElem *)elem;
            NSDictionary *dict = [self jsonData2Dictionary:customElem.data];
            if (dict) {
                cmd = dict[@"cmd"];
                data = dict[@"data"];
            }
        }
        
        if ([elem isKindOfClass:[TIMTextElem class]]) {
            TIMTextElem *textElem = (TIMTextElem *)elem;
            NSString *msgText = textElem.text;
            
            if (cmd && [cmd isEqualToString:CMD_CUSTOM_TEXT_MSG] && [data isKindOfClass:[NSDictionary class]]) {
                NSDictionary *userInfo = (NSDictionary *)data;
                NSString *nickName = nil;
                NSString *headPic = nil;
                if (userInfo) {
                    nickName = userInfo[@"nickName"];
                    headPic = userInfo[@"headPic"];
                }
                
                if (_delegate) {
                    [_delegate onRecvGroupTextMsg:_groupID userID:msg.sender textMsg:msgText nickName:nickName headPic:headPic];
                }
               
            }
        }
    }
}


#pragma mark - utils

- (NSData *)dictionary2JsonData:(NSDictionary *)dict {
    if ([NSJSONSerialization isValidJSONObject:dict]) {
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
        if (error) {
            NSLog(@"dictionary2JsonData failed: %@", dict);
            return nil;
        }
        return data;
    }
    return nil;
}

- (NSDictionary *)jsonData2Dictionary:(NSData *)jsonData {
    if (jsonData == nil) {
        return nil;
    }
    NSError *err = nil;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&err];
    if (err) {
        NSLog(@"JjsonData2Dictionary failed: %@", jsonData);
        return nil;
    }
    return dic;
}

@end
