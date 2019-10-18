    //
//  MoviePlayerViewController.m
//
// Copyright (c) 2016年 任子丰 ( http://github.com/renzifeng )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MoviePlayerViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import <Masonry/Masonry.h>
#import "ZFPlayer.h"
#import "UINavigationController+ZFFullscreenPopGesture.h"
#import "ScanQRController.h"
#import "UIImage+Additions.h"
#import "ListVideoCell.h"
#import "TXPlayerAuthParams.h"
#import "TXVodPlayer.h"

#define LIST_VIDEO_CELL_ID @"LIST_VIDEO_CELL_ID"

__weak UITextField *appField;
__weak UITextField *fileidField;

@interface MoviePlayerViewController () <ZFPlayerDelegate, ScanQRDelegate, UITableViewDelegate, UITableViewDataSource,TXVodPlayListener>
/** 播放器View的父视图*/
@property (nonatomic) UIView *playerFatherView;
@property (strong, nonatomic) ZFPlayerView *playerView;
/** 离开页面时候是否在播放 */
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, strong) ZFPlayerModel *playerModel;
@property (nonatomic, strong) UIView *bottomView;
@property (weak, nonatomic) IBOutlet UIButton *backBtn;
@property (nonatomic, strong) UITextField *textView;

@property (nonatomic, strong) UITableView *videoListView;
@property NSMutableArray *authParamArray;
@property NSMutableArray *dataSourceArray;
@property TXVodPlayer *getInfoPlayer;

@end

@implementation MoviePlayerViewController

- (void)dealloc {
    NSLog(@"%@释放了",self.class);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.hidden = NO;
    
    
    UIImageView *imageView=[[UIImageView alloc] initWithFrame:self.view.bounds];
    imageView.image=[UIImage imageNamed:@"背景"];
    [self.view insertSubview:imageView atIndex:0];
    
    // 右侧
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    //修改按钮向右移动10pt
    [button setFrame:CGRectMake(0, 0, 60, 25)];
    [button setBackgroundImage:[UIImage imageNamed:@"扫码"] forState:UIControlStateNormal];
    [button addTarget:self action:@selector(clickScan:) forControlEvents:UIControlEventTouchUpInside];
    [button sizeToFit];
    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithCustomView:button];
    self.navigationItem.rightBarButtonItems = @[rightItem];

    // 左侧
    UIButton *leftbutton = [UIButton buttonWithType:UIButtonTypeCustom];
    //修改按钮向右移动10pt
    [leftbutton setFrame:CGRectMake(0, 0, 60, 25)];
    [leftbutton setBackgroundImage:[UIImage imageNamed:@"返回"] forState:UIControlStateNormal];
    [leftbutton addTarget:self action:@selector(backClick) forControlEvents:UIControlEventTouchUpInside];
    [leftbutton sizeToFit];
    UIBarButtonItem *leftItem = [[UIBarButtonItem alloc] initWithCustomView:leftbutton];
    self.navigationItem.leftBarButtonItems = @[leftItem];
    
    self.title = @"超级播放器";
//    // 中间
//    self.navigationItem.titleView = ({
//        UITextField *textView = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, ScreenWidth-120, self.navigationController.navigationBar.bounds.size.height-8)];
//        textView.textColor = [UIColor whiteColor];
//        textView.backgroundColor = [UIColor clearColor];
//        UIImageView *imgView = [[UIImageView alloc]initWithFrame: textView.frame];
//        imgView.image = [UIImage imageNamed: @"搜索框"];
//        [textView addSubview: imgView];
//        [textView sendSubviewToBack: imgView];
//        self.textView = textView;
//        textView;
//    });
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.navigationBar.hidden = YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _authParamArray = [NSMutableArray new];
    _dataSourceArray = [NSMutableArray new];
    
    TXPlayerAuthParams *p = [TXPlayerAuthParams new];
    p.appId = 1252463788;
    p.fileId = @"4564972819220421305";
    [_authParamArray addObject:p];
    
    p = [TXPlayerAuthParams new];
    p.appId = 1252463788;
    p.fileId = @"4564972819219071568";
    [_authParamArray addObject:p];
    
    p = [TXPlayerAuthParams new];
    p.appId = 1252463788;
    p.fileId = @"4564972819219071668";
    [_authParamArray addObject:p];
    
    p = [TXPlayerAuthParams new];
    p.appId = 1252463788;
    p.fileId = @"4564972819219071679";
    [_authParamArray addObject:p];
    
