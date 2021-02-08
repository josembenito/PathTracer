/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Header for platform independent renderer class
*/

#import <MetalKit/MetalKit.h>

// Our platform independent renderer class.   Implements the MTKViewDelegate protocol which
//   allows it to accept per-frame update and drawable resize callbacks.
@interface Renderer : NSObject <MTKViewDelegate>

-(nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)view;

-(void) moveCameraWithSpeedX:(float)x Y:(float)y Z:(float)z RX:(float)rx RY:(float)ry;
- (void)createSceneFromUrl:(NSURL*)fileUrl;
@end

