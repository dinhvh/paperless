//
//  PLOutlineView.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 22/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PLOutlineView.h"


@implementation PLOutlineView

- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)sender
{
    if ([[self delegate] respondsToSelector:@selector(outlineView:draggingEntered:)]) {
        return [(id <PLOutlineViewDelegate>)[self delegate] outlineView:self draggingEntered:sender];
    }
    return NSDragOperationNone;
}

- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)sender
{
    if ([[self delegate] respondsToSelector:@selector(outlineView:draggingUpdated:)]) {
        return [(id <PLOutlineViewDelegate>)[self delegate] outlineView:self draggingUpdated:sender];
    }
    return NSDragOperationNone;
}

- (void)draggingExited:(id < NSDraggingInfo >)sender
{
    if ([[self delegate] respondsToSelector:@selector(outlineView:draggingExited:)]) {
        [(id <PLOutlineViewDelegate>)[self delegate] outlineView:self draggingExited:sender];
    }
}

- (BOOL)prepareForDragOperation:(id < NSDraggingInfo >)sender
{
    if ([[self delegate] respondsToSelector:@selector(outlineView:prepareForDragOperation:)]) {
        return [(id <PLOutlineViewDelegate>)[self delegate] outlineView:self prepareForDragOperation:sender];
    }
    return YES;
}

- (BOOL)performDragOperation:(id < NSDraggingInfo >)sender
{
    if ([[self delegate] respondsToSelector:@selector(outlineView:performDragOperation:)]) {
        return [(id <PLOutlineViewDelegate>)[self delegate] outlineView:self performDragOperation:sender];
    }
    return YES;
}

- (void)concludeDragOperation:(id < NSDraggingInfo >)sender
{
    if ([[self delegate] respondsToSelector:@selector(outlineView:concludeDragOperation:)]) {
        [(id <PLOutlineViewDelegate>)[self delegate] outlineView:self concludeDragOperation:sender];
        return;
    }
}

- (void)keyDown:(NSEvent *)theEvent
{
    if ([[self delegate] respondsToSelector:@selector(outlineView:keyDown:)]) {
        if ([(id <PLOutlineViewDelegate>)[self delegate] outlineView:self keyDown:theEvent]) {
            return;
        }
    }
    
    [super keyDown:theEvent];
}

- (void)mouseDown:(NSEvent *)theEvent
{
    if ([[self delegate] respondsToSelector:@selector(outlineView:mouseDown:)]) {
        if ([(id <PLOutlineViewDelegate>)[self delegate] outlineView:self mouseDown:theEvent]) {
            // do nothing
        }
    }
    
    [super mouseDown:theEvent];
}

- (void)drawRow:(NSInteger)rowIndex clipRect:(NSRect)clipRect
{
    if ([[self delegate] respondsToSelector:@selector(outlineView:drawRow:clipRect:)]) {
        if ([(id <PLOutlineViewDelegate>)[self delegate] outlineView:self drawRow:rowIndex clipRect:clipRect])
            [super drawRow:rowIndex clipRect:clipRect];
    }
    else {
        [super drawRow:rowIndex clipRect:clipRect];
    }
}

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
    if ([[self delegate] respondsToSelector:@selector(outlineView:draggingSourceOperationMaskForLocal:)]) {
        return [(id <PLOutlineViewDelegate>)[self delegate] outlineView:self draggingSourceOperationMaskForLocal:isLocal];
    }
    
    return [super draggingSourceOperationMaskForLocal:isLocal];
}

- (void)editColumn:(NSInteger)columnIndex row:(NSInteger)rowIndex withEvent:(NSEvent *)theEvent select:(BOOL)flag
{
    if ([[self delegate] respondsToSelector:@selector(outlineView:beforeEditColumn:row:withEvent:select:)]) {
        [(id <PLOutlineViewDelegate>)[self delegate] outlineView:self beforeEditColumn:columnIndex row:rowIndex withEvent:theEvent select:flag];
    }
    [super editColumn:columnIndex row:rowIndex withEvent:theEvent select:flag];
    if ([[self delegate] respondsToSelector:@selector(outlineView:afterEditColumn:row:withEvent:select:)]) {
        [(id <PLOutlineViewDelegate>)[self delegate] outlineView:self afterEditColumn:columnIndex row:rowIndex withEvent:theEvent select:flag];
    }
}

- (NSMenu*) menuForEvent:(NSEvent*)event
{
    if ([[self delegate] respondsToSelector:@selector(outlineView:menuForEvent:)]) {
        return [(id <PLOutlineViewDelegate>)[self delegate] outlineView:self menuForEvent:event];
    }
    
    return nil;
}

@end
