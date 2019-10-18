//
//  RoomMsgMgr.h
//  TXLiteAVDemo
//
//  Created by lijie on 2017/11/1.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface RoomMsgMgrConfig : NSObject
@property (nonatomic, copy) NSString* userID;        // 后台分配的唯一ID
@property (nonatomic, assign) int     appID;         // IM登录的appid
@property (nonatomic, copy) NSString* accountType;   // IM登录的账号类型
@property (nonatomic, copy) NSString* userSig;       // IM登录需要的签名
@property (nonatomic, copy) NSString* nickName;      // 发送自定义文本消息时需要
@property (nonatomic, copy) NSString* headPicUrl;    // 发送自定义文本消息时需要
@end


@protocol RoomMsgListener <NSObject>

- (void)onRecvGroupTextMsg:(NSString *)groupID userID:(NSString *)userID textMsg:(NSString *)textMsg nickName:(NSString *)nickName headPic:(NSString *)headPic;

- (void)onMemberChange:(NSString *)groupID;

- (void)onGroupDelete:(NSString *)groupID;

@end


typedef void (^IRoomMsgMgrCompletion)(int errCode, NSString *errMsg);


@interface RoomMsgMgr : NSObject

@property (nonatomic, weak) id<RoomMsgListener> delegate;


- (instancetype)initWithConfig:(RoomMsgMgrConfig *)config;

// 登录
- (void)login:(IRoomMsgMgrCompletion)completion;

// 登出
- (void)logout:(IRoomMsgMgrCompletion)completion;

// 创建房间
- (void)createRoom:(NSString *)groupID groupName:(NSString *)groupName completion:(IRoomMsgMgrCompletion)completion;

// 加入房间
- (void)enterRoom:(NSString *)groupID completion:(IRoomMsgMgrCompletion)completion;

// 退出房间
- (void)leaveRoom:(NSString *)groupID completion:(IRoomMsgMgrCompletion)completion;

// 发送自定义消息
- (void)sendCustomMessage:(NSData *)data;

// 发送群文本消息
- (void)sendRoomTextMsg:(NSString *)textMsg;

@end
