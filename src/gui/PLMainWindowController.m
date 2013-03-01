//
//  PLMainWindowController.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 3/24/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PLMainWindowController.h"

#import "PLLibrary.h"
#import "PLDocumentTreeDataSource.h"
#import "PLDocument.h"
#import "PLScanner.h"
#import "PLPreferencesWindowController.h"
#import "PLPDFPageGeneration.h"
#import "PLFileManager.h"
#import "NSString+Date.h"
#import "PLTextView.h"
#import "PLOutlineTextView.h"
#import "PLEyeFiManager.h"

#define NORMAL_RESOLUTION 300
#define PHOTO_RESOLUTION 600

@interface PLMainWindowController (Private) <PLScannerDelegate, PLLibrarySearchDelegate, PLDocumentTreeDataSourceDelegate, PLEyeFiManagerDelegate, NSTextFieldDelegate, NSToolbarDelegate>

- (void) _setupToolbar;
- (void) _performScan;
- (void) plScanner_scanDone:(NSObject <PLScannerProtocol> *)scanner;
- (void) plLibrary_searchDone:(NSArray *)documentList;

// search view delegate
- (void)controlTextDidChange:(NSNotification *)aNotification;
- (void) _delayedSearch:(NSString *)searchStr;
- (void) _search;

// comment view delegate
- (void) textDidChange:(NSNotification *)aNotification;
- (void) _delayedSaveComment:(NSString *)comment;
- (void) _saveCommentNow;

// actions
- (void) _undoWithData:(NSArray *)data;
- (void) _deleteDocumentList:(NSArray *)documentList;
- (void) _registerUndoForDocumentDeletion:(NSArray *)documentList;
- (void) _undeleteDocumentList:(NSArray *)documentList;
- (void) _registerUndoForDocumentUndeletion:(NSArray *)documentList;
- (void) _renameDocument:(PLDocument *)doc name:(NSString *)name;
- (void) _registerUndoForDocumentRename:(PLDocument *)doc;
- (void) _mergeDocumentList:(NSArray *)documentList;
- (void) _registerUndoForDocumentMerge:(NSArray *)documentList mergedDoc:(PLDocument *)mergedDoc;
- (NSArray *) _importFileList:(NSArray *)fileList;
- (void) _importFile:(NSString *)filename documentList:(NSMutableArray *)documentList;
- (void) _registerUndoForDocumentImport:(NSArray *)documentList;
- (void) _setComment:(NSString *)comment forDocument:(PLDocument *)doc updateTextView:(BOOL)doUpdate;
- (void) _registerUndoForCommentChange:(PLDocument *)document;

// data source delegate
- (void) plDocumentTreeDataSource_selectionDidChange:(PLDocumentTreeDataSource *)source;
- (void) plDocumentTreeDataSource_importFileList:(NSArray *)fileList;
- (void) plDocumentTreeDataSource_renameDocument:(PLDocument *)doc name:(NSString *)name;
- (NSArray *) plDocumentTreeDataSource_exportDocumentList:(NSArray *)docList toFolder:(NSString *)folder;;
- (void) plDocumentTreeDataSource_revealInFinder;

- (void) _updatePreviouslyPendingDocument:(NSNotification *)notification;
- (void) _setSelectedDocument:(PLDocument *)doc;
- (void) _switchToPlaceholderView;
- (void) _switchToPDFView;

- (void) _fileManagerProgressStarted:(NSNotification *)notification;
- (void) _delayedProgressStarted;
- (void) _fileManagerProgressEnded:(NSNotification *)notification;
- (void) _fileManagerProgressUpdated:(NSNotification *)notification;
- (void) _startScanProgress;
- (void) _stopScanProgress;
- (void) _updateProgress;

- (NSArray *) _exportDocumentList:(NSArray *)docList toFolder:(NSString *)folder;
- (void)_exportOpenPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode  contextInfo:(void  *)contextInfo;

- (void) plDocumentTreeDataSource_beforeEdit;
- (void) plDocumentTreeDataSource_afterEdit;

- (void) _outlineTextView_cancelled:(NSNotification *)notification;
- (void) _outlineTextView_didInsertText:(NSNotification *)notification;

- (void) _saveEditedName;
- (void) _restoreEditedName;

- (void) _completionForName;

- (void) _viewPDFDocument;
- (void) _cancelViewPDFDocument;
- (void) _viewPDFDocumentNow;

@end

@implementation PLMainWindowController

@synthesize undoManager = _undoManager;

static PLMainWindowController * _singleton = nil;

+ (PLMainWindowController *) sharedController
{
    if (_singleton == nil)
        _singleton = [[PLMainWindowController alloc] init];
    
    return _singleton;
}

- (id) init
{
    NSUndoManager * undoManager;
    
	self = [super init];
	_library = [[PLLibrary alloc] init];
    undoManager = [[NSUndoManager alloc] init];
    [self setUndoManager:undoManager];
    
    [[PLFileManager sharedManager] cleanImport];
    [[PLFileManager sharedManager] emptyTrash];
    [[PLFileManager sharedManager] emptyDragFolder];
    _eyeFi = [[PLEyeFiManager alloc] init];
    [_eyeFi setDelegate:self];
    [_eyeFi import];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_updatePreviouslyPendingDocument:) name:PLFILEMANAGER_FINISHED_NOTIFICATION object:[PLFileManager sharedManager]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_fileManagerProgressStarted:) name:PLFILEMANAGER_PROGRESS_START_NOTIFICATION object:[PLFileManager sharedManager]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_fileManagerProgressEnded:) name:PLFILEMANAGER_PROGRESS_END_NOTIFICATION object:[PLFileManager sharedManager]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_fileManagerProgressUpdated:) name:PLFILEMANAGER_PROGRESS_UPDATE_NOTIFICATION object:[PLFileManager sharedManager]];
    
	return self;
}

