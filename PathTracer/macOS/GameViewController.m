/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Implementation for our macOS view controller
*/

#import "GameViewController.h"
#import "Renderer.h"
#import "GameView.h"

@implementation GameViewController
{
    //MTKView *_view;
    GameView * _view;
    Renderer *_renderer;
    NSPoint prevMouseLocation;

}

- (void)viewDidLoad
{
    [super viewDidLoad];

    
    //_view = (MTKView *)self.view;
    _view = (GameView *)self.view;
    
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(globalKeyDown:) name:@"viewKeyEvent" object:nil];
    
    // Set color space of view to SRGB  
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceLinearSRGB);
    _view.colorspace = colorSpace;
    CGColorSpaceRelease(colorSpace);
    
    // Lookup high power GPU if this is a discrete GPU system
    NSArray<id <MTLDevice>> *devices = MTLCopyAllDevices();
    
    id <MTLDevice> device = devices[0];
    
    for (id <MTLDevice> potentialDevice in devices) {
        if (!potentialDevice.lowPower) {
            device = potentialDevice;
            break;
        }
    }

    _view.device = device;
    [_view becomeFirstResponder];
    
    if(!_view.device)
    {
        NSLog(@"Metal is not supported on this device");
        self.view = [[NSView alloc] initWithFrame:self.view.frame];
        return;
    }

    _renderer = [[Renderer alloc] initWithMetalKitView:_view];

    [_renderer mtkView:_view drawableSizeWillChange:_view.bounds.size];

    _view.delegate = _renderer;
    _view.viewController = self;
    
    prevMouseLocation = [NSEvent mouseLocation];

}

-(void) mouseEnteredView: (NSEvent *) event
{
    prevMouseLocation = [NSEvent mouseLocation];
}

-(void) mouseExitedView: (NSEvent *) event
{
    prevMouseLocation = [NSEvent mouseLocation];

}

-(bool) viewEvent: (NSEvent *) event
{
    bool ret = false;
    const float moveLength = 1.f;
    float x = 0, y = 0, z = 0, rx = 0, ry = 0;
    if ([event type] == NSEventTypeKeyUp ) {
        if( [event keyCode] == 123) {
            x=-moveLength;
            ret = true;
        }
        if( [event keyCode] == 124) {
            x=moveLength;
            ret = true;
        }
        if( [event keyCode] == 125) {
            z=-moveLength;
            ret = true;
        }
        if( [event keyCode] == 126) {
            z=moveLength;
            ret = true;
        }
        if( [event keyCode] == 116) {
            y=moveLength;
            ret = true;
        }
        if( [event keyCode] == 121) {
            y=-moveLength;
            ret = true;
        }
        if( [event keyCode] == 0) {
            ry=moveLength;
            ret = true;
        }
        if( [event keyCode] == 2) {
            ry=-moveLength;
            ret = true;
        }
        if( [event keyCode] == 13) {
            rx=moveLength;
            ret = true;
        }
        if( [event keyCode] == 1) {
            rx=-moveLength;
            ret = true;
        }
    }
    else if ([event type] == NSEventTypeLeftMouseDragged) {
        NSPoint mouseLocation = [NSEvent mouseLocation];
        NSPoint mouseDelta;
        mouseDelta.x = mouseLocation.x-prevMouseLocation.x;
        mouseDelta.y = mouseLocation.y-prevMouseLocation.y;
        prevMouseLocation = mouseLocation;
        NSLog(@"mouse dragged:%lu",(unsigned long)[NSEvent pressedMouseButtons]);
        if ([NSEvent pressedMouseButtons] == 1) {
            ry=-mouseDelta.x*0.01f;
            rx=mouseDelta.y*0.01f;
            ret = true;
        }
    }
    else if ([event type] == NSEventTypeLeftMouseDown) {
        prevMouseLocation = [NSEvent mouseLocation];
        NSLog(@"mouseDown");
    }
    else if ([event type] == NSEventTypeLeftMouseUp) {
        NSLog(@"mouseUp");
    }
    if (ret) {
        [_renderer moveCameraWithSpeedX:x Y:y Z:z RX:rx RY:ry];
    }
    return ret;
}

-(bool)loadMeshFromUrl:(NSURL *)fileURL
{
    [_renderer createSceneFromUrl:fileURL];
    return true;
}
@end
