//
//  SecondViewController.m
//  LivePhotoMaker
//
//  Created by tako on 2016/01/24.
//  Copyright © 2016年 tako. All rights reserved.
//

#import "SecondViewController.h"

@import Photos;
@import PhotosUI;

@interface DummyLivePhotoViewSubclass : PHLivePhotoView
@end
@implementation DummyLivePhotoViewSubclass
@end

@interface SecondViewController ()
@property (weak, nonatomic) IBOutlet PHLivePhotoView *livePhotoView;

@end

@implementation SecondViewController

-(void)viewDidLoad {
    [super viewDidLoad];
    
    UIImage *img = [UIImage imageNamed:PATH_IMAGE_FILE];
    
    [PHLivePhoto requestLivePhotoWithResourceFileURLs:@[[NSURL fileURLWithPath:PATH_MOVIE_FILE],[NSURL fileURLWithPath:PATH_IMAGE_FILE]]
                                     placeholderImage:nil
                                           targetSize:img.size
                                          contentMode:PHImageContentModeDefault
                                        resultHandler:^(PHLivePhoto * _Nullable livePhoto, NSDictionary * _Nonnull info) {
                                            self.livePhotoView.livePhoto = livePhoto;
                                        }];
}

- (void)saveLivePhoto
{
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        
        PHAssetCreationRequest *req = [PHAssetCreationRequest creationRequestForAsset];
        
        [req addResourceWithType:PHAssetResourceTypePhoto fileURL:[NSURL fileURLWithPath:PATH_IMAGE_FILE] options:nil];
        [req addResourceWithType:PHAssetResourceTypePairedVideo fileURL:[NSURL fileURLWithPath:PATH_MOVIE_FILE] options:nil];
        
    } completionHandler:^(BOOL success, NSError *error) {
        NSLog(@"Finished adding asset. %@", (success ? @"Success" : error));
        NSString *result = (success ? @"Success" : @"Error");
        //if(success)
        {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:result preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            dispatch_async(dispatch_get_main_queue(),^{
                [self presentViewController:alertController animated:YES completion:nil];
            });
        }
    }];
}

#pragma mark - IB Actions
- (IBAction)pushSave:(id)sender {
    [self saveLivePhoto];
}

@end
