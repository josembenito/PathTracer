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
    if (! [gameViewController viewEvent:event]) {
        [super keyUp:event];
    }
    NSLog(@"%hu",event.keyCode);
    
}

- (void)mouseDown:(NSEvent *)event
{
    GameViewController* gameViewController = (GameViewController*) self.viewController;
    if (! [gameViewController viewEvent:event]) {
        [super mouseDown:event];
    }
}

- (void)mouseUp:(NSEvent *)event
{
    GameViewController* gameViewController = (GameViewController*) self.viewController;
    if (! [gameViewController viewEvent:event]) {
        [super mouseUp:event];
    }
}

-(void)mouseDragged:(NSEvent *)event
{
    GameViewController* gameViewController = (GameViewController*) self.viewController;
    [gameViewController viewEvent:event];
}

- (void)mouseEntered:(NSEvent *)event
{
    GameViewController* gameViewController = (GameViewController*) self.viewController;
    [gameViewController mouseEnteredView:event];
}

- (void)mouseExited:(NSEvent *)event
{
    GameViewController* gameViewController = (GameViewController*) self.viewController;
    [gameViewController mouseEnteredView:event];
}


- (void)mouseMoved:(NSEvent *)event {
    GameViewController* gameViewController = (GameViewController*) self.viewController;
    if (! [gameViewController viewEvent:event]) {

    }
}
- (IBAction)onButtonPushed:(id)sender {
    // Create the File Open Dialog class.
    NSOpenPanel* openDlg = [NSOpenPanel openPanel];

    // Enable the selection of files in the dialog.
    [openDlg setCanChooseFiles:YES];

    // Multiple files not allowed
    [openDlg setAllowsMultipleSelection:NO];

    // Can't select a directory
    [openDlg setCanChooseDirectories:NO];

    // Display the dialog. If the OK button was pressed,
    // process the files.
    if ( [openDlg runModal] == NSModalResponseOK )
    {
        // Get an array containing the full filenames of all
        // files and directories selected.
        NSArray* urls = [openDlg URLs];

        // Loop through all the files and process them.
//        for(int i = 0; i < [urls count]; i++ )
        int i = 0;
        {
            NSString* urlString = [urls objectAtIndex:i];
            NSString *urlStr =[NSString stringWithFormat:@"%@", urlString];
            NSURL *url = [NSURL URLWithString:urlStr];
            NSLog(@"Url: %@", urlString);
            GameViewController* gameViewController = (GameViewController*) self.viewController;
            [gameViewController loadMeshFromUrl:url];
        }
    }
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}
@end