//    p = [TXPlayerAuthParams new];
//    p.appId = 1252463788;
//    p.fileId = @"4564972819219071693";
//    [_authParamArray addObject:p];
    
    p = [TXPlayerAuthParams new];
    p.appId = 1252463788;
    p.fileId = @"4564972819219081699";
    [_authParamArray addObject:p];
    
    [self getNextInfo];
    
    self.zf_prefersNavigationBarHidden = NO;
    self.videoURL = [NSURL URLWithString:@"http://1252463788.vod2.myqcloud.com/95576ef5vodtransgzp1252463788/68e3febf4564972819220421305/master_playlist.m3u8"];
    
    self.playerFatherView = [[UIView alloc] init];
    self.playerFatherView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:self.playerFatherView];
    [self.playerFatherView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(20+self.navigationController.navigationBar.bounds.size.height);
        make.leading.trailing.mas_equalTo(0);
        // 这里宽高比16：9,可自定义宽高比
        make.height.mas_equalTo(self.playerFatherView.mas_width).multipliedBy(9.0f/16.0f);
    }];
    [self.playerView autoPlayTheVideo];
    
    UILabel *label_v = [[UILabel alloc] initWithFrame:CGRectZero];
    label_v.text = @"视频列表";
    label_v.textColor = [UIColor whiteColor];
    label_v.font = [UIFont systemFontOfSize:18];
    [self.view addSubview:label_v];
    [label_v mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(self.playerFatherView.mas_bottom).offset(20);
        make.left.mas_equalTo(15);
    }];
    [label_v sizeToFit];
    
    self.videoListView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.videoListView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.videoListView];
    [self.videoListView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(label_v.mas_bottom).offset(5);
        make.left.mas_equalTo(0);
        make.leading.trailing.mas_equalTo(0);
        make.bottom.mas_equalTo(self.view.mas_bottom);
    }];
    self.videoListView.delegate = self;
    self.videoListView.dataSource = self;
    [self.videoListView registerClass:[ListVideoCell class] forCellReuseIdentifier:LIST_VIDEO_CELL_ID];
    
    UIView *tableFooterView = [UIView new];
    tableFooterView.frame = CGRectMake(0, 0, ScreenWidth, 80);
    self.videoListView.tableFooterView = tableFooterView;
    [self.videoListView setSeparatorColor:[UIColor clearColor]];
    
    // 定义一个button
    UIButton *addButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [addButton setImage:[UIImage imageNamed:@"addp"] forState:UIControlStateNormal];
    [self.view addSubview:addButton];
    [addButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.mas_equalTo(label_v.mas_centerY);
        make.right.mas_equalTo(self.view.mas_right).offset(-15);
    }];
    [addButton addTarget:self action:@selector(onAddClick:) forControlEvents:UIControlEventTouchUpInside];
}

// 返回值要必须为NO
- (BOOL)shouldAutorotate {
    return NO;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    // 这里设置横竖屏不同颜色的statusbar
    // if (ZFPlayerShared.isLandscape) {
    //    return UIStatusBarStyleDefault;
    // }
    return UIStatusBarStyleLightContent;
}

- (BOOL)prefersStatusBarHidden {
    return ZFPlayerShared.isStatusBarHidden;
}

#pragma mark - ZFPlayerDelegate

- (void)zf_playerBackAction {
    [self backClick];
}

- (void)zf_playerDownload:(NSString *)url {

}

- (void)zf_playerControlViewWillShow:(UIView *)controlView isFullscreen:(BOOL)fullscreen {

}

- (void)zf_playerControlViewWillHidden:(UIView *)controlView isFullscreen:(BOOL)fullscreen {

}

#pragma mark - Getter

- (ZFPlayerModel *)playerModel {
    if (!_playerModel) {
        _playerModel                  = [[ZFPlayerModel alloc] init];
        _playerModel.title            = @"小直播宣传视频";
        _playerModel.videoURL         = self.videoURL;
        _playerModel.placeholderImage = [UIImage imageNamed:@"loading_bgView1"];
        _playerModel.fatherView       = self.playerFatherView;
    }
    return _playerModel;
}