- (void) dealloc
{
	[[PLPreferencesWindowController sharedController] removeObserver:self forKeyPath:@"selectedScanner"];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:PLFILEMANAGER_PROGRESS_UPDATE_NOTIFICATION object:[PLFileManager sharedManager]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:PLFILEMANAGER_PROGRESS_END_NOTIFICATION object:[PLFileManager sharedManager]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:PLFILEMANAGER_PROGRESS_START_NOTIFICATION object:[PLFileManager sharedManager]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:PLFILEMANAGER_FINISHED_NOTIFICATION object:[PLFileManager sharedManager]];
    [_textViewForOutlineView release];
    [_dataSource release];
    [_undoManager release];
    [_library release];
	[_toolbarDict release];
	[_toolbar release];
    [_savedText release];
    [_eyeFi release];
	[super dealloc];
}

- (void) save
{
    [self _setSelectedDocument:nil];
    [_library save];
}

- (NSString *) windowNibName
{
    return @"MainWindow";
}

- (void) awakeFromNib
{
	[self _setupToolbar];
    
    _dataSource = [[PLDocumentTreeDataSource alloc] initWithLibrary:_library];
    [_dataSource setOutlineView:_outlineView];
    [_dataSource setDelegate:self];
    [_dataSource setup];
    [_outlineView setDataSource:_dataSource];
    [_outlineView setDelegate:_dataSource];
    [_outlineView reloadData];
    [_outlineView registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]];
    [_outlineView expandItem:nil expandChildren:YES];
    [self plDocumentTreeDataSource_selectionDidChange:_dataSource];
    
    [_searchField setDelegate:self];
    [_commentView setPlaceholderString:@"Document comments"];
    [_commentView setDelegate:self];
    
    _textViewForOutlineView = [[PLOutlineTextView alloc] initWithFrame:[_outlineView bounds]];
    [_textViewForOutlineView setFocusRingType:NSFocusRingTypeDefault];
    [_textViewForOutlineView setFieldEditor:YES];
    [_textViewForOutlineView setRichText:NO];
    [_textViewForOutlineView setAllowedInputSourceLocales:[NSArray arrayWithObject:NSAllRomanInputSourcesLocaleIdentifier]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_outlineTextView_cancelled:) name:PLOUTLINETEXTVIEW_CANCEL object:_textViewForOutlineView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_outlineTextView_didInsertText:) name:PLOUTLINETEXTVIEW_DIDINSERTTEXT object:_textViewForOutlineView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textDidChange:) name:NSTextDidChangeNotification object:_textViewForOutlineView];
    
	[[PLPreferencesWindowController sharedController] addObserver:self forKeyPath:@"selectedScanner" options:0 context:NULL];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ((object == [PLPreferencesWindowController sharedController]) && ([keyPath isEqualToString:@"selectedScanner"])) {
        [_toolbar validateVisibleItems];
    }
}

- (void) _setupToolbar
{
	NSToolbarItem * item;

    _toolbar = [[NSToolbar alloc] initWithIdentifier:@"PaperLess"];
	[_toolbar setShowsBaselineSeparator:NO];
    [_toolbar setDelegate:self];
    _toolbarDict = [[NSMutableDictionary alloc] init];
    item = [[NSToolbarItem alloc] initWithItemIdentifier:@"scan"];
    [item setImage:[NSImage imageNamed:@"scanner.png"]];
    [item setLabel:@"Scan"];
    [item setTarget:self];
    [item setAction:@selector(scan:)];
    [_toolbarDict setObject:item forKey:[item itemIdentifier]];
    [item release];
    item = [[NSToolbarItem alloc] initWithItemIdentifier:@"merge"];
    [item setImage:[NSImage imageNamed:@"filequeue.png"]];
    [item setLabel:@"Merge"];
    [item setTarget:self];
    [item setAction:@selector(merge:)];
    [_toolbarDict setObject:item forKey:[item itemIdentifier]];
    [item release];
    item = [[NSToolbarItem alloc] initWithItemIdentifier:@"openInPreview"];
    [item setImage:[NSImage imageNamed:@"preview.icns"]];
    [item setLabel:@"Open"];
    [item setTarget:self];
    [item setAction:@selector(openInPreview:)];
    [_toolbarDict setObject:item forKey:[item itemIdentifier]];
    [item release];
    item = [[NSToolbarItem alloc] initWithItemIdentifier:@"search"];
    [item setLabel:@"Search"];
	[item setView:_searchField];
    [_toolbarDict setObject:item forKey:[item itemIdentifier]];
    [item release];
	
	//NSLog(@"setup toolbar %@ %@", self, [[[self window] toolbar] delegate]);
    [[self window] setToolbar:_toolbar];
    [[[self window] toolbar] validateVisibleItems];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
    return [_toolbarDict objectForKey:itemIdentifier];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
    return [_toolbarDict allKeys];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
    return [NSArray arrayWithObjects:@"scan", @"merge", @"openInPreview", NSToolbarFlexibleSpaceItemIdentifier, @"search", nil];
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem
{
    //NSLog(@"coin %@", [theItem itemIdentifier]);
    if ([[theItem itemIdentifier] isEqualToString:@"scan"]) {
        return [self isScanEnabled];
    }
    else if ([[theItem itemIdentifier] isEqualToString:@"merge"]) {
        return [self isMergeEnabled];
    }
    else if ([[theItem itemIdentifier] isEqualToString:@"openInPreview"]) {
        return [self isOpenInPreviewEnabled];
    }
    else if ([[theItem itemIdentifier] isEqualToString:@"search"]) {
        return YES;
    }
	else {
		return YES;
    }
}

- (BOOL) isScanEnabled
{
    if ([[PLPreferencesWindowController sharedController] selectedScanner] == nil) {
        return NO;
    }
    else {
        if (_scanning)
            return NO;
        else
            return YES;
    }
}

- (void) _updatePreviouslyPendingDocument:(NSNotification *)notification
{
    PLDocument * pendingDoc;
    NSDictionary * userInfo;
    NSArray * selection;
    
    userInfo = [notification userInfo];
    pendingDoc = [userInfo objectForKey:@"doc"];
    
    selection = [_dataSource selection];
    
    [_dataSource preModifyDocumentTimestamp:pendingDoc];
    [pendingDoc importMetaData];
    [_dataSource postModifyDocumentTimestamp:pendingDoc];
    
    [_dataSource reloadData];
    
    [_dataSource selectDocumentList:selection];
    [self plDocumentTreeDataSource_selectionDidChange:_dataSource];
    
    if (_editAfterImport && (pendingDoc == _editAfterImportDoc)) {
        [_dataSource selectDocumentList:[NSArray arrayWithObject:pendingDoc]];
        [self plDocumentTreeDataSource_selectionDidChange:_dataSource];
        [_dataSource editName];
        _editAfterImport = NO;
    }
    
    if (_currentDoc == nil)
        return;
    
    if (pendingDoc != _currentDoc)
        return;
    
    [self _viewPDFDocument];
}

- (void) plDocumentTreeDataSource_selectionDidChange:(PLDocumentTreeDataSource *)source
{
    NSArray * selection;
    
    selection = [_dataSource selection];
    
    if ([selection count] == 1) {
        PLDocument * doc;
        
        doc = [selection objectAtIndex:0];
        [self _setSelectedDocument:doc];
    }
    else {
        [self _setSelectedDocument:nil];
    }
}

- (void) scan:(id)sender
{
    [self _performScan];
}

- (void) _performScan
{
    NSObject <PLScannerProtocol> * scanner;
    int resolution;
    NSString * paperSizeName;
    
    [[self window] makeFirstResponder:[self window]];
    
    NSAssert(!_scanning, @"should not be scanning");
    [self willChangeValueForKey:@"scanning"];
    _scanning = YES;
    [self didChangeValueForKey:@"scanning"];
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"PhotoQuality"]) {
        resolution = PHOTO_RESOLUTION;
    }
    else {
        resolution = NORMAL_RESOLUTION;
    }
    paperSizeName = [[NSUserDefaults standardUserDefaults] objectForKey:@"PaperSize"];
    
    scanner = [[PLPreferencesWindowController sharedController] selectedScanner];
    //NSLog(@"%@ %@", scanner, [scanner scannerName]);
    
    [self _startScanProgress];
    
    [scanner retain];
    [scanner setResolution:resolution];
    [scanner setPageSizeFromName:paperSizeName];
    [scanner setDelegate:self];
    [scanner scan];
}

