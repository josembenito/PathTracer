//
//  MTKView+GameView.m
//  MPSPathTracingSample-macOS
//
//  Created by Chema on 28/09/2020.
//  Copyright © 2020 Apple. All rights reserved.
//

#import "GameView.h"
#import "GameViewController.h"

@implementation GameView
{
    
}

- (void) viewWillMoveToWindow:(NSWindow *)newWindow {
    // Setup a new tracking area when the view is added to the window.
    NSTrackingArea* trackingArea = [[NSTrackingArea alloc] initWithRect:[self bounds] options: (NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingMouseMoved) owner:self userInfo:nil];
    [self addTrackingArea:trackingArea];
}


	
- (void)keyUp:(NSEvent *)event
{
    GameViewController* gameViewController = (GameViewController*) self.viewController;
    if (! [gameViewController globalKeyDown:event]) {
        [super keyDown:event];
    }
    NSLog(@"%hu",event.keyCode);
    
}

- (void)mouseEntered:(NSEvent *)event
{
    GameViewController* gameViewController = (GameViewController*) self.viewController;
    [gameViewController globalMouseEntered:event];
}

- (void)mouseMoved:(NSEvent *)event {
    GameViewController* gameViewController = (GameViewController*) self.viewController;
    if (! [gameViewController globalKeyDown:event]) {

    }
}
- (IBAction)onButtonPushed:(id)sender {
    NSLog(@"Hello");
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}
@end
