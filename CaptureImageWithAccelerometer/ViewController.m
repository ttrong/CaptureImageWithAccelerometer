//
//  ViewController.m
//  CaptureImageWithAccelerometer
//
//  Created by Trong Ton on 5/25/18.
//  Copyright © 2018 trong.ton2003@gmail.com. All rights reserved.
//

#import "ViewController.h"
#import "JPSCameraButton.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIView *currentAngleView;
@property (weak, nonatomic) IBOutlet UILabel *zAngleLable;
@property (weak, nonatomic) IBOutlet UILabel *numberCapture;

@property (weak, nonatomic) IBOutlet UIView *contenCameraShow;
@property (weak, nonatomic) IBOutlet JPSCameraButton *CaptureButton;
@property (weak, nonatomic) IBOutlet UIView *topBarView;
@property (weak, nonatomic) IBOutlet UIView *bottomBarView;

@property (weak, nonatomic) IBOutlet UIButton *cameraButton;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *cameraViewTopConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *cameraViewBottomConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomBarHeightConstraint;

@property (strong, nonatomic) UIVisualEffectView *blurView;

@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) UIView *capturePreviewView;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *capturePreviewLayer;
@property (nonatomic, strong) NSOperationQueue *captureQueue;
@property (nonatomic, assign) UIImageOrientation imageOrientation;
@property (assign, nonatomic) AVCaptureFlashMode flashMode;

@property (nonatomic, strong) UIImage *fImageCapture;
@property (nonatomic, strong) UIImage *sImageCapture;

@property (nonatomic, assign) float fAngleDevice;
@property (nonatomic, assign) float sAngleDevice;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    // Initialise the capture queue
    indexCapture = 1;
    self.captureQueue = [[NSOperationQueue alloc] init];
    
    // Initialise the blur effect used when switching between cameras
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:effect];
    
    // Listen for orientation changes so that we can update the UI
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(orientationChanged:)
//                                                 name:UIDeviceOrientationDidChangeNotification
//                                               object:nil];
    
    
    self.numberCapture.text = [NSString stringWithFormat:@"Chụp lần %d", indexCapture];
    self.motionManager = [CMMotionManager new];
    [self.motionManager setAccelerometerUpdateInterval:.2];
    rotation = 0;
    
    __weak typeof(self) weakSelf = self;
    if (self.motionManager.deviceMotionAvailable) {
        [self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue currentQueue] withHandler:^(CMDeviceMotion *motion, NSError *error) {
            // Get the attitude of the device
            CMAttitude *attitude = motion.attitude;
            
            // Get the pitch (in radians) and convert to degrees.
//            NSLog(@"%f", attitude.pitch * 180.0/M_PI);
            dispatch_async(dispatch_get_main_queue(), ^{
                // Update some UI
                float angleCenvert = attitude.pitch * 180.0/M_PI;
                weakSelf.zAngleLable.text = [NSString stringWithFormat:@"%.02f", angleCenvert];
                weakSelf.currentAngleView.layer.transform = CATransform3DRotate(CATransform3DIdentity, motion.rotationRate.x, 0, 0, 1);
            });
        }];
    }
    
    self.buttonStealer = [[RBVolumeButtons alloc] init];
    self.buttonStealer.upBlock = ^{
        if (weakSelf.isShowDetail) {
            if (weakSelf.destViewController) {
                [weakSelf.destViewController saveButtonPress:nil];
            }
        } else {
            [weakSelf takePicture];
        }
    };
    self.buttonStealer.downBlock = ^{
        if (weakSelf.isShowDetail) {
            if (weakSelf.destViewController) {
                [weakSelf.destViewController saveButtonPress:nil];
            }
        } else {
            [weakSelf takePicture];
        }
    };
    [self.buttonStealer startStealingVolumeButtonEvents];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _isShowDetail = NO;
//    [self.buttonStealer startStealingVolumeButtonEvents];
    [self enableCapture];
