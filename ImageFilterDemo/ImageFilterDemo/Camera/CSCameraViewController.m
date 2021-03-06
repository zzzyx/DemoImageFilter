//
//  CSCameraViewController.m
//  ImageFilterDemo
//
//  Created by Chris Hu on 16/8/2.
//  Copyright © 2016年 icetime17. All rights reserved.
//


// Custom camera using GPUImage

#import "CSCameraViewController.h"

#import "CLLocation+GPSDictionary.h"

#import "GPUImage.h"
#import "GPUImageSnapchatFilter.h"
#import "GPUImageMoonlightFilter.h"
#import "CameraFocusView.h"
#import "CSSlider.h"

#import <Photos/Photos.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "UIImage+CSCategory.h"

// transition animation
#import "TestViewController.h"
#import "AnimatorPushPopTransition.h"

#import <MGBenchmark/MGBenchmark.h>
#import <MGBenchmark/MGBenchmarkSession.h>

#ifndef COMPARE_SYSTEM_VERSION
#define COMPARE_SYSTEM_VERSION(v)    ([[[UIDevice currentDevice] systemVersion] compare:(v) options:NSNumericSearch])
#endif

#ifndef SYSTEM_VERSION_EQUAL_TO
#define SYSTEM_VERSION_EQUAL_TO(v)                  (COMPARE_SYSTEM_VERSION(v) == NSOrderedSame)
#endif

#ifndef SYSTEM_VERSION_GREATER_THAN
#define SYSTEM_VERSION_GREATER_THAN(v)              (COMPARE_SYSTEM_VERSION(v) == NSOrderedDescending)
#endif

#ifndef SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  (COMPARE_SYSTEM_VERSION(v) != NSOrderedAscending)
#endif

#ifndef SYSTEM_VERSION_LESS_THAN
#define SYSTEM_VERSION_LESS_THAN(v)                 (COMPARE_SYSTEM_VERSION(v) == NSOrderedAscending)
#endif

#ifndef SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     (COMPARE_SYSTEM_VERSION(v) != NSOrderedDescending)
#endif

#ifndef SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO_8_0
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO_8_0 (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"8.0"))
#endif


typedef void (^CSPhotoManagerResultBlock)(BOOL success, NSError *error);


typedef NS_ENUM(NSInteger, CameraProportionType) {
    CameraProportionType11,
    CameraProportionType34,
    CameraProportionTypeFill,
};


@interface CSCameraViewController () <

    GPUImageVideoCameraDelegate,
    CSSliderDelegate,
    CLLocationManagerDelegate,
    UINavigationControllerDelegate
>

@end

@implementation CSCameraViewController {
    
    GPUImageView *_previewView;
    GPUImageStillCamera *stillCamera;
    
    GPUImageFilterGroup *_filterGroup;
    GPUImageFilterPipeline *_filterPipeline;
    
    GPUImageOutput<GPUImageInput> *filter;
    
    NSInteger cameraProportionType;
    
    CameraFocusView *cameraFocusView;
    UIView *_maskViewCapture;
    
    CSSlider *csSlider;
    
    UIView *topBar;
    UIView *toolBar;
    
    UIView *_viewAlbumThumbnail;
    UIImageView *_thumbnailAlbum;
    UIButton *_btnAlbumThumbnail;
    UIActivityIndicatorView *_activityIndicator;
    
    CLLocationManager *_locationManager;
    CLLocation *_currentLocation;
    
    AVAudioPlayer *_audioPlayer;
    
    UIVisualEffectView *_blurView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    MGBenchStart(@"Test");
    MGBenchStep(@"Test", @"1");
    
    [self initCameraView];
    
    [self initExposureSlider];
    
    [self initTopBar];
    [self initToolBar];
    
    _locationManager = [[CLLocationManager alloc] init];
    _locationManager.delegate = self;
    
    [self initAudioPlayer];
    
    MGBenchStep(@"Test", @"2");
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    MGBenchStep(@"Test", @"3");
    
    if (!_blurView) {
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        _blurView = [[UIVisualEffectView alloc] initWithFrame:_previewView.bounds];
        _blurView.effect = blurEffect;
        [self.view insertSubview:_blurView aboveSubview:_previewView];
    }
    _blurView.alpha = 1.f;
    
    [stillCamera startCameraCapture];
    
    [self listenAVCaptureDeviceSubjectAreaDidChangeNotification];
    
    MGBenchStep(@"Test", @"4");
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    MGBenchStep(@"Test", @"5");
    
    [_locationManager requestAlwaysAuthorization];
    
    [_locationManager startUpdatingLocation];
    
    [UIView animateWithDuration:0.3f animations:^{
        _blurView.alpha = 0.f;
    }];
    
    MGBenchStep(@"Test", @"6");
    MGBenchEnd(@"Test");
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [stillCamera stopCameraCapture];
    
    [UIView animateWithDuration:0.3f animations:^{
        _blurView.alpha = 1.f;
    }];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:nil];
    
    [_locationManager stopUpdatingLocation];
    
    if (_audioPlayer) {
        [_audioPlayer stop];
        _audioPlayer = nil;
    }
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskLandscapeRight;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>)coordinator {
    [self updateLayoutAfterRotationViaSize:size];
}

