//
//  PLEyeFiManager.m
//  PaperLess2
//
//  Created by DINH Viêt Hoà on 2/17/13.
//
//

#import "PLEyeFiManager.h"

#import "PLPDFPageGeneration.h"
#import "PLScannerUtils.h"
#import "PLPageSizeInfo.h"

@implementation PLEyeFiManager

- (id) init
{
    self = [super init];
    
    NSString * paperSizeName = [[NSUserDefaults standardUserDefaults] objectForKey:@"PaperSize"];
    PLPageSizeInfo * pageSize = [[PLScannerUtils sharedManager] pageSizeWithName:paperSizeName];
    _paperSize = [pageSize size];
    
    return self;
}

- (void) dealloc
{
    [super dealloc];
}

- (void) import
{
    [NSThread detachNewThreadSelector:@selector(_run) toTarget:self withObject:nil];
}

- (void) _run
{
    NSString * folder;
    NSArray * subpaths;
    NSArray * donePaths;
    NSSet * donePathsSet;
    NSMutableArray * result;
    
    NSString * configFile = [@"~/Library/Application Support/PaperLess/eyefi.plist" stringByExpandingTildeInPath];
    
    donePaths = [[NSArray alloc] initWithContentsOfFile:configFile];
    donePathsSet = [[NSSet alloc] initWithArray:donePaths];
    
    folder = [@"~/Dropbox/Eye-Fi" stringByExpandingTildeInPath];
    subpaths = [[NSFileManager defaultManager] subpathsAtPath:folder];
    
    NSString * importFolder = [@"~/Library/Application Support/PaperLess/Import" stringByExpandingTildeInPath];
    importFolder = [importFolder stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtPath:importFolder withIntermediateDirectories:YES attributes:nil error:NULL];
    
    result = [NSMutableArray array];
    
    unsigned int count = 0;
    for(NSString * path in subpaths) {
        if ([donePathsSet containsObject:path]) {
            continue;
        }
        if (![[[path pathExtension] lowercaseString] isEqualToString:@"jpg"]) {
            continue;
        }
        
        count ++;
    }
    _progressMaxValue = count;
    
    _isImporting = YES;
    _formatter = [[NSDateFormatter alloc] init];
    [_formatter setDateFormat:@"yyyy-MM-dd"];
    
    [self _updateProgress];
    
    unsigned int timeDiff = 0;
    for(NSString * path in subpaths) {
        if ([donePathsSet containsObject:path]) {
            continue;
        }
        if (![[[path pathExtension] lowercaseString] isEqualToString:@"jpg"]) {
            continue;
        }
        NSString * fullPath = [folder stringByAppendingPathComponent:path];;
        NSString * pdfFilename = [self _generatePDFForFile:fullPath toFolder:importFolder timeDiff:timeDiff];
        [result addObject:pdfFilename];
        _progressValue ++;
        timeDiff ++;
        [self _updateProgress];
    }
    
    [donePathsSet release];
    [donePaths release];
    
    _isImporting = NO;
    [self _updateProgress];
    [_formatter release];
    _formatter = nil;
    
    [self performSelectorOnMainThread:@selector(_importPDFs:) withObject:result waitUntilDone:YES];
    
    [subpaths writeToFile:configFile atomically:YES];
    
    [self performSelectorOnMainThread:@selector(_finished) withObject:nil waitUntilDone:NO];
}

- (NSString *) _generatePDFForFile:(NSString *)path toFolder:(NSString *)importFolder timeDiff:(unsigned int)timeDiff
{
    PLPDFPageGeneration * generation;
    PDFDocument * pdf;
    NSString * destFilename;
    
    destFilename = [importFolder stringByAppendingPathComponent:[[path lastPathComponent] stringByDeletingPathExtension]];
    NSString * dateString = [[path stringByDeletingLastPathComponent] lastPathComponent];
    NSDate * date = [_formatter dateFromString:dateString];
    date = [date dateByAddingTimeInterval:(NSTimeInterval) timeDiff];
    NSDateComponents * components = [[NSCalendar currentCalendar] components:NSYearCalendarUnit | NSMonthCalendarUnit |  NSDayCalendarUnit
                                                                    fromDate:date];
    destFilename = [destFilename stringByAppendingFormat:@"-%u-%u-%u",
                    (unsigned) [components year], (unsigned) [components month], (unsigned) [components day]];
    destFilename = [destFilename stringByAppendingPathExtension:@"pdf"];
    
    generation = [[PLPDFPageGeneration alloc] init];
    [generation setPageSize:_paperSize];
    [generation setImage:path];
    pdf = [generation document];
    [pdf writeToFile:destFilename];
    if (date != nil) {
        NSMutableDictionary * attr = [[NSMutableDictionary alloc] init];
        [attr setObject:date forKey:NSFileModificationDate];
        [[NSFileManager defaultManager] setAttributes:attr ofItemAtPath:destFilename error:NULL];
        [attr release];
    }
    [generation release];
    
    return destFilename;
}

- (void) _importPDFs:(NSArray *)filenames
{
    [[self delegate] PLEyeFiManager:self addPDFFilenames:filenames];
}

- (void) _finished
{
}

- (unsigned int) progressMaxValue
{
    return _progressMaxValue;
}

- (unsigned int) progressValue
{
    return _progressValue;
}

- (BOOL) isImporting
{
    return _isImporting;
}

- (void) _updateProgress
{
    [self performSelectorOnMainThread:@selector(_updateProgressOnMainThread) withObject:nil waitUntilDone:YES];
}

- (void) _updateProgressOnMainThread
{
    [[self delegate] PLEyeFiManager_progressUpdated:self];
}

@end
