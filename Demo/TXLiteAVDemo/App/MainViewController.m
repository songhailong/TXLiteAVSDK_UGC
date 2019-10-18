//
//  MainViewController.m
//  RTMPiOSDemo
//
//  Created by rushanting on 2017/4/28.
//  Copyright © 2017年 tencent. All rights reserved.
//

#import "MainViewController.h"
#ifdef ENABLE_PUSH
#import "PublishViewController.h"
#endif
#ifdef ENABLE_PLAY
#import "PlayViewController.h"
#ifndef DISABLE_VOD
#import "PlayVodViewController.h"
#endif
#endif
#ifdef ENABLE_UGC
#import "VideoConfigureViewController.h"
#import "QBImagePickerController.h"
#endif
#if defined(ENABLE_PLAY) && defined(ENABLE_AV)
#import "LiveAVViewController.h"
#endif

#import "VideoLoadingController.h"
#import "ColorMacro.h"
#import "MainTableViewCell.h"
#import "TXLiveBase.h"

#define STATUS_BAR_HEIGHT [UIApplication sharedApplication].statusBarFrame.size.height

#define OLD_VOD 0

@interface MainViewController ()<
#ifdef ENABLE_UGC
QBImagePickerControllerDelegate,
#endif
UITableViewDelegate,
UITableViewDataSource
>

@property (nonatomic) NSMutableArray<CellInfo*>* cellInfos;
@property (nonatomic) UITableView* tableView;

@end

@implementation MainViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
   
    [self initCellInfos];
    [self initUI];
}

- (void)initCellInfos
{
    _cellInfos = [NSMutableArray new];
    CellInfo* cellInfo = nil;
    
    
#if defined(ENABLE_PLAY) && defined(ENABLE_PUSH)
    cellInfo = [CellInfo new];
    cellInfo.title = @"在线答题室";
    cellInfo.iconName = @"qa";
    cellInfo.navigateToController = @"AnswerRoomListViewController";
    [_cellInfos addObject:cellInfo];
#endif

#if defined(ENABLE_PLAY)
    cellInfo = [CellInfo new];
    cellInfo.title = @"答题播放器";
    cellInfo.iconName = @"qa";
    cellInfo.navigateToController = @"AnswerPlayViewController";
    [_cellInfos addObject:cellInfo];
#endif
    
#if defined(ENABLE_PLAY) && defined(ENABLE_PUSH)
    cellInfo = [CellInfo new];
    cellInfo.title = @"直播体验室";
    cellInfo.iconName = @"live_room";
    cellInfo.navigateToController = @"LiveRoomListViewController";
    [_cellInfos addObject:cellInfo];
    
    cellInfo = [CellInfo new];
    cellInfo.title = @"双人音视频";
    cellInfo.iconName = @"double_room";
    cellInfo.navigateToController = @"RTCDoubleRoomListViewController";
    [_cellInfos addObject:cellInfo];
    
    cellInfo = [CellInfo new];
    cellInfo.title = @"多人音视频";
    cellInfo.iconName = @"multi_room";
    cellInfo.navigateToController = @"RTCMultiRoomListViewController";
    [_cellInfos addObject:cellInfo];
#endif
    
#ifndef DISABLE_VOD
#if OLD_VOD || DEBUG
    cellInfo = [CellInfo new];
    cellInfo.title = @"点播播放器";
    cellInfo.iconName = @"vodplay";
    cellInfo.navigateToController = @"PlayVodViewController";
    [_cellInfos addObject:cellInfo];
#endif
    cellInfo = [CellInfo new];
    cellInfo.title = @"超级播放器";
    cellInfo.iconName = @"vodplay";
    cellInfo.navigateToController = @"MoviePlayerViewController";
    [_cellInfos addObject:cellInfo];
#endif
    
#ifdef ENABLE_UGC
    cellInfo = [CellInfo new];
    cellInfo.title = @"短视频录制";
    cellInfo.iconName = @"video";
    cellInfo.navigateToController = @"VideoConfigureViewController";
    [_cellInfos addObject:cellInfo];
    
    cellInfo = [CellInfo new];
    cellInfo.title = @"短视频特效";
    cellInfo.iconName = @"cut";
    cellInfo.navigateToController = @"QBImagePickerController";
    [_cellInfos addObject:cellInfo];
    
    cellInfo = [CellInfo new];
    cellInfo.title = @"短视频拼接";
    cellInfo.iconName = @"composite";
    cellInfo.navigateToController = @"QBImagePickerController";
    [_cellInfos addObject:cellInfo];
#endif
    
#ifdef ENABLE_PUSH
    cellInfo = [CellInfo new];
    cellInfo.title = @"RTMP 推流";
    cellInfo.iconName = @"push";
    cellInfo.navigateToController = @"PublishViewController";
    [_cellInfos addObject:cellInfo];
    
//    cellInfo = [CellInfo new];
//    cellInfo.title = @"推流+";
//    cellInfo.iconName = @"push";
//    cellInfo.navigateToController = @"PublishViewController";
//    [_cellInfos addObject:cellInfo];
#endif
    
#ifdef ENABLE_PLAY
    cellInfo = [CellInfo new];
    cellInfo.title = @"直播播放器";
    cellInfo.iconName = @"liveplay";
    cellInfo.navigateToController = @"PlayViewController";
    [_cellInfos addObject:cellInfo];
    
    
    cellInfo = [CellInfo new];
    cellInfo.title = @"低延时播放";
    cellInfo.iconName = @"realtime-player";
    cellInfo.navigateToController = @"PlayViewController";
    [_cellInfos addObject:cellInfo];

#endif
    
#ifdef ENABLE_AV
    cellInfo = [CellInfo new];
    cellInfo.title = @"视频小派对";
    cellInfo.iconName = @"avroom";
    cellInfo.navigateToController = @"AVRoomViewController";
    [_cellInfos addObject:cellInfo];
#endif


//#if defined(ENABLE_PLAY) && defined(ENABLE_AV)
//    cellInfo = [CellInfo new];
//    cellInfo.title = @"直播+会议";
//    cellInfo.iconName = @"avroom";
//    cellInfo.navigateToController = @"LiveAVViewController";
//    [_cellInfos addObject:cellInfo];
//#endif
    
//#if defined(ENABLE_PUSH) && defined(ENABLE_PLAY)
//    cellInfo = [CellInfo new];
//    cellInfo.title = @"连麦";
//    cellInfo.iconName = @"mic";
//    cellInfo.navigateToController = @"LinkMicViewController";
//    [_cellInfos addObject:cellInfo];
//#endif

}