- (void) plScanner_scanDone:(NSObject <PLScannerProtocol> *)scanner
{
    [self willChangeValueForKey:@"scanning"];
    _scanning = NO;
    [self didChangeValueForKey:@"scanning"];
    
    [self _stopScanProgress];
    
    if ([scanner error] == nil) {
        PDFDocument * pdf;
        PLPDFPageGeneration * generation;
        PLDocument * doc;
        
        doc = [[PLDocument alloc] initWithLibrary:_library];
        [doc setName:[[_library getUntitledName] stringByAppendingPLDateIfNeeded]];
        generation = [[PLPDFPageGeneration alloc] init];
        [generation setPageSize:[scanner pageSize]];
        [generation setImage:[scanner filename]];
        pdf = [generation document];
        //NSLog(@"try to write PDF");
        [pdf writeToFile:[doc filename]];
        //NSLog(@"%@ write to %@", pdf, [doc filename]);
        [generation release];
        [[NSFileManager defaultManager] removeItemAtPath:[scanner filename] error:NULL];
        [_dataSource addDocument:doc];
        [_dataSource reloadData];
        
        [_dataSource selectDocumentList:[NSArray arrayWithObject:doc]];
        [self plDocumentTreeDataSource_selectionDidChange:_dataSource];
        
        if ([_dataSource selection] > 0) {
            [self editName];
        }
        
        [doc release];
    }
    else {
        [NSApp presentError:[scanner error]];
    }
    
    [scanner release];
}

- (BOOL) scanning
{
    return _scanning;
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
    if ([aNotification object] == _searchField) {
        NSString * searchStr;
        
        searchStr = [_searchField stringValue];
        [self _delayedSearch:searchStr];
    }
}

- (void) _delayedSearch:(NSString *)searchStr
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_searchNow) object:nil];
    [_searchStr release];
    _searchStr = [searchStr copy];
    [self performSelector:@selector(_searchNow) withObject:nil afterDelay:0.5];
}

- (void) _searchNow
{
    if ((_searchStr == nil) || ([_searchStr length] == 0)) {
        [self cancelFilter];
        [_toolbar validateVisibleItems];
        return;
    }
    
    //_isCompleting = NO;
    [_library search:_searchStr delegate:self];
}

- (void) plLibrary_searchDone:(NSArray *)documentList
{
    //NSLog(@"result count: %u", [documentList count]);
    [_searchStr release];
    _searchStr = nil;
    
    [self applyFilter:documentList];
    [_toolbar validateVisibleItems];
}

- (void) textDidChange:(NSNotification *)aNotification
{
    if ([aNotification object] == _commentView) {
        [self _delayedSaveComment:[_commentView string]];
    }
    else if ([aNotification object] == _textViewForOutlineView) {
        //NSLog(@"outline edit");
        //[self _completionForName];
    }
}

- (void) _delayedSaveComment:(NSString *)comment
{
    [_delayedComment release];
    _delayedComment = [comment copy];
    if (!_hasDelayedComment) {
        _hasDelayedComment = YES;
        [self performSelector:@selector(_saveCommentNow) withObject:nil afterDelay:0.5];
        //NSLog(@"schedule save comment now");
    }
}

- (void) _saveCommentNow
{
    if (!_hasDelayedComment)
        return;
    
    //NSLog(@"save comment now");
    [self _setComment:_delayedComment forDocument:_currentDoc updateTextView:NO];
    [_delayedComment release];
    _delayedComment = nil;
    _hasDelayedComment = NO;
}

- (void) undo:(id)sender
{
    [[self undoManager] undo];
}

- (BOOL) isUndoEnabled
{
    return [[self undoManager] canUndo];
}

- (void) redo:(id)sender
{
    [[self undoManager] redo];
}

- (BOOL) isRedoEnabled
{
    return [[self undoManager] canRedo];
}

- (void) merge:(id)sender
{
    [self _mergeDocumentList:[_dataSource selection]];
}

