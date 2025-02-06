

#import "QSPasteboardObjectView.h"

@implementation QSPasteboardObjectView

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    return NSDragOperationCopy;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {    
    [[QSObject objectWithPasteboard:[sender draggingPasteboard]] putOnPasteboard:[NSPasteboard generalPasteboard]];
    return YES;
}

@end