- (void)updateLayoutAfterRotationViaSize:(CGSize)size {
    NSLog(@"%@", NSStringFromCGSize(size));
//    _previewView.frame = CGRectMake(0, 0, size.width, size.height);
//    topBar.frame = CGRectMake(0, 0, size.width, 40);
//    toolBar.frame = CGRectMake(0, size.height - 100, size.width, 100);
}

#pragma mark - Top Bar

- (void)initTopBar {
    topBar = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.frame), 40)];
    topBar.backgroundColor = [UIColor clearColor];
    [_operationView addSubview:topBar];
    
    // Settings
    UIButton *btnSettings = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    [btnSettings setBackgroundImage:[UIImage imageNamed:@"btnSettings"] forState:UIControlStateNormal];
    [btnSettings addTarget:self action:@selector(actionSettings:) forControlEvents:UIControlEventTouchUpInside];
    [topBar addSubview:btnSettings];
    
    // Close
    UIButton *btnClose = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    [btnClose setBackgroundImage:[UIImage imageNamed:@"btnClose"] forState:UIControlStateNormal];
    [btnClose addTarget:self action:@selector(actionClose:) forControlEvents:UIControlEventTouchUpInside];
    [topBar addSubview:btnClose];
    
    // Rotate
    UIButton *btnRotate = [[UIButton alloc] initWithFrame:CGRectMake(CGRectGetWidth(topBar.frame) - 40, 0, 40, 40)];
    [btnRotate setBackgroundImage:[UIImage imageNamed:@"btnRotate"] forState:UIControlStateNormal];
    [btnRotate addTarget:self action:@selector(actionRotate:) forControlEvents:UIControlEventTouchUpInside];
    [topBar addSubview:btnRotate];
    
    btnSettings.center  = topBar.center;
    btnClose.center     = CGPointMake(btnClose.center.x, btnSettings.center.y);
    btnRotate.center    = CGPointMake(btnRotate.center.x, btnSettings.center.y);
}

- (void)actionSettings:(UIButton *)sender {
    TestViewController *testVC = [[TestViewController alloc] init];
    self.navigationController.delegate = self;
    [self.navigationController pushViewController:testVC animated:YES];
}

- (void)actionClose:(UIButton *)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)actionRotate:(UIButton *)sender {
    [stillCamera rotateCamera];
}

#pragma mark - Tool Bar