- (void)initUI
{
    int originX = 15;
    CGFloat width = self.view.frame.size.width - 2 * originX;
    
    self.view.backgroundColor = UIColorFromRGB(0x0d0d0d);
    
    //大标题
    UILabel* lbHeadLine = [[UILabel alloc] initWithFrame:CGRectMake(originX, 50, width, 48)];
    lbHeadLine.text = @"腾讯视频云";
    lbHeadLine.textColor = UIColorFromRGB(0xffffff);
    lbHeadLine.textAlignment = NSTextAlignmentLeft;
    lbHeadLine.font = [UIFont systemFontOfSize:24];
    [lbHeadLine sizeToFit];
    [self.view addSubview:lbHeadLine];
    
    //副标题
    UILabel* lbSubHead = [[UILabel alloc] initWithFrame:CGRectMake(originX, lbHeadLine.frame.origin.y + lbHeadLine.frame.size.height + 15, width, 50)];
    lbSubHead.numberOfLines = 2;
    lbSubHead.text = @"本 DEMO 以最精简的代码展示视频腾讯云 SDK 的使用方法，最新版微信可搜索同名 \"小程序\"";
    lbSubHead.textColor = UIColor.grayColor;
    lbSubHead.textAlignment = NSTextAlignmentLeft;
    lbSubHead.font = [UIFont systemFontOfSize:14];
    lbSubHead.textColor = UIColorFromRGB(0xdddddd);
    //行间距
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:lbSubHead.text];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setLineSpacing:7.5f];//设置行间距
    [attributedString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, lbSubHead.text.length)];
    lbSubHead.attributedText = attributedString;
    [self.view addSubview:lbSubHead];
    
    //功能列表
    int tableviewY = lbSubHead.frame.origin.y + lbSubHead.frame.size.height + 30;
    _tableView = [[UITableView alloc] initWithFrame:CGRectMake(originX, tableviewY, width, self.view.frame.size.height - tableviewY)];
    _tableView.backgroundColor = UIColor.clearColor;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [self.view addSubview:_tableView];
    
    UIView *view = [UIView new];
    view.backgroundColor = [UIColor clearColor];
    [_tableView setTableFooterView:view];
    
    _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;

}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _cellInfos.count;
}


- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (_cellInfos.count < indexPath.row)
        return nil;
    
    static NSString* cellIdentifier = @"MainViewCellIdentifier";
    MainTableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[MainTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    
    CellInfo* cellInfo = _cellInfos[indexPath.row];

    [cell setCellData:cellInfo];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (_cellInfos.count < indexPath.row)
        return ;
    
    CellInfo* cellInfo = _cellInfos[indexPath.row];

    NSString* controllerClassName = cellInfo.navigateToController;
    Class controllerClass = NSClassFromString(controllerClassName);
    id controller = [[controllerClass alloc] init];

    
#ifdef ENABLE_PUSH
//    if ([cellInfo.title isEqualToString:@"推流"]) {
//        ((PublishViewController*)controller).enableNearestIP = NO;
//    }
//    if ([cellInfo.title isEqualToString:@"推流+"]) {
//        ((PublishViewController*)controller).enableNearestIP = YES;
//    }
#endif
    
#ifdef ENABLE_PLAY
    if ([cellInfo.title isEqualToString:@"直播播放器"]) {
        ((PlayViewController*)controller).isLivePlay = YES;
    }
    else if ([cellInfo.title isEqualToString:@"低延时播放"]) {
        ((PlayViewController*)controller).isLivePlay = YES;
        ((PlayViewController*)controller).isRealtime = YES;
    }
#endif
    
#if defined(ENABLE_PLAY) && defined(ENABLE_AV)
    if ([cellInfo.title isEqualToString:@"直播+会议"]) {
        ((LiveAVViewController*)controller).isLivePlay = YES;
    }
#endif
    
#ifdef ENABLE_UGC
    if ([controller isKindOfClass:[VideoConfigureViewController class]]) {
        controller = [[VideoConfigureViewController alloc] initWithNibName:@"VideoConfigureViewController" bundle:nil];
    }
    if ([controller isKindOfClass:[QBImagePickerController class]]) {
        QBImagePickerController* imagePicker = ((QBImagePickerController*)controller);
        imagePicker.mediaType = QBImagePickerMediaTypeVideo;
        imagePicker.delegate = self;

        if ([cellInfo.title isEqualToString:@"短视频拼接"]) {
            imagePicker.allowsMultipleSelection = YES;
            imagePicker.showsNumberOfSelectedAssets = YES;
            imagePicker.maximumNumberOfSelection = 10;
        } else {
            imagePicker.allowsMultipleSelection = NO;
            imagePicker.showsNumberOfSelectedAssets = NO;
        }
    }
#endif
    [self.navigationController pushViewController:controller animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 65;
}

#ifdef ENABLE_UGC
#pragma mark - QBImagePickerControllerDelegate
- (void)qb_imagePickerController:(QBImagePickerController *)imagePickerController didFinishPickingAssets:(NSArray *)assets
{
    [self.navigationController popViewControllerAnimated:YES];
    
    VideoLoadingController *loadvc = [[VideoLoadingController alloc] init];
    NSInteger selectedRow = _tableView.indexPathForSelectedRow.row;
    if (selectedRow >= _cellInfos.count)
        return;
    
    CellInfo* cellInfo = _cellInfos[selectedRow];
    if ([cellInfo.title isEqualToString:@"短视频特效"]) {
        loadvc.composeMode = NO;
    } else if ([cellInfo.title isEqualToString:@"短视频拼接"]) {
        loadvc.composeMode = YES;
    } else return;
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:loadvc];
    [self presentViewController:nav animated:YES completion:nil];
    [loadvc exportAssetList:assets];
}

- (void)qb_imagePickerControllerDidCancel:(QBImagePickerController *)imagePickerController
{
    NSLog(@"imagePicker Canceled.");
    
    [self.navigationController popViewControllerAnimated:YES];

}
#endif

@end
