//
//  PreviewViewController.h
//  CaptureImageWithAccelerometer
//
//  Created by Trong Ton on 6/5/18.
//  Copyright © 2018 trong.ton2003@gmail.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MBProgressHUD.h"
#import "RBVolumeButtons.h"

@interface PreviewViewController : UIViewController {
    
}

@property (nonatomic, strong) MBProgressHUD *loadingView;
@property (strong, nonatomic) UIImage *imageCapture;
@property (strong, nonatomic) UIImage *sImageCapture;

@property (assign, nonatomic) float angleDevice;
@property (assign, nonatomic) float sAngleDevice;

//@property (nonatomic, strong) RBVolumeButtons *buttonStealer;

- (IBAction)saveButtonPress:(id)sender;

@end