- (void)initToolBar {
    toolBar = [[UIView alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(self.view.frame) - 100, CGRectGetWidth(self.view.frame), 100)];
    toolBar.backgroundColor = [UIColor clearColor];
    [_operationView addSubview:toolBar];
    
    // Capture
    UIButton *btnCapture = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 70, 70)];
    [btnCapture setBackgroundImage:[UIImage imageNamed:@"btnCapture"] forState:UIControlStateNormal];
    [btnCapture setBackgroundImage:[UIImage imageNamed:@"btnCaptureHighlighted"] forState:UIControlStateHighlighted];
    [btnCapture addTarget:self action:@selector(actionCapture:) forControlEvents:UIControlEventTouchUpInside];
    [toolBar addSubview:btnCapture];
    
    // Album
    _viewAlbumThumbnail = [[UIView alloc] initWithFrame:CGRectMake(10, 0, 40, 40)];
    _viewAlbumThumbnail.layer.borderColor= [UIColor whiteColor].CGColor;
    _viewAlbumThumbnail.layer.borderWidth = 1.f;
    _viewAlbumThumbnail.layer.cornerRadius = 2.0f;
    _viewAlbumThumbnail.layer.masksToBounds = YES;
    [toolBar addSubview:_viewAlbumThumbnail];
    
    _thumbnailAlbum = [[UIImageView alloc] initWithFrame:_viewAlbumThumbnail.bounds];
    _thumbnailAlbum.image = [UIImage imageNamed:@"Model.png"];
    [_viewAlbumThumbnail addSubview:_thumbnailAlbum];
    
    _btnAlbumThumbnail = [[UIButton alloc] initWithFrame:_viewAlbumThumbnail.bounds];
    [_btnAlbumThumbnail addTarget:self action:@selector(actionAlbum:) forControlEvents:UIControlEventTouchUpInside];
    [_viewAlbumThumbnail addSubview:_btnAlbumThumbnail];
    
    _activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:_viewAlbumThumbnail.bounds];
    [_viewAlbumThumbnail addSubview:_activityIndicator];
    
    // Proportion
    UIButton *btnProportion = [[UIButton alloc] initWithFrame:CGRectMake(CGRectGetMaxX(_btnAlbumThumbnail.frame) + 20, 0, 40, 40)];
    [btnProportion setBackgroundImage:[UIImage imageNamed:@"btnProportion11"] forState:UIControlStateNormal];
    [btnProportion addTarget:self action:@selector(actionProportion:) forControlEvents:UIControlEventTouchUpInside];
    btnProportion.layer.cornerRadius = 5.0f;
    btnProportion.layer.masksToBounds = YES;
    [toolBar addSubview:btnProportion];
    
    // Filter
    UIButton *btnFilter = [[UIButton alloc] initWithFrame:CGRectMake(CGRectGetWidth(toolBar.frame) - 40 - 10, 0, 40, 40)];
    [btnFilter setBackgroundImage:[UIImage imageNamed:@"btnFilter"] forState:UIControlStateNormal];
    [btnFilter addTarget:self action:@selector(actionFilter:) forControlEvents:UIControlEventTouchUpInside];
    btnFilter.layer.cornerRadius = 5.0f;
    btnFilter.layer.masksToBounds = YES;
    [toolBar addSubview:btnFilter];
    
    btnCapture.center       = CGPointMake(toolBar.center.x, CGRectGetHeight(toolBar.frame) / 2);
    _viewAlbumThumbnail.center         = CGPointMake(_btnAlbumThumbnail.center.x, btnCapture.center.y);
    btnProportion.center    = CGPointMake(CGRectGetMaxX(_btnAlbumThumbnail.frame) + (CGRectGetMinX(btnCapture.frame) - CGRectGetMaxX(_btnAlbumThumbnail.frame))/2, btnCapture.center.y);
    btnFilter.center        = CGPointMake(btnFilter.center.x, btnCapture.center.y);
}

- (UIImage *)imageWithData:(NSData *)imageData metadata:(NSDictionary *)metadata
{
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    NSMutableDictionary * sourceDic = [NSMutableDictionary dictionary];
    NSDictionary *source_metadata = (NSDictionary *)CFBridgingRelease(CGImageSourceCopyProperties(source, NULL));
    [sourceDic addEntriesFromDictionary: metadata];
    [sourceDic addEntriesFromDictionary:source_metadata];
    
    NSMutableData *dest_data = [NSMutableData data];
    CFStringRef UTI = CGImageSourceGetType(source);
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)dest_data, UTI, 1,NULL);
    CGImageDestinationAddImageFromSource(destination, source, 0, (__bridge CFDictionaryRef)sourceDic);
    CGImageDestinationFinalize(destination);
    CFRelease(source);
    CFRelease(destination);
    return [UIImage imageWithData: dest_data];
    
    /*
     //add the image contained in the image source to the destination, overidding the old metadata with our modified metadata
     CGImageDestinationAddImageFromSource(destination, imgSource, 0, (__bridge CFDictionaryRef)metadata);
     
     BOOL success = CGImageDestinationFinalize(destination);
     
     if(!success) {
     NSLog(@"***Could not create data from image destination ***");
     }
     
     //            CGImageRef img = CGImageSourceCreateImageAtIndex(imgSource, 0, NULL);
     ////            CGContextRef ctx = UIGraphicsGetCurrentContext();
     //
     //            UIImage *dstImage = [UIImage imageWithCGImage:img];
     
     NSData *newData = [self writeMetadataIntoImageData:imageData metadata:metadata];
     
     UIImage *dstImage = [UIImage imageWithData:newData];
     
     CFRelease(imgSource);
     CFRelease(destination);
     
     
     
     CIImage *ciImage = [CIImage imageWithCGImage:[dstImage CGImage]];
     NSDictionary *info = ciImage.properties;
     */
}

- (void)writeImageDataToSavedPhotosAlbum:(NSData *)imageData metadata:(NSDictionary *)metadata
{
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        UIImage *image = [self imageWithData:imageData metadata:metadata];
        [PHAssetChangeRequest creationRequestForAssetFromImage:image];
    } completionHandler:^(BOOL success, NSError *error) {
    }];
}

- (void)saveImageToCameraRoll:(UIImage*)image location:(CLLocation*)location
{
    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
        PHAssetChangeRequest *newAssetRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:image];
        newAssetRequest.location = location;
        newAssetRequest.creationDate = [NSDate date];
    } completionHandler:^(BOOL success, NSError *error) {
    }];
}

