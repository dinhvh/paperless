//
//  PLOutlineView.h
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 22/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol PLOutlineViewDelegate <NSOutlineViewDelegate>

- (NSDragOperation) outlineView:(NSOutlineView *)outlineView draggingEntered:(id < NSDraggingInfo >)sender;
- (NSDragOperation) outlineView:(NSOutlineView *)outlineView draggingUpdated:(id < NSDraggingInfo >)sender;
- (void) outlineView:(NSOutlineView *)outlineView draggingExited:(id < NSDraggingInfo >)sender;

- (BOOL) outlineView:(NSOutlineView *)outlineView prepareForDragOperation:(id <NSDraggingInfo>)sender;
- (BOOL) outlineView:(NSOutlineView *)outlineView performDragOperation:(id <NSDraggingInfo>)sender;
- (void) outlineView:(NSOutlineView *)outlineView concludeDragOperation:(id <NSDraggingInfo>)sender;

- (BOOL) outlineView:(NSOutlineView *)outlineView keyDown:(NSEvent *)theEvent;
- (BOOL) outlineView:(NSOutlineView *)outlineView mouseDown:(NSEvent *)theEvent;

- (NSDragOperation) outlineView:(NSOutlineView *)outlineView draggingSourceOperationMaskForLocal:(BOOL)isLocal;

- (BOOL) outlineView:(NSOutlineView *)outlineView drawRow:(NSInteger)rowIndex clipRect:(NSRect)clipRect;

- (void) outlineView:(NSOutlineView *)outlineView beforeEditColumn:(NSInteger)columnIndex row:(NSInteger)rowIndex withEvent:(NSEvent *)theEvent select:(BOOL)flag;
- (void) outlineView:(NSOutlineView *)outlineView afterEditColumn:(NSInteger)columnIndex row:(NSInteger)rowIndex withEvent:(NSEvent *)theEvent select:(BOOL)flag;

- (NSMenu *) outlineView:(NSOutlineView *)outlineView menuForEvent:(NSEvent *)event;

@end

@interface PLOutlineView : NSOutlineView {

}

@end
