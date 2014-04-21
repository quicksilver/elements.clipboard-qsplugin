
#import <Foundation/Foundation.h>
typedef enum {
	QSPasteboardHistoryMode = 1, // Global pasteboard history
	QSPasteboardStoreMode = 2, // numbered storage bins
	QSPasteboardQueueMode = 3, // FIFO Cycling
	QSPasteboardStackMode = 4 // LIFO Cycling
} QSPasteboardMode;

@class QSObjectView;


#define kCapturePasteboardHistory @"Capture Pasteboard History"
#define kCapturePasteboardHistoryCount @"Capture Pasteboard History Count"
#define kStorePasteboardHistoryOnDisk @"Store Pasteboard History"
#define kCapturePasteboardIgnoreApps @"clipboardIgnoreApps"

@interface QSPasteboardController : NSWindowController {
	// Array storing all the clipboard history
    NSMutableArray *pasteboardHistoryArray;
    NSMutableArray *pasteboardStoreArray;
    NSMutableArray *pasteboardCacheArray;
		
    IBOutlet NSMatrix *pasteboardHistoryMatrix;
    IBOutlet NSTableView *pasteboardHistoryTable;
    IBOutlet QSObjectView *pasteboardItemView;
    IBOutlet NSWindow *pasteboardProxyWindow;
    
    IBOutlet NSButton *clearButton;
    IBOutlet NSTextField *titleField;
    IBOutlet NSMenu *pasteboardMenu;
    QSObjectView *pasteboardObjectView;
    BOOL supressCapture;
    BOOL adjustRowsToFit;
	BOOL cacheIsReversed;
    BOOL asPlainText;
    NSInteger maxPasteboardCount;
    BOOL captureHistory;
    NSArray *ignoredApps;
	NSUInteger mode;
    dispatch_queue_t pasteboardQueue;
}

@property NSMutableArray *currentArray;

+ (void)showClipboard:(id)sender;

- (void)clearStore;
- (void)copyToClipboard:(QSObject*)obj;
- (id)selectedObject;
- (void)switchToMode:(NSUInteger)newMode;
- (void)setCacheIsReversed:(BOOL)reverse;
- (void)adjustRowHeight;
- (IBAction)clearHistory:(id)sender;
- (IBAction)setMode:(id)sender;

- (IBAction)qsPaste:(id)sender;

- (IBAction)toggleAdjustRows:(id)sender;

- (IBAction)showPreferences:(id)sender;

+ (id)sharedInstance;

- (IBAction)hideWindow:(id)sender;
@end
