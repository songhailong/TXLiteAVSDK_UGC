//
//  VideoLoadingController.m
//  TCLVBIMDemo
//
//  Created by annidyfeng on 2017/4/17.
//  Copyright © 2017年 tencent. All rights reserved.
//

#import "VideoLoadingController.h"
#import "VideoEditViewController.h"
#import "VideoJoinerController.h"
#import <Photos/Photos.h>

@interface VideoLoadingController ()
@property IBOutlet UIImageView *loadingImageView;
@property (weak, nonatomic) IBOutlet UILabel *loadingLabel;
@property NSMutableArray *localPaths;
@property NSArray     *videosAssets;
@property NSMutableArray     *videosToEditAssets;
@property NSUInteger  exportIndex;
@property AVMutableComposition *mutableComposition;
@property AVMutableVideoComposition *mutableVideoComposition;
@end

@implementation VideoLoadingController
{
    BOOL  _loadingIsInterrupt;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.title = @"选择视频";
    self.view.backgroundColor = UIColor.blackColor;
    
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onAudioSessionEvent:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (IBAction)cancelLoad:(id)sender {
    _loadingIsInterrupt = YES;
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}

- (void) onAudioSessionEvent: (NSNotification *) notification
{
    NSDictionary *info = notification.userInfo;
    AVAudioSessionInterruptionType type = [info[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (type == AVAudioSessionInterruptionTypeBegan) {
        _loadingIsInterrupt = YES;
        [self exportAssetError];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)exportAssetList:(NSArray *)videosAssets
{
    _videosAssets = videosAssets;
    _exportIndex = 0;
    _localPaths = [NSMutableArray new];
    _videosToEditAssets = [NSMutableArray array];
    [self exportAssetInternal];
}

- (void)exportAssetInternal
{
    if (_exportIndex == _videosAssets.count) {
        if (!self.composeMode) {
            VideoEditViewController *vc = [VideoEditViewController new];
            //vc.videoPath = _localPaths[0];
            vc.videoAsset = _videosToEditAssets[0];
            if(!_loadingIsInterrupt) [self.navigationController pushViewController:vc animated:YES];
            return;
        } else {
            VideoJoinerController *vc = [VideoJoinerController new];
//            vc.videoList = _localPaths;
            vc.videoAssertList = _videosToEditAssets;
            if(!_loadingIsInterrupt) [self.navigationController pushViewController:vc animated:YES];
            return;
        }
    }
    
    self.mutableComposition = nil;
    self.mutableVideoComposition = nil;
    
    __weak __typeof(self) weakSelf = self;
//    __block AVAssetExportSession *weakExportSession = _exportSession;
    PHAsset *expAsset = _videosAssets[_exportIndex];
    PHVideoRequestOptions *options = [PHVideoRequestOptions new];
    // 最高质量的视频
    options.deliveryMode = PHVideoRequestOptionsDeliveryModeHighQualityFormat;
    // 可从iCloud中获取图片
    options.networkAccessAllowed = YES;
    // 如果是iCloud的视频，可以获取到下载进度
    options.progressHandler = ^(double progress, NSError * _Nullable error, BOOL * _Nonnull stop, NSDictionary * _Nullable info) {
        [weakSelf loadingCloudVideoProgress:progress];
        *stop = _loadingIsInterrupt;
    };
    [[PHImageManager defaultManager] requestAVAssetForVideo:expAsset options:options resultHandler:^(AVAsset * _Nullable avAsset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
        //SDK内部通过avAsset 读取视频数据，会极大的降低视频loading时间
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            if (avAsset) {
                [_videosToEditAssets addObject:avAsset];
                _exportIndex++;
                [self exportAssetInternal];
            }
        });
    }];
}

- (void)exportAssetError
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:@"视频导出失败，原因可能是在导出的过程中，程序进后台，或则被闹钟，电话等打断" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"好" style:0 handler:^(UIAlertAction * _Nonnull action) {
        [self.navigationController dismissViewControllerAnimated:YES completion:nil];
    }];
    [alert addAction:ok];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)loadingCloudVideoProgress:(float)progress
{
    dispatch_async(dispatch_get_main_queue(), ^{
        _loadingLabel.text =  [NSString stringWithFormat:@"视频 %@ 正在从icloud下载，请稍等...",@(_exportIndex + 1)];
        self.loadingImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"video_record_share_loading_%d", (int)(progress * 8)]];
    });
}

#define degreesToRadians( degrees ) ( ( degrees ) / 180.0 * M_PI )

