//
//  QSReloadingDockingWindow.m
//  Clipboard
//
//  Created by Patrick Robertson on 18/03/2025.
//

#import "QSReloadingDockingWindow.h"

@implementation QSReloadingDockingWindow


- (IBAction)show:(id)sender {
    // this is a hack because cell-based table views seem buggy in later OS versions (10.10+) since they were deprecated
    // replacing them with view based table views is not worth it at this point (PITA)
    [tv reloadData];
    [super show:sender];
}
@end
