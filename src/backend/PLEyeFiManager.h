//
//  PLEyeFiManager.h
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 2/17/13.
//
//

#import <Foundation/Foundation.h>

@class PLLibrary;
@protocol PLEyeFiManagerDelegate;

@interface PLEyeFiManager : NSObject {
    id <PLEyeFiManagerDelegate> _delegate;
    NSSize _paperSize;
    unsigned int _progressMaxValue;
    unsigned int _progressValue;
    BOOL _isImporting;
    NSDateFormatter * _formatter;
}

@property (nonatomic, assign) id <PLEyeFiManagerDelegate> delegate;

- (void) import;

- (unsigned int) progressMaxValue;
- (unsigned int) progressValue;
- (BOOL) isImporting;

@end

@protocol PLEyeFiManagerDelegate

- (void) PLEyeFiManager:(PLEyeFiManager *)manager addPDFFilenames:(NSArray *)pdfFilenames;
- (void) PLEyeFiManager_progressUpdated:(PLEyeFiManager *)manager;

@end
