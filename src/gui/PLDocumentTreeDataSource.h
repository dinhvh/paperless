//
//  PLDocumentTreeDataSource.h
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 16/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PLLibrary;
@class PLDocumentByDate;
@class PLDocument;
@class PLDocumentTreeDataSource;
@class PLFileManager;

@protocol PLDocumentTreeDataSourceDelegate

- (void) plDocumentTreeDataSource_selectionDidChange:(PLDocumentTreeDataSource *)source;
- (void) plDocumentTreeDataSource_importFileList:(NSArray *)fileList;
- (void) plDocumentTreeDataSource_renameDocument:(PLDocument *)doc name:(NSString *)name;
- (NSArray *) plDocumentTreeDataSource_exportDocumentList:(NSArray *)docList toFolder:(NSString *)folder;
- (void) plDocumentTreeDataSource_revealInFinder;

- (void) plDocumentTreeDataSource_beforeEdit;
- (void) plDocumentTreeDataSource_afterEdit;

@end

@interface PLDocumentTreeDataSource : NSObject <NSOutlineViewDataSource, NSOutlineViewDelegate> {
    PLLibrary * _library;
    PLDocumentByDate * _documentByDate;
    NSMutableArray * _nodeList;
    NSOutlineView * _outlineView;
    id _delegate;
    BOOL _dragValidResult;
    // filter
    BOOL _filterEnabled;
    PLDocumentByDate * _filteredDocumentByDate;
    NSMutableArray * _filteredNodeList;
    NSMenu * _documentMenu;
    NSDateFormatter * _dateFormatter;
}

@property (assign) id delegate;
@property (retain) NSOutlineView * outlineView;

- (id) initWithLibrary:(PLLibrary *)library;
- (void) dealloc;

- (void) setup;

- (void) addDocument:(PLDocument *)doc;
- (void) addDocument:(PLDocument *)doc sort:(BOOL)sortFlag;
- (void) addDocumentList:(NSArray *)docList;
- (void) addDocumentList:(NSArray *)docList sort:(BOOL)sortFlag;
- (void) removeDocument:(PLDocument *)doc;
- (void) removeDocumentList:(NSArray *)docList;
//- (void) modifyDocumentTimestamp:(PLDocument *)doc;
- (void) preModifyDocumentTimestamp:(PLDocument *)doc;
- (void) postModifyDocumentTimestamp:(PLDocument *)doc;

- (void) reloadData;
- (void) reloadDataLight:(BOOL)light;

- (NSArray *) selection;

// data source
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item;
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item;
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item;
- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item;

// delegate
- (NSDragOperation) outlineView:(NSOutlineView *)outlineView draggingEntered:(id < NSDraggingInfo >)sender;
- (NSDragOperation) outlineView:(NSOutlineView *)outlineView draggingUpdated:(id < NSDraggingInfo >)sender;
- (void) outlineView:(NSOutlineView *)outlineView draggingExited:(id < NSDraggingInfo >)sender;
- (BOOL) outlineView:(NSOutlineView *)outlineView prepareForDragOperation:(id <NSDraggingInfo>)sender;
- (BOOL) outlineView:(NSOutlineView *)outlineView performDragOperation:(id <NSDraggingInfo>)sender;
- (void) outlineView:(NSOutlineView *)outlineView concludeDragOperation:(id <NSDraggingInfo>)sender;
- (BOOL) outlineView:(NSOutlineView *)outlineView keyDown:(NSEvent *)theEvent;
- (void)outlineViewSelectionDidChange:(NSNotification *)notification;
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item;
- (NSDragOperation) outlineView:(NSOutlineView *)outlineView draggingSourceOperationMaskForLocal:(BOOL)isLocal;
- (NSArray *)outlineView:(NSOutlineView *)outlineView namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination forDraggedItems:(NSArray *)items;
- (BOOL) outlineView:(NSOutlineView *)outlineView drawRow:(NSInteger)rowIndex clipRect:(NSRect)clipRect;
- (NSMenu *) outlineView:(NSOutlineView *)outlineView menuForEvent:(NSEvent *)event;

- (void) applyFilter:(NSArray *)documentList;
- (void) cancelFilter;
- (BOOL) filterEnabled;

- (void) selectDocumentList:(NSArray *)documentList;
- (void) editName;

@end
