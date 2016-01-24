//
//  FirstViewController.m
//  LivePhotoMaker
//
//  Created by tako on 2016/01/24.
//  Copyright © 2016年 tako. All rights reserved.
//

#import "FirstViewController.h"

#import "AWPlayer.h"
#import <QBImagePickerController/QBImagePickerController.h>
#import "LivePhotoMaker-Swift.h"

@import MobileCoreServices;

@interface FirstViewController () <QBImagePickerControllerDelegate>

@property (strong, nonatomic) IBOutlet AWPlayer *awPlayer;
@property (strong, nonatomic) AVPlayerItem *playerItem;
@property (strong, nonatomic) AVPlayer *videoPlayer;
@property (weak, nonatomic) IBOutlet UISlider *sliderTime;
@property (nonatomic, assign) id playTimeObserver;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *buttonMake;

@property (weak, nonatomic) IBOutlet UILabel *labelLicense;

@property (strong, nonatomic) NSString *genUUID;

@end

@implementation FirstViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        self.sliderTime.hidden = YES;
        self.buttonMake.enabled = NO;
        [self.labelLicense setText:@"LivePhotoMaker by @tako0910\nCore technology (LoveLiver) by @mzp"];
    });
}

#pragma mark - AWPlayer
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    const AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
    
    switch (status) {
        case AVPlayerStatusReadyToPlay:
            // [self.videoPlayer play];
            [self setupSeekBar];
            break;
        case AVPlayerStatusFailed:
            NSLog(@"error: %@", self.videoPlayer.error);
            break;
        default:
            break;
    }
}

- (void)setupSeekBar
{
    self.sliderTime.minimumValue = 0;
    self.sliderTime.maximumValue = CMTimeGetSeconds( self.playerItem.duration );
    self.sliderTime.value = 0;
    [self.sliderTime addTarget:self action:@selector(seekBarValueChanged:) forControlEvents:UIControlEventValueChanged];
    
    __block FirstViewController *blockself = self;
    
    Float64 interval = ( 0.1f * self.sliderTime.maximumValue ) / self.sliderTime.bounds.size.width;
    CMTime time = CMTimeMakeWithSeconds( interval, NSEC_PER_SEC );
    self.playTimeObserver = [self.videoPlayer addPeriodicTimeObserverForInterval:time
                                                                           queue:dispatch_get_main_queue()
                                                                      usingBlock:^( CMTime time ) { [blockself syncSeekBar]; }];
}

- (void)syncSeekBar
{
    Float64 duration = CMTimeGetSeconds( [self.videoPlayer.currentItem duration] );
    Float64 time = CMTimeGetSeconds([self.videoPlayer currentTime]);
    Float32 value = ( self.sliderTime.maximumValue - self.sliderTime.minimumValue ) * time / duration + self.sliderTime.minimumValue;
    
    [self.sliderTime setValue:value];
}

- (void)seekBarValueChanged:(UISlider *)slider
{
    [self.videoPlayer seekToTime:CMTimeMakeWithSeconds( slider.value, NSEC_PER_SEC ) toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero];
}

#pragma mark - IB Actions
- (IBAction)pushAdd:(id)sender {
    
    QBImagePickerController *imagePickerController = [QBImagePickerController new];
    imagePickerController.delegate = self;
    
    imagePickerController.allowsMultipleSelection = NO;
    
    imagePickerController.assetCollectionSubtypes = @[
                                                      @(PHAssetCollectionSubtypeSmartAlbumVideos)
                                                      ];
    
    imagePickerController.mediaType = QBImagePickerMediaTypeVideo;
    
    [self presentViewController:imagePickerController animated:YES completion:nil];
}

#pragma mark - QBImagePickerController Delegate
- (void)qb_imagePickerController:(QBImagePickerController *)imagePickerController didFinishPickingAssets:(NSArray *)assets {
    
    [self dismissViewControllerAnimated:YES completion:^{
        self.awPlayer.hidden = NO;
        self.sliderTime.hidden = NO;
        self.labelLicense.hidden = YES;
        self.buttonMake.enabled = YES;
    }];
    
    [self.playerItem removeObserver:self forKeyPath:@"status"];
    
    PHAsset *asset = assets.firstObject;
    
    [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:nil resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
        self.playerItem = [[AVPlayerItem alloc] initWithAsset:asset];
        self.videoPlayer = [[AVPlayer alloc] initWithPlayerItem:self.playerItem];
        
        AVPlayerLayer* layer = ( AVPlayerLayer* )self.awPlayer.layer;
        //layer.videoGravity = AVLayerVideoGravityResizeAspect;
        layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        layer.player       = self.videoPlayer;
        
        [self.playerItem addObserver:self
                          forKeyPath:@"status"
                             options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                             context:nil];
    }];
    
}

