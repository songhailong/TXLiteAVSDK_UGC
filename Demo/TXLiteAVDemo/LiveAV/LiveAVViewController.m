//
//  LiveAVViewController.m
//  TXLiteAVDemo
//
//  Created by AlexiChen on 2017/9/18.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import "LiveAVViewController.h"
#import "ScanQRController.h"
//#import "TXUGCPublish.h"
#import "TXLiveRecordListener.h"
//#import "TXUGCPublishListener.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <mach/mach.h>
#import "AppLogMgr.h"
#import "AFNetworkReachabilityManager.h"
#import "UIView+Additions.h"
#import "UIImage+Additions.h"

#import "TXCAVRoom.h"
#define TEST_MUTE   0

#define RTMP_URL    @"rtmp://live.hkstv.hk.lxdns.com/live/hks"//请输入或扫二维码获取播放地址"

typedef NS_ENUM(NSInteger, ENUM_TYPE_CACHE_STRATEGY)
{
    CACHE_STRATEGY_FAST           = 1,  //极速
    CACHE_STRATEGY_SMOOTH         = 2,  //流畅
    CACHE_STRATEGY_AUTO           = 3,  //自动
};

#define CACHE_TIME_FAST             1.0f
#define CACHE_TIME_SMOOTH           5.0f

#define CACHE_TIME_AUTO_MIN         5.0f
#define CACHE_TIME_AUTO_MAX         10.0f

@interface LiveAVViewController ()<
UITextFieldDelegate,
TXLiveRecordListener,
TXLivePlayListener,
//TXVideoPublishListener,
TXVideoCustomProcessDelegate,
ScanQRDelegate,
TXCAVRoomListener
>

@end

@interface LiveAVPreview : UIView

@property (nonatomic, copy) NSString *userID;
@property (nonatomic, strong) UIView *view;

@end

@implementation LiveAVPreview

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        self.view = [[UIView alloc] initWithFrame:self.bounds];
        [self addSubview:self.view];
    }
    return self;
}

@end

typedef enum : NSUInteger {
    AVROOM_IDLE,
    AVROOM_ENTERING,
    AVROOM_ENTERED,
    AVROOM_EXITING,
} AVRoomStatus;

@implementation LiveAVViewController
{
    BOOL        _bHWDec;
    UISlider*   _playProgress;
    UISlider*   _playableProgress;
    UILabel*    _playDuration;
    UILabel*    _playStart;
    UIButton*   _btnPlayMode;
    UIButton*   _btnHWDec;
    UIButton*   _btnMute;
    long long   _trackingTouchTS;
    BOOL        _startSeek;
    BOOL        _videoPause;
    CGRect      _videoWidgetFrame; //改变videoWidget的frame时候记得对其重新进行赋值
    UIImageView * _loadingImageView;
    BOOL        _appIsInterrupt;
    float       _sliderValue;
    TX_Enum_PlayType _playType;
    long long	_startPlayTS;
    UIView *    mVideoContainer;
    NSString    *_playUrl;
    UIButton    *_btnRecordVideo;
    UIButton    *_btnPublishVideo;
    UILabel     *_labProgress;
    
    BOOL                _recordStart;
    float               _recordProgress;
    //    TXPublishParam       *_publishParam;
    //    TXUGCPublish         *_videoPublish;
    TXRecordResult       *_recordResult;
    BOOL                _enableCache;
    
    NSString  *_scanQRUrl;
    
    UIButton *_enterRoom;
    
    //=============================
    UIView *_controlPanel;
    
    UIButton *_horScreenButton;
    UIButton *_fillModeButton;
    UIButton *_hwSpeedButton;
    UIButton *_switchCameraButton;
    UIButton *_muteButton;
    UIButton *_cameraOnButton;
    
    
    //====================
    UIView *_avPanel;
    NSMutableArray *_previews;
    
    
    // AVRoom相关
    TXCAVRoom*                _avRoom;
    
    
    BOOL             _camera_switch;
    BOOL             _mirror_switch;
    BOOL             _mute_switch;
    BOOL             _pure_switch;
    UInt64                    _selfUserID;
    int                       _evtStatsDataIndex;
    BOOL                      _appIsInActive;
    BOOL                      _appIsBackground;
    AVRoomStatus              _roomStatus;
    
}

- (void)viewDidLoad {
    _recordStart = NO;
    _recordProgress = 0.f;
    
    
    [super viewDidLoad];
    
    _selfUserID = arc4random();
    
    TXCAVRoomConfig *config = [[TXCAVRoomConfig alloc] init];      // 使用默认值即可
    config.videoBitrate = AVROOM_VIDEO_ASPECT_3_4;
    config.videoBitrate = 400;
    config.videoFPS = 15;
    config.pauseImg = [UIImage imageNamed:@"pause_publish.jpg"];
    
    _avRoom = [[TXCAVRoom alloc] initWithConfig:config andAppId:1400035356 andUserID:_selfUserID];
    _avRoom.delegate = self;
    //[_avRoom setBeautyLevel:5 whitenessLevel:5 ruddinessLevel:5];   // 设置美颜
    
    //    _playerViewDic = [[NSMutableDictionary alloc] init];
    
//    _evtStatsDataArray = [[NSMutableArray alloc] init];
    _evtStatsDataIndex = 0;
    
    _appIsInterrupt = NO;
    _appIsInActive = NO;
    _appIsBackground = NO;
    _roomStatus = AVROOM_IDLE;
    
//    [_vBeauty resetValues];
    
    [self initUI];
}

- (void)statusBarOrientationChanged:(NSNotification *)note
{
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.hidden = NO;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.navigationController.navigationBar.hidden = YES;
}

