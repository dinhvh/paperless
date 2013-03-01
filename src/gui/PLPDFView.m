//
//  PLPDFView.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 16/08/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PLPDFView.h"

#import "PLMainWindowController.h"

@implementation PLPDFView

- (void)mouseDown:(NSEvent *)theEvent
{
    if ([theEvent clickCount] == 2) {
        [[PLMainWindowController sharedController] openInPreview:self];
        return;
    }
    
    [super mouseDown:theEvent];
}

@end
