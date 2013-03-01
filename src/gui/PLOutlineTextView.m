//
//  PLOutlineTextView.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 19/08/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PLOutlineTextView.h"


@implementation PLOutlineTextView

- (void) keyDown:(NSEvent *)event
{
    if ([[event characters] length] > 0) {
        //NSLog(@"%u %u %u", [event keyCode], [[event characters] length], [[event characters] characterAtIndex:0]);
        if ([[event characters] characterAtIndex:0] == 27) {
            [[NSNotificationCenter defaultCenter] postNotificationName:PLOUTLINETEXTVIEW_CANCEL object:self];
            [[self window] makeFirstResponder:[self window]];
            return;
        }
    }
    
    [super keyDown:event];
}

- (void)insertText:(NSString *)insertStr
{
    [super insertText:insertStr];
    [[NSNotificationCenter defaultCenter] postNotificationName:PLOUTLINETEXTVIEW_DIDINSERTTEXT object:self];
}

@end
