//
//  PLDocumentTreeDataSource.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 16/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PLDocumentTreeDataSource.h"

#import "PLDocumentByDate.h"
#import "PLLibrary.h"
#import "PLDocument.h"
#import "PLFileManager.h"
#import "NSString+Date.h"

#import <Quartz/Quartz.h>
#include <regex.h>

@interface PLDocumentDateNode : NSObject {
    NSString * _dateDescription;
    unsigned int _intervalIndex;
}

- (id) init;
- (void) dealloc;

@property (copy) NSString * dateDescription;
@property unsigned int intervalIndex;

@end

@implementation PLDocumentDateNode

@synthesize dateDescription = _dateDescription;
@synthesize intervalIndex = _intervalIndex;

- (id) init
{
    self = [super init];
    
    return self;
}

- (void) dealloc
{
    [_dateDescription release];
    [super dealloc];
}

@end

@interface PLDocumentTreeDataSource (Private)

- (void) _setupIntervalList;
- (BOOL) _dragValid:(id < NSDraggingInfo >)sender;
- (BOOL) _containsPDF:(NSString *)filename;
- (void) _setupNodeList:(NSMutableArray *)nodeList forDocumentByDate:(PLDocumentByDate *)documentByDate;
- (void) _editCurrentSelectionName;
- (void) _revealInFinder:(id)sender;

@end

@implementation PLDocumentTreeDataSource

@synthesize outlineView = _outlineView;
@synthesize delegate = _delegate;

