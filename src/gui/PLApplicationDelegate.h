//
//  PLApplicationDelegate.h
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 3/24/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class PLMainWindowController;
@class PLPreferencesWindowController;

@interface PLApplicationDelegate : NSObject {
    NSMutableArray * _fileList;
    BOOL _started;
}

- (id) init;
- (void) dealloc;

- (BOOL) applicationShouldHandleReopen:(NSApplication *)theApplication
                     hasVisibleWindows:(BOOL)flag;
- (void) applicationDidFinishLaunching:(NSNotification *)aNotification;
- (void) applicationWillTerminate:(NSNotification *)notification;
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender;
- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename;
- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames;

- (void) openPreferences:(id)sender;

- (void) scan:(id)sender;
- (void) merge:(id)sender;
- (void) revealInFinder:(id)sender;
- (void) openInPreview:(id)sender;
- (void) deleteDocument:(id)sender;
- (void) export:(id)sender;
- (void) import:(id)sender;
- (void) save:(id)sender;

- (void) undo:(id)sender;
- (void) redo:(id)sender;

- (void) print:(id)sender;
- (void) runPageLayout:(id)sender;

@end