//    if (_motionManager) {
//        [_motionManager startDeviceMotionUpdates];
//    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    _isShowDetail = YES;
//    [self.buttonStealer stopStealingVolumeButtonEvents];
//    if (_motionManager) {
//        [_motionManager stopDeviceMotionUpdates];
//    }
    
    [self.captureQueue cancelAllOperations];
    [self.capturePreviewLayer removeFromSuperlayer];
    for (AVCaptureInput *input in self.session.inputs) {
        [self.session removeInput:input];
    }
    for (AVCaptureOutput *output in self.session.outputs) {
        [self.session removeOutput:output];
    }
    [self.session stopRunning];
    self.session = nil;
}

- (void)showNativeCamera
{
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) return;
    
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
    imagePickerController.delegate = self;
    
    [self presentViewController:imagePickerController animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
//    UIImage *image = info[UIImagePickerControllerOriginalImage];
//    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)focusAtPoint:(UITapGestureRecognizer *)point {
    if (point.state == UIGestureRecognizerStateRecognized) {
        CGPoint location = [point locationInView:_contenCameraShow];
        dispatch_async(dispatch_get_main_queue(), ^{
            AVCaptureDevice *device = [self currentDevice];
            if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
                NSError *error;
                if ([device lockForConfiguration:&error]) {
                    [device setFocusPointOfInterest:location];
                    [device setFocusMode:AVCaptureFocusModeAutoFocus];
                    [device unlockForConfiguration];
                } else {
                    //            id delegate = [self delegate];
                    //
                    //            if ([delegate respondsToSelector:@selector(acquiringDeviceLockFailedWithError:)]) {
                    //
                    //                [delegate acquiringDeviceLockFailedWithError:error];
                    //
                    //            }
                }
            }
        });
    }
}

- (void)enableCapture
{
    if (self.session) return;
    
//    self.flashButton.hidden = YES;
    self.cameraButton.hidden = YES;
    
    NSBlockOperation *operation = [self captureOperation];
    operation.completionBlock = ^{
        [self operationCompleted];
        dispatch_async(dispatch_get_main_queue(), ^{
            AVCaptureDeviceInput *input = self.session.inputs.firstObject;
            if (input.device.position != AVCaptureDevicePositionFront) {
                NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
                for (AVCaptureDevice *device in devices) {
                    if (device.position == AVCaptureDevicePositionFront) {
                        [self.session removeInput:input];
                        NSError *error = nil;
                        input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
                        if (!input) return;
                        [self.session addInput:input];
                    }
                }
            }
        });
    };
    operation.queuePriority = NSOperationQueuePriorityVeryHigh;
    [self.captureQueue addOperation:operation];
}


- (NSBlockOperation *)captureOperation {
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        self.session = [[AVCaptureSession alloc] init];
        self.session.sessionPreset = AVCaptureSessionPreset1280x720;
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];

        NSError *error = nil;
        
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
        if (!input) return;
        
        [self.session addInput:input];
        
        // Turn on point autofocus for middle of view
        [device lockForConfiguration:&error];
        if (!error) {
            if ([device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
                device.focusPointOfInterest = CGPointMake(0.5,0.5);
                device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
            }
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
                if ([device isFlashModeSupported:AVCaptureFlashModeAuto]) {
                    device.flashMode = AVCaptureFlashModeAuto;
                } else {
                    device.flashMode = AVCaptureFlashModeOff;
                }
                self.flashMode = device.flashMode;
            }
            
        }
        [device unlockForConfiguration];
        
        self.capturePreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
        self.capturePreviewLayer.frame = self.contenCameraShow.bounds;
        self.capturePreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        
        // Still Image Output
        AVCaptureStillImageOutput *stillOutput = [[AVCaptureStillImageOutput alloc] init];
        stillOutput.outputSettings = @{AVVideoCodecKey: AVVideoCodecJPEG};
        [self.session addOutput:stillOutput];
    }];
    return operation;
}

