//
//  PLPreferencesWindowController.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 31/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PLPreferencesWindowController.h"
#import "PLScannerList.h"
#import "PLScanner.h"
#import "PLMainWindowController.h"
#import "PLTwainManager.h"
#import "PLTwainScanner.h"
#import "PLTwainSource.h"
#import "PLScannerUtils.h"
#import "PLPageSizeInfo.h"

@interface PLPreferencesWindowController (Private)

- (void) _setupPaperSizeList;
- (void) _paperSizeSelected:(id)sender;
- (void) _scannerSelected:(id)sender;

- (void) _validateSelection;
- (void) _setupDeviceList;
- (void) _setupImageCaptureDeviceList;
- (void) _setupAdvancedDeviceList;

- (void) _photoQualityChecked:(id)sender;
- (void) _setupToolbar;
- (void) _unsetupToolbar;
- (void) _advancedScannerSelected:(id)sender;
- (void) _openAdvancedSheet;
- (PLScanner *) _selectedScanner;

- (NSArray *) _twainSources;
- (NSArray *) _imageCaptureSources;

@end

@implementation PLPreferencesWindowController

@synthesize deleteAfterImportCheckboxEnabled = _deleteAfterImportCheckboxEnabled;

static PLPreferencesWindowController * _singleton = nil;

+ (PLPreferencesWindowController *) sharedController
{
    if (_singleton == nil) {
        _singleton = [[PLPreferencesWindowController alloc] init];
        [_singleton loadWindow];
    }
    
    return _singleton;
}

- (id) init
{
    self = [super init];
    
    return self;
}

- (void) dealloc
{
	[[PLMainWindowController sharedController] removeObserver:self forKeyPath:@"scanning"];
	UNOBSERVE(self, PLSCANNERLIST_UPDATED, [PLScannerList defaultManager]);
    //[self _unsetupToolbar];
    [super dealloc];
}

- (NSString *) windowNibName
{
    return @"Preferences";
}

- (void) awakeFromNib
{
    NSWindow * window;
    NSSize diff;
    NSRect frame;
    NSString * appendDateToName;
    NSString * photoQuality;
    
    window = [self window];
    diff.width = [window frame].size.width - [[window contentView] frame].size.width;
    diff.height = [window frame].size.height - [[window contentView] frame].size.height;
    frame = [_mainView bounds];
    frame.origin.x = 0;
    frame.origin.y = 0;
    frame.size.width += diff.width;
    frame.size.height += diff.height;
    [window setFrame:frame display:YES animate:NO];
    [[window contentView] addSubview:_mainView];
	[window center];
    
    [PLScannerList defaultManager];
    
	[self _setupDeviceList];
    [self _setupPaperSizeList];
    [_paperSizePopupList setTarget:self];
    [_paperSizePopupList setAction:@selector(_paperSizeSelected:)];
    
    [_devicePopupList setTarget:self];
    [_devicePopupList setAction:@selector(_scannerSelected:)];

    appendDateToName = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppendDateToName"];
	if (appendDateToName == nil) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"AppendDateToName"];
    }
    
    photoQuality = [[NSUserDefaults standardUserDefaults] stringForKey:@"PhotoQuality"];
	if (photoQuality == nil) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"PhotoQuality"];
    }
    
	OBSERVE(self, @selector(_setupDeviceList), PLSCANNERLIST_UPDATED, [PLScannerList defaultManager]);
	[[PLMainWindowController sharedController] addObserver:self forKeyPath:@"scanning" options:0 context:NULL];
    
    //[self _setupToolbar];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ((object == [PLMainWindowController sharedController]) && ([keyPath isEqualToString:@"scanning"])) {
        if ([[PLMainWindowController sharedController] scanning]) {
            [_devicePopupList setEnabled:NO];
            [_paperSizePopupList setEnabled:NO];
            [_photoQualityCheckbox setEnabled:NO];
            [_deviceLabel setTextColor:[NSColor disabledControlTextColor]];
            [_paperSizeLabel setTextColor:[NSColor disabledControlTextColor]];
        }
        else {
            [_devicePopupList setEnabled:YES];
            [_paperSizePopupList setEnabled:YES];
            [_photoQualityCheckbox setEnabled:YES];
            [_deviceLabel setTextColor:[NSColor controlTextColor]];
            [_paperSizeLabel setTextColor:[NSColor controlTextColor]];
        }
    }
}