- (id) initWithLibrary:(PLLibrary *)library;
{
    NSMenuItem * item;
    
    self = [super init];
    
    _dateFormatter = [[NSDateFormatter alloc] init];
    [_dateFormatter setDateStyle:NSDateFormatterShortStyle];
    [_dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    _documentByDate = [[PLDocumentByDate alloc] init];
    _library = [library retain];
    _nodeList = [[NSMutableArray alloc] init];
    _documentMenu = [[NSMenu alloc] init];
    item = [[NSMenuItem alloc] initWithTitle:@"Reveal in Finder" action:@selector(_revealInFinder:) keyEquivalent:@""];
    [item setTarget:self];
    [_documentMenu addItem:item];
    [item release];
    
    return self;
}

- (void) dealloc
{
    [self cancelFilter];
    [_outlineView release];
    [_documentMenu release];
    [_nodeList release];
    [_library release];
    [_documentByDate release];
    [_dateFormatter release];
    [super dealloc];
}

- (void) setup
{
    NSDictionary * documentDict;
    NSArray * documentList;
    
    documentDict = [_library documentDict];
    documentList = [documentDict allValues];
    [_documentByDate addDocumentList:documentList];
    [self _setupIntervalList];
}

- (void) _setupNodeList:(NSMutableArray *)nodeList forDocumentByDate:(PLDocumentByDate *)documentByDate
{
    NSArray * docByIntervalList;
    unsigned int i;
    NSMutableDictionary * nodeDict;
    
    nodeDict = [[NSMutableDictionary alloc] init];
    for(i = 0 ; i < [nodeList count] ; i ++) {
        PLDocumentDateNode * node;
        
        node = [nodeList objectAtIndex:i];
        [nodeDict setObject:node forKey:[NSNumber numberWithInt:[node intervalIndex]]];
    }
    
    [nodeList removeAllObjects];
    docByIntervalList = [documentByDate documentByIntervalList];
    for(i = 0 ; i < [docByIntervalList count] ; i ++) {
        NSArray * table;
        
        table = [docByIntervalList objectAtIndex:i];
        if ([table count] > 0) {
            PLDocumentDateNode * node;
            
            node = [nodeDict objectForKey:[NSNumber numberWithInt:i]];
            if (node != nil) {
                [node retain];
            }
            else {
                node = [[PLDocumentDateNode alloc] init];
                [node setIntervalIndex:i];
                [node setDateDescription:[documentByDate dateDescriptionForInterval:i]];
            }
            [nodeList addObject:node];
            [node release];
        }
    }
    
    [nodeDict release];
}

- (void) _setupIntervalList
{
    [self _setupNodeList:_nodeList forDocumentByDate:_documentByDate];
}

- (NSArray *) nodeList
{
    if (_filterEnabled) {
        return _filteredNodeList;
    }
    else {
        return _nodeList;
    }
}

- (PLDocumentByDate *) documentByDate
{
    if (_filterEnabled) {
        return _filteredDocumentByDate;
    }
    else {
        return _documentByDate;
    }
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)childIndex ofItem:(id)item
{
    if (item == nil) {
        PLDocumentDateNode * node;
        
        if ([[self nodeList] count] == 0) {
            return nil;
        }
        
        node = [[self nodeList] objectAtIndex:childIndex];
        
        return node;
    }
    else {
        NSArray * docList;
        NSArray * docByIntervalList;
        PLDocumentDateNode * dateNode;
        
        dateNode = item;
        docByIntervalList = [[self documentByDate] documentByIntervalList];
        docList = [docByIntervalList objectAtIndex:[dateNode intervalIndex]];
        
        return [docList objectAtIndex:childIndex];
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    if (item == nil) {
        return NO;
    }
    else if ([item isKindOfClass:[PLDocumentDateNode class]]) {
        return YES;
    }
    else {
        return NO;
    }
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    if (item == nil) {
        if ([[self nodeList] count] == 0)
            return 1;
        
        return [[self nodeList] count];
    }
    else if ([item isKindOfClass:[PLDocument class]]) {
        return 0;
    }
    else if ([item isKindOfClass:[PLDocumentDateNode class]]) {
        NSArray * docByIntervalList;
        PLDocumentDateNode * dateNode;
        NSArray * docList;
        
        dateNode = item;
        docByIntervalList = [[self documentByDate] documentByIntervalList];
        docList = [docByIntervalList objectAtIndex:[dateNode intervalIndex]];
        
        return [docList count];
    }
    else {
        return 0;
    }
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    if (item == nil) {
        if ([[tableColumn identifier] isEqualToString:@"name"]) {
            NSMutableAttributedString * str;
            NSMutableDictionary * attr;
            NSMutableParagraphStyle * paragraphStyle;
            
            attr = [[NSMutableDictionary alloc] init];
            [attr setObject:[NSColor disabledControlTextColor] forKey:NSForegroundColorAttributeName];
            paragraphStyle = [[NSMutableParagraphStyle alloc] init];
            [paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
            [attr setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
            if (_filterEnabled)
                str = [[NSMutableAttributedString alloc] initWithString:@"No matching documents found" attributes:attr];
            else
                str = [[NSMutableAttributedString alloc] initWithString:@"No documents" attributes:attr];
            [paragraphStyle release];
        	[attr release];
            
            return [str autorelease];
        }
        else {
            return nil;
        }
    }
    else if ([item isKindOfClass:[PLDocumentDateNode class]]) {
        PLDocumentDateNode * dateNode;
        
        dateNode = item;
        if ([[tableColumn identifier] isEqualToString:@"name"]) {
            return [dateNode dateDescription];
        }
        else {
            return nil;
        }
    }
    else if ([item isKindOfClass:[PLDocument class]]) {
		PLDocument * doc;
        NSString * value;
        NSMutableAttributedString * str;
        NSMutableDictionary * attr;
        NSMutableParagraphStyle * paragraphStyle;
        
        doc = item;
        
        if ([[tableColumn identifier] isEqualToString:@"date"]) {
            value = [_dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:[doc timestamp]]];
        }
        else if ([[tableColumn identifier] isEqualToString:@"name"]) {
            value = [doc name];
        }
        else {
            value = @"";
        }
        
        attr = [[NSMutableDictionary alloc] init];
        if ([doc importInProgress]) {
            [attr setObject:[NSColor disabledControlTextColor] forKey:NSForegroundColorAttributeName];
        }
        paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        [paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
        [attr setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];
        str = [[NSMutableAttributedString alloc] initWithString:value attributes:attr];
        [paragraphStyle release];
        [attr release];
        
        return [str autorelease];
    }
    else {
        return nil;
    }
}

- (BOOL) _containsPDF:(NSString *)filename
{
    BOOL isDir;
    
    //NSLog(@"%@", filename);
    if ([[filename pathExtension] caseInsensitiveCompare:@"pdf"] == NSOrderedSame) {
		return YES;
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filename isDirectory:&isDir]) {
        if (isDir && (![[filename lastPathComponent] isEqualToString:@".AppleDouble"])) {
            NSEnumerator * enumerator;
            
            enumerator = [[NSFileManager defaultManager] enumeratorAtPath:filename];
            while (1) {
                NSString * curFile;
                
                curFile = [enumerator nextObject];
                if (curFile == nil)
                    break;
                if ([[curFile pathExtension] caseInsensitiveCompare:@"pdf"] == NSOrderedSame) {
                    //NSLog(@"%@", curFile);
                    return YES;
                }
            }
        }
    }
    
    return NO;
}

- (BOOL) _dragValid:(id < NSDraggingInfo >)sender
{
    NSPasteboard * pasteboard;
    NSArray * files;
    unsigned int i;
    BOOL hasPDF;
    
    pasteboard = [sender draggingPasteboard];
    files = [pasteboard propertyListForType:NSFilenamesPboardType];
    
    hasPDF = NO;
    
    // detect PDF files
    for(i = 0 ; i < [files count] ; i ++)  {
        NSString * filename;
        
        filename = [files objectAtIndex:i];
        if ([[[filename stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] isEqualToString:[@"~/Library/Application Support/PaperLess/Drag" stringByExpandingTildeInPath]]) {
            continue;
        }
        
        if ([self _containsPDF:filename]) {
            hasPDF = YES;
            break;
        }
    }
    
    return hasPDF;
}

// delegate
- (NSDragOperation) outlineView:(NSOutlineView *)outlineView draggingEntered:(id < NSDraggingInfo >)sender
{
    if (_filterEnabled)
        return NSDragOperationNone;
    
    _dragValidResult = [self _dragValid:sender];
    if (_dragValidResult) {
        return NSDragOperationCopy;
    }
    else {
        return NSDragOperationNone;
    }
}

- (NSDragOperation) outlineView:(NSOutlineView *)outlineView draggingUpdated:(id < NSDraggingInfo >)sender
{
    if (_dragValidResult) {
        return NSDragOperationCopy;
    }
    else {
        return NSDragOperationNone;
    }
}

- (void) outlineView:(NSOutlineView *)outlineView draggingExited:(id < NSDraggingInfo >)sender
{
}

- (BOOL) outlineView:(NSOutlineView *)outlineView prepareForDragOperation:(id <NSDraggingInfo>)sender
{
    return YES;
}
 
- (BOOL) outlineView:(NSOutlineView *)outlineView performDragOperation:(id <NSDraggingInfo>)sender
{
    NSPasteboard * pasteboard;
    NSArray * files;
    NSMutableArray * documentList;
    
    documentList = [[NSMutableArray alloc] init];
    
    pasteboard = [sender draggingPasteboard];
    files = [pasteboard propertyListForType:NSFilenamesPboardType];
    if ([[self delegate] respondsToSelector:@selector(plDocumentTreeDataSource_importFileList:)])
        [[self delegate] plDocumentTreeDataSource_importFileList:files];
    
    [documentList release];
    
    return YES;
}

- (void) addDocument:(PLDocument *)doc
{
	[self addDocument:doc sort:YES];
}

- (void) addDocument:(PLDocument *)doc sort:(BOOL)sortFlag
{
    [_library addDocument:doc];
    [_documentByDate addDocument:doc sort:sortFlag];
}

- (void) addDocumentList:(NSArray *)docList
{
    [self addDocumentList:docList sort:YES];
}

- (void) addDocumentList:(NSArray *)docList sort:(BOOL)sortFlag
{
    unsigned int i;
    
    [_library beginTransaction];
    for(i = 0 ; i < [docList count] ; i ++) {
        PLDocument * doc;
        
        doc = [docList objectAtIndex:i];
        [self addDocument:doc sort:NO];
    }
    [_library endTransaction];
    if (sortFlag)
        [_documentByDate sort];
}

- (void) removeDocument:(PLDocument *)doc
{
    if (_filterEnabled) {
        [_filteredDocumentByDate removeDocument:doc];
    }
    [_documentByDate removeDocument:doc];
    [_library removeDocumentForKey:[doc uid]];
}

- (void) preModifyDocumentTimestamp:(PLDocument *)doc
{
    if (_filterEnabled) {
        [_filteredDocumentByDate removeDocument:doc];
    }
    [_documentByDate removeDocument:doc];
}

- (void) postModifyDocumentTimestamp:(PLDocument *)doc
{
    [_documentByDate addDocument:doc];
    if (_filterEnabled) {
        [_filteredDocumentByDate addDocument:doc];
    }
}

- (void) removeDocumentList:(NSArray *)docList
{
    unsigned int i;
    
    if (_filterEnabled) {
        [_filteredDocumentByDate removeDocumentList:docList];
    }
    
    [_documentByDate removeDocumentList:docList];
    [_library beginTransaction];
    for(i = 0 ; i < [docList count] ; i ++) {
        PLDocument * doc;
        
        doc = [docList objectAtIndex:i];
        [_library removeDocumentForKey:[doc uid]];
    }
    [_library endTransaction];
}

- (void) outlineView:(NSOutlineView *)outlineView concludeDragOperation:(id <NSDraggingInfo>)sender
{
	//NSLog(@"conclude");
}

- (BOOL) outlineView:(NSOutlineView *)outlineView keyDown:(NSEvent *)theEvent
{
    NSArray * selection;
    
    //NSLog(@"key %u", [theEvent keyCode]);
    switch ([theEvent keyCode]) {
        case 36:
        case 76:
            selection = [self selection];
            if ([selection count] == 1) {
                [self _editCurrentSelectionName];
                return YES;
            }
            return NO;
            
        default:
            return NO;
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
    if (item == nil) {
        return NO;
    }
    else if ([item isKindOfClass:[PLDocument class]]) {
        return YES;
    }
    else {
        return NO;
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldCollapseItem:(id)item
{
	return NO;
}

- (NSArray *) selection
{
    NSIndexSet * indexSet;
    NSUInteger * indexArray;
    unsigned int count;
    unsigned int i;    
    NSMutableArray * result;
    
    result = [NSMutableArray array];
    
    indexSet = [_outlineView selectedRowIndexes];
    count = [indexSet count];
    indexArray = malloc(count * sizeof(NSUInteger));
    [indexSet getIndexes:indexArray maxCount:count inIndexRange:nil];
    
    for(i = 0 ; i < count ; i ++) {
        PLDocument * doc;
        
        doc = [_outlineView itemAtRow:indexArray[i]];
        [result addObject:doc];
    }
    
    free(indexArray);
    
    return result;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    if (([self delegate] != nil) && ([[self delegate] respondsToSelector:@selector(plDocumentTreeDataSource_selectionDidChange:)])) {
        [[self delegate] plDocumentTreeDataSource_selectionDidChange:self];
    }
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    if ([[self delegate] respondsToSelector:@selector(plDocumentTreeDataSource_renameDocument:name:)]) {
        NSString * newName;
        
        newName = object;
        
        [[self delegate] plDocumentTreeDataSource_renameDocument:item name:newName];
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
    if ([item isKindOfClass:[PLDocument class]]) {
        return YES;
    }
    else {
        return NO;
    }
}

- (void) reloadData
{
    [self reloadDataLight:NO];
}

- (void) reloadDataLight:(BOOL)light
{
    if (!light) {
        if (!_filterEnabled) {
            [self _setupIntervalList];
        }
        else {
            [self _setupNodeList:_filteredNodeList forDocumentByDate:_filteredDocumentByDate];
        }
    }
    [_outlineView reloadData];
    if (!light) {
        [_outlineView expandItem:nil expandChildren:YES];
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{
    NSMutableArray * fileList;
    unsigned int i;
    
#if 0
    fileList = [NSMutableArray array];
    for(i = 0 ; i < [items count] ; i ++) {
        id item;
        PLDocument * doc;
        
        item = [items objectAtIndex:i];
        if (![item isKindOfClass:[PLDocument class]])
            continue;
        
        doc = item;
        [fileList addObject:[doc filename]];
    }
#endif
    
#if 1
    fileList = [NSMutableArray array];
    for(i = 0 ; i < [items count] ; i ++) {
        id item;
        PLDocument * doc;
        NSString * path;
        NSString * name;
        
        item = [items objectAtIndex:i];
        if (![item isKindOfClass:[PLDocument class]])
            continue;
        
        doc = item;
        
        path = [[NSString stringWithFormat:@"~/Library/Application Support/PaperLess/Drag/%@", [doc uid]] stringByExpandingTildeInPath];
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
        
        name = [doc name];
        name = [name stringByReplacingOccurrencesOfString:@"/" withString:@":"];
        name = [name stringByAppendingPathExtension:@"pdf"];
        path = [[NSString stringWithFormat:@"~/Library/Application Support/PaperLess/Drag/%@/%@", [doc uid], name] stringByExpandingTildeInPath];
        //NSLog(@"%@", path);
        
        [[NSFileManager defaultManager] linkItemAtPath:[doc filename] toPath:path error:NULL];
        
        [fileList addObject:path];
    }
#endif
    
#if 1
    [pboard declareTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, nil]
                   owner:self];
    [pboard setPropertyList:fileList forType:NSFilenamesPboardType];
#elif 0
    [pboard declareTypes:[NSArray arrayWithObjects:NSFilesPromisePboardType, NSFilenamesPboardType, nil]
                   owner:self];
    [pboard setPropertyList:[NSArray arrayWithObject:@"pdf"]  
                    forType:NSFilesPromisePboardType];
    [pboard setPropertyList:fileList forType:NSFilenamesPboardType];
#else
    [pboard declareTypes:[NSArray arrayWithObject:NSFilesPromisePboardType]
                   owner:self];
    [pboard setPropertyList:[NSArray arrayWithObject:@"pdf"]  
                    forType:NSFilesPromisePboardType];
#endif
    
    return YES;
}

- (NSDragOperation) outlineView:(NSOutlineView *)outlineView draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
    if (isLocal)
        return NSDragOperationNone;
    else
        return NSDragOperationCopy;
}

- (NSArray *)outlineView:(NSOutlineView *)outlineView namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination forDraggedItems:(NSArray *)items
{
    NSMutableArray * docList;
    NSArray * fileList;
    NSString * folder;
    unsigned int i;
    
    docList = [NSMutableArray array];
    folder = [dropDestination path];
    
    for(i = 0 ; i < [items count] ; i ++) {
        id item;
        PLDocument * doc;
        
        item = [items objectAtIndex:i];
        if (![item isKindOfClass:[PLDocument class]])
            continue;
        
        doc = item;
        [docList addObject:doc];
    }
    
    if ([[self delegate] respondsToSelector:@selector(plDocumentTreeDataSource_exportDocumentList:toFolder:)]) {
        fileList = [[self delegate] plDocumentTreeDataSource_exportDocumentList:docList toFolder:folder];
    }
    else {
        fileList = [NSArray array];
    }

    return fileList;
}

- (BOOL) outlineView:(NSOutlineView *)outlineView drawRow:(NSInteger)rowIndex clipRect:(NSRect)clipRect
{
    NSRect rowRect;
    id item;
    
    rowRect = [outlineView rectOfRow:rowIndex];
    if (NSIntersectionRect(clipRect, rowRect).size.width == 0.0) {
        return YES;
    }
    
    if ([[outlineView selectedRowIndexes] containsIndex:rowIndex]) {
        return YES;
    }
    
    item = [outlineView itemAtRow:rowIndex];
    if ([item isKindOfClass:[PLDocumentDateNode class]]) {
        //[[NSColor colorWithCalibratedRed:0.75 green:0.75 blue:1.0 alpha:1.0] setFill];
        [[NSColor colorWithCalibratedRed:0.90 green:0.90 blue:1.0 alpha:1.0] setFill];
        NSRectFill(rowRect);
    }
    
    return YES;
}

- (void) applyFilter:(NSArray *)documentList
{
    NSArray * selection;
    
    selection = [self selection];
    
    [self cancelFilter];
    
    _filterEnabled = YES;
    _filteredDocumentByDate = [[PLDocumentByDate alloc] init];
    [_filteredDocumentByDate addDocumentList:documentList];
    _filteredNodeList = [[NSMutableArray alloc] init];
    [self _setupNodeList:_filteredNodeList forDocumentByDate:_filteredDocumentByDate];
    [[[_outlineView tableColumnWithIdentifier:@"name"] headerCell] setStringValue:@"Search Results"];
    
    [self reloadData];
    
    [self selectDocumentList:selection];
}

- (void) cancelFilter
{
    NSArray * selection;
    
    selection = [self selection];
    
    [_filteredDocumentByDate release];
    _filteredDocumentByDate = nil;
    [_filteredNodeList release];
    _filteredNodeList = nil;
    _filterEnabled = NO;
    [[[_outlineView tableColumnWithIdentifier:@"name"] headerCell] setStringValue:@"Documents"];
    
    [self reloadData];
    
    [self selectDocumentList:selection];
}

- (BOOL) filterEnabled
{
    return _filterEnabled;
}

- (void) selectDocumentList:(NSArray *)documentList
{
    unsigned int i;
    NSMutableIndexSet * set;
    
    set = [[NSMutableIndexSet alloc] init];
    
    for(i = 0 ; i < [documentList count] ; i ++) {
        PLDocument * doc;
        NSInteger rowIndex;
        
        doc = [documentList objectAtIndex:i];
        rowIndex = [_outlineView rowForItem:doc];
        if (rowIndex != -1)
            [set addIndex:rowIndex];
        
        if (i == 0) {
            [_outlineView scrollRowToVisible:rowIndex];
        }
    }
    
    [_outlineView selectRowIndexes:set byExtendingSelection:NO];
    
    [set release];
}

- (void) _editCurrentSelectionName
{
    NSArray * selection;
    NSInteger row;
    id item;
    
    selection = [self selection];
    if ([selection count] == 0)
        return;
    
    item = [selection objectAtIndex:0];
    row = [_outlineView rowForItem:item];
    [_outlineView editColumn:0 row:row withEvent:nil select:YES];
}

- (void) editName
{
    [self _editCurrentSelectionName];
}

- (void) outlineView:(NSOutlineView *)outlineView beforeEditColumn:(NSInteger)columnIndex row:(NSInteger)rowIndex withEvent:(NSEvent *)theEvent select:(BOOL)flag
{
    [[self delegate] plDocumentTreeDataSource_beforeEdit];
}

- (void) outlineView:(NSOutlineView *)outlineView afterEditColumn:(NSInteger)columnIndex row:(NSInteger)rowIndex withEvent:(NSEvent *)theEvent select:(BOOL)flag
{
    [[self delegate] plDocumentTreeDataSource_afterEdit];
}

- (NSMenu *) outlineView:(NSOutlineView *)outlineView menuForEvent:(NSEvent *)event
{
	NSPoint menuPoint;
    NSInteger row;
    id item;
    
	[[_outlineView window] makeFirstResponder:_outlineView];
    
    menuPoint = [_outlineView convertPoint:[event locationInWindow] fromView:nil];
	row = [_outlineView rowAtPoint:menuPoint];
	if (row == -1) {
        [self selectDocumentList:[NSArray array]];
        return _documentMenu;
    }
    
    item = [_outlineView itemAtRow:row];
    if (![item isKindOfClass:[PLDocument class]]) {
        [self selectDocumentList:[NSArray array]];
        return _documentMenu;
    }
    
    [self selectDocumentList:[NSArray arrayWithObject:item]];
	
    return _documentMenu;
}

- (void) _revealInFinder:(id)sender
{
    if ([[self delegate] respondsToSelector:@selector(plDocumentTreeDataSource_revealInFinder)])
        [[self delegate] plDocumentTreeDataSource_revealInFinder];
}

- (BOOL) validateMenuItem:(NSMenuItem *)item
{
    if ([item action] == @selector(_revealInFinder:)) {
        if ([[self selection] count] == 0)
            return NO;
        
        return YES;
    }
    else {
        return NO;
    }
}

@end