- (void)operationCompleted
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!self.session) return;
        self.capturePreviewView = [[UIView alloc] initWithFrame:CGRectZero];
#if TARGET_IPHONE_SIMULATOR
        self.capturePreviewView.backgroundColor = [UIColor redColor];
#endif
        [self.contenCameraShow addSubview:self.capturePreviewView];
//        [self.capturePreviewView autoPinEdgesToSuperviewEdges];
        [self.capturePreviewView.layer addSublayer:self.capturePreviewLayer];
        [self.session startRunning];
        if ([[self currentDevice] hasFlash]) {
            [self updateFlashlightState];
//            self.flashButton.hidden = NO;
        }
        if ([UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront] &&
            [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear]) {
            self.cameraButton.hidden = NO;
        }
        
        UITapGestureRecognizer* tapScanner = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusAtPoint:)];
        [self.contenCameraShow addGestureRecognizer:tapScanner];
    });
}


- (void)updateFlashlightState
{
    if (![self currentDevice]) return;
    
//    self.flashAutoButton.selected = self.flashMode == AVCaptureFlashModeAuto;
//    self.flashOnButton.selected = self.flashMode == AVCaptureFlashModeOn;
//    self.flashOffButton.selected = self.flashMode == AVCaptureFlashModeOff;
    
    AVCaptureDevice *device = [self currentDevice];
    NSError *error = nil;
    BOOL success = [device lockForConfiguration:&error];
    if (success) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            device.flashMode = self.flashMode;
        }
    }
    [device unlockForConfiguration];
}


- (AVCaptureDevice *)currentDevice
{
    return [(AVCaptureDeviceInput *)self.session.inputs.firstObject device];
}


- (AVCaptureDevice *)frontCamera
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if (device.position == AVCaptureDevicePositionFront) {
            return device;
        }
    }
    return nil;
}


- (UIImageOrientation)currentImageOrientation
{
    UIDeviceOrientation deviceOrientation = [[UIDevice currentDevice] orientation];
    UIImageOrientation imageOrientation;
    
    AVCaptureDeviceInput *input = self.session.inputs.firstObject;
    if (input.device.position == AVCaptureDevicePositionBack) {
        switch (deviceOrientation) {
            case UIDeviceOrientationLandscapeLeft:
                imageOrientation = UIImageOrientationUp;
                break;
                
            case UIDeviceOrientationLandscapeRight:
                imageOrientation = UIImageOrientationDown;
                break;
                
            case UIDeviceOrientationPortraitUpsideDown:
                imageOrientation = UIImageOrientationLeft;
                break;
                
            default:
                imageOrientation = UIImageOrientationRight;
                break;
        }
    } else {
        switch (deviceOrientation) {
            case UIDeviceOrientationLandscapeLeft:
                imageOrientation = UIImageOrientationDownMirrored;
                break;
                
            case UIDeviceOrientationLandscapeRight:
                imageOrientation = UIImageOrientationUpMirrored;
                break;
                
            case UIDeviceOrientationPortraitUpsideDown:
                imageOrientation = UIImageOrientationRightMirrored;
                break;
                
            default:
                imageOrientation = UIImageOrientationLeftMirrored;
                break;
        }
    }
    
    return imageOrientation;
}

- (void)volumeChanged {
    [self takePicture];
}

