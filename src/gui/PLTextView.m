//
//  PLTextView.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 18/08/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PLTextView.h"


@implementation PLTextView

@synthesize placeholderString = _placeholderString;

- (void) drawRect:(NSRect)rect
{
    [super drawRect:rect];
    
    if (!_hasFocus || ![self isEditable]) {
        if ([[self textStorage] length] == 0) {
            NSAttributedString * attrStr;
            NSMutableDictionary * attributes;
            
            attributes = [NSMutableDictionary dictionary];
            [attributes setObject:[NSColor disabledControlTextColor] forKey:NSForegroundColorAttributeName];
            attrStr = [[NSAttributedString alloc] initWithString:[self placeholderString] attributes:attributes];
            [attrStr drawAtPoint:NSMakePoint(5.0, -1.0)];
            [attrStr release];
        }
    }
}

- (BOOL)becomeFirstResponder
{
    _hasFocus = YES;
    [self setNeedsDisplay:YES];
    return [super becomeFirstResponder];
}

- (BOOL)resignFirstResponder
{
	_hasFocus = NO;
    [self setNeedsDisplay:YES];
    return [super resignFirstResponder];
}

@end
