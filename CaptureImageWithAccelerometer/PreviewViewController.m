//
//  PreviewViewController.m
//  CaptureImageWithAccelerometer
//
//  Created by Trong Ton on 6/5/18.
//  Copyright © 2018 trong.ton2003@gmail.com. All rights reserved.
//

#import "PreviewViewController.h"
#import "AFAppDotNetAPIClient.h"
#import <sys/utsname.h>

@interface PreviewViewController ()

@property (weak, nonatomic) IBOutlet UIButton *closeButton;
@property (weak, nonatomic) IBOutlet UIImageView *imagePreview;
@property (weak, nonatomic) IBOutlet UILabel *angleLable;
@property (weak, nonatomic) IBOutlet UIButton *saveButton;

@end

@implementation PreviewViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _closeButton.layer.cornerRadius = _closeButton.bounds.size.width/2;
    _imagePreview.image = _imageCapture;
    _angleLable.text = [NSString stringWithFormat:@"Image capture at: %.2f", _angleDevice];
    
    _loadingView = [[MBProgressHUD alloc] initWithView:self.view];
    _loadingView.animationType = MBProgressHUDAnimationZoom;
    _loadingView.labelText = @"Loading...";
    [self.view addSubview:_loadingView];
    [_loadingView hide:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)closeButtonPress:(id)sender {
    [self dismissViewControllerAnimated:YES completion:^{
    }];
}

- (IBAction)saveButtonPress:(id)sender {
    //do save image to server
    [_loadingView show:YES];
    [self saveImageToServer];
}

#pragma mark - API function

- (void)saveImageToServer {
//    NSString *DeviceInfo = [[UIDevice currentDevice] localizedModel];
    struct utsname systemInfo;
    uname(&systemInfo);
//    NSString *iOSDeviceModelsPath = [[NSBundle mainBundle] pathForResource:@"iOSDeviceModelMapping" ofType:@"plist"];
//    NSDictionary *iOSDevices = [NSDictionary dictionaryWithContentsOfFile:iOSDeviceModelsPath];
    NSString* deviceModel = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
    NSString *version = [[UIDevice currentDevice] systemVersion];
    
    NSData *fimageData = UIImageJPEGRepresentation(self.imageCapture, 1.0);
    NSData *simageData = UIImageJPEGRepresentation(self.sImageCapture, 1.0);
//    NSMutableData *fileAngleData = [NSMutableData dataWithCapacity:0];
//    [fileAngleData appendBytes:&_angleDevice length:sizeof(float)];
//    NSMutableData *sfileAngleData = [NSMutableData dataWithCapacity:0];
//    [sfileAngleData appendBytes:&_sAngleDevice length:sizeof(float)];
//    NSData *deviceData = [DeviceInfo dataUsingEncoding:NSUTF8StringEncoding];
//    NSData *versionData = [version dataUsingEncoding:NSUTF8StringEncoding];
    
//    NSMutableDictionary *parame = [[NSMutableDictionary alloc] init];
//    [parame setObject:@"new" forKey:@"action"];
//    [parame setObject:[NSNumber numberWithFloat:_angleDevice] forKey:@"fileAngle"];
//    [parame setObject:[NSNumber numberWithFloat:_sAngleDevice] forKey:@"sfileAngle"];
//    [parame setObject:DeviceInfo forKey:@"deviceName"];
//    [parame setObject:version forKey:@"osVersion"];
//    @"api?action=new"
    NSString *partLink = [NSString stringWithFormat:@"api?action=new&fileAngle=%.2f&sfileAngle=%.2f&deviceName=%@&osVersion=%@",_angleDevice, _sAngleDevice, deviceModel, version];
    [[AFAppDotNetAPIClient sharedClient] POST:partLink parameters:nil constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        [formData appendPartWithFileData:fimageData name:@"fimage" fileName:@"fimage.jpg" mimeType:@"image/jpeg"];
        [formData appendPartWithFileData:simageData name:@"simage" fileName:@"simage.jpg" mimeType:@"image/jpeg"];
//        [formData appendPartWithFormData:fileAngleData name:@"fileAngle"];
//        [formData appendPartWithFormData:sfileAngleData name:@"sfileAngle"];
//        [formData appendPartWithFormData:deviceData name:@"deviceName"];
//        [formData appendPartWithFormData:versionData name:@"osVersion"];
    } progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        int success = [[responseObject objectForKey:@"errorCode"] boolValue];
        if (success == 1) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.loadingView hide:YES];
                [self closeButtonPress:nil];
            });
        } else {
            [self.loadingView hide:YES];
            NSString *errorString = [responseObject objectForKey:@"errorMsg"];
            UIAlertController *alertView = [UIAlertController alertControllerWithTitle:@"Thông báo" message:errorString preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* closeButton = [UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
            }];
            [alertView addAction:closeButton];
            [self presentViewController:alertView animated:YES completion:nil];
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"error message %s = %@", __PRETTY_FUNCTION__, error.localizedDescription);
        [self.loadingView hide:YES];
        UIAlertController *alertView = [UIAlertController alertControllerWithTitle:@"Thông báo" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* closeButton = [UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        }];
        [alertView addAction:closeButton];
        [self presentViewController:alertView animated:YES completion:nil];
    }];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
