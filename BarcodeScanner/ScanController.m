//
//  ScanController.m
//  BarcodeScanner
//
//  Created by Vijay Subrahmanian on 09/05/15.
//  Copyright (c) 2015 Vijay Subrahmanian. All rights reserved.
//

#import "ScanController.h"
#import <AVFoundation/AVFoundation.h>

@interface ScanController () <AVCaptureMetadataOutputObjectsDelegate>

@property (weak, nonatomic) IBOutlet UIView *cameraPreviewView;
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *captureLayer;
@property AVCaptureAutoFocusRangeRestriction autoFocusRangeRestriction;
@property UITapGestureRecognizer *recognizer;
@property AVCaptureDevice *captureDevice;
//@property AVCaptureDevice *flash;

@end

@implementation ScanController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self setupScanningSession];
//    [self setUpFlash];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // Start the camera capture session as soon as the view appears completely.
    [self.captureSession startRunning];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)setupScanningSession {
    // Initalising hte Capture session before doing any video capture/scanning.
    self.captureSession = [[AVCaptureSession alloc] init];
    
    NSError *error;
    // Set camera capture device to default and the media type to video.
    self.captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    // Set video capture input: If there a problem initialising the camera, it will give am error.
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:self.captureDevice error:&error];
    
    if (!input) {
        NSLog(@"Error Getting Camera Input");
        return;
    }
    // Adding input souce for capture session. i.e., Camera
    [self.captureSession addInput:input];

    AVCaptureMetadataOutput *captureMetadataOutput = [[AVCaptureMetadataOutput alloc] init];
    // Set output to capture session. Initalising an output object we will use later.
    [self.captureSession addOutput:captureMetadataOutput];
    
    [self.captureDevice lockForConfiguration:nil];
    CGPoint focusPoint = self.cameraPreviewView.center;
    if (input.device.isFocusPointOfInterestSupported) {
        self.captureDevice.focusPointOfInterest = focusPoint;
    }
    
    UIView *highlight = [[UIView alloc] initWithFrame:CGRectMake(self.cameraPreviewView.frame.size.width/6, self.cameraPreviewView.frame.size.height/3.7, self.view.frame.size.width / 1.5, self.view.frame.size.width / 1.5)];
    highlight.backgroundColor = [UIColor clearColor];
    highlight.layer.borderWidth = 2.0;
    highlight.layer.borderColor = [UIColor redColor].CGColor;
//    NSLog(@"%f, %f, %f, %f", self.view.frame.origin.x, self.view.frame.origin.y, self.cameraPreviewView.frame.origin.x, self.cameraPreviewView.frame.origin.y);
    
//    [self setUpFlash];
    
    // Create a new queue and set delegate for metadata objects scanned.
    dispatch_queue_t dispatchQueue;
    dispatchQueue = dispatch_queue_create("scanQueue", NULL);
    [captureMetadataOutput setMetadataObjectsDelegate:self queue:dispatchQueue];
    // Delegate should implement captureOutput:didOutputMetadataObjects:fromConnection: to get callbacks on detected metadata.
    [captureMetadataOutput setMetadataObjectTypes:[captureMetadataOutput availableMetadataObjectTypes]];
    
    // Layer that will display what the camera is capturing.
    self.captureLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    [self.captureLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [self.captureLayer setFrame:self.cameraPreviewView.layer.bounds];
    // Adding the camera AVCaptureVideoPreviewLayer to our view's layer.
    [self.cameraPreviewView.layer addSublayer:self.captureLayer];
    [self.cameraPreviewView addSubview:highlight];
}


-(IBAction) setUpFlash {
    if([self.captureDevice isFlashAvailable] && [self.captureDevice isTorchModeSupported:AVCaptureTorchModeOn]) {
        BOOL success = [self.captureDevice lockForConfiguration:nil];
        if (success) {
            if ([self.captureDevice isTorchActive]) {
                self.captureDevice.torchMode = AVCaptureTorchModeOff;
            } else {
                self.captureDevice.torchMode = AVCaptureTorchModeOn;
            }
            [self.captureDevice unlockForConfiguration];
        }
    }
}


-(void) configureTap {
    self.recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusTap:)];
    [self.cameraPreviewView addGestureRecognizer:self.recognizer];
}


-(void) focusTap:(UITapGestureRecognizer *)tap {
    CGPoint tapPoint = [self.recognizer locationInView:self.recognizer.view];
    CGPoint devicePoint = [self.captureLayer captureDevicePointOfInterestForPoint:tapPoint];
    self.captureDevice.focusPointOfInterest = devicePoint;
    self.captureDevice.focusMode = AVCaptureFocusModeContinuousAutoFocus;
    [self.captureDevice unlockForConfiguration];
}


// AVCaptureMetadataOutputObjectsDelegate method
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    // Do your action on barcode capture here:
    NSString *capturedBarcode = nil;
    CGRect HLViewrect = CGRectZero;
    // Specify the barcodes you want to read here:
    NSArray *supportedBarcodeTypes = @[AVMetadataObjectTypeUPCECode,
                                       AVMetadataObjectTypeCode39Code,
                                       AVMetadataObjectTypeCode39Mod43Code,
                                       AVMetadataObjectTypeEAN13Code,
                                       AVMetadataObjectTypeEAN8Code,
                                       AVMetadataObjectTypeCode93Code,
                                       AVMetadataObjectTypeCode128Code,
                                       AVMetadataObjectTypePDF417Code,
                                       AVMetadataObjectTypeQRCode,
                                       AVMetadataObjectTypeAztecCode];
    
    // In all scanned values..
    for (AVMetadataObject *barcodeMetadata in metadataObjects) {
        // ..check if it is a suported barcode
        for (NSString *supportedBarcode in supportedBarcodeTypes) {
            
            if ([supportedBarcode isEqualToString:barcodeMetadata.type]) {
                // This is a supported barcode
                // Note barcodeMetadata is of type AVMetadataObject
                // AND barcodeObject is of type AVMetadataMachineReadableCodeObject
                AVMetadataMachineReadableCodeObject *barcodeObject = (AVMetadataMachineReadableCodeObject *)[self.captureLayer transformedMetadataObjectForMetadataObject:barcodeMetadata];
                capturedBarcode = [barcodeObject stringValue];
                HLViewrect = barcodeObject.bounds;
                // Got the barcode. Set the text in the UI and break out of the loop.
                
                dispatch_sync(dispatch_get_main_queue(), ^{
//                    [self.captureSession stopRunning];
                    // upload task here
                    NSString *code = [NSString stringWithFormat:@"%@", @"http://140.116.82.52/reader.php?code="];
                    NSString *code2 = [code stringByAppendingString:capturedBarcode];
                    NSURL *url = [NSURL URLWithString:code2];
                    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
                });
                return;
            }
        }
    }
}

@end