- (NSDictionary *)metadataForImage:(UIImage *)image withCLLocation:(CLLocation *)location
{
//    NSData *imageData = UIImageJPEGRepresentation(image, 1.f);
//    
//    CGImageSourceRef imgSource = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
//    //this is the type of image (e.g., public.jpeg)
//    CFStringRef UTI = CGImageSourceGetType(imgSource);
//    
//    //this will be the data CGImageDestinationRef will write into
//    NSMutableData *newImageData = [NSMutableData data];
//    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)newImageData, UTI, 1, NULL);
//    
//    if(!destination) {
//        NSLog(@"***Could not create image destination ***");
//        return nil;
//    }
//    CFRelease(imgSource);
//    CFRelease(destination);
//    
    //get original metadata
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    
    NSDictionary *gpsDict = [location GPSDictionary];
    if (metadata && gpsDict) {
        [metadata setValue:gpsDict forKey:(NSString *)kCGImagePropertyGPSDictionary];
    }

    return metadata;
}

#pragma mark - Capture

- (void)actionCapture:(UIButton *)sender {
    if (![UIApplication sharedApplication].isIgnoringInteractionEvents) {
        [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
    }
    
    MGBenchStart(@"Capture");
    MGBenchStep(@"Capture", @"start");
    
    [stillCamera capturePhotoAsImageProcessedUpToFilter:filter withOrientation:UIImageOrientationUp withCompletionHandler:^(UIImage *processedImage, NSError *error) {
        
        _thumbnailAlbum.image = nil;
        _maskViewCapture.hidden = NO;
        [stillCamera pauseCameraCapture];
        
        [_activityIndicator startAnimating];
        
        if (error == nil) {
            
            [stillCamera resumeCameraCapture];
            
            MGBenchStep(@"Capture", @"end");
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1f * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                MGBenchStep(@"Capture", @"anim begin");
                [_activityIndicator stopAnimating];
                _maskViewCapture.hidden = YES;
                
                _thumbnailAlbum.transform = CGAffineTransformMakeScale(0.1f, 0.1f);
                UIImage *imgAlbumThumbnail = [processedImage cs_imageFitTargetSize:_viewAlbumThumbnail.frame.size];
                _thumbnailAlbum.image = imgAlbumThumbnail;
                [UIView animateWithDuration:0.3f animations:^{
                    _thumbnailAlbum.transform = CGAffineTransformIdentity;
                } completion:^(BOOL finished) {
                    if ([UIApplication sharedApplication].isIgnoringInteractionEvents) {
                        [[UIApplication sharedApplication] endIgnoringInteractionEvents];
                    }
                }];
                MGBenchStep(@"Capture", @"anim end");
            });
            
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                MGBenchStep(@"Capture", @"save begin");
                
                NSDictionary *metadata = [self metadataForImage:processedImage withCLLocation:_currentLocation];
                
//                // 仅此方法可以保存GPS信息。其他都不行。
//                ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
//                [library writeImageToSavedPhotosAlbum:[processedImage CGImage] metadata:metadata completionBlock:^(NSURL *assetURL, NSError *error) {
//                    NSLog(@"ok");
//                }];
                
                [self writeImageData:UIImageJPEGRepresentation(processedImage, 1.f) metadata:metadata toAlbum:nil resultBlock:nil];
                
                MGBenchStep(@"Capture", @"save end");
            });
        }
    }];
}

- (NSData *)imageDataWithData:(NSData *)imageData metadata:(NSDictionary *)metadata
{
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)imageData, NULL);
    NSMutableDictionary *source_metadata = [(NSMutableDictionary *)CFBridgingRelease(CGImageSourceCopyProperties(source, NULL)) mutableCopy];
    [source_metadata addEntriesFromDictionary:metadata];
    
    NSMutableData *dest_data = [NSMutableData data];
    CFStringRef UTI = CGImageSourceGetType(source);
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)dest_data, UTI, 1,NULL);
    
    float compression = 1.0f; //设置压缩比
    NSMutableDictionary* dest_metadata = [NSMutableDictionary dictionaryWithDictionary:metadata];
    [dest_metadata setObject:[NSNumber numberWithFloat:compression] forKey:(NSString *)kCGImageDestinationLossyCompressionQuality];
    
    CGImageDestinationAddImageFromSource(destination, source, 0, (__bridge CFDictionaryRef)dest_metadata);
    CGImageDestinationFinalize(destination);
    
    destination == NULL ? : CFRelease(destination);
    source == NULL ?      : CFRelease(source);
    
    return dest_data;
}