- (BOOL) isMergeEnabled
{
    NSArray * selection;
    
    selection = [_dataSource selection];
    if ([selection count] > 1) {
        return YES;
    }
    else {
        return NO;
    }
}

- (void) deleteDocument:(id)sender
{
    NSArray * selection;
    
    selection = [_dataSource selection];
    if ([selection count] > 0) {
        [self _deleteDocumentList:selection];
    }
}

- (BOOL) isDeleteDocumentEnabled
{
    NSArray * selection;
    
    selection = [_dataSource selection];
    
    return [selection count] > 0;
}

- (BOOL) isRevealInFinderEnabled
{
    NSArray * selection;
    
    selection = [_dataSource selection];
    return ([selection count] == 1);
}

- (void) revealInFinder:(id)sender
{
    [[NSWorkspace sharedWorkspace] selectFile:[_currentDoc filename] inFileViewerRootedAtPath:@""];
}

- (BOOL) isOpenInPreviewEnabled
{
    NSArray * selection;
    
    selection = [_dataSource selection];
    return ([selection count] > 0);
}

- (void) openInPreview:(id)sender
{
    NSArray * selection;
    unsigned int i;
    
    selection = [_dataSource selection];
    for(i = 0 ; i < [selection count] ; i ++) {
        PLDocument * doc;
        
        doc = [selection objectAtIndex:i];
        [[NSWorkspace sharedWorkspace] openFile:[doc filename]];
    }
}

- (void) updateUndoMenuItem:(NSMenuItem *)item
{
    [item setTitle:[[self undoManager] undoMenuItemTitle]];
}

- (void) updateRedoMenuItem:(NSMenuItem *)item
{
    [item setTitle:[[self undoManager] redoMenuItemTitle]];
}

- (void) _undoWithData:(NSArray *)data
{
    NSString * actionType;
    
    //NSLog(@"undo: %@", data);
    actionType = [data objectAtIndex:0];
    if ([actionType isEqualToString:@"delete"]) {
        NSArray * docList;
        
        docList = [data objectAtIndex:1];
        
        [self _undeleteDocumentList:docList];
    }
    else if ([actionType isEqualToString:@"undelete"]) {
        NSArray * docList;
        
        docList = [data objectAtIndex:1];
        
        [self _deleteDocumentList:docList];
    }
    else if ([actionType isEqualToString:@"rename"]) {
        PLDocument * doc;
        NSString * oldName;
        
        doc = [data objectAtIndex:1];
        oldName = [data objectAtIndex:2];
        
        [self _renameDocument:doc name:oldName];
    }
    else if ([actionType isEqualToString:@"merge"]) {
        PLDocument * doc;
        NSArray * docList;
        
        doc = [data objectAtIndex:1];
        docList = [data objectAtIndex:2];
        
        [self _undeleteDocumentList:docList];
        [self _deleteDocumentList:[NSArray arrayWithObject:doc]];
    }
    else if ([actionType isEqualToString:@"import"]) {
        NSArray * docList;
        
        docList = [data objectAtIndex:1];
        
        [self _deleteDocumentList:docList];
    }
    else if ([actionType isEqualToString:@"comment"]) {
        PLDocument * doc;
        NSString * comment;
        
        doc = [data objectAtIndex:1];
        comment = [data objectAtIndex:2];
        
        [self _setComment:comment forDocument:doc updateTextView:YES];
    }
}

- (void) _undeleteDocumentList:(NSArray *)documentList
{
    unsigned int i;
    
    //NSLog(@"undelete doc");
    [self _registerUndoForDocumentUndeletion:documentList];
    for(i = 0 ; i < [documentList count] ; i ++) {
        PLDocument * doc;
        
        doc = [documentList objectAtIndex:i];
        [[PLFileManager sharedManager] queueUndeleteDocument:doc];
    }
    [_dataSource addDocumentList:documentList];
    [_dataSource reloadData];
    [_dataSource selectDocumentList:documentList];
    [self plDocumentTreeDataSource_selectionDidChange:_dataSource];
}

- (void) _registerUndoForDocumentUndeletion:(NSArray *)documentList
{
    NSMutableArray * undoData;
    
    if (![[self undoManager] isUndoing])
        [[self undoManager] setActionName:@"Undelete"];
    
    undoData = [NSMutableArray array];
    [undoData addObject:@"undelete"];
    [undoData addObject:documentList];
    
    [[self undoManager] registerUndoWithTarget:self selector:@selector(_undoWithData:) object:undoData];
}

- (void) _deleteDocumentList:(NSArray *)documentList
{
    unsigned int i;
    
    //NSLog(@"delete doc");
    [self _registerUndoForDocumentDeletion:documentList];
    for(i = 0 ; i < [documentList count] ; i ++) {
        PLDocument * doc;
        
        doc = [documentList objectAtIndex:i];
        [[PLFileManager sharedManager] queueDeleteDocument:doc];
    }
    [_dataSource removeDocumentList:documentList];
    [_dataSource reloadData];
    [_dataSource selectDocumentList:[NSArray array]];
    [self plDocumentTreeDataSource_selectionDidChange:_dataSource];
}

- (void) _registerUndoForDocumentDeletion:(NSArray *)documentList
{
    NSMutableArray * undoData;
    
    if (![[self undoManager] isUndoing])
        [[self undoManager] setActionName:@"Delete"];
    
    undoData = [NSMutableArray array];
    [undoData addObject:@"delete"];
    [undoData addObject:documentList];
    
    [[self undoManager] registerUndoWithTarget:self selector:@selector(_undoWithData:) object:undoData];
}

- (void) _renameDocument:(PLDocument *)doc name:(NSString *)name
{
    //NSDate * date;
    
    if ([name isEqualToString:[doc name]])
        return;
    
    [self _registerUndoForDocumentRename:doc];
    
    [_dataSource preModifyDocumentTimestamp:doc];
    [doc setName:name];
    [_dataSource postModifyDocumentTimestamp:doc];
    [_dataSource reloadData];
    
    [_dataSource selectDocumentList:[NSArray arrayWithObject:doc]];
    [self plDocumentTreeDataSource_selectionDidChange:_dataSource];
}