- (ZFPlayerView *)playerView {
    if (!_playerView) {
        _playerView = [[ZFPlayerView alloc] init];
        
        /*****************************************************************************************
         *   // 指定控制层(可自定义)
         *   // ZFPlayerControlView *controlView = [[ZFPlayerControlView alloc] init];
         *   // 设置控制层和播放模型
         *   // 控制层传nil，默认使用ZFPlayerControlView(如自定义可传自定义的控制层)
         *   // 等效于 [_playerView playerModel:self.playerModel];
         ******************************************************************************************/
        [_playerView playerControlView:nil playerModel:self.playerModel];
        
        // 设置代理
        _playerView.delegate = self;
        
        //（可选设置）可以设置视频的填充模式，内部设置默认（ZFPlayerLayerGravityResizeAspect：等比例填充，直到一个维度到达区域边界）
        // _playerView.playerLayerGravity = ZFPlayerLayerGravityResize;
        
        // 打开下载功能（默认没有这个功能）
//        _playerView.hasDownload    = YES;
        
        // 打开预览图
        self.playerView.hasPreviewView = YES;

    }
    return _playerView;
}

- (void)onPlayEvent:(TXVodPlayer *)player event:(int)EvtID withParam:(NSDictionary *)param
{
    if (EvtID == PLAY_ERR_GET_PLAYINFO_FAIL) {
        
    }
    
    if (EvtID == PLAY_EVT_GET_PLAYINFO_SUCC) {
        ListVideoModel *model = [ListVideoModel new];
        model.cover = param[EVT_PLAY_COVER_URL];
        model.duration = [param[EVT_PLAY_DURATION] intValue];
        model.url = param[EVT_PLAY_URL];
        
        [_dataSourceArray addObject:model];
        [_videoListView reloadData];
    }
    
    [player stopPlay];
    [self getNextInfo];
}

- (void)getNextInfo {
    if (_authParamArray.count == 0)
        return;
    TXPlayerAuthParams *p = [_authParamArray objectAtIndex:0];
    [_authParamArray removeObject:p];
    
    self.getInfoPlayer = [[TXVodPlayer alloc] init];
    [self.getInfoPlayer setIsAutoPlay:NO];
    self.getInfoPlayer.vodDelegate = self;
    [self.getInfoPlayer startPlayWithParams:p];
}

#pragma mark - Action

- (IBAction)backClick {
    [self.playerView resetPlayer];  //非常重要
    [self.navigationController popViewControllerAnimated:YES];
}


-(void) clickScan:(UIButton*) btn
{
    ScanQRController* vc = [[ScanQRController alloc] init];
    vc.delegate = self;
    [self.navigationController pushViewController:vc animated:NO];
}

- (void)onScanResult:(NSString *)result
{
    self.textView.text = result;
    self.playerModel.title            = @"这是新播放的视频";
    self.playerModel.videoURL         = [NSURL URLWithString:result];
    [self.playerView resetToPlayNewVideo:self.playerModel];
}

- (void)onAddClick:(UIButton *)btn
{
    UIAlertController *control = [UIAlertController alertControllerWithTitle:@"添加视频" message:@"" preferredStyle:UIAlertControllerStyleAlert];
    
    [control addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"请输入appid";
        appField = textField;
    }];
    
    [control addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"请输入fileid";
        fileidField = textField;
    }];
    
    [control addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
        TXPlayerAuthParams *p = [TXPlayerAuthParams new];
        p.appId = [appField.text intValue];
        p.fileId = fileidField.text;
        [_authParamArray addObject:p];
        
        [self getNextInfo];
        
    }]];
     
    [control addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
    }]];
    
    [self.navigationController presentViewController:control animated:YES completion:nil];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath; {
    return 78;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
{
    return _dataSourceArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
{
    NSInteger row = indexPath.row;
    ListVideoModel *param = [_dataSourceArray objectAtIndex:row];
    if (param) {
        ListVideoCell *cell = [tableView dequeueReusableCellWithIdentifier:LIST_VIDEO_CELL_ID];
        [cell setDataSource:param];
        return cell;
    }
    return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    ListVideoCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if (cell) {
        _playerModel.title = [cell getSource].title;
        _playerModel.videoURL = [NSURL URLWithString:[cell getSource].url];
        _playerModel.placeholderImage = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:[cell getSource].cover]]];
        
        [_playerView resetToPlayNewVideo:self.playerModel];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return YES if you want the specified item to be editable.
    return YES;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [_dataSourceArray removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];

    }
}
@end