- (void)writeImageData:(NSData *)imageData metadata:(NSDictionary *)metadata toAlbum:(NSString *)albumName resultBlock:(CSPhotoManagerResultBlock)resultBlock
{
    // 临时使用此相册
    PHFetchResult<PHAssetCollection *> *albums = [PHAssetCollection fetchAssetCollectionsWithType:PHAssetCollectionTypeAlbum subtype:PHAssetCollectionSubtypeAlbumRegular options:nil];
    
    
    __block NSString *assetID = nil;
    if (metadata) {
        imageData = [self imageDataWithData:imageData metadata:metadata];
    }
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"9.0") && [PHAssetCreationRequest supportsAssetResourceTypes:@[@(PHAssetResourceTypePhoto)]]) {
        //iOS9
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAsset];
            [request addResourceWithType:PHAssetResourceTypePhoto
                                    data:imageData
                                 options:nil];
            assetID = request.placeholderForCreatedAsset.localIdentifier;
            PHAssetCollectionChangeRequest *collectionRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:albums[0]];
            [collectionRequest addAssets:@[request.placeholderForCreatedAsset]];
        } completionHandler:^(BOOL success, NSError *error) {
            
            if (success && assetID) {
                PHFetchResult<PHAsset *> *assets = [PHAsset fetchAssetsWithLocalIdentifiers:@[assetID] options:nil];
                PHAsset *asset = assets[0];
                if (resultBlock) {
                    resultBlock(success, error);
                }
            } else {
                if (resultBlock) {
                    resultBlock(success, error);
                }
            }
            
        }];
    } else {
        //iOS8
        NSString *temporaryFileName = [NSProcessInfo processInfo].globallyUniqueString;
        NSString *temporaryFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[temporaryFileName stringByAppendingPathExtension:@"jpg"]];
        NSURL *temporaryFileURL = [NSURL fileURLWithPath:temporaryFilePath];
        
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            NSError *error = nil;
            [imageData writeToURL:temporaryFileURL options:NSDataWritingAtomic error:&error];
            if (error) {
                NSLog(@"Error occured while writing image data to a temporary file: %@", error);
            } else {
                PHAssetChangeRequest *assetRequest = [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:temporaryFileURL];
                PHAssetCollectionChangeRequest *collectionRequest = [PHAssetCollectionChangeRequest changeRequestForAssetCollection:albums[0]];
                [collectionRequest addAssets:@[assetRequest.placeholderForCreatedAsset]];
                assetID = assetRequest.placeholderForCreatedAsset.localIdentifier;
            }
        } completionHandler:^(BOOL success, NSError *error) {
            // Delete the temporary file.
            NSError *removeError = nil;
            [[NSFileManager defaultManager] removeItemAtURL:temporaryFileURL error:&removeError];
            
            if (success && assetID) {
                PHFetchResult<PHAsset *> *assets = [PHAsset fetchAssetsWithLocalIdentifiers:@[assetID] options:nil];
                PHAsset *asset = assets[0];
                if (resultBlock) {
                    resultBlock(success, error);
                }
            } else {
                if (resultBlock) {
                    resultBlock(success, error);
                }
            }
        }];
    }
}

- (NSData *)writeMetadataIntoImageData:(NSData *)imageData metadata:(NSMutableDictionary *)metadata {
    // create an imagesourceref
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef) imageData, NULL);
    
    // this is the type of image (e.g., public.jpeg)
    CFStringRef UTI = CGImageSourceGetType(source);
    
    // create a new data object and write the new image into it
    NSMutableData *dest_data = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)dest_data, UTI, 1, NULL);
    if (!destination) {
        NSLog(@"Error: Could not create image destination");
    }
    // add the image contained in the image source to the destination, overidding the old metadata with our modified metadata
    CGImageDestinationAddImageFromSource(destination, source, 0, (__bridge CFDictionaryRef) metadata);
    BOOL success = NO;
    success = CGImageDestinationFinalize(destination);
    if (!success) {
        NSLog(@"Error: Could not create data from image destination");
    }
    CFRelease(destination);
    CFRelease(source);
    return dest_data;
}