- (void) _setupPaperSizeList
{
    NSArray * list;
    unsigned int i;
    NSString * selectedName;
    int popupIndex;
    
    list = [[PLScannerUtils sharedManager] pageSizeLocalizedNames];
    
    [_paperSizePopupList removeAllItems];
    
    for(i = 0 ; i < [list count] ; i ++) {
        [_paperSizePopupList addItemWithTitle:[list objectAtIndex:i]];
    }
    
    selectedName = [[NSUserDefaults standardUserDefaults]
                    objectForKey:@"PaperSize"];
    if (selectedName != nil) {
        popupIndex = [[PLScannerUtils sharedManager] indexForPageSizeName:selectedName];
        if (popupIndex == -1)
            popupIndex = 0;
        [_paperSizePopupList selectItemAtIndex:popupIndex];
    }
}

- (void) _paperSizeSelected:(id)sender
{
    int popupIndex;
    NSString * name;
    PLPageSizeInfo * pageSize;
    
    popupIndex = [_paperSizePopupList indexOfSelectedItem];
    if (popupIndex == -1)
        return;
    
    pageSize = [[[PLScannerUtils sharedManager] pageSizes] objectAtIndex:popupIndex];
    name = [pageSize name];
    [[NSUserDefaults standardUserDefaults] setObject:name
                                              forKey:@"PaperSize"];
}

- (void) _setupAdvancedDeviceList
{
    NSArray * twainSources;
    unsigned int i;
    
    _hasScanSnap = NO;
    _hasOtherScanner = NO;
    [_advancedDevicePopupList removeAllItems];
    
    twainSources = [self _twainSources];
    for(i = 0 ; i < [twainSources count] ; i ++) {
        PLTwainSource * source;
        
        source = [twainSources objectAtIndex:i];
        [_advancedDevicePopupList addItemWithTitle:[source name]];
        _hasOtherScanner = YES;
    }
    
    // /Applications/ScanSnap -> Add Item
#if 0
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/Applications/ScanSnap"]) {
        [_advancedDevicePopupList addItemWithTitle:@"ScanSnap"];
        [self setDeleteAfterImportCheckboxEnabled:YES];
        _hasOtherScanner = YES;
        _hasScanSnap = YES;
    }
    else {
        [self setDeleteAfterImportCheckboxEnabled:NO];
    }
#endif
	
    [_advancedDevicePopupList setTarget:self];
    [_advancedDevicePopupList setAction:@selector(_advancedScannerSelected:)];
}

- (void) _setupImageCaptureDeviceList
{
    NSArray * list;
    unsigned int i;
    
    list = [self _imageCaptureSources];
    
    [_devicePopupList removeAllItems];
    
    if (([list count] == 0) && ([[self _twainSources] count] == 0)) {
        [_devicePopupList addItemWithTitle:NSLocalizedStringFromTable(@"No scanner", @"Preferences", @"scanner popup list")];
    }
    else {
        for(i = 0 ; i < [list count] ; i ++) {
            PLScanner * scanner;
            
            scanner = [list objectAtIndex:i];
            [_devicePopupList addItemWithTitle:[scanner scannerName]];
        }
    }
    
    if (_hasOtherScanner) {
        NSString * title;
        
        if (![[self selectedScanner] isKindOfClass:[PLScanner class]])
            title = [NSString stringWithFormat:@"Advanced (%@)...", [[self selectedScanner] scannerName]];
        else
        	title = @"Advanced...";
        [_devicePopupList addItemWithTitle:title];
    }
}

- (void) _setupDeviceList
{
    BOOL otherScanner;
    NSArray * list;
    
    [self _validateSelection];
    [self _setupAdvancedDeviceList];
    [self _setupImageCaptureDeviceList];
    
    list = [self _imageCaptureSources];
    otherScanner =[[NSUserDefaults standardUserDefaults] boolForKey:@"OtherScanner"];
    if (![[self selectedScanner] isKindOfClass:[PLScanner class]]) {
        [_devicePopupList selectItemAtIndex:[list count]];
    }
    else {
        unsigned int i;
        
        for(i = 0 ; i < [list count] ; i ++) {
            PLScanner * scanner;
            
            scanner = [list objectAtIndex:i];
            if (scanner == _selectedScanner) {
                [_devicePopupList selectItemAtIndex:i];
            }
        }
    }
}