- (void)takePicture {
    if (!self.cameraButton.enabled) return;
    AVCaptureStillImageOutput *output = self.session.outputs.lastObject;
    AVCaptureConnection *videoConnection = output.connections.lastObject;
    if (!videoConnection) return;
    if (indexCapture == 1) {
        self.fAngleDevice = [self.zAngleLable.text floatValue];
    } else {
        self.sAngleDevice = [self.zAngleLable.text floatValue];
    }
    [output captureStillImageAsynchronouslyFromConnection:videoConnection
                                        completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
                                            self.cameraButton.enabled = YES;
                                            
                                            if (!imageDataSampleBuffer || error) return;
                                            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                                            
//                                            UIImage *image = [[UIImage alloc]initWithData:imageData scale:1];
//                                            AVCaptureDeviceInput *input = self.session.inputs.firstObject;
//                                            if (input.device.position == AVCaptureDevicePositionFront) {
//                                                image = [UIImage imageWithCGImage:image.CGImage scale:image.scale orientation:UIImageOrientationLeftMirrored];
//                                            }
                                            
                                            UIImage *image = [UIImage imageWithCGImage:[[[UIImage alloc] initWithData:imageData] CGImage] scale:1.0f orientation:[self currentImageOrientation]];
                                            
                                            [self handleImage:image];
                                        }];
    self.cameraButton.enabled = NO;
}


/**
 *  @brief Do something with the image that's been taken (camera) / chosen (photo album)
 *
 *  @param image The image
 */
- (void)handleImage:(UIImage *)image {
    /* Render the screen shot at custom resolution */
//    CGSize targetSize = CGSizeMake(720, 1280);//CGSizeMake(1280 ,720);//
//    UIImage *sourceImage = image;
//    //Image redimenssionnée
//    UIImage *newImage = nil;
//
//    //Taille de l'image de base
//    CGSize imageSize = sourceImage.size;
//    //Longueur et largeur
//    CGFloat width = imageSize.width;
//    CGFloat height = imageSize.height;
//
//    //Dimension désirée
//    CGFloat targetWidth = targetSize.width;
//    CGFloat targetHeight = targetSize.height;
//
//    //Echelle...
//    CGFloat scaleFactor = 0.0;
//    CGFloat scaledWidth = targetWidth;
//    CGFloat scaledHeight = targetHeight;
//    CGPoint thumbnailPoint = CGPointMake(0.0,0.0);
//
//    //Si taille des image est différentes on redimensionne de facon proportionnelle
//    if (CGSizeEqualToSize(imageSize, targetSize) == NO) {
//        CGFloat widthFactor = targetWidth / width;
//        CGFloat heightFactor = targetHeight / height;
//
//        if (widthFactor > heightFactor)
//            scaleFactor = widthFactor; // scale to fit height
//        else
//            scaleFactor = heightFactor; // scale to fit width
//        scaledWidth  = width * scaleFactor;
//        scaledHeight = height * scaleFactor;
//
//        //Centre l'image
//        if (widthFactor > heightFactor)
//        {
//            thumbnailPoint.y = (targetHeight - scaledHeight) * 0.5;
//        }
//        else if (widthFactor < heightFactor)
//        {
//            thumbnailPoint.x = (targetWidth - scaledWidth) * 0.5;
//        }
//    }
//
//    UIGraphicsBeginImageContext(targetSize);
//
//    CGRect thumbnailRect = CGRectZero;
//    thumbnailRect.origin = thumbnailPoint;
//    thumbnailRect.size.width  = scaledWidth;
//    thumbnailRect.size.height = scaledHeight;
//
//    [sourceImage drawInRect:thumbnailRect];
//
//    newImage = UIGraphicsGetImageFromCurrentImageContext();
//    UIImage *sourceImage = image;
    UIImage *newImage = image;//[self resizedImageWithContentMode:UIViewContentModeScaleAspectFill imageToScale:image bounds:targetSize interpolationQuality:kCGInterpolationDefault];
//    CGSize imageSize = newImage.size;
    if(newImage == nil)
        NSLog(@"could not scale image");
    if (indexCapture == 1) {
        _fImageCapture = [self captureImageShare:newImage];
    } else {
        _sImageCapture = [self captureImageShare:newImage];
    }
    
//    UIGraphicsEndImageContext();
    
    if (indexCapture == 1) {
        indexCapture += 1;
        self.numberCapture.text = [NSString stringWithFormat:@"Chụp lần %d", indexCapture];
    } else {
        indexCapture = 1;
        [self performSegueWithIdentifier:@"showPreviewImage" sender:self];
        self.numberCapture.text = [NSString stringWithFormat:@"Chụp lần %d", indexCapture];
    }
//    UIImageWriteToSavedPhotosAlbum(newImage, nil, nil, nil);
}

