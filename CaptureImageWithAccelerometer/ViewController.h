//
//  ViewController.h
//  CaptureImageWithAccelerometer
//
//  Created by Trong Ton on 5/25/18.
//  Copyright © 2018 trong.ton2003@gmail.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreMotion/CMMotionManager.h>
#import "RBVolumeButtons.h"

@interface ViewController : UIViewController<UIImagePickerControllerDelegate, UINavigationControllerDelegate> {
    float device_angle;
    float rotation;
    int indexCapture;
}

@property (nonatomic, strong) RBVolumeButtons *buttonStealer;
@property (nonatomic, strong)CMMotionManager *motionManager;

@end

