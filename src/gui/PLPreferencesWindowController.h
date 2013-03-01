//
//  PLPreferencesWindowController.h
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 31/07/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "PLUtils.h"

@protocol PLScannerProtocol;
@class PLScanner;

@interface PLPreferencesWindowController : NSWindowController {
    IBOutlet NSView * _mainView;
    IBOutlet NSView * _advancedView;
    IBOutlet NSPopUpButton * _devicePopupList;
    IBOutlet NSPopUpButton * _paperSizePopupList;
    IBOutlet NSButton * _photoQualityCheckbox;
    IBOutlet NSTextField * _deviceLabel;
    IBOutlet NSTextField * _paperSizeLabel;
    IBOutlet NSPopUpButton * _advancedDevicePopupList;
    IBOutlet NSButton * _deleteAfterImportCheckbox;
    NSMutableDictionary * _toolbarDict;
    NSToolbar * _toolbar;
    CGFloat _maxWidth;
    BOOL _scannerSupport;
    BOOL _deleteAfterImportCheckboxEnabled;
    IBOutlet NSWindow * _advancedWindow;
    BOOL _hasOtherScanner;
    NSObject <PLScannerProtocol> * _selectedScanner;
    BOOL _hasScanSnap;
}

@property BOOL deleteAfterImportCheckboxEnabled;

+ (PLPreferencesWindowController *) sharedController;

- (id) init;
- (void) dealloc;
- (NSString *) windowNibName;

- (void) awakeFromNib;

- (NSObject <PLScannerProtocol> *) selectedScanner;

- (void) openGeneral:(id)sender;
- (void) openAdvanced:(id)sender;

- (void) cancelAdvanced:(id)sender;
- (void) doneAdvanced:(id)sender;

@end