- (void) _registerUndoForDocumentRename:(PLDocument *)doc
{
    NSMutableArray * undoData;
    
    if (![[self undoManager] isUndoing])
        [[self undoManager] setActionName:@"Rename"];
    
    undoData = [NSMutableArray array];
    [undoData addObject:@"rename"];
    [undoData addObject:doc];
    [undoData addObject:[doc name]];
    
    [[self undoManager] registerUndoWithTarget:self selector:@selector(_undoWithData:) object:undoData];
}

- (void) _mergeDocumentList:(NSArray *)documentList
{
    PLDocument * mainDoc;
    PLDocument * firstDoc;
    PLDocument * mergedDoc;
    PDFDocument * mergedPDF;
    int i;
    NSMutableString * globalComment;
    
    firstDoc = [documentList objectAtIndex:0];
    mainDoc = [documentList objectAtIndex:[documentList count] - 1];
    mergedDoc = [[PLDocument alloc] initWithLibrary:_library];
    [mergedDoc setName:[firstDoc name]];
    [mergedDoc setTimestamp:[mainDoc timestamp]];
    globalComment = [[mainDoc comment] mutableCopy];
    
    [self _registerUndoForDocumentMerge:documentList mergedDoc:mergedDoc];
    
    [[NSFileManager defaultManager] copyPath:[mainDoc filename] toPath:[mergedDoc filename] handler:nil];
    
    //NSLog(@"merge to %@", [mergedDoc filename]);
    mergedPDF = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:[mergedDoc filename]]];
    for(i = [documentList count] - 2 ; i >= 0 ; i --) {
        PLDocument * doc;
        PDFDocument * pdf;
        unsigned int k;
        NSString * comment;
        
        doc = [documentList objectAtIndex:i];
        pdf = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:[doc filename]]];
        //NSLog(@"merging pdf : %@", [doc filename]);
        for(k = 0 ; k < [pdf pageCount] ; k ++) {
            PDFPage * page;
            
            page = [pdf pageAtIndex:k];
            [mergedPDF insertPage:page atIndex:[mergedPDF pageCount]];
        }
        [pdf release];
        
        comment = [doc comment];
        if ([comment length] != 0) {
            if ([globalComment length] != 0) {
                [globalComment appendString:@"\n"];
            }
            [globalComment appendString:comment];
        }
    }
    [mergedPDF writeToFile:[mergedDoc filename]];
    [mergedPDF release];
    
    [mergedDoc setComment:globalComment];
    
    [_dataSource addDocument:mergedDoc];
    
    [_dataSource removeDocumentList:documentList];
    for(i = 0 ; i < (int) [documentList count] ; i ++) {
        PLDocument * doc;
        
        doc = [documentList objectAtIndex:i];
        [[PLFileManager sharedManager] queueDeleteDocument:doc];
    }
    
    [_dataSource reloadData];
    [_dataSource selectDocumentList:[NSArray arrayWithObject:mergedDoc]];
    [self plDocumentTreeDataSource_selectionDidChange:_dataSource];
    [self editName];
    
    [mergedDoc release];
}

- (void) _registerUndoForDocumentMerge:(NSArray *)documentList mergedDoc:(PLDocument *)mergedDoc
{
    NSMutableArray * undoData;
    
    if (![[self undoManager] isUndoing])
        [[self undoManager] setActionName:@"Merge"];
    
    undoData = [NSMutableArray array];
    [undoData addObject:@"merge"];
    [undoData addObject:mergedDoc];
    [undoData addObject:documentList];
    
    [[self undoManager] registerUndoWithTarget:self selector:@selector(_undoWithData:) object:undoData];
}

- (NSArray *) _importFileList:(NSArray *)fileList
{
    unsigned int i;
    NSMutableArray * documentList;
    
    documentList = [[NSMutableArray alloc] init];
    
    for(i = 0 ; i < [fileList count] ; i ++) {
        NSString * filename;
        
        filename = [fileList objectAtIndex:i];
        
        if ([[[filename stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] isEqualToString:[@"~/Library/Application Support/PaperLess/Drag" stringByExpandingTildeInPath]]) {
            continue;
        }
        
        [self _importFile:filename documentList:documentList];
    }
    
    [_dataSource addDocumentList:documentList];
    [_dataSource reloadData];
    //[_dataSource selectDocumentList:documentList];
    [_dataSource selectDocumentList:[NSArray array]];
    [self plDocumentTreeDataSource_selectionDidChange:_dataSource];
	
    [self _registerUndoForDocumentImport:documentList];
	
    return [documentList autorelease];
}

- (void) _importFile:(NSString *)filename documentList:(NSMutableArray *)documentList
{
    PLDocument * doc;
    
    if ([[filename pathExtension] caseInsensitiveCompare:@"pdf"] == NSOrderedSame) {
        //NSDictionary * fileAttributes;
        //NSDate * date;
        
        doc = [[PLDocument alloc] initWithLibrary:_library];
        [doc setName:[[filename lastPathComponent] stringByDeletingPathExtension]];
        if ([[doc name] PLDate] == nil) {
            NSDictionary * fileAttributes;
            NSDate * date;
            
            fileAttributes = [[NSFileManager defaultManager] fileAttributesAtPath:filename traverseLink:YES];
            date = [fileAttributes objectForKey:NSFileModificationDate];
            [doc setTimestamp:[date timeIntervalSinceReferenceDate]];
        }
        
        [[PLFileManager sharedManager] queueFile:filename document:doc];
        
        [documentList addObject:doc];
        
        [doc release];
    }
    else {
        BOOL isDir;
        
        if ([[NSFileManager defaultManager] fileExistsAtPath:filename isDirectory:&isDir]) {
            if (isDir && (![[filename lastPathComponent] isEqualToString:@".AppleDouble"])) {
                NSArray * fileList;
                unsigned int i;
                
                fileList = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:filename error:NULL];
                for(i = 0 ; i < [fileList count] ; i ++) {
                    NSString * basename;
                    NSString * path;
                    
                    basename = [fileList objectAtIndex:i];
                    path = [filename stringByAppendingPathComponent:basename];
                    [self _importFile:path documentList:documentList];
                }
            }
        }
    }
}

