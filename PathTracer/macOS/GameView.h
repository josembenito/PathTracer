//
//  MTKView+GameView.h
//  MPSPathTracingSample-macOS
//
//  Created by Chema on 28/09/2020.
//  Copyright © 2020 Apple. All rights reserved.
//

#import <MetalKit/MetalKit.h>


@interface GameView : MTKView
- (void) viewWillMoveToWindow:(NSWindow *)newWindow;

- (void)keyUp:(NSEvent *)event;
- (void)keyDown:(NSEvent *)event;
- (BOOL)acceptsFirstResponder;

@property (weak, nonatomic) NSViewController* viewController;
@end

