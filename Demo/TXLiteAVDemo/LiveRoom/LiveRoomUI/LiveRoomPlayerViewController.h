//
//  LiveRoomPlayerViewController.h
//  TXLiteAVDemo
//
//  Created by lijie on 2017/11/22.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LiveRoom.h"

@interface LiveRoomPlayerViewController : UIViewController <LiveRoomListener, UITextFieldDelegate>

@property (nonatomic, weak)    LiveRoom*          liveRoom;
@property (nonatomic, copy)    NSString*          roomName;
@property (nonatomic, copy)    NSString*          roomID;
@property (nonatomic, copy)    NSString*          nickName;

@end
