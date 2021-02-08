/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Header for our macOS view controller
*/

#import <Cocoa/Cocoa.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import "Renderer.h"

// Our macOS view controller.
@interface GameViewController : NSViewController
-(bool) loadMeshFromUrl:(NSURL*) fileURL;
-(bool) viewEvent: (NSEvent *) event;
-(void) mouseEnteredView: (NSEvent *) event;
-(void) mouseExitedView: (NSEvent *) event;
@end
