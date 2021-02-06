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
- (void)keyDown:(NSEvent *)event;
- (BOOL)acceptsFirstResponder;


- (void)mouseMoved:(NSEvent *)event;
@property (weak, nonatomic) NSViewController* viewController;
@end

