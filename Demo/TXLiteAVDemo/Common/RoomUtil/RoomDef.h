//
//  RoomDef.h
//  TXLiteAVDemo
//
//  Created by lijie on 2017/11/21.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>

// 用户账号信息
@interface SelfAccountInfo : NSObject
@property (nonatomic, copy)   NSString*   userID;
@property (nonatomic, copy)   NSString*   userSig;
@property (nonatomic, assign) int         appID;
@property (nonatomic, copy)   NSString*   accountType;
@property (nonatomic, copy)   NSString*   nickName;
@property (nonatomic, copy)   NSString*   headPicUrl;
@end

// 推流者信息
@interface PusherInfo : NSObject
@property (nonatomic, copy)   NSString*   userID;
@property (nonatomic, copy)   NSString*   nickName;
@property (nonatomic, copy)   NSString*   headPicUrl;
@property (nonatomic, copy)   NSString*   playUrl;
@end

// 房间信息
@interface RoomInfo : NSObject
@property (nonatomic, copy)   NSString*   roomID;
@property (nonatomic, copy)   NSString*   roomName;
@property (nonatomic, copy)   NSString*   roomCreator;   // 房间创建者的userID
@property (nonatomic, copy)   NSString*   mixedPlayURL;  // 房间混流播放地址
@property (nonatomic, strong) NSMutableArray<PusherInfo*>*  pusherInfoArray;
@end


// 视频分辨率比例
typedef NS_ENUM(NSInteger, RoomVideoRatio) {
    ROOM_VIDEO_RATIO_9_16    =   1,  // 视频分辨率为9:16
    ROOM_VIDEO_RATIO_3_4     =   2,  // 视频分辨率为3:4
    ROOM_VIDEO_RATIO_1_1     =   3,  // 视频分辨率为1:1
};

// 错误码列表
typedef NS_ENUM(NSInteger, RoomErrCode) {
    ROOM_SUCCESS                  =  0,  // 成功
    ROOM_ERR_REQUEST_TIMEOUT      =  -1, // 请求超时
    ROOM_ERR_IM_LOGIN             =  -2, // IM登录失败
    ROOM_ERR_CREATE_ROOM          =  -3, // 创建房间失败
    ROOM_ERR_ENTER_ROOM           =  -4, // 加入房间失败
    ROOM_ERR_PUSH_DISCONNECT      =  -5, // 推流连接断开
};