- (void)performWithAsset:(AVAsset*)asset rotate:(CGFloat)angle
{
    AVMutableVideoCompositionInstruction *instruction = nil;
    AVMutableVideoCompositionLayerInstruction *layerInstruction = nil;
    CGAffineTransform t1;
    CGAffineTransform t2;
    
    AVAssetTrack *assetVideoTrack = nil;
    AVAssetTrack *assetAudioTrack = nil;
    // Check if the asset contains video and audio tracks
    if ([[asset tracksWithMediaType:AVMediaTypeVideo] count] != 0) {
        assetVideoTrack = [asset tracksWithMediaType:AVMediaTypeVideo][0];
    }
    if ([[asset tracksWithMediaType:AVMediaTypeAudio] count] != 0) {
        assetAudioTrack = [asset tracksWithMediaType:AVMediaTypeAudio][0];
    }
    
    CMTime insertionPoint = kCMTimeZero;
    NSError *error = nil;
    
    
    // Step 1
    // Create a composition with the given asset and insert audio and video tracks into it from the asset
    if (!self.mutableComposition) {
        
        // Check whether a composition has already been created, i.e, some other tool has already been applied
        // Create a new composition
        self.mutableComposition = [AVMutableComposition composition];
        
        // Insert the video and audio tracks from AVAsset
        if (assetVideoTrack != nil) {
            AVMutableCompositionTrack *compositionVideoTrack = [self.mutableComposition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
            [compositionVideoTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, [asset duration]) ofTrack:assetVideoTrack atTime:insertionPoint error:&error];
        }
        if (assetAudioTrack != nil) {
            AVMutableCompositionTrack *compositionAudioTrack = [self.mutableComposition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
            [compositionAudioTrack insertTimeRange:CMTimeRangeMake(kCMTimeZero, [asset duration]) ofTrack:assetAudioTrack atTime:insertionPoint error:&error];
        }
        
    }
    
    
    // Step 2
    // Translate the composition to compensate the movement caused by rotation (since rotation would cause it to move out of frame)
    if (angle == 90)
    {
        t1 = CGAffineTransformMakeTranslation(assetVideoTrack.naturalSize.height, 0.0);
    }else if (angle == -90){
        t1 = CGAffineTransformMakeTranslation(0.0, assetVideoTrack.naturalSize.width);
    } else {
        return;
    }
    // Rotate transformation
    t2 = CGAffineTransformRotate(t1, degreesToRadians(angle));
    
    
    // Step 3
    // Set the appropriate render sizes and rotational transforms
    if (!self.mutableVideoComposition) {
        
        // Create a new video composition
        self.mutableVideoComposition = [AVMutableVideoComposition videoComposition];
        self.mutableVideoComposition.renderSize = CGSizeMake(assetVideoTrack.naturalSize.height,assetVideoTrack.naturalSize.width);
        self.mutableVideoComposition.frameDuration = CMTimeMake(1, 30);
        
        // The rotate transform is set on a layer instruction
        instruction = [AVMutableVideoCompositionInstruction videoCompositionInstruction];
        instruction.timeRange = CMTimeRangeMake(kCMTimeZero, [self.mutableComposition duration]);
        layerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:(self.mutableComposition.tracks)[0]];
        [layerInstruction setTransform:t2 atTime:kCMTimeZero];
        
    } else {
        
        self.mutableVideoComposition.renderSize = CGSizeMake(self.mutableVideoComposition.renderSize.height, self.mutableVideoComposition.renderSize.width);
        
        // Extract the existing layer instruction on the mutableVideoComposition
        instruction = (self.mutableVideoComposition.instructions)[0];
        layerInstruction = (instruction.layerInstructions)[0];
        
        // Check if a transform already exists on this layer instruction, this is done to add the current transform on top of previous edits
        CGAffineTransform existingTransform;
        
        if (![layerInstruction getTransformRampForTime:[self.mutableComposition duration] startTransform:&existingTransform endTransform:NULL timeRange:NULL]) {
            [layerInstruction setTransform:t2 atTime:kCMTimeZero];
        } else {
            // Note: the point of origin for rotation is the upper left corner of the composition, t3 is to compensate for origin
            CGAffineTransform t3 = CGAffineTransformMakeTranslation(-1*assetVideoTrack.naturalSize.height/2, 0.0);
            CGAffineTransform newTransform = CGAffineTransformConcat(existingTransform, CGAffineTransformConcat(t2, t3));
            [layerInstruction setTransform:newTransform atTime:kCMTimeZero];
        }
        
    }
    
    
    // Step 4
    // Add the transform instructions to the video composition
    instruction.layerInstructions = @[layerInstruction];
    self.mutableVideoComposition.instructions = @[instruction];
    
    
    // Step 5
    // Notify AVSEViewController about rotation operation completion
    //    [[NSNotificationCenter defaultCenter] postNotificationName:AVSEEditCommandCompletionNotification object:self];
}

@end


@implementation PHAsset (My)

- (NSString *)orignalFilename {
    NSString *filename;
    if ([[PHAssetResource class] instancesRespondToSelector:@selector(assetResourcesForAsset:)]) {
        NSArray *resources = [PHAssetResource assetResourcesForAsset:self];
        PHAssetResource *resource = resources.firstObject;
        if (resources) {
            filename = resource.originalFilename;
        }
    }
    if (filename == nil) {
        filename = [self valueForKey:@"filename"];
        if (filename == nil ||
            ![filename isKindOfClass:[NSString class]]) {
            filename = [NSString stringWithFormat:@"temp%ld", time(NULL)];
        }
    }
    
    return filename;
}

@end


static inline CGFloat RadiansToDegrees(CGFloat radians) {
    return radians * 180 / M_PI;
};

@implementation AVAsset (My)
@dynamic videoOrientation;

- (LBVideoOrientation)videoOrientation
{
    NSArray *videoTracks = [self tracksWithMediaType:AVMediaTypeVideo];
    if ([videoTracks count] == 0) {
        return LBVideoOrientationNotFound;
    }
    
    AVAssetTrack* videoTrack    = [videoTracks objectAtIndex:0];
    CGAffineTransform txf       = [videoTrack preferredTransform];
    CGFloat videoAngleInDegree  = RadiansToDegrees(atan2(txf.b, txf.a));
    
    LBVideoOrientation orientation = 0;
    switch ((int)videoAngleInDegree) {
        case 0:
            orientation = LBVideoOrientationRight;
            break;
        case 90:
            orientation = LBVideoOrientationUp;
            break;
        case 180:
            orientation = LBVideoOrientationLeft;
            break;
        case -90:
            orientation	= LBVideoOrientationDown;
            break;
        default:
            orientation = LBVideoOrientationNotFound;
            break;
    }
    
    return orientation;
}

@end