- (UIImage *)resizedImageWithContentMode:(UIViewContentMode)contentMode imageToScale:(UIImage*)imageToScale bounds:(CGSize)bounds interpolationQuality:(CGInterpolationQuality)quality {
    //Get the size we want to scale it to
    CGFloat horizontalRatio = bounds.width / imageToScale.size.width;
    CGFloat verticalRatio = bounds.height / imageToScale.size.height;
    CGFloat ratio;
    
    switch (contentMode) {
        case UIViewContentModeScaleAspectFill:
            ratio = MAX(horizontalRatio, verticalRatio);
            break;
            
        case UIViewContentModeScaleAspectFit:
            ratio = MIN(horizontalRatio, verticalRatio);
            break;
            
        default:
            [NSException raise:NSInvalidArgumentException format:@"Unsupported content mode: %d", contentMode];
    }
    
    //...and here it is
    CGSize newSize = CGSizeMake(imageToScale.size.width * ratio, imageToScale.size.height * ratio);
    CGPoint thumbnailPoint = CGPointMake(0.0,0.0);
    //Si taille des image est différentes on redimensionne de facon proportionnelle
    if (CGSizeEqualToSize(newSize, bounds) == NO) {
        thumbnailPoint.x = (bounds.width - newSize.width) * 0.5;
        thumbnailPoint.y = (bounds.height - newSize.height) * 0.5;
//
//        //Centre l'image
//        if (widthFactor > heightFactor)
//        {
//            thumbnailPoint.y = (targetHeight - scaledHeight) * 0.5;
//        }
//        else if (widthFactor < heightFactor)
//        {
//            thumbnailPoint.x = (targetWidth - scaledWidth) * 0.5;
//        }
    }
    
    UIGraphicsBeginImageContext(bounds);
    
    CGRect thumbnailRect = CGRectZero;
    thumbnailRect.origin = thumbnailPoint;
    thumbnailRect.size.width  = newSize.width;
    thumbnailRect.size.height = newSize.height;
    
    [imageToScale drawInRect:thumbnailRect];
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
//
//
//
//
//    //start scaling it
//    CGRect newRect = CGRectIntegral(CGRectMake(0, 0, newSize.width, newSize.height));
//    CGImageRef imageRef = imageToScale.CGImage;
//    CGContextRef bitmap = CGBitmapContextCreate(NULL,
//                                                newRect.size.width,
//                                                newRect.size.height,
//                                                CGImageGetBitsPerComponent(imageRef),
//                                                0,
//                                                CGImageGetColorSpace(imageRef),
//                                                CGImageGetBitmapInfo(imageRef));
//
//    CGContextSetInterpolationQuality(bitmap, quality);
//
//    // Draw into the context; this scales the image
//    CGContextDrawImage(bitmap, newRect, imageRef);
//
//    // Get the resized image from the context and a UIImage
//    CGImageRef newImageRef = CGBitmapContextCreateImage(bitmap);
//    UIImage *newImage = [UIImage imageWithCGImage:newImageRef];
//
//    // Clean up
//    CGContextRelease(bitmap);
//    CGImageRelease(newImageRef);
    
    return newImage;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    _destViewController = nil;
    if ([segue.identifier isEqualToString:@"showPreviewImage"]) {
        _destViewController = segue.destinationViewController;
        _destViewController.imageCapture = _fImageCapture;//[recipes objectAtIndex:indexPath.row];
        _destViewController.angleDevice = _fAngleDevice;
        _destViewController.sImageCapture = _sImageCapture;
        _destViewController.sAngleDevice = _sAngleDevice;
    }
}

#pragma mark -
#pragma mark Actions