- (NSData *)taggedImageData:(NSData *)imageData metadata:(NSDictionary *)metadata orientation:(UIImageOrientation)orientation {
    NSMutableDictionary *newMetadata = [NSMutableDictionary dictionaryWithDictionary:metadata];
    if (!newMetadata[(NSString *)kCGImagePropertyGPSDictionary] && _currentLocation) {
        newMetadata[(NSString *)kCGImagePropertyGPSDictionary] = [_currentLocation GPSDictionary];
    }
    
    // Reference: http://sylvana.net/jpegcrop/exif_orientation.html
    int newOrientation;
    switch (orientation) {
        case UIImageOrientationUp:
            newOrientation = 1;
            break;
            
        case UIImageOrientationDown:
            newOrientation = 3;
            break;
            
        case UIImageOrientationLeft:
            newOrientation = 8;
            break;
            
        case UIImageOrientationRight:
            newOrientation = 6;
            break;
            
        case UIImageOrientationUpMirrored:
            newOrientation = 2;
            break;
            
        case UIImageOrientationDownMirrored:
            newOrientation = 4;
            break;
            
        case UIImageOrientationLeftMirrored:
            newOrientation = 5;
            break;
            
        case UIImageOrientationRightMirrored:
            newOrientation = 7;
            break;
            
        default:
            newOrientation = -1;
    }
    if (newOrientation != -1) {
        newMetadata[(NSString *)kCGImagePropertyOrientation] = @(newOrientation);
    }
    NSData *newImageData = [self writeMetadataIntoImageData:imageData metadata:newMetadata];
    return newImageData;
}

- (void)actionAlbum:(UIButton *)sender {
    [self dismissViewControllerAnimated:YES completion:^{
        if (_delegate && [_delegate respondsToSelector:@selector(CSCameraViewControllerDelegateActionAlbum)]) {
            [_delegate CSCameraViewControllerDelegateActionAlbum];
        }
    }];
}

- (void)actionProportion:(UIButton *)sender {
    CGFloat width = _previewView.frame.size.width;
    switch (cameraProportionType) {
        case CameraProportionType11:
            cameraProportionType = CameraProportionType34;
            break;
        case CameraProportionType34:
            cameraProportionType = CameraProportionTypeFill;
            break;
        case CameraProportionTypeFill:
            cameraProportionType = CameraProportionType11;
            break;
        default:
            break;
    }
}

- (void)actionFilter:(UIButton *)sender {
//    if (_audioPlayer) {
//        [_audioPlayer play];
//    }
    
    TestViewController *testVC = [[TestViewController alloc] init];
    self.navigationController.delegate = self;
    [self.navigationController pushViewController:testVC animated:YES];
}

- (void)initAudioPlayer
{
//    NSURL *audioURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"magic_animation" ofType:@"m4a"]];
    
    NSURL *audioURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"countdown" ofType:@"wav"]];
    _audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:audioURL error:nil];
}

#pragma mark - Camera View

