

#import <Foundation/Foundation.h>

#define QSPasteboardDidChangeNotification @"QSPasteboardDidChangeNotification"

@interface QSPasteboardMonitor : NSObject {

    NSTimer *pollTimer;

    NSInteger lastChangeCount;
}
+ (id)sharedInstance;


@end