- (void) _registerUndoForDocumentImport:(NSArray *)documentList
{
    NSMutableArray * undoData;
    
    if (![[self undoManager] isUndoing])
        [[self undoManager] setActionName:@"Import"];
    
    undoData = [NSMutableArray array];
    [undoData addObject:@"import"];
    [undoData addObject:documentList];
    
    [[self undoManager] registerUndoWithTarget:self selector:@selector(_undoWithData:) object:undoData];
}

- (void) _setComment:(NSString *)comment forDocument:(PLDocument *)doc updateTextView:(BOOL)doUpdate
{
    [self _registerUndoForCommentChange:doc];
    [doc setComment:comment];
    
    if (doUpdate) {
        if (doc == _currentDoc) {
            NSAttributedString * attrStr;
            
            attrStr = [[NSAttributedString alloc] initWithString:comment];
            [[_commentView textStorage] setAttributedString:attrStr];
            [attrStr release];
        }
    }
}

- (void) _registerUndoForCommentChange:(PLDocument *)doc
{
    NSMutableArray * undoData;
    
    if (![[self undoManager] isUndoing])
        [[self undoManager] setActionName:@"Typing"];
    
    undoData = [NSMutableArray array];
    [undoData addObject:@"comment"];
    [undoData addObject:doc];
    [undoData addObject:[doc comment]];
    
    [[self undoManager] registerUndoWithTarget:self selector:@selector(_undoWithData:) object:undoData];
}

- (void) editName
{
    [_dataSource editName];
}

- (void) applyFilter:(NSArray *)documentList
{
    [_dataSource applyFilter:documentList];
}

- (void) cancelFilter
{
    [_dataSource cancelFilter];
}

- (void) plDocumentTreeDataSource_importFileList:(NSArray *)fileList
{
    [self _importFileList:fileList];
}

- (void) plDocumentTreeDataSource_renameDocument:(PLDocument *)doc name:(NSString *)name
{
    [self _renameDocument:doc name:name];
}

- (void) _switchToPlaceholderView
{
    [_pdfView removeFromSuperview];
    [_placeHolderWithlabelView setFrame:[_rightView bounds]];
    [_rightView addSubview:_placeHolderWithlabelView];
}

- (void) _switchToPDFView
{
    [_placeHolderWithlabelView removeFromSuperview];
    [_pdfView setFrame:[_rightView bounds]];
    [_rightView addSubview:_pdfView];
}

- (void) _setSelectedDocument:(PLDocument *)doc
{
    [self _saveCommentNow];
    _currentDoc = doc;
    
    if (doc == nil) {
        NSArray * selection;
        NSAttributedString * attrStr;
        
        selection = [_dataSource selection];
        
        [self _cancelViewPDFDocument];
        [self _switchToPlaceholderView];
        
        attrStr = [[NSAttributedString alloc] initWithString:@""];
        [[_commentView textStorage] setAttributedString:attrStr];
        [attrStr release];
        [_commentView setEditable:NO];
        [_commentView setPlaceholderString:@"Select a document"];
        
        [self _cancelViewPDFDocument];
        [_pdfView setDocument:nil];
        
        if ([selection count] == 0) {
            if ([[_library documentDict] count] == 0) {
                [_labelView setStringValue:@"Scan or import a document"];
            }
            else {
                [_labelView setStringValue:@"Select a document"];
            }
        }
        else { // [selection count] >= 2
            [_labelView setStringValue:@"Several documents are selected"];
        }
    }
    else {
        NSString * filename;
        NSAttributedString * attrStr;
        NSString * str;
        
        filename = [doc filename];
        
        [self _cancelViewPDFDocument];
        if ([[PLFileManager sharedManager] isPendingDoc:doc]) {
            [self _switchToPlaceholderView];
            [_labelView setStringValue:@"Document is being imported"];
        }
        else if (![[NSFileManager defaultManager] fileExistsAtPath:filename]) {
            [self _switchToPlaceholderView];
            [_labelView setStringValue:@"Document is missing"];
        }
        else {
            [self _viewPDFDocument];
        }
        
        str = [doc comment];
        attrStr = [[NSAttributedString alloc] initWithString:str];
        [[_commentView textStorage] setAttributedString:attrStr];
        [attrStr release];
        [_commentView setPlaceholderString:@"Document comments"];
        [_commentView setEditable:YES];
    }
    
    [_toolbar validateVisibleItems];
}

- (void) _cancelViewPDFDocument
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_viewPDFDocumentNow) object:nil];
}

- (void) _viewPDFDocument
{
    [self _cancelViewPDFDocument];
    [self _switchToPlaceholderView];
    [_labelView setStringValue:@"Loading Document..."];
    [self performSelector:@selector(_viewPDFDocumentNow) withObject:nil afterDelay:0.2];
}

- (void) _viewPDFDocumentNow
{
    PDFDocument * pdf;
    
    pdf = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:[_currentDoc filename]]];
    if (pdf == nil) {
        [self _switchToPlaceholderView];
        [_labelView setStringValue:@"Document is broken"];
        return;
    }
    
    [_pdfView setDocument:pdf];
    [pdf release];
    
    [self _switchToPDFView];
}

- (void) _fileManagerProgressStarted:(NSNotification *)notification
{
    [self performSelector:@selector(_delayedProgressStarted) withObject:nil afterDelay:1.5];
}

- (void) _delayedProgressStarted
{
    _fmProgressStarted = YES;
    [self _updateProgress];
}

- (void) _fileManagerProgressUpdated:(NSNotification *)notification
{
    [self _updateProgress];
}

- (void) _fileManagerProgressEnded:(NSNotification *)notification
{
    if (!_fmProgressStarted) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_delayedProgressStarted) object:nil];
    }
    else {
        _fmProgressStarted = NO;
        [self _updateProgress];
    }
}

- (void) _startScanProgress
{
    NSLog(@"start scan progress");
    _scanProgressStarted = YES;
    [self _updateProgress];
}

