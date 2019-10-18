//
//  LiveAVViewController.h
//  TXLiteAVDemo
//
//  Created by AlexiChen on 2017/9/18.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TXLivePlayer.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface LiveAVViewController : UIViewController
{
    TXLivePlayer *      _txLivePlayer;
    UITextView*         _statusView;
    UITextView*         _logViewEvt;
    unsigned long long  _startTime;
    unsigned long long  _lastTime;
    
    UIButton*           _btnPlay;
    UIButton*           _btnClose;
    UIView*             _cover;
    
    BOOL                _screenPortrait;
    BOOL                _renderFillScreen;
    BOOL                _log_switch;
    BOOL                _play_switch;
    
    
    NSString*           _logMsg;
    NSString*           _tipsMsg;
    NSString*           _testPath;
    NSInteger           _cacheStrategy;
    
    UIButton*           _btnCacheStrategy;
    UIView*             _vCacheStrategy;
    UIButton*           _radioBtnFast;
    UIButton*           _radioBtnSmooth;
    UIButton*           _radioBtnAUTO;
    
    TXLivePlayConfig*   _config;
    
    NSString *_scanQBURL;
    
    UITextField *_roomNum;
    
}

@property (nonatomic, assign) BOOL isLivePlay;

@end
