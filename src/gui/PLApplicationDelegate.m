//
//  PLApplicationDelegate.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 3/24/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "PLApplicationDelegate.h"

#import "PLMainWindowController.h"
#import "PLPreferencesWindowController.h"
#import "PLScannerList.h"
#import "PLFileManager.h"
#import "PLTwainManager.h"

@interface PLApplicationDelegate (Private)

- (void) _setupMenu;
- (void) _debugCheckFiles:(id)sender;
- (void) _debugRemainingFiles:(id)sender;
- (void) _openFiles;

@end


@implementation PLApplicationDelegate

- (id) init
{
    self = [super init];
    
    _started = NO;
    _fileList = [[NSMutableArray alloc] init];
    
    return self;
}

- (void) dealloc
{
    [_fileList release];
    
    [super dealloc];
}

- (BOOL) applicationShouldHandleReopen:(NSApplication *)theApplication
                     hasVisibleWindows:(BOOL)flag
{
    [[PLMainWindowController sharedController] showWindow:nil];
	return YES;
}

- (void) applicationDidFinishLaunching:(NSNotification *)aNotification
{
    _started = YES;
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DebugMenu"]) {
        [self _setupMenu];
    }
    [PLTwainManager sharedManager];
    [[PLMainWindowController sharedController] showWindow:nil];
    [PLPreferencesWindowController sharedController];
    
    [self _openFiles];
}

- (void) applicationWillTerminate:(NSNotification *)notification
{
    [[PLTwainManager sharedManager] terminate];
	//NSLog(@"close all session");
    [[PLMainWindowController sharedController] save];
	[[PLScannerList defaultManager] closeAllSession];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    [[PLMainWindowController sharedController] willTerminate];
    
    if ([[PLFileManager sharedManager] hasPendingOperations]) {
        NSAlert * alert;
        
        [[PLMainWindowController sharedController] showWindow:nil];
        
        alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"No"];
        [alert addButtonWithTitle:@"Yes"];
        [alert setMessageText:@"Do you really want to quit now ?"];
        [alert setInformativeText:@"Background operations are still in progress."];
        [alert setAlertStyle:NSWarningAlertStyle];
        
        [alert beginSheetModalForWindow:[[PLMainWindowController sharedController] window] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:NULL];
        
        [alert release];
        
        return NSTerminateLater;
    }
    else {
        return NSTerminateNow;
    }
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    [[alert window] orderOut:self];
    
    if (returnCode == NSAlertFirstButtonReturn)
        [NSApp replyToApplicationShouldTerminate:NO];
    else
        [NSApp replyToApplicationShouldTerminate:YES];
}
        
- (void) openPreferences:(id)sender
{
    [[PLPreferencesWindowController sharedController] showWindow:nil];
}

- (void) scan:(id)sender
{
    [[PLMainWindowController sharedController] scan:sender];
}

- (void) merge:(id)sender
{
    [[PLMainWindowController sharedController] merge:sender];
}
 
- (void) revealInFinder:(id)sender
{
    [[PLMainWindowController sharedController] revealInFinder:sender];
}

- (void) openInPreview:(id)sender
{
    [[PLMainWindowController sharedController] openInPreview:sender];
}

- (void) deleteDocument:(id)sender
{
    [[PLMainWindowController sharedController] deleteDocument:sender];
}

- (void) undo:(id)sender
{
    [[PLMainWindowController sharedController] undo:sender];
}

- (void) redo:(id)sender
{
    [[PLMainWindowController sharedController] redo:sender];
}

- (void) export:(id)sender
{
    [[PLMainWindowController sharedController] export:sender];
}

- (void) import:(id)sender
{
    [[PLMainWindowController sharedController] import:sender];
}

- (void) save:(id)sender
{
    [[PLMainWindowController sharedController] save:sender];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    if ([menuItem action] == @selector(undo:)) {
        [[PLMainWindowController sharedController] updateUndoMenuItem:menuItem];
        return [[PLMainWindowController sharedController] isUndoEnabled];
    }
    else if ([menuItem action] == @selector(redo:)) {
        [[PLMainWindowController sharedController] updateRedoMenuItem:menuItem];
        return [[PLMainWindowController sharedController] isRedoEnabled];
    }
    else if ([menuItem action] == @selector(deleteDocument:)) {
        return [[PLMainWindowController sharedController] isDeleteDocumentEnabled];
    }
    else if ([menuItem action] == @selector(openInPreview:)) {
        return [[PLMainWindowController sharedController] isOpenInPreviewEnabled];
    }
    else if ([menuItem action] == @selector(revealInFinder:)) {
        return [[PLMainWindowController sharedController] isRevealInFinderEnabled];
    }
    else if ([menuItem action] == @selector(merge:)) {
        return [[PLMainWindowController sharedController] isMergeEnabled];
    }
    else if ([menuItem action] == @selector(export:)) {
        return [[PLMainWindowController sharedController] isExportToFolderEnabled];
    }
    else if ([menuItem action] == @selector(import:)) {
        return YES;
    }
    else if ([menuItem action] == @selector(save:)) {
        return [[PLMainWindowController sharedController] isSaveEnabled];
    }
    else if ([menuItem action] == @selector(scan:)) {
        return [[PLMainWindowController sharedController] isScanEnabled];
    }
    else if ([menuItem action] == @selector(print:)) {
        return NO;
    }
    else if ([menuItem action] == @selector(runPageLayout:)) {
        return NO;
    }
    else {
        return YES;
    }
}

- (void) _setupMenu
{
    NSMenu * menu;
    NSMenuItem * debugMenuItem;
    NSMenu * debugMenu;
    
    menu = [NSApp mainMenu];
    debugMenuItem = [[NSMenuItem alloc] init];
    debugMenu = [[NSMenu alloc] initWithTitle:@"Debug"];
    [debugMenu addItemWithTitle:@"Check all PDF" action:@selector(_debugCheckFiles:) keyEquivalent:@""];
    [debugMenu addItemWithTitle:@"Check for remaining files" action:@selector(_debugRemainingFiles:) keyEquivalent:@""];
    [debugMenuItem setSubmenu:debugMenu];
    
    [menu addItem:debugMenuItem];
    
    [debugMenu release];
    [debugMenuItem release];
}

- (void) _debugCheckFiles:(id)sender
{
    [[PLMainWindowController sharedController] debugCheckFiles:sender];
}

- (void) _debugRemainingFiles:(id)sender
{
    [[PLMainWindowController sharedController] debugRemainingFiles:sender];
}

- (void) print:(id)sender
{
}

- (void) runPageLayout:(id)sender
{
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename
{
    [_fileList addObject:filename];
    
    if (_started) {
        [self _openFiles];
    }
    
    return YES;
}

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
    [_fileList addObjectsFromArray:filenames];
    
    if (_started) {
        [self _openFiles];
    }
}

- (void) _openFiles
{
    [[PLMainWindowController sharedController] openFileList:_fileList];
    [_fileList removeAllObjects];
}

@end