- (NSArray *) _twainSources
{
    return [[PLTwainManager sharedManager] sources];
    //return [NSArray array];
}

- (NSArray *) _imageCaptureSources
{
    return [[PLScannerList defaultManager] getScannerList];
    //return [NSArray array];
}

- (void) _validateSelection
{
    NSString * scannerName;
    BOOL otherScanner;
    unsigned int i;
    
    [self willChangeValueForKey:@"selectedScanner"];
    [_selectedScanner release];
    _selectedScanner = nil;
    
    scannerName = [[NSUserDefaults standardUserDefaults] objectForKey:@"ScannerName"];
    otherScanner = [[NSUserDefaults standardUserDefaults] boolForKey:@"OtherScanner"];
    if (otherScanner) {
        NSArray * list;
        
        list = [self _twainSources];
        for(i = 0 ; i < [list count] ; i ++) {
            PLTwainSource * source;
            
            source = [list objectAtIndex:i];
            if ([[source name] isEqualToString:scannerName]) {
                _selectedScanner = [[PLTwainScanner alloc] initWithTwainManagerSource:source];
            }
        }
    }
    
    if (!otherScanner) {
        NSArray * list;
        
        list = [self _imageCaptureSources];
        for(i = 0 ; i < [list count] ; i ++) {
            PLScanner * scanner;
            
            scanner = [list objectAtIndex:i];
            if ([[scanner scannerName] isEqualToString:scannerName]) {
                _selectedScanner = [scanner retain];
            }
        }
    }
    
    if (_selectedScanner == nil) {
        NSArray * list;
        
        list = [self _imageCaptureSources];
        if ([list count] > 0) {
            _selectedScanner = [list objectAtIndex:0];
            [_selectedScanner retain];
        }
    }
    if (_selectedScanner == nil) {
        NSArray * list;
        
        list = [self _twainSources];
        if ([list count] > 0) {
            PLTwainSource * source;
            
            source = [list objectAtIndex:0];
            _selectedScanner = [[PLTwainScanner alloc] initWithTwainManagerSource:source];
        }
    }
    NSLog(@"validated %@", _selectedScanner);
    [self didChangeValueForKey:@"selectedScanner"];
}

- (void) _scannerSelected:(id)sender
{
    PLScanner * scanner;
    
    if (_hasOtherScanner) {
        if ([_devicePopupList indexOfSelectedItem] == [_devicePopupList numberOfItems] - 1) {
            [self _openAdvancedSheet];
            return;
        }
    }
    
    scanner = [self _selectedScanner];
    [[NSUserDefaults standardUserDefaults] setObject:[scanner scannerName]
                                              forKey:@"ScannerName"];
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"OtherScanner"];
    
    [self _validateSelection];
}

- (PLScanner *) _selectedScanner
{
    int popupIndex;
    NSArray * list;
    PLScanner * scanner;
    
    if (_hasOtherScanner) {
        if ([_devicePopupList indexOfSelectedItem] == [_devicePopupList numberOfItems] - 1) {
            return nil;
        }
    }
    
    popupIndex = [_devicePopupList indexOfSelectedItem];
    if (popupIndex == -1)
        return nil;
    
    list = [self _imageCaptureSources];
    if ([list count] == 0)
        return nil;
	
    scanner = [list objectAtIndex:popupIndex];
	
	return scanner;
}

- (NSObject <PLScannerProtocol> *) selectedScanner
{
    return _selectedScanner;
}