- (void)initUI
{
    for (UIView *view in self.view.subviews) {
        [view removeFromSuperview];
    }
    self.title = @"直播+会议";
    
    _videoWidgetFrame = [UIScreen mainScreen].bounds;
    
    [self.view setBackgroundImage:[UIImage imageNamed:@"background.jpg"]];
    
    CGSize size = [[UIScreen mainScreen] bounds].size;
    
    int icon_size = size.width / 10;
    
    UIButton* btnScan = [UIButton buttonWithType:UIButtonTypeCustom];
    btnScan.frame = CGRectMake(10 , 30 + icon_size + 10, icon_size, icon_size);
    [btnScan setImage:[UIImage imageNamed:@"QR_code"] forState:UIControlStateNormal];
    [btnScan addTarget:self action:@selector(clickScan:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btnScan];
    
    
    
    _btnPlay = [UIButton buttonWithType:UIButtonTypeCustom];
    _btnPlay.frame = CGRectMake(10 + icon_size + 10, 30 + icon_size + 10, icon_size, icon_size);
    [_btnPlay setImage:[UIImage imageNamed:@"start"] forState:UIControlStateNormal];
    [_btnPlay addTarget:self action:@selector(clickPlay:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_btnPlay];
    
    _roomNum = [[UITextField alloc] initWithFrame:CGRectMake(_btnPlay.frame.origin.x + _btnPlay.frame.size.width + 10, 30 + icon_size + 10, size.width - (_btnPlay.frame.origin.x + _btnPlay.frame.size.width + 10) - 10 - icon_size - 10, icon_size)];
    [_roomNum setBorderStyle:UITextBorderStyleRoundedRect];
    _roomNum.keyboardType = UIKeyboardTypeNumberPad;
    _roomNum.placeholder = @"请输入房间号：如6830";
    _roomNum.text = @"";
    _roomNum.background = [UIImage imageNamed:@"Input_box"];
    _roomNum.alpha = 0.5;
    _roomNum.autocapitalizationType = UITextAutocorrectionTypeNo;
    [self.view addSubview:_roomNum];
    
    UIButton *enterroom = [UIButton buttonWithType:UIButtonTypeCustom];
    enterroom.frame = CGRectMake(size.width - icon_size - 10 , 30 + icon_size + 10, icon_size, icon_size);;
    enterroom.backgroundColor = [UIColor grayColor];
    enterroom.layer.cornerRadius = enterroom.frame.size.width/2;
    enterroom.layer.masksToBounds = YES;
    [enterroom setTitleColor:[UIColor darkGrayColor]  forState:UIControlStateNormal];
    [enterroom setTitle:@"进房" forState:UIControlStateNormal];
    [enterroom setTitle:@"退房" forState:UIControlStateSelected];
    [enterroom addTarget:self action:@selector(onEnterAVRoom:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:enterroom];
    _enterRoom = enterroom;
    
    _play_switch = NO;
    
    if (self.isLivePlay) {
        _btnClose = nil;
    }
    
    _log_switch = NO;
    _bHWDec = NO;
    _screenPortrait = NO;
    _renderFillScreen = YES;
    _txLivePlayer = [[TXLivePlayer alloc] init];
    _txLivePlayer.recordDelegate = self;
    
    if (!self.isLivePlay) {
        _btnCacheStrategy = nil;
    }
    [self setCacheStrategy:CACHE_STRATEGY_AUTO];
    
    _videoPause = NO;
    _trackingTouchTS = 0;
    
    if (!self.isLivePlay)
    {
        _playStart.hidden = NO;
        _playDuration.hidden = NO;
        _playProgress.hidden = NO;
        _playableProgress.hidden = NO;
    }
    else
    {
        _playStart.hidden = YES;
        _playDuration.hidden = YES;
        _playProgress.hidden = YES;
        _playableProgress.hidden = YES;
    }
    

    [self addAVPanel];
    [self addControlPanel];
    
    CGRect VideoFrame = self.view.bounds;
    VideoFrame.origin.y = _btnPlay.frame.origin.y + _btnPlay.frame.size.height + 4;
    VideoFrame.size.height = _avPanel.frame.origin.y;
    VideoFrame.size.height -= VideoFrame.origin.y;
    mVideoContainer = [[UIView alloc] initWithFrame:VideoFrame];
    [self.view insertSubview:mVideoContainer atIndex:0];
    
    //loading imageview
    float width = 34;
    float height = 34;
    float offsetX = (mVideoContainer.frame.size.width - width) / 2;
    float offsetY = mVideoContainer.frame.origin.y + (mVideoContainer.frame.size.height - height) / 2;
    NSMutableArray *array = [[NSMutableArray alloc] initWithObjects:[UIImage imageNamed:@"loading_image0.png"],[UIImage imageNamed:@"loading_image1.png"],[UIImage imageNamed:@"loading_image2.png"],[UIImage imageNamed:@"loading_image3.png"],[UIImage imageNamed:@"loading_image4.png"],[UIImage imageNamed:@"loading_image5.png"],[UIImage imageNamed:@"loading_image6.png"],[UIImage imageNamed:@"loading_image7.png"], nil];
    _loadingImageView = [[UIImageView alloc] initWithFrame:CGRectMake(offsetX, offsetY, width, height)];
    _loadingImageView.animationImages = array;
    _loadingImageView.animationDuration = 1;
    _loadingImageView.hidden = YES;
    [self.view addSubview:_loadingImageView];

}

- (LiveAVPreview *)getPreableView
{
    for (LiveAVPreview *view in _previews)
    {
        if (view.userID.length == 0)
        {
            if (!view.view)
            {
                view.view = [[UIView alloc] initWithFrame:view.bounds];
            }
            
            if (!view.view.superview) {
                [view addSubview:view.view];
            }
            
            view.view.frame = view.bounds;
            
            return view;
        }
    }
    
    return nil;
}

- (void)resetPreviews
{
    for (LiveAVPreview *view in _previews)
    {
        [view.view removeFromSuperview];
        view.userID = nil;
    }
}

- (LiveAVPreview *)getPreviewOf:(NSString *)userID
{
    if (userID.length)
    {
        for (LiveAVPreview *view in _previews)
        {
            if ([view.userID isEqualToString:userID])
            {
                return view;
            }
        }
        
        LiveAVPreview *preview = [self getPreableView];
        
        if (preview)
        {
            preview.userID = userID;
        }
        return preview;
    }
    
    return nil;
}

- (void)addAVPanel
{
    CGRect rect = self.view.bounds;
    rect.origin.y += rect.size.height * 0.6;
    
    int width = (int)((rect.size.width - 4*4)/3 + 0.5);
    int height = (int)(width * 16 / 9.0);
    
    rect.size.height = height + 2*4;
    
    _avPanel = [[UIView alloc] initWithFrame:rect];
    [self.view addSubview:_avPanel];
    
    _previews = [[NSMutableArray alloc] init];
    
    rect = _avPanel.bounds;
    
    rect.size.width = width;
    rect.size.height -= 8;
    rect.origin.y += 4;
    rect.origin.x += 4;
    
    for (int i = 0; i < 3; i++)
    {
        LiveAVPreview *pre = [[LiveAVPreview alloc] initWithFrame:rect];
        [_avPanel addSubview:pre];
        [_previews addObject:pre];
        [pre setBackgroundImage:[UIImage imageNamed:@"pause_publish.jpg"]];
        rect.origin.x += rect.size.width + 4;
    }
}

//静画
- (void)onClickPure:(UIButton *)btn
{
    _pure_switch = !_pure_switch;
    _cameraOnButton.selected = _pure_switch;
    
        if (_pure_switch)
        {
            [_avRoom stopLocalPreview];
        }
        else
        {
           
            if (_roomStatus == AVROOM_ENTERED)
            {
                LiveAVPreview *preview = [self getPreviewOf:[NSString stringWithFormat:@"%u", _selfUserID]];
                [_avRoom startLocalPreview:preview.view];
            }
        }
}

//静音
- (void)onClickMute:(UIButton *)btn {
    _mute_switch = !_mute_switch;
    [_avRoom setLocalMute:_mute_switch];
    _muteButton.selected = _mute_switch;
    
}
//切换摄像头
- (void)onClickCamera:(UIButton*)btn
{
    _camera_switch = !_camera_switch;
    btn.selected = _camera_switch;
    if (_avRoom) {
        [_avRoom switchCamera];
    }
}


- (void)onClickRenderMode:(UIButton*) sender {
    [self clickRenderMode:sender];
}

- (void)onClickScreenOrientation:(UIButton *) sender
{
    [self clickScreenOrientation:sender];
}

- (void)addControlPanel
{
    CGRect rect = self.view.bounds;
    rect.origin.y += rect.size.height - 48;
    rect.size.height = 48;
    
    _controlPanel = [[UIView alloc] initWithFrame:rect];
    [self.view addSubview:_controlPanel];
    
    rect = _controlPanel.bounds;
    rect.origin.x += 4;
    
    if (rect.size.height > 40)
    {
        rect.origin.y += (rect.size.height - 40)/2;
        rect.size.height = 40;
    }
    
    rect.size.width = rect.size.height;
    
    int mar = (_controlPanel.bounds.size.width - 6 * rect.size.width)/7;
    
    rect.origin.x = mar;
    _horScreenButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _horScreenButton.frame = rect;
    [_horScreenButton setImage:[UIImage imageNamed:@"portrait"] forState:UIControlStateNormal];
    [_horScreenButton setImage:[UIImage imageNamed:@"landscape"] forState:UIControlStateSelected];
    [_horScreenButton addTarget:self action:@selector(onClickScreenOrientation:) forControlEvents:UIControlEventTouchUpInside];
    [_controlPanel addSubview:_horScreenButton];
    
    rect.origin.x += rect.size.width + mar;
    
    _fillModeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _fillModeButton.frame = rect;
    [_fillModeButton setImage:[UIImage imageNamed:@"adjust"] forState:UIControlStateNormal];
    [_fillModeButton setImage:[UIImage imageNamed:@"fill"] forState:UIControlStateSelected];
    [_fillModeButton addTarget:self action:@selector(onClickRenderMode:) forControlEvents:UIControlEventTouchUpInside];
    [_controlPanel addSubview:_fillModeButton];
    
    
    rect.origin.x += rect.size.width + mar;
    _hwSpeedButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _hwSpeedButton.frame = rect;
    [_hwSpeedButton setImage:[UIImage imageNamed:@"quick2"] forState:UIControlStateNormal];
    [_hwSpeedButton setImage:[UIImage imageNamed:@"quick"] forState:UIControlStateSelected];
    [_hwSpeedButton addTarget:self action:@selector(onClickHardware:) forControlEvents:UIControlEventTouchUpInside];
    [_controlPanel addSubview:_hwSpeedButton];
    
    rect.origin.x += rect.size.width + mar;
    _switchCameraButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _switchCameraButton.frame = rect;
    [_switchCameraButton setImage:[UIImage imageNamed:@"camera"] forState:UIControlStateNormal];
    [_switchCameraButton setImage:[UIImage imageNamed:@"camera2"] forState:UIControlStateSelected];
    [_switchCameraButton addTarget:self action:@selector(onClickCamera:) forControlEvents:UIControlEventTouchUpInside];
    [_controlPanel addSubview:_switchCameraButton];
    
    
    // 推流端静音(纯视频推流)
    rect.origin.x += rect.size.width + mar;
    
    _muteButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _muteButton.frame = rect;
    [_muteButton setImage:[UIImage imageNamed:@"mic"] forState:UIControlStateNormal];
    [_muteButton setImage:[UIImage imageNamed:@"mic_press"] forState:UIControlStateSelected];
    [_muteButton addTarget:self action:@selector(onClickMute:) forControlEvents:UIControlEventTouchUpInside];
    [_controlPanel addSubview:_muteButton];
    
    
    // 推流端静画(纯音频推流)
    rect.origin.x += rect.size.width + mar;
    _cameraOnButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _cameraOnButton.frame = rect;
    [_cameraOnButton setImage:[UIImage imageNamed:@"camera_nol"] forState:UIControlStateNormal];
    [_cameraOnButton setImage:[UIImage imageNamed:@"camera_dis"] forState:UIControlStateSelected];
    [_cameraOnButton addTarget:self action:@selector(onClickPure:) forControlEvents:UIControlEventTouchUpInside];
    [_controlPanel addSubview:_cameraOnButton];
}

- (void)onEnterAVRoom:(UIButton *)btn
{
    [_roomNum resignFirstResponder];
    [self clickjoin:btn];
}

//加入或退出房间
- (void)clickjoin:(UIButton *)btn {
    
    if (_roomStatus == AVROOM_EXITING || _roomStatus == AVROOM_ENTERING) {
        return;
    }
    
    
    if (_roomStatus == AVROOM_IDLE)
    {
        _roomStatus = AVROOM_ENTERING;
        NSString *roomid = _roomNum.text;
        if (roomid == nil || [roomid  isEqual: @""]) {
            roomid = @"12580";
            _roomNum.text = roomid;
        }
        
        //是否有摄像头权限
        AVAuthorizationStatus statusVideo = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        if (statusVideo == AVAuthorizationStatusDenied) {
            [self toastTip:@"获取摄像头权限失败，请前往隐私-相机设置里面打开应用权限"];
            return;
        }
        
        //是否有麦克风权限
        AVAuthorizationStatus statusAudio = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
        if (statusAudio == AVAuthorizationStatusDenied) {
            [self toastTip:@"获取麦克风权限失败，请前往隐私-麦克风设置里面打开应用权限"];
            return;
        }
        
//        [_evtStatsDataArray removeAllObjects];
        _evtStatsDataIndex = 0;
        
//        [self addEventStatusItem:_selfUserID];
        
        LiveAVPreview *preview = [self getPreableView];
        
//        _videoPreview.rect = self.view.frame;
//        _videoPreview.view.frame = _videoPreview.rect;
        
        // 保留上次的设置
        if (!_pure_switch && preview)
        {
            preview.userID = [NSString stringWithFormat:@"%u", _selfUserID];
            [_avRoom startLocalPreview:preview.view];
        }
        if (_mirror_switch) {
            [_avRoom setMirror:YES];
        }
        if (_renderFillScreen)
        {
            [_avRoom setRenderMode:AVROOM_RENDER_MODE_FILL_SCREEN];
        } else
        {
            [_avRoom setRenderMode:AVROOM_RENDER_MODE_FILL_EDGE];
        }
        
        //获取进房密钥
        NSString *urlStr = [NSString stringWithFormat:@"http://119.29.173.130:8081/getKey?account=%llu&appId=%d&authId=%d&privilegeMap=%d", _selfUserID ,1400035356, [roomid intValue], -1];
        NSURL *url = [[NSURL alloc] initWithString:urlStr];
        
        NSURLSession *session = [NSURLSession sharedSession];
        
        NSURLSessionTask *task = [session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if(error || httpResponse.statusCode != 200 || data == nil){
                //请求sig出错
                _roomStatus = AVROOM_IDLE;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self toastTip:@"sig拉取出错"];
                });
                return;
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                
                TXCAVRoomParam *avroomParam = [[TXCAVRoomParam alloc] init];
                avroomParam.roomID = [roomid intValue];
                avroomParam.authBits = AVROOM_AUTH_BITS_DEFAULT;
                avroomParam.authBuffer = data;
                
                
                [_avRoom enterRoom:avroomParam withCompletion:^(int result) {
                    NSLog(@"enterRoom result: %d", result);
                    if (result == 0) {//进房成功
                        dispatch_async(dispatch_get_main_queue(), ^{
                            _roomStatus = AVROOM_ENTERED;
                            [self toastTip:@"进房成功!"];
                            [btn setSelected:YES];
                            [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
                            
                            // 保留上次的设置
                            if (_mute_switch) {
                                [_avRoom setLocalMute:YES];
                            }
                            
                        });
                    }
                    else{
                        dispatch_async(dispatch_get_main_queue(), ^{
                            _roomStatus = AVROOM_IDLE;
                            [self toastTip:@"进房失败!"];
                            
                            [_avRoom exitRoom:^(int result) {
                                [self resetPreviews];
                            }];
                        });
                    }
                }];
            });
            
            
        }];
        [task resume];
        
        
        
    }
    else {
        _roomStatus = AVROOM_EXITING;
        [_avRoom exitRoom:^(int result) {
            _roomStatus = AVROOM_IDLE;
            [self resetPreviews];
        }];
//        [_vBeauty resetValues];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [btn setSelected:NO];
//            [_btnJoin setImage:[UIImage imageNamed:@"start"] forState:UIControlStateNormal];
            [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
            
//            [_evtStatsDataArray removeAllObjects];
            _evtStatsDataIndex = 0;
            
//            for (id userID in _playerViewDic) {
//                TXCAVRoomPlayerView *playerView = [_playerViewDic objectForKey:userID];
//                [playerView.view removeFromSuperview];
//            }
//            [_playerViewDic removeAllObjects];
        });
    }
    
}