- (void)qb_imagePickerControllerDidCancel:(QBImagePickerController *)imagePickerController {
    [self dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - Segue
- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    
    // We don't need to check. But to make sure...
    if ([identifier isEqualToString:@"next"]) {
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:@"Generating..." preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:alertController animated:YES completion:nil];
        
        BOOL __block ret = NO;
        
        // Generate UUID
        self.genUUID = [[NSUUID UUID] UUIDString];
        NSLog(@"genUUID: %@", self.genUUID);
        
        do {
            // Generate image.
            {
                ret = [self generateStillImage:CMTimeGetSeconds([self.videoPlayer currentTime]) url:(AVURLAsset *)self.playerItem.asset];
                if (ret == NO) break;
            }
            
            // Generate movie.
            {
                // Remove temporary files
                [self removeFile:PATH_TEMP_FILE];
                [self removeFile:PATH_MOVIE_FILE];
                
                // First, save movie to app storage.
                AVAssetExportSession *exportSession = [[AVAssetExportSession alloc] initWithAsset:self.playerItem.asset presetName:AVAssetExportPresetPassthrough];
                exportSession.outputFileType = [[exportSession supportedFileTypes] objectAtIndex:0];
                
                // NSLog(@"%@", [[exportSession supportedFileTypes] description]);
                
                exportSession.outputURL = [NSURL fileURLWithPath:PATH_TEMP_FILE];
                
                dispatch_semaphore_t __block semaphore = dispatch_semaphore_create(0);
                [exportSession exportAsynchronouslyWithCompletionHandler:^{
                    if (exportSession.status == AVAssetExportSessionStatusCompleted) {
                        NSLog(@"export session completed");
                    } else {
                        NSLog(@"export session error: %@", exportSession.error);
                        ret = NO;
                    }
                    dispatch_semaphore_signal(semaphore);
                }];
                dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
                if (ret == NO) break;
                
                // Second. add metadata to movie.
                QuickTimeMov *qtmov = [[QuickTimeMov alloc] initWithPath:PATH_TEMP_FILE];
                [qtmov write:PATH_MOVIE_FILE assetIdentifier:self.genUUID];
                
                ret = [[NSFileManager defaultManager] fileExistsAtPath:PATH_MOVIE_FILE];
                if (ret == NO) break;
            }
            ret = YES;
            
        } while (NO);
        
        [alertController dismissViewControllerAnimated:YES completion:nil];
        
        if (ret)
        {
            // Go to next screen.
            return YES;
        }
        else
        {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:@"error" preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alertController animated:YES completion:nil];
        }
    }
    
    return NO;
}

#pragma mark -
- (BOOL)generateStillImage:(float)time url:(AVURLAsset *)asset
{
    AVAssetImageGenerator *imageGen = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    [imageGen setAppliesPreferredTrackTransform:YES];
    imageGen.requestedTimeToleranceBefore = kCMTimeZero;
    imageGen.requestedTimeToleranceAfter = kCMTimeZero;
    NSError *error = nil;
    CMTime cutPoint = CMTimeMakeWithSeconds(time, NSEC_PER_SEC);
    
    CGImageRef ref = [imageGen copyCGImageAtTime:cutPoint actualTime:nil error:&error];
    
    if(error) return NO;
    
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    
    NSDictionary *kFigAppleMakerNote_AssetIdentifier = [NSDictionary dictionaryWithObject:self.genUUID forKey:@"17"];
    [metadata setObject:kFigAppleMakerNote_AssetIdentifier forKey:@"{MakerApple}"];
    
    NSMutableData *imageData = [[NSMutableData alloc] init];
    CGImageDestinationRef dest = CGImageDestinationCreateWithData((CFMutableDataRef)imageData, kUTTypeJPEG, 1, nil);
    CGImageDestinationAddImage(dest, ref, (CFDictionaryRef)metadata);
    CGImageDestinationFinalize(dest);
    
    [imageData writeToFile:PATH_IMAGE_FILE atomically:YES];
    
    return YES;
}

-(BOOL)removeFile:(NSString *)path
{
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:path])
    {
        NSError *error = nil;
        [fm removeItemAtPath:path error:&error];
        if(error)
        {
            NSLog(@"remove error: %@", error);
            return NO;
        }
    }
    
    return YES;
}

@end