- (void) _setupToolbar
{
	NSToolbarItem * item;
	NSRect bounds;
	NSRect frame;
    
	_toolbarDict = [[NSMutableDictionary alloc] init];
	
	item = [[NSToolbarItem alloc] initWithItemIdentifier:@"General"];
	[item setLabel:@"General"];
	[item setImage:[NSImage imageNamed:@"pref_general.tiff"]];
	[item setTarget:self];
	[item setAction:@selector(openGeneral:)];
	[_toolbarDict setObject:item forKey:[item itemIdentifier]];
	[item release];
    
	item = [[NSToolbarItem alloc] initWithItemIdentifier:@"Advanced"];
	[item setLabel:@"Advanced"];
	[item setImage:[NSImage imageNamed:@"pref_advanced.tiff"]];
	[item setTarget:self];
	[item setAction:@selector(openAdvanced:)];
	[_toolbarDict setObject:item forKey:@"Advanced"];
	[item release];
	
	_toolbar = [[NSToolbar alloc] initWithIdentifier:@"Preferences"];
	[_toolbar setDelegate:self];
	[[self window] setToolbar:_toolbar];
	
	[_toolbar validateVisibleItems];
	[_toolbar setSelectedItemIdentifier:@"General"];
	
	_maxWidth = 0;
	bounds = [_mainView bounds];
	if (bounds.size.width > _maxWidth)
		_maxWidth = bounds.size.width;
	bounds = [_advancedView bounds];
	if (bounds.size.width > _maxWidth)
		_maxWidth = bounds.size.width;
	frame = [_mainView frame];
    frame.size.width = _maxWidth;
    [_mainView setFrame:frame];
	frame = [_advancedView frame];
    frame.size.width = _maxWidth;
    [_advancedView setFrame:frame];
    
	frame = [[self window] frame];
	frame.size.width = _maxWidth;
	[[self window] setFrame:frame display:YES];
	
	[self openGeneral:nil];
	[[self window] center];
}

- (void) _unsetupToolbar
{
	[_toolbar release];
	
	[_toolbarDict release];
}

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
	return [_toolbarDict objectForKey:itemIdentifier];
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
	return [NSArray arrayWithObjects:@"General", @"Advanced", nil];
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
	return [NSArray arrayWithObjects:@"General", @"Advanced", nil];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return [NSArray arrayWithObjects:@"General", @"Advanced", nil];
}

- (void) openGeneral:(id)sender
{
	float diff;
	float diffX;
	NSRect startFrame;
	NSRect finalFrame;
	NSRect frame;
	
	startFrame = [[[self window] contentView] bounds];
	finalFrame = [_mainView frame];
	diff = finalFrame.size.height - startFrame.size.height;
	diffX = finalFrame.size.width - startFrame.size.width;
	
	[_mainView removeFromSuperview];
	[_advancedView removeFromSuperview];
	
	frame = [[self window] frame];
	frame.size.height += diff;
	frame.origin.y -= diff;
    frame.size.width += diffX;
	[[self window] setFrame:frame display:YES animate:YES];
	
	[[[self window] contentView] addSubview:_mainView];
}

- (void) openAdvanced:(id)sender
{
	float diff;
	float diffX;
	NSRect startFrame;
	NSRect finalFrame;
	NSRect frame;
	
	startFrame = [[[self window] contentView] bounds];
	finalFrame = [_advancedView frame];
	diff = finalFrame.size.height - startFrame.size.height;
	diffX = finalFrame.size.width - startFrame.size.width;
	
	[_mainView removeFromSuperview];
	[_advancedView removeFromSuperview];
	
	frame = [[self window] frame];
	frame.size.height += diff;
	frame.origin.y -= diff;
    frame.size.width += diffX;
	[[self window] setFrame:frame display:YES animate:YES];
	
	[[[self window] contentView] addSubview:_advancedView];
}

- (void) _advancedScannerSelected:(id)sender
{
}

- (void) _openAdvancedSheet
{
    [NSApp beginSheet:_advancedWindow modalForWindow:[self window] modalDelegate:self didEndSelector:@selector(_advancedScannerSheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void) _advancedScannerSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
}

- (void) cancelAdvanced:(id)sender
{
    NSArray * list;
    unsigned int i;
    
    [NSApp endSheet:_advancedWindow];
    [_advancedWindow orderOut:self];
    
    list = [self _imageCaptureSources];
    for(i = 0 ; i < [list count] ; i ++) {
        PLScanner * scanner;
        
        scanner = [list objectAtIndex:i];
        if (scanner == _selectedScanner) {
            [_devicePopupList selectItemAtIndex:i];
            break;
        }
    }
}

- (void) doneAdvanced:(id)sender
{
    if ([_advancedDevicePopupList indexOfSelectedItem] != -1) {
        PLTwainSource * source;
        
        source = [[self _twainSources] objectAtIndex:[_advancedDevicePopupList indexOfSelectedItem]];
        [[NSUserDefaults standardUserDefaults] setObject:[source name]
                                                  forKey:@"ScannerName"];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"OtherScanner"];
        
        [self _validateSelection];
        [self _setupDeviceList];
    }
    
    [NSApp endSheet:_advancedWindow];
    [_advancedWindow orderOut:self];
}

@end
