//
//  PLMainWindowController.h
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 3/24/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@class PLLibrary;
@class PLDocumentTreeDataSource;
@class PLDocument;
@class PLTextView;
@class PLOutlineTextView;
@class PLEyeFiManager;

@interface PLMainWindowController : NSWindowController {
	NSMutableDictionary * _toolbarDict;
	NSToolbar * _toolbar;
	IBOutlet NSSearchField * _searchField;
    IBOutlet NSOutlineView * _outlineView;
    IBOutlet PDFView * _pdfView;
    IBOutlet PLTextView * _commentView;
    IBOutlet NSView * _rightView;
    IBOutlet NSView * _placeHolderWithlabelView;
    IBOutlet NSTextField * _labelView;
    IBOutlet NSTextField * _progressLabel;
    IBOutlet NSProgressIndicator * _progressView;
    PLLibrary * _library;
    PLDocumentTreeDataSource * _dataSource;
    BOOL _scanning;
    NSString * _searchStr;
    NSString * _delayedComment;
    BOOL _hasDelayedComment;
    NSUndoManager * _undoManager;
    PLDocument * _currentDoc;
    BOOL _fmProgressStarted;
    BOOL _scanProgressStarted;
    BOOL _progressVisible;
    PLOutlineTextView * _textViewForOutlineView;
    NSString * _savedText;
    BOOL _editAfterImport;
    PLDocument * _editAfterImportDoc;
    PLEyeFiManager * _eyeFi;
    BOOL _eyeFiStarted;
}

@property (retain) NSUndoManager * undoManager;

+ (PLMainWindowController *) sharedController;

- (BOOL) scanning;

- (void) scan:(id)sender;
- (BOOL) isScanEnabled;

- (void) merge:(id)sender;
- (BOOL) isMergeEnabled;

- (BOOL) isRevealInFinderEnabled;
- (void) revealInFinder:(id)sender;

- (void) openInPreview:(id)sender;
- (BOOL) isOpenInPreviewEnabled;

- (void) save;

- (BOOL) isUndoEnabled;
- (void) undo:(id)sender;

- (BOOL) isRedoEnabled;
- (void) redo:(id)sender;

- (void) deleteDocument:(id)sender;
- (BOOL) isDeleteDocumentEnabled;

- (void) updateUndoMenuItem:(NSMenuItem *)item;
- (void) updateRedoMenuItem:(NSMenuItem *)item;

- (void) editName;

- (void) applyFilter:(NSArray *)documentList;
- (void) cancelFilter;

- (void) export:(id)sender;
- (BOOL) isExportToFolderEnabled;

- (void) import:(id)sender;

- (void) save:(id)sender;
- (BOOL) isSaveEnabled;

- (void) debugCheckFiles:(id)sender;
- (void) debugRemainingFiles:(id)sender;

- (void) willTerminate;

- (void) openFileList:(NSArray *)fileList;

@end