- (void) _stopScanProgress
{
    NSLog(@"stop scan progress");
    _scanProgressStarted = NO;
    [self _updateProgress];
}

- (void) _updateProgress
{
    if (!_progressVisible) {
        if (_fmProgressStarted || _scanProgressStarted || _eyeFiStarted) {
            [_progressLabel setHidden:NO];
            [_progressView setIndeterminate:YES];
            [_progressView setUsesThreadedAnimation:YES];
            [_progressView setHidden:NO];
            [_progressView startAnimation:self];
            _progressVisible = YES;
        }
    }
    else {
        if (!_fmProgressStarted && !_scanProgressStarted && !_eyeFiStarted) {
            [_progressView stopAnimation:self];
            [_progressView setHidden:YES];
            [_progressLabel setHidden:YES];
            _progressVisible = NO;
        }
    }
	
    if (!_progressVisible)
        return;
    
    if (_scanProgressStarted) {
        [_progressView setIndeterminate:YES];
        [_progressLabel setStringValue:@"Scanning"];
    }
    else if (_fmProgressStarted) {
        [_progressView setIndeterminate:NO];
        [_progressLabel setStringValue:[[PLFileManager sharedManager] currentOperationDescription]];
        [_progressView setDoubleValue:[[PLFileManager sharedManager] progressValue]];
        [_progressView setMaxValue:[[PLFileManager sharedManager] progressMaxValue]];
    }
    else if (_eyeFiStarted) {
        if ([_eyeFi progressMaxValue] == 0) {
            [_progressView setIndeterminate:YES];
            [_progressLabel setStringValue:@"Importing"];
        }
        else {
            [_progressView setIndeterminate:NO];
            [_progressLabel setStringValue:@"Importing"];
            [_progressView setDoubleValue:[_eyeFi progressValue]];
            [_progressView setMaxValue:[_eyeFi progressMaxValue]];
        }
    }
}

- (BOOL) isExportToFolderEnabled
{
    NSArray * selection;
    
    selection = [_dataSource selection];
    if ([selection count] == 0)
        return NO;
    
    return YES;
}

- (NSArray *) _exportDocumentList:(NSArray *)docList toFolder:(NSString *)folder
{
    NSMutableArray * fileList;
    unsigned int i;
    NSMutableSet * filenameSet;
    NSArray * contents;
    
    filenameSet = [[NSMutableSet alloc] init];
    fileList = [NSMutableArray array];
    
    contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:NULL];
    [filenameSet addObjectsFromArray:contents];
    
    for(i = 0 ; i < [docList count] ; i ++) {
        PLDocument * doc;
        NSString * destination;
        unsigned int destinationIndex;
        NSString * name;
        NSString * filename;
        
        doc = [docList objectAtIndex:i];
        name = [doc name];
        name = [name stringByReplacingOccurrencesOfString:@"/" withString:@":"];
        filename = [name stringByAppendingPathExtension:@"pdf"];
        destination = [folder stringByAppendingPathComponent:filename];
        destinationIndex = 1;
        while ([filenameSet containsObject:filename]) {
            filename = [[NSString stringWithFormat:@"%@ %u", name , destinationIndex] stringByAppendingPathExtension:@"pdf"];
            destination = [folder stringByAppendingPathComponent:filename];
            //[[NSData data] writeToFile:filename atomically:NO];
            
            destinationIndex ++;
        }
        
        [[PLFileManager sharedManager] queueExportDocument:doc destination:destination];
        [fileList addObject:destination];
        
        [filenameSet addObject:destination];
    }
    
    [filenameSet release];
    
    return fileList;
}

- (NSArray *) plDocumentTreeDataSource_exportDocumentList:(NSArray *)docList toFolder:(NSString *)folder;
{
    return [self _exportDocumentList:docList toFolder:folder];
}

- (void) export:(id)sender
{
    NSOpenPanel * panel;
    
    panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel setTitle:@"Export..."];
    [panel setMessage:@"Choose a folder where the exported documents will be stored."];
    
    [panel beginSheetForDirectory:nil file:nil types:[NSArray array] modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(_exportOpenPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)_exportOpenPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
    if (returnCode == NSOKButton) {
        NSArray * selection;
        NSString * folder;
        
        selection = [_dataSource selection];
        folder = [panel filename];
        [self _exportDocumentList:selection toFolder:folder];
    }
}