- (UIButton*)createBottomBtnIndex:(int)index Icon:(NSString*)icon Action:(SEL)action Gap:(int)gap Size:(int)size
{
    UIButton* btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake((index+1)*gap + index*size, [[UIScreen mainScreen] bounds].size.height - size - 10, size, size);
    [btn setImage:[UIImage imageNamed:icon] forState:UIControlStateNormal];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    return btn;
}

- (UIButton*)createBottomBtnIndexEx:(int)index Icon:(NSString*)icon Action:(SEL)action Gap:(int)gap Size:(int)size
{
    UIButton* btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake((index+1)*gap + index*size, [[UIScreen mainScreen] bounds].size.height - 2*(size + 10), size, size);
    [btn setImage:[UIImage imageNamed:icon] forState:UIControlStateNormal];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    return btn;
}

//在低系统（如7.1.2）可能收不到这个回调，请在onAppDidEnterBackGround和onAppWillEnterForeground里面处理打断逻辑
- (void) onAudioSessionEvent: (NSNotification *) notification
{
    NSDictionary *info = notification.userInfo;
    AVAudioSessionInterruptionType type = [info[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (type == AVAudioSessionInterruptionTypeBegan)
    {
        if (_play_switch == YES && _appIsInterrupt == NO)
        {
//            if ([self isVODType:_playType]) {
//                if (!_videoPause) {
//                    [_txLivePlayer pause];
//                }
//            }
            _appIsInterrupt = YES;
        }
    }
    else
    {
        AVAudioSessionInterruptionOptions options = [info[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue];
        if (options == AVAudioSessionInterruptionOptionShouldResume)
        {
            // 收到该事件不能调用resume，因为此时可能还在后台
            /*
            if (_play_switch == YES && _appIsInterrupt == YES) {
                if ([self isVODType:_playType]) {
                    if (!_videoPause) {
                        [_txLivePlayer resume];
                    }
                }
                _appIsInterrupt = NO;
            }
             */
        }
    }
    

    if (AVAudioSessionInterruptionTypeBegan == type) {
        _appIsInterrupt = YES;
        if (_avRoom) {
            [_avRoom pause];
        }
    }
    if (AVAudioSessionInterruptionTypeEnded == type) {
        _appIsInterrupt = NO;
        if (!_appIsBackground && !_appIsInActive && !_appIsInterrupt) {
            if (_avRoom) {
                [_avRoom resume];
            }
        }
    }
}

- (void)onAppDidEnterBackGround:(UIApplication*)app {
    if (_play_switch == YES) {
        if ([self isVODType:_playType]) {
            if (!_videoPause) {
                [_txLivePlayer pause];
            }
        }
    }
    
    [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        
    }];
    
    _appIsBackground = YES;
    if (_avRoom) {
        [_avRoom pause];
    }
}

- (void)onAppWillEnterForeground:(UIApplication*)app {
    if (_play_switch == YES) {
        if ([self isVODType:_playType]) {
            if (!_videoPause) {
                [_txLivePlayer resume];
            }
        }
    }
    
    _appIsBackground = NO;
    if (!_appIsBackground && !_appIsInActive && !_appIsInterrupt) {
        if (_avRoom) {
            [_avRoom resume];
        }
    }
    
}

- (void)onAppDidBecomeActive:(UIApplication*)app {
    if (_play_switch == YES && _appIsInterrupt == YES) {
        if ([self isVODType:_playType]) {
            if (!_videoPause) {
                [_txLivePlayer resume];
            }
        }
        _appIsInterrupt = NO;
    }
    
    _appIsInActive = NO;
    if (!_appIsBackground && !_appIsInActive && !_appIsInterrupt) {
        if (_avRoom) {
            [_avRoom resume];
        }
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    if (_play_switch == YES) {
        [self stopRtmp];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    
#if !TARGET_IPHONE_SIMULATOR
    //是否有摄像头权限
    AVAuthorizationStatus statusVideo = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (statusVideo == AVAuthorizationStatusDenied) {
        [self toastTip:@"获取摄像头权限失败，请前往隐私-相机设置里面打开应用权限"];
        return;
    }
#endif
    
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAudioSessionEvent:) name:AVAudioSessionInterruptionNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppDidEnterBackGround:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(statusBarOrientationChanged:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
}

- (void)onAppWillResignActive:(NSNotification*)notification {
    _appIsInActive = YES;
    if (_avRoom) {
        [_avRoom pause];
    }
}

- (void)dealloc
{
    NSLog(@"=======>>>>>>>");
    if (_avRoom) {
        [_avRoom stopLocalPreview];
        [_avRoom exitRoom:^(int result) {
            
        }];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma -- example code bellow
- (void)clearLog {
    _tipsMsg = @"";
    _logMsg = @"";
    [_statusView setText:@""];
    [_logViewEvt setText:@""];
    _startTime = [[NSDate date]timeIntervalSince1970]*1000;
    _lastTime = _startTime;
}

-(BOOL)isVODType:(int)playType {
    if (playType == PLAY_TYPE_VOD_FLV || playType == PLAY_TYPE_VOD_HLS || playType == PLAY_TYPE_VOD_MP4 || playType == PLAY_TYPE_LOCAL_VIDEO) {
        return YES;
    }
    return NO;
}

-(BOOL)checkPlayUrl:(NSString*)playUrl {
    if (self.isLivePlay) {
        if ([playUrl hasPrefix:@"rtmp:"]) {
            _playType = PLAY_TYPE_LIVE_RTMP;
        } else if (([playUrl hasPrefix:@"https:"] || [playUrl hasPrefix:@"http:"]) && [playUrl rangeOfString:@".flv"].length > 0) {
            _playType = PLAY_TYPE_LIVE_FLV;
        } else{
            [self toastTip:@"播放地址不合法，直播目前仅支持rtmp,flv播放方式!"];
            return NO;
        }
    } else {
        if ([playUrl hasPrefix:@"https:"] || [playUrl hasPrefix:@"http:"]) {
            if ([playUrl rangeOfString:@".flv"].length > 0) {
                _playType = PLAY_TYPE_VOD_FLV;
            } else if ([playUrl rangeOfString:@".m3u8"].length > 0){
                _playType= PLAY_TYPE_VOD_HLS;
            } else if ([playUrl rangeOfString:@".mp4"].length > 0){
                _playType= PLAY_TYPE_VOD_MP4;
            } else {
                [self toastTip:@"播放地址不合法，点播目前仅支持flv,hls,mp4播放方式!"];
                return NO;
            }
            
        } else {
            _playType = PLAY_TYPE_LOCAL_VIDEO;
        }
    }
    
    return YES;
}
-(BOOL)startRtmp{
    NSString* playUrl = RTMP_URL;//_scanQBURL;//self.txtRtmpUrl.text;
    if (playUrl.length == 0) {
        playUrl = @"http://1253488539.vod2.myqcloud.com/2e50eecfvodgzp1253488539/490caa849031868223239825008/f0.mp4";
    }
    
    if (![self checkPlayUrl:playUrl]) {
        return NO;
    }
    
    [self clearLog];
    
    // arvinwu add. 增加播放按钮事件的时间打印。
    unsigned long long recordTime = [[NSDate date] timeIntervalSince1970]*1000;
    int mil = recordTime%1000;
    NSDateFormatter* format = [[NSDateFormatter alloc] init];
    format.dateFormat = @"hh:mm:ss";
    NSString* time = [format stringFromDate:[NSDate date]];
    NSString* log = [NSString stringWithFormat:@"[%@.%-3.3d] 点击播放按钮", time, mil];
    
    NSString *ver = [TXLiveBase getSDKVersionStr];
    _logMsg = [NSString stringWithFormat:@"liteav sdk version: %@\n%@", ver, log];
    [_logViewEvt setText:_logMsg];

    
    if(_txLivePlayer != nil)
    {
        _txLivePlayer.delegate = self;
//        _txLivePlayer.recordDelegate = self;
//        _txLivePlayer.videoProcessDelegate = self;
        if (self.isLivePlay) {
            [_txLivePlayer setupVideoWidget:CGRectMake(0, 0, 0, 0) containView:mVideoContainer insertIndex:0];
        }
        
        if (_config == nil)
        {
            _config = [[TXLivePlayConfig alloc] init];
            _config.enableAEC = YES;
        }
        
        if (_enableCache) {
            _config.cacheFolderPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            _config.maxCacheItems = 2;
            
        } else {
            _config.cacheFolderPath = nil;
        }
        _config.playerPixelFormatType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
        [_txLivePlayer setConfig:_config];
        
        //设置播放器缓存策略
        //这里将播放器的策略设置为自动调整，调整的范围设定为1到4s，您也可以通过setCacheTime将播放器策略设置为采用
        //固定缓存时间。如果您什么都不调用，播放器将采用默认的策略（默认策略为自动调整，调整范围为1到4s）
        //[_txLivePlayer setCacheTime:5];
        //[_txLivePlayer setMinCacheTime:1];
        //[_txLivePlayer setMaxCacheTime:4];
//        _txLivePlayer.isAutoPlay = NO;
//        [_txLivePlayer setRate:1.5];
        int result = [_txLivePlayer startPlay:playUrl type:_playType];
        if( result != 0)
        {
            NSLog(@"播放器启动失败");
            return NO;
        }
        
        if (_screenPortrait) {
            [_txLivePlayer setRenderRotation:HOME_ORIENTATION_RIGHT];
        } else {
            [_txLivePlayer setRenderRotation:HOME_ORIENTATION_DOWN];
        }
        if (_renderFillScreen) {
            [_txLivePlayer setRenderMode:RENDER_MODE_FILL_SCREEN];
        } else {
            [_txLivePlayer setRenderMode:RENDER_MODE_FILL_EDGE];
        }
        
        [self startLoadingAnimation];
        
        _videoPause = NO;
        [_btnPlay setImage:[UIImage imageNamed:@"suspend"] forState:UIControlStateNormal];
    }
    [self startLoadingAnimation];
    _startPlayTS = [[NSDate date]timeIntervalSince1970]*1000;
    
    _playUrl = playUrl;
    
    return YES;
}


- (void)stopRtmp{
    _playUrl = @"";
    [self stopLoadingAnimation];
    if(_txLivePlayer != nil)
    {
        [_txLivePlayer stopPlay];
        [_btnMute setImage:[UIImage imageNamed:@"mic"] forState:UIControlStateNormal];
        [_btnMute setHighlighted:NO];
        [_txLivePlayer removeVideoWidget];
        _txLivePlayer.delegate = nil;
    }
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:nil];
}

#pragma - ui event response.
- (void) clickPlay:(UIButton*) sender {
    //-[UIApplication setIdleTimerDisabled:]用于控制自动锁屏，SDK内部并无修改系统锁屏的逻辑
    if (_play_switch == YES)
    {
        if ([self isVODType:_playType]) {
            if (_videoPause) {
                [_txLivePlayer resume];
                [sender setImage:[UIImage imageNamed:@"suspend"] forState:UIControlStateNormal];
                [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
            } else {
                [_txLivePlayer pause];
                [sender setImage:[UIImage imageNamed:@"start"] forState:UIControlStateNormal];
                [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
            }
            _videoPause = !_videoPause;
            
            
        } else {
            _play_switch = NO;
            [self stopRtmp];
            [sender setImage:[UIImage imageNamed:@"start"] forState:UIControlStateNormal];
            [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
        }
        
    }
    else
    {
        if (![self startRtmp]) {
            return;
        }
        
        [sender setImage:[UIImage imageNamed:@"suspend"] forState:UIControlStateNormal];
        _play_switch = YES;
        [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    }
}

//- (void)clickRecord
//{
//    _recordStart = !_recordStart;
//    _btnRecordVideo.selected = NO;
//    if (!_recordStart) {
//        [_btnRecordVideo setImage:[UIImage imageNamed:@"start"] forState:UIControlStateNormal];
//        _labProgress.text = @"";
//        [_txLivePlayer stopRecord];
//        
//        _publishParam = [[TXPublishParam alloc] init];
//    } else {
//        [_btnRecordVideo setImage:[UIImage imageNamed:@"suspend"] forState:UIControlStateNormal];
//        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"开始录流" message:nil delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
//        [alertView show];
//    }
//}

//- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
//{
//    if (0 == buttonIndex) {
//         [_txLivePlayer startRecord:RECORD_TYPE_STREAM_SOURCE];
//    }
//    _publishParam = nil;
//}

//- (void)clickPublish
//{
//    NSError* error;
//    NSDictionary* dictParam = @{@"Action" : @"GetVodSignatureV2"};
//    NSData *data = [NSJSONSerialization dataWithJSONObject:dictParam options:0 error:&error];
//    
//    NSMutableString *strUrl = [[NSMutableString alloc] initWithString:@"https://livedemo.tim.qq.com/interface.php"];
//    
//    NSURL *URL = [NSURL URLWithString:strUrl];
//    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
//    
//    if (data)
//    {
//        [request setValue:[NSString stringWithFormat:@"%ld",(long)[data length]] forHTTPHeaderField:@"Content-Length"];
//        [request setHTTPMethod:@"POST"];
//        [request setValue:@"application/json; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
//        [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
//        
//        [request setHTTPBody:data];
//    }
//    
//    [request setTimeoutInterval:30];
//    
//    
//    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
//        
//        NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//        NSData *responseData = [responseString dataUsingEncoding:NSUTF8StringEncoding];
//        NSError *err = nil;
//        NSDictionary *resultDict = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableContainers error:&err];
//        
//        int errCode = -1;
//        NSDictionary* dataDict = nil;
//        if (resultDict)
//        {
//            if (resultDict[@"returnValue"]) {
//                errCode = [resultDict[@"returnValue"] intValue];
//            }
//            
//            if (0 == errCode && resultDict[@"returnData"]) {
//                dataDict = resultDict[@"returnData"];
//            }
//        }
//        
//        if (dataDict && _publishParam && _videoPublish) {
//            _publishParam.signature  = dataDict[@"signature"];
//            _publishParam.coverImage = _recordResult.coverImage;
//            _publishParam.videoPath  = _recordResult.videoPath;
//            [_videoPublish publishVideo:_publishParam];
//        }
//    }];
//    
//    [task resume];
//}


#pragma mark - TXLiveRecordListener
-(void) onRecordProgress:(NSInteger)milliSecond
{
    int progress = (int)milliSecond/1000;
    _labProgress.text = [NSString stringWithFormat:@"%d", progress];
}

-(void) onRecordComplete:(TXRecordResult*)result
{
    if(result == nil || result.retCode != 0)
    {
        NSLog(@"Error, record failed:%ld %@", (long)result.retCode, result.descMsg);
        [self toastTip:[NSString stringWithFormat:@"录制失败!![%ld]", (long)result.retCode]];
        return;
    }
    _labProgress.text = @"录制成功";
    _recordResult = result;
    
    //    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    //    [library writeVideoAtPathToSavedPhotosAlbum:[NSURL fileURLWithPath:result.videoPath] completionBlock:^(NSURL *assetURL, NSError *error) {
    //        if (error != nil) {
    //            NSLog(@"save video fail:%@", error);
    //        }
    //    }];
}

//-(void) onPublishProgress:(NSInteger)uploadBytes totalBytes: (NSInteger)totalBytes
//{
//    _labProgress.text = [NSString stringWithFormat:@"%d%%", (int)(uploadBytes*100/totalBytes)];
//}
//
//-(void) onPublishComplete:(TXPublishResult*)result
//{
//    if (!result.retCode) {
//        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
//
//        if (result.videoURL == nil) {
//            [self toastTip:@"发布失败！请检查发布的流程是否正常"];
//        }else{
//            [pasteboard setString:result.videoURL];
//            [self toastTip:@"发布成功啦！播放地址已经复制到粘贴板"];
//        }
//
//         _labProgress.text = @"";
//
//    } else {
//        [self toastTip:[NSString stringWithFormat:@"发布失败啦![%d]", result.retCode]];
//    }
//}

- (void)clickClose:(UIButton*)sender {
    if (_play_switch) {
        _play_switch = NO;
        [self stopRtmp];
        [_btnPlay setImage:[UIImage imageNamed:@"start"] forState:UIControlStateNormal];
        _playStart.text = @"00:00";
        [_playDuration setText:@"00:00"];
        [_playProgress setValue:0];
        [_playProgress setMaximumValue:0];
        [_playableProgress setValue:0];
        [_playableProgress setMaximumValue:0];
        
        [_btnRecordVideo setImage:[UIImage imageNamed:@"start"] forState:UIControlStateNormal];
        _labProgress.text = @"";
    }
}

- (void) clickLog:(UIButton*) sender {
    if (_log_switch == YES)
    {
        _statusView.hidden = YES;
        _logViewEvt.hidden = YES;
        [sender setImage:[UIImage imageNamed:@"log"] forState:UIControlStateNormal];
        _cover.hidden = YES;
        _log_switch = NO;
    }
    else
    {
        _statusView.hidden = NO;
        _logViewEvt.hidden = NO;
        [sender setImage:[UIImage imageNamed:@"log2"] forState:UIControlStateNormal];
        _cover.hidden = NO;
        _log_switch = YES;
    }
    
    //    [_txLivePlayer snapshot:^(UIImage *img) {
    //        img = img;
    //    }];
}

- (void) clickScreenOrientation:(UIButton*) sender {
    _screenPortrait = !_screenPortrait;
    
    if (_screenPortrait) {
        [sender setImage:[UIImage imageNamed:@"landscape"] forState:UIControlStateNormal];
        [_txLivePlayer setRenderRotation:HOME_ORIENTATION_RIGHT];
    } else {
        [sender setImage:[UIImage imageNamed:@"portrait"] forState:UIControlStateNormal];
        [_txLivePlayer setRenderRotation:HOME_ORIENTATION_DOWN];
    }
}

- (void) clickRenderMode:(UIButton*) sender {
    _renderFillScreen = !_renderFillScreen;
    
    if (_renderFillScreen) {
        [sender setImage:[UIImage imageNamed:@"adjust"] forState:UIControlStateNormal];
        [_txLivePlayer setRenderMode:RENDER_MODE_FILL_SCREEN];
    } else {
        [sender setImage:[UIImage imageNamed:@"fill"] forState:UIControlStateNormal];
        [_txLivePlayer setRenderMode:RENDER_MODE_FILL_EDGE];
    }
}

- (void)clickMute:(UIButton*)sender
{
    if (sender.isSelected) {
//        [_txLivePlayer setMute:NO];
        [sender setSelected:NO];
        [sender setImage:[UIImage imageNamed:@"mic"] forState:UIControlStateNormal];
    }
    else {
//        [_txLivePlayer setMute:YES];
        [sender setSelected:YES];
        [sender setImage:[UIImage imageNamed:@"vodplay"] forState:UIControlStateNormal];
    }
}

- (void) setCacheStrategy:(NSInteger) nCacheStrategy
{
    if (_btnCacheStrategy == nil || _cacheStrategy == nCacheStrategy)    return;
    
    if (_config == nil)
    {
        _config = [[TXLivePlayConfig alloc] init];
    }
    
    _cacheStrategy = nCacheStrategy;
    switch (_cacheStrategy) {
        case CACHE_STRATEGY_FAST:
            _config.bAutoAdjustCacheTime = YES;
            _config.minAutoAdjustCacheTime = CACHE_TIME_FAST;
            _config.maxAutoAdjustCacheTime = CACHE_TIME_FAST;
            [_txLivePlayer setConfig:_config];
            break;
            
        case CACHE_STRATEGY_SMOOTH:
            _config.bAutoAdjustCacheTime = NO;
            _config.cacheTime = CACHE_TIME_SMOOTH;
            [_txLivePlayer setConfig:_config];
            break;
            
        case CACHE_STRATEGY_AUTO:
            _config.bAutoAdjustCacheTime = YES;
            _config.minAutoAdjustCacheTime = CACHE_TIME_FAST;
            _config.maxAutoAdjustCacheTime = CACHE_TIME_SMOOTH;
            [_txLivePlayer setConfig:_config];
            break;
            
        default:
            break;
    }
}

- (void) onAdjustCacheStrategy:(UIButton*) sender
{
#if TEST_MUTE
    static BOOL flag = YES;
//    [_txLivePlayer setMute:flag];
    flag = !flag;
#else
    _vCacheStrategy.hidden = NO;
    switch (_cacheStrategy) {
        case CACHE_STRATEGY_FAST:
            [_radioBtnFast setBackgroundImage:[UIImage imageNamed:@"black"] forState:UIControlStateNormal];
            [_radioBtnFast setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [_radioBtnSmooth setBackgroundImage:[UIImage imageNamed:@"white"] forState:UIControlStateNormal];
            [_radioBtnSmooth setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            [_radioBtnAUTO setBackgroundImage:[UIImage imageNamed:@"white"] forState:UIControlStateNormal];
            [_radioBtnAUTO setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            break;
            
        case CACHE_STRATEGY_SMOOTH:
            [_radioBtnFast setBackgroundImage:[UIImage imageNamed:@"white"] forState:UIControlStateNormal];
            [_radioBtnFast setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            [_radioBtnSmooth setBackgroundImage:[UIImage imageNamed:@"black"] forState:UIControlStateNormal];
            [_radioBtnSmooth setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [_radioBtnAUTO setBackgroundImage:[UIImage imageNamed:@"white"] forState:UIControlStateNormal];
            [_radioBtnAUTO setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            break;
            
        case CACHE_STRATEGY_AUTO:
            [_radioBtnFast setBackgroundImage:[UIImage imageNamed:@"white"] forState:UIControlStateNormal];
            [_radioBtnFast setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            [_radioBtnSmooth setBackgroundImage:[UIImage imageNamed:@"white"] forState:UIControlStateNormal];
            [_radioBtnSmooth setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            [_radioBtnAUTO setBackgroundImage:[UIImage imageNamed:@"black"] forState:UIControlStateNormal];
            [_radioBtnAUTO setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            break;
            
        default:
            break;
    }
#endif
}

- (void) onAdjustFast:(UIButton*) sender
{
    _vCacheStrategy.hidden = YES;
    [self setCacheStrategy:CACHE_STRATEGY_FAST];
}

- (void) onAdjustSmooth:(UIButton*) sender
{
    _vCacheStrategy.hidden = YES;
    [self setCacheStrategy:CACHE_STRATEGY_SMOOTH];
}

- (void) onAdjustAuto:(UIButton*) sender
{
    _vCacheStrategy.hidden = YES;
    [self setCacheStrategy:CACHE_STRATEGY_AUTO];
}

- (void) onClickHardware:(UIButton*) sender {
    
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 8.0) {
        [self toastTip:@"iOS 版本低于8.0，不支持硬件加速."];
        return;
    }
    
    if (_play_switch == YES)
    {
        [self stopRtmp];
    }
    
    _txLivePlayer.enableHWAcceleration = !_bHWDec;
    
    _bHWDec = _txLivePlayer.enableHWAcceleration;
    
    if(_bHWDec)
    {
        [sender setImage:[UIImage imageNamed:@"quick"] forState:UIControlStateNormal];
    }
    else
    {
        [sender setImage:[UIImage imageNamed:@"quick2"] forState:UIControlStateNormal];
    }
    
    if (_play_switch == YES) {
        if (_bHWDec) {
            
            [self toastTip:@"切换为硬解码. 重启播放流程"];
        }
        else
        {
            [self toastTip:@"切换为软解码. 重启播放流程"];
            
        }

        [self startRtmp];
    }

}


-(void) clickScan:(UIButton*) btn
{
    [self stopRtmp];
    _play_switch = NO;
    [_btnPlay setImage:[UIImage imageNamed:@"start"] forState:UIControlStateNormal];
    ScanQRController* vc = [[ScanQRController alloc] init];
    vc.delegate = self;
    [self.navigationController pushViewController:vc animated:NO];
}

#pragma -- UISlider - play seek
-(void)onSeek:(UISlider *)slider{
    [_txLivePlayer seek:_sliderValue];
    _trackingTouchTS = [[NSDate date]timeIntervalSince1970]*1000;
    _startSeek = NO;
    NSLog(@"vod seek drag end");
}

-(void)onSeekBegin:(UISlider *)slider{
    _startSeek = YES;
    NSLog(@"vod seek drag begin");
}

-(void)onDrag:(UISlider *)slider {
    float progress = slider.value;
    int intProgress = progress + 0.5;
    _playStart.text = [NSString stringWithFormat:@"%02d:%02d",(int)(intProgress / 60), (int)(intProgress % 60)];
    _sliderValue = slider.value;
}

#pragma -- UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void) touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [_roomNum resignFirstResponder];
    _vCacheStrategy.hidden = YES;
}


#pragma mark -- ScanQRDelegate
- (void)onScanResult:(NSString *)result
{
    _scanQRUrl = result;
}

- (void)cacheEnable:(id)sender {
    _enableCache = !_enableCache;
    if (_enableCache) {
        [sender setImage:[UIImage imageNamed:@"cache"] forState:UIControlStateNormal];
    } else {
        [sender setImage:[UIImage imageNamed:@"cache2"] forState:UIControlStateNormal];
    }
}
/**
 @method 获取指定宽度width的字符串在UITextView上的高度
 @param textView 待计算的UITextView
 @param Width 限制字符串显示区域的宽度
 @result float 返回的高度
 */
- (float) heightForString:(UITextView *)textView andWidth:(float)width{
    CGSize sizeToFit = [textView sizeThatFits:CGSizeMake(width, MAXFLOAT)];
    return sizeToFit.height;
}

- (void) toastTip:(NSString*)toastInfo
{
    CGRect frameRC = [[UIScreen mainScreen] bounds];
    frameRC.origin.y = frameRC.size.height - 110;
    frameRC.size.height -= 110;
    __block UITextView * toastView = [[UITextView alloc] init];
    
    toastView.editable = NO;
    toastView.selectable = NO;
    
    frameRC.size.height = [self heightForString:toastView andWidth:frameRC.size.width];
    
    toastView.frame = frameRC;
    
    toastView.text = toastInfo;
    toastView.backgroundColor = [UIColor whiteColor];
    toastView.alpha = 0.5;
    
    [self.view addSubview:toastView];
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC);
    
    dispatch_after(popTime, dispatch_get_main_queue(), ^(){
        [toastView removeFromSuperview];
        toastView = nil;
    });
}

#pragma ###TXLivePlayListener
-(void) appendLog:(NSString*) evt time:(NSDate*) date mills:(int)mil
{
    if (evt == nil) {
        return;
    }
    NSDateFormatter* format = [[NSDateFormatter alloc] init];
    format.dateFormat = @"hh:mm:ss";
    NSString* time = [format stringFromDate:date];
    NSString* log = [NSString stringWithFormat:@"[%@.%-3.3d] %@", time, mil, evt];
    if (_logMsg == nil) {
        _logMsg = @"";
    }
    _logMsg = [NSString stringWithFormat:@"%@\n%@", _logMsg, log ];
    [_logViewEvt setText:_logMsg];
}

-(void) onPlayEvent:(int)EvtID withParam:(NSDictionary*)param
{
    NSDictionary* dict = param;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if (EvtID == PLAY_EVT_RCV_FIRST_I_FRAME) {

//            _publishParam = nil;
            if (!self.isLivePlay)
                [_txLivePlayer setupVideoWidget:CGRectMake(0, 0, 0, 0) containView:mVideoContainer insertIndex:0];
        }
        
        if (EvtID == PLAY_EVT_PLAY_BEGIN) {
            [self stopLoadingAnimation];
            long long playDelay = [[NSDate date]timeIntervalSince1970]*1000 - _startPlayTS;
            AppDemoLog(@"AutoMonitor:PlayFirstRender,cost=%lld", playDelay);
        } else if (EvtID == PLAY_EVT_PLAY_PROGRESS) {
            if (_startSeek) {
                return;
            }
            // 避免滑动进度条松开的瞬间可能出现滑动条瞬间跳到上一个位置
            long long curTs = [[NSDate date]timeIntervalSince1970]*1000;
            if (llabs(curTs - _trackingTouchTS) < 500) {
                return;
            }
            _trackingTouchTS = curTs;
            
            float progress = [dict[EVT_PLAY_PROGRESS] floatValue];
            float duration = [dict[EVT_PLAY_DURATION] floatValue];
            
            int intProgress = progress + 0.5;
            _playStart.text = [NSString stringWithFormat:@"%02d:%02d", (int)(intProgress / 60), (int)(intProgress % 60)];
            [_playProgress setValue:progress];
            
            int intDuration = duration + 0.5;
            if (duration > 0 && _playProgress.maximumValue != duration) {
                [_playProgress setMaximumValue:duration];
                [_playableProgress setMaximumValue:duration];
                _playDuration.text = [NSString stringWithFormat:@"%02d:%02d", (int)(intDuration / 60), (int)(intDuration % 60)];
            }
            
            [_playableProgress setValue:[dict[EVT_PLAYABLE_DURATION] floatValue]];
            return ;
        } else if (EvtID == PLAY_ERR_NET_DISCONNECT || EvtID == PLAY_EVT_PLAY_END) {
            [self stopRtmp];
            _play_switch = NO;
            [_btnPlay setImage:[UIImage imageNamed:@"start"] forState:UIControlStateNormal];
            [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
            [_playProgress setValue:0];
             _playStart.text = @"00:00";
            _videoPause = NO;
            
            if (EvtID == PLAY_ERR_NET_DISCONNECT) {
                NSString* Msg = (NSString*)[dict valueForKey:EVT_MSG];
                [self toastTip:Msg];
            }
            
        } else if (EvtID == PLAY_EVT_PLAY_LOADING){
            [self startLoadingAnimation];
        }
        else if (EvtID == PLAY_EVT_CONNECT_SUCC) {
            BOOL isWifi = [AFNetworkReachabilityManager sharedManager].reachableViaWiFi;
            if (!isWifi) {
                __weak __typeof(self) weakSelf = self;
                [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
                    if (_playUrl.length == 0) {
                        return;
                    }
                    if (status == AFNetworkReachabilityStatusReachableViaWiFi) {
                        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@""
                                                                                       message:@"您要切换到Wifi再观看吗?"
                                                                                preferredStyle:UIAlertControllerStyleAlert];
                        [alert addAction:[UIAlertAction actionWithTitle:@"是" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                            [alert dismissViewControllerAnimated:YES completion:nil];
                            [weakSelf stopRtmp];
                            [weakSelf startRtmp];
                        }]];
                        [alert addAction:[UIAlertAction actionWithTitle:@"否" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                            [alert dismissViewControllerAnimated:YES completion:nil];
                        }]];
                        [weakSelf presentViewController:alert animated:YES completion:nil];
                    }
                }];
            }
        }
//        NSLog(@"evt:%d,%@", EvtID, dict);
        long long time = [(NSNumber*)[dict valueForKey:EVT_TIME] longLongValue];
        int mil = time % 1000;
        NSDate* date = [NSDate dateWithTimeIntervalSince1970:time/1000];
        NSString* Msg = (NSString*)[dict valueForKey:EVT_MSG];
        [self appendLog:Msg time:date mills:mil];
    });
}

-(void) onNetStatus:(NSDictionary*) param
{
    NSDictionary* dict = param;

    dispatch_async(dispatch_get_main_queue(), ^{
        int netspeed  = [(NSNumber*)[dict valueForKey:NET_STATUS_NET_SPEED] intValue];
        int vbitrate  = [(NSNumber*)[dict valueForKey:NET_STATUS_VIDEO_BITRATE] intValue];
        int abitrate  = [(NSNumber*)[dict valueForKey:NET_STATUS_AUDIO_BITRATE] intValue];
        int cachesize = [(NSNumber*)[dict valueForKey:NET_STATUS_CACHE_SIZE] intValue];
        int dropsize  = [(NSNumber*)[dict valueForKey:NET_STATUS_DROP_SIZE] intValue];
        int jitter    = [(NSNumber*)[dict valueForKey:NET_STATUS_NET_JITTER] intValue];
        int fps       = [(NSNumber*)[dict valueForKey:NET_STATUS_VIDEO_FPS] intValue];
        int width     = [(NSNumber*)[dict valueForKey:NET_STATUS_VIDEO_WIDTH] intValue];
        int height    = [(NSNumber*)[dict valueForKey:NET_STATUS_VIDEO_HEIGHT] intValue];
        float cpu_usage = [(NSNumber*)[dict valueForKey:NET_STATUS_CPU_USAGE] floatValue];
        float cpu_app_usage = [(NSNumber*)[dict valueForKey:NET_STATUS_CPU_USAGE_D] floatValue];
        NSString *serverIP = [dict valueForKey:NET_STATUS_SERVER_IP];
        int codecCacheSize = [(NSNumber*)[dict valueForKey:NET_STATUS_CODEC_CACHE] intValue];
        int nCodecDropCnt = [(NSNumber*)[dict valueForKey:NET_STATUS_CODEC_DROP_CNT] intValue];
        int nCahcedSize = [(NSNumber*)[dict valueForKey:NET_STATUS_CACHE_SIZE] intValue]/1000;
        int nSetVideoBitrate = [(NSNumber *) [dict valueForKey:NET_STATUS_SET_VIDEO_BITRATE] intValue];
        int videoCacheSize = [(NSNumber *) [dict valueForKey:NET_STATUS_VIDEO_CACHE_SIZE] intValue];
        int vDecCacheSize = [(NSNumber *) [dict valueForKey:NET_STATUS_V_DEC_CACHE_SIZE] intValue];
        int playInterval = [(NSNumber *) [dict valueForKey:NET_STATUS_AV_PLAY_INTERVAL] intValue];
        int avRecvInterval = [(NSNumber *) [dict valueForKey:NET_STATUS_AV_RECV_INTERVAL] intValue];
        float audioPlaySpeed = [(NSNumber *) [dict valueForKey:NET_STATUS_AUDIO_PLAY_SPEED] floatValue];
        NSString * audioInfo = [dict valueForKey:NET_STATUS_AUDIO_INFO];
        int videoGop = (int)([(NSNumber *) [dict valueForKey:NET_STATUS_VIDEO_GOP] doubleValue]+0.5f);
        NSString* log = [NSString stringWithFormat:@"CPU:%.1f%%|%.1f%%\tRES:%d*%d\tSPD:%dkb/s\nJITT:%d\tFPS:%d\tGOP:%ds\tARA:%dkb/s\nQUE:%d|%d,%d,%d|%d,%d,%0.1f\nDRP:%d|%d\tVRA:%dkb/s\nSVR:%@\tAINFO:%@",
                        cpu_app_usage*100,
                         cpu_usage*100,
                         width,
                         height,
                         netspeed,
                         jitter,
                         fps,
                         videoGop,
                         abitrate,
                         codecCacheSize,
                         cachesize,
                         videoCacheSize,
                         vDecCacheSize,
                         avRecvInterval,
                         playInterval,
                         audioPlaySpeed,
                         nCodecDropCnt,
                         dropsize,
                         vbitrate,
                         serverIP,
                         audioInfo];
        [_statusView setText:log];
        AppDemoLogOnlyFile(@"Current status, VideoBitrate:%d, AudioBitrate:%d, FPS:%d, RES:%d*%d, netspeed:%d", vbitrate, abitrate, fps, width, height, netspeed);
    });
}

-(void) startLoadingAnimation
{
    if (_loadingImageView != nil) {
        _loadingImageView.hidden = NO;
        [_loadingImageView startAnimating];
    }
}

-(void) stopLoadingAnimation
{
    if (_loadingImageView != nil) {
        _loadingImageView.hidden = YES;
        [_loadingImageView stopAnimating];
    }
}

- (BOOL)onPlayerPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    return NO;
}

#pragma mark - TXCAVRoomListener
/**
 * 房间成员变化
 * flag为YES: 表示该userID进入房间
 * flag为NO: 表示该userID退出房间
 */
- (void)onMemberChange:(UInt64)userID withFlag:(BOOL)flag {
    if (flag) {
        NSLog(@"%llu enter room", userID);
    } else {
        NSLog(@"%llu exit room", userID);
    }
}

/**
 * 指定userID的视频状态变化通知
 * flag为YES: 表示该userID正在进行视频推流
 * flag为NO: 表示该userID已经停止视频推流
 */
- (void)onVideoStateChange:(UInt64)userID withFlag:(BOOL)flag {
    if (flag) {
        dispatch_async(dispatch_get_main_queue(), ^{
            //
            
            LiveAVPreview *preview = [self getPreviewOf:[NSString stringWithFormat:@"%u", userID]];
            if (preview)
            {
                preview.userID = [NSString stringWithFormat:@"%u", userID];
                [_avRoom startRemoteView:preview.view withUserID:userID];
//                TXCAVRoomPlayerView *playerView = [[TXCAVRoomPlayerView alloc] init];
//                [playerView.view setBackgroundColor:[UIColor blackColor]];
//                [self.view addSubview:playerView.view];
//
//                [_playerViewDic setObject:playerView forKey:@(userID)];
//
//                [self addEventStatusItem:userID];
//
//                // 请求视频
//                [_avRoom startRemoteView:playerView.view withUserID:userID];
//
//                [self relayout];
//
//                [self freshCurrentEvtStatsView];
            }
        });
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            LiveAVPreview *preview = [self getPreviewOf:[NSString stringWithFormat:@"%u", userID]];
            [preview.view removeFromSuperview];
            preview.userID = nil;
            
//            TXCAVRoomPlayerView *playerView = [_playerViewDic objectForKey:@(userID)];
//            [playerView.view removeFromSuperview];
//            [_playerViewDic removeObjectForKey:@(userID)];
//            [self delEventStatusItem:userID];
//
//            [self relayout];
        });
    }
}


- (void)onAVRoomEvent:(UInt64)userID withEventID:(int)eventID andParam:(NSDictionary *)param {
    if (eventID == AVROOM_EVT_UP_CHANGE_BITRATE) {
        // 这个事件会比较频繁，如果频繁刷新UI界面会导致主线程卡住
        return;
    }
    
//    [self appendEventMsg:userID withEventID:eventID andParam:param];
//    
//    [self updateEvtAndStats:_currEvtStatsView index:_evtStatsDataIndex];
    
    if (eventID == AVROOM_WARNING_DISCONNECT)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [_avRoom exitRoom:^(int result) {
                _roomStatus = AVROOM_IDLE;
                [_enterRoom setSelected:NO];
                [self resetPreviews];
//                [_btnJoin setImage:[UIImage imageNamed:@"start"] forState:UIControlStateNormal];
            }];
        });
    }
}

- (void)onAVRoomStatus:(NSArray *)array {
//    for (NSDictionary * statusItem in array) {
//        [self getStatusDescription:statusItem];
//    }
//
//    [self updateEvtAndStats:_currEvtStatsView index:_evtStatsDataIndex];
}
@end