- (IBAction)resetButtonPress:(id)sender {
    indexCapture = 1;
    self.numberCapture.text = [NSString stringWithFormat:@"Chụp lần %d", indexCapture];
}

- (IBAction)flashButtonWasTouched:(UIButton *)sender {
//    [self toggleFlashModeButtons];
}


- (IBAction)flashModeButtonWasTouched:(UIButton *)sender {
//    if (sender == self.flashAutoButton) {
//        self.flashMode = AVCaptureFlashModeAuto;
//    } else if (sender == self.flashOnButton) {
//        self.flashMode = AVCaptureFlashModeOn;
//    } else {
//        self.flashMode = AVCaptureFlashModeOff;
//    }
//
//    [self updateFlashlightState];
//
//    [self toggleFlashModeButtons];
}


- (IBAction)cameraButtonWasTouched:(UIButton *)sender
{
    if (!self.session) return;
    [self.session stopRunning];
    
    // Input Switch
    NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
        AVCaptureDeviceInput *input = self.session.inputs.firstObject;
        
        AVCaptureDevice *newCamera = nil;
        
        if (input.device.position == AVCaptureDevicePositionBack) {
            newCamera = [self frontCamera];
        } else {
            newCamera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        }
        
        // Should the flash button still be displayed?
        dispatch_async(dispatch_get_main_queue(), ^{
//            self.flashButton.hidden = !newCamera.isFlashAvailable;
        });
        
        // Remove previous camera, and add new
        [self.session removeInput:input];
        NSError *error = nil;
        
        input = [AVCaptureDeviceInput deviceInputWithDevice:newCamera error:&error];
        if (!input) return;
        [self.session addInput:input];
    }];
    operation.completionBlock = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.session) return;
            [self.session startRunning];
            [self.blurView removeFromSuperview];
        });
    };
    operation.queuePriority = NSOperationQueuePriorityVeryHigh;
    
    // disable button to avoid crash if the user spams the button
    self.cameraButton.enabled = NO;
    
    // Add blur to avoid flickering
    self.blurView.hidden = NO;
    [self.capturePreviewView addSubview:self.blurView];
//    [self.blurView autoPinEdgesToSuperviewEdges];
    
    // Flip Animation
    [UIView transitionWithView:self.capturePreviewView
                      duration:0.5f
                       options:UIViewAnimationOptionTransitionFlipFromLeft | UIViewAnimationOptionAllowAnimatedContent
                    animations:nil
                    completion:^(BOOL finished) {
                        self.cameraButton.enabled = YES;
                        [self.captureQueue addOperation:operation];
                    }];
}


- (IBAction)openPhotoAlbumButtonWasTouched:(UIButton *)sender
{
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePickerController.delegate = self;
    
    [self presentViewController:imagePickerController animated:YES completion:nil];
}


- (IBAction)takePhotoButtonWasTouched:(UIButton *)sender
{
    [self takePicture];
}


- (IBAction)cancelButtonWasTouched:(UIButton *)sender
{
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}


- (void)orientationChanged:(NSNotification *)sender
{
//    [self updateOrientation];
}


- (void)doneBarButtonWasTouched:(UIBarButtonItem *)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (UIImage*)captureImageShare:(UIImage *)image {
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, image.size.width, image.size.height)];
    //    view.backgroundColor = [UIColor colorWithPatternImage:image];
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:view.bounds];
    imageView.image = image;
//    imageView.contentMode = UIViewContentModeScaleAspectFill;
    [view addSubview:imageView];
    
    CGRect rect = [view bounds];
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 1.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [view.layer renderInContext:context];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return img;
}

//#pragma mark -
//#pragma mark UIImagePickerControllerDelegate
//
//- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info
//{
//    UIImage *image = info[UIImagePickerControllerOriginalImage];
//
//    [self dismissViewControllerAnimated:YES completion:^{
//        [self handleImage:image];
//    }];
//}
//
//
//- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
//{
//    [self dismissViewControllerAnimated:YES completion:nil];
//}

@end