- (void) import:(id)sender
{
    NSOpenPanel * panel;
    
    panel = [NSOpenPanel openPanel];
    [panel setCanChooseDirectories:YES];
    [panel setCanChooseFiles:YES];
    [panel setAllowsMultipleSelection:YES];
    [panel setResolvesAliases:YES];
    [panel setPrompt:@"Import from"];
    [panel setMessage:@"Choose files to import."];
    
    [panel beginSheetForDirectory:nil file:nil types:[NSArray arrayWithObject:@"pdf"] modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(_importOpenPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)_importOpenPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
    if (returnCode == NSOKButton) {
        NSArray * filenames;
        
        filenames = [panel filenames];
        [self _importFileList:filenames];
    }
}

- (void) save:(id)sender
{
    NSSavePanel * panel;
    NSArray * selection;
    PLDocument * doc;
    
    selection = [_dataSource selection];
    doc = [selection objectAtIndex:0];
    
    panel = [NSSavePanel savePanel];
    [panel setRequiredFileType:@"pdf"];
    [panel beginSheetForDirectory:nil file:[doc name] modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(_savePanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)_savePanelDidEnd:(NSSavePanel *)panel returnCode:(int)returnCode contextInfo:(void  *)contextInfo
{
    if (returnCode == NSOKButton) {
        NSString * filename;
        NSArray * selection;
        PLDocument * doc;
        
        selection = [_dataSource selection];
        doc = [selection objectAtIndex:0];
        
        filename = [panel filename];
        
        [[NSFileManager defaultManager] removeItemAtPath:filename error:NULL];
        [[PLFileManager sharedManager] queueExportDocument:doc destination:filename];
    }
}

- (BOOL) isSaveEnabled
{
    NSArray * selection;
    
    selection = [_dataSource selection];
    if ([selection count] == 1)
        return YES;
    else
        return NO;
}

- (id)windowWillReturnFieldEditor:(NSWindow *)window toObject:(id)anObject
{
    if (anObject == _outlineView) {
        return _textViewForOutlineView;
    }
    return nil;
}

- (void) _appendDateIfNeeded
{
    NSString * newName;
    NSDate * date;
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"AppendDateToName"]) {
        return;
    }
    
    newName = [[_textViewForOutlineView textStorage] string];
    date = [newName PLDate];
    if (date == nil) {
        NSAttributedString * dateStr;
        
        dateStr = [[NSAttributedString alloc] initWithString:[@"" stringByAppendingPLDateIfNeeded] attributes:[_textViewForOutlineView typingAttributes]];
        [[_textViewForOutlineView textStorage] appendAttributedString:dateStr];
        [dateStr release];
    }
    else {
        NSAttributedString * dateStr;
        
        newName = [newName stringByRemovingPLDate];
        
        dateStr = [[NSAttributedString alloc] initWithString:[newName stringByAppendingPLDate:date] attributes:[_textViewForOutlineView typingAttributes]];
        [[_textViewForOutlineView textStorage] setAttributedString:dateStr];
        [dateStr release];
        
        [_textViewForOutlineView setSelectedRange:NSMakeRange(0, [newName length])];
    }
}

- (void) plDocumentTreeDataSource_beforeEdit
{
}

- (void) plDocumentTreeDataSource_afterEdit
{
    [self _saveEditedName];
    [self _appendDateIfNeeded];
}

- (void) _saveEditedName
{
    [_savedText release];
    _savedText = [[[_textViewForOutlineView textStorage] string] copy];
}

- (void) _restoreEditedName
{
    NSAttributedString * attrStr;
    
    if (_savedText == nil)
        return;
    
    attrStr = [[NSAttributedString alloc] initWithString:_savedText attributes:[_textViewForOutlineView typingAttributes]];
    [[_textViewForOutlineView textStorage] setAttributedString:attrStr];
    [attrStr release];
    
    [_savedText release];
    _savedText = nil;
}

- (void) _outlineTextView_cancelled:(NSNotification *)notification
{
    [self _restoreEditedName];
}

- (void) _outlineTextView_didInsertText:(NSNotification *)notification
{
    [self _completionForName];
}

- (void) _completionForName
{
    NSString * str;
    NSArray * ranges;
    NSValue * value;
    NSRange range;
    NSString * subStr;
    NSString * name;
    NSAttributedString * attrStr;
    NSString * additionalCompletion;
    
    //_isCompleting = YES;
    ranges = [_textViewForOutlineView selectedRanges];
    if ([ranges count] == 0)
        return;
    
    str = [[_textViewForOutlineView textStorage] string];
    value = [ranges objectAtIndex:0];
    range = [value rangeValue];
    subStr = [str substringWithRange:NSMakeRange(0, range.location)];
    name = [_library probableNameStartWith:subStr];
    additionalCompletion = [name substringFromIndex:range.location];
    attrStr = [[NSAttributedString alloc] initWithString:additionalCompletion attributes:[_textViewForOutlineView typingAttributes]];
    [[_textViewForOutlineView textStorage] insertAttributedString:attrStr atIndex:range.location];
    [_textViewForOutlineView setSelectedRange:NSMakeRange(range.location, [additionalCompletion length])];
    [attrStr release];
}

- (void) debugCheckFiles:(id)sender
{
    NSArray * keys;
    unsigned int i;
    
    NSLog(@"check pdf");
    keys = [_library allKeys];
    for(i = 0 ; i < [keys count] ; i ++) {
        NSString * key;
        PLDocument * doc;
        PDFDocument * pdf;
        
        key = [keys objectAtIndex:i];
        doc = [_library documentForKey:key];
        pdf = [[PDFDocument alloc] initWithURL:[NSURL fileURLWithPath:[doc filename]]];
        if (pdf == nil) {
            NSLog(@"error on %@ %@", key, [doc name]);
        }
        [pdf release];
    }
    NSLog(@"check pdf done");
}

- (void) debugRemainingFiles:(id)sender
{
    NSString * folder;
    NSArray * contents;
    NSMutableSet * docSet;
    NSArray * keys;
    unsigned int i;
    
    NSLog(@"check remaining files");
    folder = [_library contentsPath];
    NSLog(@"load contents");
    contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:NULL];
    NSLog(@"load contents done");
    
    docSet = [[NSMutableSet alloc] init];
    
    keys = [_library allKeys];
    for(i = 0 ; i < [keys count] ; i ++) {
        NSString * key;
        PLDocument * doc;
        
        key = [keys objectAtIndex:i];
        doc = [_library documentForKey:key];
        [docSet addObject:[[doc filename] lastPathComponent]];
    }
    
    for(i = 0 ; i < [contents count] ; i ++) {
        NSString * filename;
        
        filename = [contents objectAtIndex:i];
        if (![docSet containsObject:filename]) {
            NSLog(@"%@", filename);
        }
    }
    
    [docSet release];
    NSLog(@"check remaining files done");
}

- (void) willTerminate
{
}

- (void) plDocumentTreeDataSource_revealInFinder
{
    [self revealInFinder:nil];
}

- (void) openFileList:(NSArray *)fileList
{
    NSArray * list;
    
    list = [self _importFileList:fileList];
    if ([list count] == 1) {
        _editAfterImport = YES;
        _editAfterImportDoc = [list objectAtIndex:0];
    }
}

- (void) PLEyeFiManager:(PLEyeFiManager *)manager addPDFFilenames:(NSArray *)pdfFilenames
{
    //NSLog(@"import %@", pdfFilenames);
    [self _importFileList:pdfFilenames];
}

- (void) PLEyeFiManager_progressUpdated:(PLEyeFiManager *)manager
{
    if (_eyeFiStarted) {
        if (![_eyeFi isImporting]) {
            _eyeFiStarted = NO;
        }
    }
    else {
        if ([_eyeFi isImporting]) {
            _eyeFiStarted = YES;
        }
    }
    [self _updateProgress];
}

@end