- (void)initCameraView {
    _cameraView = [[UIView alloc] initWithFrame:self.view.frame];
    [self.view addSubview:_cameraView];
    
    _previewView = [[GPUImageView alloc] initWithFrame:_cameraView.bounds];
    // 保持与iOS系统相机的位置一致。
    cameraProportionType = CameraProportionType34;
    _previewView.backgroundColor = [UIColor whiteColor];
    _previewView.fillMode = kGPUImageFillModePreserveAspectRatioAndFill;
    [_cameraView addSubview:_previewView];
    
    _maskViewCapture = [[UIView alloc] initWithFrame:_previewView.bounds];
    [_cameraView insertSubview:_maskViewCapture aboveSubview:_previewView];
    _maskViewCapture.backgroundColor = [UIColor blackColor];
    _maskViewCapture.hidden = YES;
    
    _operationView = [[UIView alloc] initWithFrame:self.view.frame];
    [self.view addSubview:_operationView];
    
    [self addFocusTapGesture];
    
    stillCamera = [[GPUImageStillCamera alloc] initWithSessionPreset:AVCaptureSessionPresetPhoto cameraPosition:AVCaptureDevicePositionBack];
    stillCamera.outputImageOrientation = UIInterfaceOrientationPortrait;
    stillCamera.horizontallyMirrorFrontFacingCamera = YES;
    stillCamera.delegate = self;
    
    // 此处曾因错误添加，导致闪屏
    // [stillCamera addTarget:_previewView];
    
    CGPoint focusPoint = CGPointMake(0.5f, 0.5f);
    [stillCamera.inputCamera lockForConfiguration:nil];
    if (stillCamera.inputCamera.isFocusPointOfInterestSupported) {
        stillCamera.inputCamera.focusPointOfInterest = focusPoint;
        stillCamera.inputCamera.focusMode = AVCaptureFocusModeContinuousAutoFocus;
    }
    stillCamera.inputCamera.focusPointOfInterest = focusPoint;
    stillCamera.inputCamera.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
    [stillCamera.inputCamera unlockForConfiguration];
    
    
    // TODO: 不加滤镜, 如何获取图片？
    /*
    [stillCamera addTarget:_previewView];
    [stillCamera startCameraCapture];
    */
    
    
    // 添加滤镜
    
    // GPUImageStillCamera (output) -> GPUImageFilter (input, output) -> GPUImageView (input)
    // GPUImagePicture (output)     —> GPUImageFilter (input, output) —> GPUImageView (input)
    
    
    // TODO: 有时候使用LUT的滤镜没有效果。原因未知。
    // filter = [[GPUImageSepiaFilter alloc] init];
//    filter = [[GPUImageToonFilter alloc] init];
//    filter = [[GPUImageSmoothToonFilter alloc] init];
//    filter = [[GPUImageSnapchatFilter alloc] init];
//    filter = [[GPUImageSketchFilter alloc] init];
    
    
    // 交叉线阴影
//    filter = [[GPUImageCrosshatchFilter alloc] init];
    
    // 暗角
//    filter = [[GPUImageVignetteFilter alloc] init];
    
    // 水晶球
//    filter = [[GPUImageGlassSphereFilter alloc] init];
    // 哈哈镜
//    filter = [[GPUImageStretchDistortionFilter alloc] init];
    // 浮雕
//    filter = [[GPUImageEmbossFilter alloc] init];
    
    // 水粉画
//    filter = [[GPUImageKuwaharaFilter alloc] init];
    
    // 黑色，普瑞维特(Prewitt)边缘检测(效果与Sobel差不多，貌似更平滑)
//    filter = [[GPUImagePrewittEdgeDetectionFilter alloc] init];
    
    // 像素化，Mosaic
    filter = [[GPUImagePixellateFilter alloc] init];
    // 同心圆像素化
//    filter = [[GPUImagePolarPixellateFilter alloc] init];
    
    
    [filter addTarget:_previewView];
    
    [stillCamera addTarget:filter];
    
    
    
    /*
    GPUImageFilter *filter1 = [[GPUImageToonFilter alloc] init];
    
    filter = [[GPUImageMoonlightFilter alloc] init];
    _filterGroup = [[GPUImageFilterGroup alloc] init];
    
    // 每个filter之间要连接起来
    [filter addTarget:filter1];
    // 正确设置initialFilters和terminalFilter
    _filterGroup.initialFilters = @[filter];
    _filterGroup.terminalFilter = filter1;
    
    [_filterGroup addTarget:_previewView];
    
    [stillCamera addTarget:_filterGroup];
    
    [stillCamera startCameraCapture];
     */
    
    
    /*
    GPUImageFilter *filter1 = [[GPUImageToonFilter alloc] init];
    GPUImageMoonlightFilter *filter2 = [[GPUImageMoonlightFilter alloc] init];
    NSArray *filterArr = @[filter2, filter1];
    _filterPipeline = [[GPUImageFilterPipeline alloc] initWithOrderedFilters:filterArr input:stillCamera output:_previewView];
    
    [stillCamera startCameraCapture];
     */
}

- (void)initExposureSlider {
    csSlider = [[CSSlider alloc] initWithFrame:CGRectMake(0, 0, 300, 40)];
    csSlider.center = CGPointMake(CGRectGetWidth(self.view.frame) - 40, self.view.center.y);
    csSlider.value = 0.5f;
    [_operationView addSubview:csSlider];
    csSlider.delegate = self;
    //    csSlider.thumbTintColor = [UIColor greenColor];
    
    csSlider.csThumbImage = [UIImage imageNamed:@"CSSliderHandler"];
    csSlider.csMinimumTrackTintColor = [UIColor redColor];
    csSlider.csMaximumTrackTintColor = [UIColor lightGrayColor];
    // Please use CSSliderTrackTintType_Divide after csMinimumTrackTintColor and csMaximumTrackTintColor set already. Please do not set minimumValueImage and maximumValueImage.
    csSlider.trackTintType = CSSliderTrackTintType_Linear;
    
        csSlider.sliderDirection = CSSliderDirection_Vertical;
}

#pragma mark - CSSliderDelegate

- (void)CSSliderValueChanged:(CSSlider *)sender {
    CGFloat bias = -1.5f + sender.value * (1.5f - (-1.5f));
    NSLog(@"%f", bias);
    [stillCamera.inputCamera lockForConfiguration:nil];
    [stillCamera.inputCamera setExposureTargetBias:bias completionHandler:nil];
    [stillCamera.inputCamera unlockForConfiguration];
}

- (void)CSSliderTouchDown:(CSSlider *)sender {
    
}

- (void)CSSliderTouchUp:(CSSlider *)sender {
    
}

- (void)CSSliderTouchCancel:(CSSlider *)sender {
    
}

#pragma mark - GPUImageVideoCameraDelegate

- (void)willOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    
}

#pragma mark - Focus tap

- (void)addFocusTapGesture {
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(actionFocus:)];
    [_operationView addGestureRecognizer:tapGesture];
}

- (void)actionFocus:(UITapGestureRecognizer *)sender {
    if (!cameraFocusView) {
        cameraFocusView = [[CameraFocusView alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
        [_operationView addSubview:cameraFocusView];
    }
    
    CGPoint touchpoint = [sender locationInView:_previewView];
    
    cameraFocusView.center = touchpoint;
    
    [cameraFocusView beginAnimation];
    
    // 需要同时设置focusMode为AVCaptureFocusModeAutoFocus
    NSLog(@"touchpoint : %@", NSStringFromCGPoint(touchpoint));
    // 需要坐标系转换
    CGPoint focusPoint = [self realFocusPoint:touchpoint];
    
    [stillCamera.inputCamera lockForConfiguration:nil];
    
    if (stillCamera.inputCamera.isFocusPointOfInterestSupported) {
        stillCamera.inputCamera.focusPointOfInterest = focusPoint;
        stillCamera.inputCamera.focusMode = AVCaptureFocusModeContinuousAutoFocus;
    }
    
    stillCamera.inputCamera.exposurePointOfInterest = focusPoint;
    stillCamera.inputCamera.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
    
    [stillCamera.inputCamera unlockForConfiguration];
}

- (CGPoint)realFocusPoint:(CGPoint)point
{
    CGPoint realPoint = CGPointZero;
    if (stillCamera.isBackFacingCameraPresent) {
        realPoint = CGPointMake(point.y / _previewView.frame.size.height,
                                1 - point.x / _previewView.frame.size.width);
    } else {
        realPoint = CGPointMake(point.y / _previewView.frame.size.height,
                                point.x / _previewView.frame.size.width);
    }
    return realPoint;
}

#pragma mark - 自动曝光调节

- (void)listenAVCaptureDeviceSubjectAreaDidChangeNotification {
    [stillCamera.inputCamera lockForConfiguration:nil];
    stillCamera.inputCamera.subjectAreaChangeMonitoringEnabled = YES;
    [stillCamera.inputCamera unlockForConfiguration];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(actionAVCaptureDeviceSubjectAreaDidChange:)
                                                 name:AVCaptureDeviceSubjectAreaDidChangeNotification
                                               object:nil];
}

- (void)actionAVCaptureDeviceSubjectAreaDidChange:(NSNotification *)notification {
    CGPoint devicePoint = CGPointMake(.5, .5);
    [self setupFocusMode:AVCaptureFocusModeContinuousAutoFocus
              exposeMode:AVCaptureExposureModeContinuousAutoExposure
                 atPoint:devicePoint
    subjectAreaChangeMonitoringEnabled:YES];
}

- (void)setupFocusMode:(AVCaptureFocusMode)focusMode exposeMode:(AVCaptureExposureMode)exposureMode atPoint:(CGPoint)point subjectAreaChangeMonitoringEnabled:(BOOL)subjectAreaChangeMonitoringEnabled {
    
    if ([stillCamera.inputCamera lockForConfiguration:nil]) {
        if (stillCamera.inputCamera.isFocusPointOfInterestSupported) {
            stillCamera.inputCamera.focusPointOfInterest = point;
            stillCamera.inputCamera.focusMode = focusMode;
        }
        
        if (stillCamera.inputCamera.isExposurePointOfInterestSupported) {
            stillCamera.inputCamera.exposurePointOfInterest = point;
            stillCamera.inputCamera.exposureMode = exposureMode;
        }
        
        stillCamera.inputCamera.subjectAreaChangeMonitoringEnabled = subjectAreaChangeMonitoringEnabled;
        [stillCamera.inputCamera unlockForConfiguration];
    }
}

#pragma mark - 地理定位

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    if (locations.count > 0) {
        _currentLocation = [locations firstObject];
        
        [_locationManager stopUpdatingHeading];
    }
}

#pragma mark - <UINavigationControllerDelegate>

- (nullable id <UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
                                            animationControllerForOperation:(UINavigationControllerOperation)operation
                                                         fromViewController:(UIViewController *)fromVC
                                                           toViewController:(UIViewController *)toVC {
    // Push/Pop
    AnimatorPushPopTransition *pushPopTransition = [[AnimatorPushPopTransition alloc] init];
    
    if (operation == UINavigationControllerOperationPush) {
        pushPopTransition.animatorTransitionType = kAnimatorTransitionTypePush;
    } else {
        pushPopTransition.animatorTransitionType = kAnimatorTransitionTypePop;
    }
    
    return pushPopTransition;
}

@end
