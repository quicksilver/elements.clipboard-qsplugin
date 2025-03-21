#import "QSPasteboardMonitor.h"
#import "QSPasteboardController.h"
#import "QSPasteboardAccessoryCell.h"

@interface QSController : NSWindowController

- (QSInterfaceController *)interfaceController;

@end

@interface QSPasteboardController () <QSTableViewDataSource, QSTableViewDelegate> {
	NSIndexSet *_draggedRows;
}

@end

@implementation QSPasteboardController

@dynamic window;

+ (void)initialize {
    
    // add clipboard option to the Quicksilver menu
	NSMenu *modulesMenu = [[[NSApp mainMenu] itemWithTag:128] submenu];
	NSMenuItem *modMenuItem = [modulesMenu addItemWithTitle:@"Clipboard History" action:@selector(showClipboard:) keyEquivalent:@"l"];
	[modMenuItem setTarget:self];

	[QSPasteboardMonitor sharedInstance];
    NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:kCapturePasteboardHistory])
		[QSPasteboardController sharedInstance];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(saveVisibilityState:) name:@"QSEventNotification" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showClipboardHidden:) name:@"QSApplicationDidFinishLaunchingNotification" object:nil];

	NSImage *image = [[NSImage alloc] initByReferencingFile:
                       [[NSBundle bundleForClass:[QSPasteboardController class]]pathForImageResource:@"Clipboard"]];
	[image shrinkToSize:QSSize16];
	[modMenuItem setImage:image];

    // set up the default apps to ignore clipboard content from: 1Password, Keychain and Wallet
    if (![defaults objectForKey:@"clipboardIgnoreApps"]) {
        NSArray *apps = [NSArray arrayWithObjects:@"com.agilebits.onepassword-osx",@"com.acrylic.wallet",@"com.apple.keychainaccess",@"com.microsoft.RDC",nil];
        NSMutableArray *tempArray = [NSMutableArray arrayWithCapacity:2];
        for (NSString *app in apps) {
            if ([[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:app] ) {
                [tempArray addObject:app];
            }
        }
        [defaults setObject:tempArray forKey:@"clipboardIgnoreApps"];
    }

}

+ (QSPasteboardController *)sharedInstance {
	static id _sharedInstance;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		_sharedInstance = [[[self class] allocWithZone:nil] init];
	});
	return _sharedInstance;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent {
    return YES;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

+ (BOOL)validateMenuItem:(NSMenuItem*)anItem {
	return YES;
}

+ (void)showClipboardHidden:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:@"QSPasteboardHistoryIsVisible"] || [[[self sharedInstance] window] isDocked]) {
		[[[self sharedInstance] window] orderFrontHidden:sender];
	}
}

+ (void)showClipboard:(id)sender {
	QSGCDMainAsync(^{
		[[[self sharedInstance] window] toggle:sender];
	});

}

// saves the state of the shelf window when Quicksilver goes to quit (used on next QS launch - see +loadPlugIn)
+(void)saveVisibilityState:(NSNotification *)notif {
    if ([[notif object] isEqualToString:@"QSQuicksilverWillQuitEvent"]) {
		BOOL visible = ![[[self sharedInstance] window] hidden];
        [[NSUserDefaults standardUserDefaults] setBool:visible forKey:@"QSPasteboardHistoryIsVisible"];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:kDiscardPasteboardHistoryOnQuit]) {
            // make sure any existing history is overwritten
            [[QSLib shelfNamed:@"QSPasteboardHistory"] removeAllObjects];
            [QSLib savePasteboardHistory];
        }
    }
}

- (void)clearStore {
	[pasteboardStoreArray removeAllObjects];
	for (NSInteger i = 0; i<10; i++) {
        [pasteboardStoreArray addObject:[QSNullObject nullObject]];
    };
}

- (id)init {
    if (self = [super initWithWindowNibName:@"Pasteboard" owner:self]) {

        pasteboardHistoryArray = [[QSLibrarian sharedInstance] shelfNamed:@"QSPasteboardHistory"];

		self.currentArray = pasteboardHistoryArray;
		mode = QSPasteboardHistoryMode;
		pasteboardStoreArray = [[NSMutableArray alloc] init];
		[self clearStore];
		pasteboardCacheArray = [[NSMutableArray alloc] init];

		// ***warning   * if pasteboard is empty, put last copyied item onto it

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pasteboardChanged:) name:QSPasteboardDidChangeNotification object:nil];


		if (defaultBool(@"QSClipboardModule/EnableHotKeys") ) {
			QSHotKeyEvent *hotKey;

			hotKey = (QSHotKeyEvent *)[QSHotKeyEvent getHotKeyForKeyCode:37 character:[@"L" characterAtIndex:0]
                                                           modifierFlags:NSCommandKeyMask | NSControlKeyMask];
			[hotKey setTarget:self selector:@selector(showHistory:)];
			[hotKey setEnabled:YES];

			hotKey = (QSHotKeyEvent *)[QSHotKeyEvent getHotKeyForKeyCode:37 character:[@"L" characterAtIndex:0]
                                                           modifierFlags:NSCommandKeyMask | NSShiftKeyMask | NSAlternateKeyMask];
			[hotKey setTarget:self selector:@selector(showStore:)];
			[hotKey setEnabled:YES];

			hotKey = (QSHotKeyEvent *)[QSHotKeyEvent getHotKeyForKeyCode:37 character:[@"L" characterAtIndex:0]
                                                           modifierFlags:NSCommandKeyMask | NSControlKeyMask | NSAlternateKeyMask];
			[hotKey setTarget:self selector:@selector(showQueue:)];
			[hotKey setEnabled:YES];

			hotKey = (QSHotKeyEvent *)[QSHotKeyEvent getHotKeyForKeyCode:37 character:[@"L" characterAtIndex:0]
                                                           modifierFlags:NSCommandKeyMask | NSControlKeyMask | NSShiftKeyMask];
			[hotKey setTarget:self selector:@selector(showStack:)];
			[hotKey setEnabled:YES];

			hotKey = (QSHotKeyEvent *)[QSHotKeyEvent getHotKeyForKeyCode:9 character:[@"V" characterAtIndex:0]
                                                           modifierFlags:NSCommandKeyMask | NSControlKeyMask];
			[hotKey setTarget:self selector:@selector(qsPaste:)];
			[hotKey setEnabled:YES];
		}

	}
	return self;
}



- (IBAction)showHistory:(id)sender {
	[self switchToMode:QSPasteboardHistoryMode];
	[[self window] show:sender];
}

- (IBAction)showStore:(id)sender {
	[self switchToMode:QSPasteboardStoreMode];
	[[self window] show:sender];
}

- (IBAction)showQueue:(id)sender {
	[self switchToMode:QSPasteboardQueueMode];
	[[self window] show:sender];
}

- (IBAction)showStack:(id)sender {
	[self switchToMode:QSPasteboardStackMode];
	[[self window] show:sender];
}

// used for the 'clip store copy' objects (see the plist)
- (void)copyNumber:(NSNumber *)number {
    NSUInteger zeroIndexNumber = [number unsignedIntegerValue];
    [pasteboardHistoryTable selectRowIndexes:[NSIndexSet indexSetWithIndex:zeroIndexNumber] byExtendingSelection:NO];
    [self copyToClipboard:[self selectedObject]];
}

// used for the 'clip store paste' objects
- (void)pasteNumber:(NSNumber *)number {
    [self pasteNumber:[number unsignedIntegerValue] plainText:NO];
}

- (void)pasteNumber:(NSUInteger)number plainText:(BOOL)plainText {
    NSIndexSet *rowSet = [NSIndexSet indexSetWithIndex:number];

    if (mode == QSPasteboardStoreMode && plainText == YES) {
        [pasteboardStoreArray replaceObjectAtIndex:number withObject:[QSObject objectWithPasteboard:[NSPasteboard generalPasteboard]]];
        [pasteboardHistoryTable selectRowIndexes:rowSet byExtendingSelection:NO];
    } else {
        [pasteboardHistoryTable selectRowIndexes:rowSet byExtendingSelection:NO];
        [self pasteItem:self];
    }
}

- (void)pasteItem:(id)sender {
    [[self window] resignKeyWindowNow];
    asPlainText = (([[NSApp currentEvent] modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask) == NSEventModifierFlagOption);

	[self qsPaste:nil];
	
	[self hideWindow:sender];
    [[(QSController *)[NSApp delegate] interfaceController] hideWindows:self];
	
	// scroll to first item
	[pasteboardHistoryTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];

	// ***warning   * the clipboard should be restored
}


- (IBAction)qsPaste:(id)sender {
	QSObject *selectedObject = [self selectedObject];
	switch (mode) {
		case QSPasteboardHistoryMode:
		case QSPasteboardStoreMode:
			[self copyToClipboard:selectedObject];
          QSForcePaste();
			break;
		case QSPasteboardQueueMode:
		case QSPasteboardStackMode:
			if ([pasteboardCacheArray count]) {
				id object = (sender ? [pasteboardCacheArray objectAtIndex:0] : selectedObject);
				supressCapture = YES;
				[self copyToClipboard:object];
					QSForcePaste();
				if (sender) {
					[pasteboardCacheArray removeObjectAtIndex:0];
					[pasteboardHistoryTable reloadData];
				}
			} else {
				NSBeep();
			}
			break;
		default:
			break;
	}

}

- (void)awakeFromNib {
    [[self window] addInternalWidgetsForStyleMask:NSUtilityWindowMask closeOnly:NO];
    [pasteboardHistoryTable registerForDraggedTypes:standardPasteboardTypes];
    [[self window] setLevel:27];
    [[self window] setHidesOnDeactivate:NO];
//    [self window].styleMask |= NSWindowStyleMaskResizable;
    [pasteboardHistoryArray makeObjectsPerformSelector:@selector(loadIcon)];

    [[self window] setAutosaveName:@"QSPasteboardHistoryWindow"]; // should use the real methods to do this

    //NSImageCell *imageCell = nil;
    [pasteboardHistoryTable setVerticalMotionCanBeginDrag: TRUE];

	NSUserDefaults *def = [NSUserDefaults standardUserDefaults];

	CGFloat rowHeight = [def doubleForKey:@"QSPasteboardRowHeight"];
	adjustRowsToFit = [def boolForKey:@"QSPasteboardAdjustRowHeight"];
    [pasteboardHistoryTable setRowHeight:rowHeight?rowHeight:36];
    //    [[self window] setNextResponder:self];
    [pasteboardHistoryTable setTarget:self];
    //[pasteboardHistoryTable setAction:@selector(tableAction:)];
    [pasteboardHistoryTable setDoubleAction:@selector(pasteItem:)];

    [pasteboardHistoryTable setTarget:self];
    [pasteboardHistoryTable setOpaque:YES];
    QSObjectCell *objectCell = [[QSObjectCell alloc] init];
    if ([objectCell respondsToSelector:@selector(showsRichText)]) {
        objectCell.showsRichText = YES;
    }
    [[pasteboardHistoryTable tableColumnWithIdentifier: @"object"] setDataCell:objectCell];

    NSCell *numberCell = [[QSPasteboardAccessoryCell alloc] init];

    [[pasteboardHistoryTable tableColumnWithIdentifier: @"sequence"] setDataCell:numberCell];


    if ([pasteboardHistoryArray count]) {
		NSPasteboard *pboard = [NSPasteboard generalPasteboard];
		if (![[pboard types] count]) {
			[[pasteboardHistoryArray objectAtIndex:0] putOnPasteboard:pboard];
		}
		[pasteboardItemView setObjectValue:[pasteboardHistoryArray objectAtIndex:0]];

	}


	[pasteboardHistoryTable bind:@"backgroundColor"
                        toObject:[NSUserDefaultsController sharedUserDefaultsController]
                     withKeyPath:@"values.QSAppearance3B"
                         options:[NSDictionary dictionaryWithObject:NSUnarchiveFromDataTransformerName
                                                             forKey:@"NSValueTransformerName"]];



	[pasteboardHistoryTable bind:@"highlightColor"
                        toObject:[NSUserDefaultsController sharedUserDefaultsController]
                     withKeyPath:@"values.QSAppearance3A"
                         options:[NSDictionary dictionaryWithObject:NSUnarchiveFromDataTransformerName
                                                             forKey:@"NSValueTransformerName"]];


	[[[pasteboardHistoryTable tableColumnWithIdentifier:@"object"] dataCell] bind:@"textColor"
                                                                         toObject:[NSUserDefaultsController sharedUserDefaultsController]
                                                                      withKeyPath:@"values.QSAppearance3T"
                                                                          options:[NSDictionary dictionaryWithObject:NSUnarchiveFromDataTransformerName forKey:@"NSValueTransformerName"]];

	[[[pasteboardHistoryTable tableColumnWithIdentifier:@"sequence"] dataCell] bind:@"textColor"
                                                                           toObject:[NSUserDefaultsController sharedUserDefaultsController]
                                                                        withKeyPath:@"values.QSAppearance3T"
                                                                            options:[NSDictionary dictionaryWithObject:NSUnarchiveFromDataTransformerName forKey:@"NSValueTransformerName"]];


	[pasteboardHistoryTable setGridColor:[[NSColor blackColor] colorWithAlphaComponent:0.1]];


}


- (id)resolveProxyObject:(id)proxy {
	NSPasteboard *pboard;
	if ([[proxy identifier] isEqualToString:@"QSGeneralPasteboardProxy"]) {
		pboard = [NSPasteboard generalPasteboard];
	} else {
		pboard = [NSPasteboard pasteboardWithName:NSFindPboard];
	}
	QSObject *newObject = [QSObject objectWithPasteboard:pboard];
	return newObject;
}

- (NSArray *)typesForProxyObject:(id)proxy {
	return standardPasteboardTypes;
}

// Called when an item should be added to the clipboard history
- (void)pasteboardChanged:(NSNotification*)notif {
    QSGCDMainAsync(^{
        [self handlePasteboardChanged:notif];
    });
}

- (void)handlePasteboardChanged:(NSNotification *)notif {

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (! [defaults boolForKey:kCapturePasteboardHistory]) return;
    
    // don't add the object to the clipboard if the user's whitelisted the app
    if ([[defaults arrayForKey:@"clipboardIgnoreApps"] containsObject:[[notif object] objectForKey:@"ActiveApp"]]) {
        return;
    }

    NSInteger maxCount = [[NSUserDefaults standardUserDefaults] integerForKey:kCapturePasteboardHistoryCount];
	NSPasteboard *pboard = [[notif object] objectForKey:@"Pasteboard"];
	
	if (![pboard pasteboardItems].count) {
		// Pasteboard is empty. Password apps (e.g. 1Password) push an empty item item to the pasteboard
		return;
	}
	// get a new object from the general (system-wide) pasteboard
	QSObject *newObject = [QSObject objectWithPasteboard:pboard];

	if (!newObject) {
        return;
    }

	// run through the pasteboard history, removing unused (over the max count) objects
	while ((NSInteger)[pasteboardHistoryArray count] > maxCount) [pasteboardHistoryArray removeLastObject];
	
	// Store the most 'rich' (has more data types) version of an object on the pasteboard (e.g. a QSObject with RTF data over just plaintext data)
    NSIndexSet *existingObjectIndex = [pasteboardHistoryArray indexesOfObjectsPassingTest:^BOOL(QSObject *pasteboardObject, NSUInteger idx, BOOL *stop) {
        if([[pasteboardObject stringValue] isEqualToString:[newObject stringValue]]) {
			if ([pasteboardObject dataDictionary].count > [newObject dataDictionary].count) {
					[[newObject dataDictionary] addEntriesFromDictionary:[pasteboardObject dataDictionary]];
			}
			*stop = YES;
			return YES;
        }
        return NO;
    }];
    
	[pasteboardHistoryArray removeObjectsAtIndexes:existingObjectIndex];
    [pasteboardHistoryArray insertObject:newObject atIndex:0];

    if (!supressCapture) {
        switch (mode) {
            case QSPasteboardQueueMode:
                [pasteboardCacheArray addObject:newObject];
                break;
            case QSPasteboardStackMode:
                [pasteboardCacheArray insertObject:newObject atIndex:0];
                break;
			default:
				break;
        }
    }

    supressCapture = NO;

	id selectedObject = [self selectedObject];

    /* Safeguard against weird objects getting in here, like QSNullObject */
    if (![selectedObject respondsToSelector:@selector(stringValue)])
        selectedObject = nil;

    BOOL recievingSelection = [[selectedObject stringValue] isEqualToString:[newObject stringValue]];
    if (recievingSelection) {
        [pasteboardHistoryTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        [pasteboardHistoryTable scrollRowToVisible:0];
    } else {
        NSUInteger row = [pasteboardHistoryTable selectedRow];
        if (row>0) {
            if (row+1<[pasteboardHistoryArray count]) {
                [pasteboardHistoryTable selectRowIndexes:[NSIndexSet indexSetWithIndex:row+1] byExtendingSelection:NO];
                [pasteboardHistoryTable scrollRowToVisible:row+1];
            }
            else
                [pasteboardHistoryTable deselectRow:row];
        }
    }
    [pasteboardHistoryTable reloadData];
    if (![[NSUserDefaults standardUserDefaults] boolForKey:kDiscardPasteboardHistoryOnQuit]) {
        
        [QSLib savePasteboardHistory];
    }
}

- (IBAction)clearHistory:(id)sender {
	switch (mode) {
		case QSPasteboardHistoryMode:
			if ([pasteboardHistoryArray count]) {
				[pasteboardHistoryArray removeObjectsInRange:NSMakeRange(1, [pasteboardHistoryArray count] -1)];
				[pasteboardHistoryTable reloadData];
				[QSLib savePasteboardHistory];
			}
			break;
		case QSPasteboardStoreMode:
			[self clearStore];
			break;
		case QSPasteboardQueueMode:
		case QSPasteboardStackMode:
			[pasteboardCacheArray removeAllObjects];
		default:
			break;
	}
	[pasteboardHistoryTable reloadData];
}


- (void)deleteBackward:(id)sender {

	NSInteger index = [pasteboardHistoryTable selectedRow];
	switch (mode) {
		case QSPasteboardHistoryMode:
			if (index) {
				[pasteboardHistoryArray removeObjectAtIndex:index];
				[pasteboardHistoryTable reloadData];
                if (![[NSUserDefaults standardUserDefaults] boolForKey:kDiscardPasteboardHistoryOnQuit]) {
                    [QSLib savePasteboardHistory];
                }
			}
			break;
		case QSPasteboardStoreMode:
			[pasteboardStoreArray replaceObjectAtIndex:index withObject:[QSNullObject nullObject]];

			break;
		case QSPasteboardQueueMode:
		case QSPasteboardStackMode:

			[pasteboardCacheArray removeObjectAtIndex:index];
		default:
			break;
	}
	[pasteboardHistoryTable reloadData];

}

- (void)tableAction:(id)sender {

}
- (IBAction)hideWindow:(id)sender {
	[[self window] saveFrame];
    if (![[self window] isDocked] && [[NSUserDefaults standardUserDefaults] boolForKey:@"QSPasteboardController HideAfterPasting"]) {
		[[self window] orderOut:self];
    } else {
        [[self window] hide:self];
    }
}
- (id)selectedObject {
    NSInteger index = [pasteboardHistoryTable selectedRow];
    if (index < 0 || index >= (NSInteger)self.currentArray.count) return nil;

    return [self.currentArray objectAtIndex:index];
}

- (void)copyToClipboard:(QSObject *)obj {
    if (!asPlainText) {
        [obj putOnPasteboard:[NSPasteboard generalPasteboard]];
    } else {
        [obj putOnPasteboardAsPlainTextOnly:[NSPasteboard generalPasteboard]];
    }
}



#pragma mark Key Handling

- (void)keyDown:(NSEvent *)theEvent {
    NSString *chars = [theEvent charactersIgnoringModifiers];
    static NSArray *keys = nil;
    if (keys == nil) {
        keys = @[@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9"];
    }
    if ([keys containsObject:
         chars]) {
        // switch between human numbering and machine numbering (0/1 start) so -1 from the chars integer value
        [self pasteNumber:[chars integerValue] - 1 plainText:([theEvent modifierFlags] & NSAlternateKeyMask)];
        return;
    }
    else if ([chars characterAtIndex:0] == NSCarriageReturnCharacter || [chars characterAtIndex:0] == NSEnterCharacter) {
        [self pasteItem:self];
        return;
    }
    [self interpretKeyEvents:[NSArray arrayWithObject:theEvent]];
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent {
	//NSLog(@"%@", theEvent);
	return [pasteboardMenu performKeyEquivalent:(NSEvent *)theEvent];
	return NO;
}


- (void)insertNewline:(id)sender {
    [self pasteItem:self];
}



# pragma mark Menu Handling

- (IBAction)toggleAdjustRows:(id)sender {
	adjustRowsToFit = !adjustRowsToFit;
	if (adjustRowsToFit) [self adjustRowHeight];
	[[NSUserDefaults standardUserDefaults] setBool:adjustRowsToFit forKey:@"QSPasteboardAdjustRowHeight"];

}

- (IBAction)showPreferences:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"qs://preferences#QSPasteboardPrefPane"]];
}


- (IBAction)setMode:(id)sender {
	[self switchToMode:[sender tag]];
}
- (void)switchToMode:(NSUInteger)newMode {
	mode = newMode;
	switch (mode) {
		case QSPasteboardHistoryMode:
			[titleField setStringValue:@"Clipboard History"];
			self.currentArray = pasteboardHistoryArray;
			break;
		case QSPasteboardStoreMode:

			[titleField setStringValue:@"Clipboard Storage"];
			self.currentArray = pasteboardStoreArray;
			break;
		case QSPasteboardQueueMode:
			[titleField setStringValue:@"Clipboard Cache Old"];
			[self setCacheIsReversed:YES];
			self.currentArray = pasteboardCacheArray;
			break;
		case QSPasteboardStackMode:
			[titleField setStringValue:@"Clipboard Cache New"];
			[self setCacheIsReversed:NO];
			self.currentArray = pasteboardCacheArray;
		default:
			break;
	}
	[pasteboardHistoryTable reloadData];
}
- (void)setCacheIsReversed:(BOOL)reverse {
	if (reverse != cacheIsReversed) {
		[pasteboardCacheArray reverse];
		cacheIsReversed = reverse;
	}
}

- (BOOL)validateMenuItem:(NSMenuItem*)anItem {
	//NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	if ([anItem action] == @selector(setMode:) ) {
		[anItem setState:([anItem tag] == mode)];
		return YES;
	}
	if ([anItem action] == @selector(toggleAdjustRows:) ) {
		[anItem setState:adjustRowsToFit];
		return YES;
	}

	return YES;
}



# pragma mark Table Handling

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView {
    return [self.currentArray count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {

    if (rowIndex < 0 || rowIndex >= (NSInteger)self.currentArray.count) {
        return nil;
    }
    if ([[aTableColumn identifier] isEqualToString:@"object"])
        return [self.currentArray objectAtIndex:rowIndex];

    if ([[aTableColumn identifier] isEqualToString:@"sequence"]) {
        if (rowIndex < 9) return [NSNumber numberWithInteger:rowIndex+1];
    }
    return nil;
}
- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    //NSLog(@"setCell %d", rowIndex);
    if (rowIndex < 0 || rowIndex >= (NSInteger)self.currentArray.count) return;
    if ([[aTableColumn identifier] isEqualToString:@"object"]) {
        [aCell setRepresentedObject:[self.currentArray objectAtIndex:rowIndex]];
		[aCell setState:NSOffState];
    }
}

- (void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
	NSRect windowScreenRect =[self.window convertRectToScreen:self.window.frame];
	if (!NSPointInRect(screenPoint, windowScreenRect)) {
		// We dropped outside our window, hide ourselves
		[self hideWindow:self];
	}
}

- (BOOL)tableView:(NSTableView *)tableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
	if ([rowIndexes count] > 1) return NO;

	NSArray *draggedObjects = [self.currentArray objectsAtIndexes:rowIndexes];
	if ([draggedObjects[0] isKindOfClass:[QSNullObject class]]) return NO;

	_draggedRows = rowIndexes;

	[draggedObjects[0] putOnPasteboard:pboard];
	return YES;
}

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation {
	switch (mode) {
		case QSPasteboardHistoryMode:
			if ([info draggingSource] == tableView) return NSDragOperationNone;
			[tableView setDropRow:0 dropOperation:NSTableViewDropAbove];
			break;
		case QSPasteboardStoreMode:
			if (operation == NSTableViewDropAbove || [_draggedRows containsIndex:row]) return NSDragOperationNone;
			break;
		case QSPasteboardQueueMode:
		case QSPasteboardStackMode:
			if (operation != NSTableViewDropAbove) return NSDragOperationNone;
			break;
		default:
			break;
	}


    if ([info draggingSource] == tableView)
		return NSDragOperationMove;
	return NSDragOperationCopy;
}
- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation {

	BOOL isSelfDrag = ([info draggingSource] == tableView); // Are we currently dragging objects from our contents
	NSArray <QSObject *> *objects = nil;

	if (isSelfDrag)
		objects = [self.currentArray objectsAtIndexes:_draggedRows];
	else
		/* FIXME: What actually happens if you multi-drag something else in here ? */
		objects = @[[QSObject objectWithPasteboard:[info draggingPasteboard]]];
	switch (mode) {
		case QSPasteboardHistoryMode:
			if ([info draggingSource] != tableView) {
				for (QSObject *object in objects) {
					[object putOnPasteboard:[NSPasteboard generalPasteboard]];
				}
			}
			break;
		case QSPasteboardStoreMode:
			[pasteboardStoreArray replaceObjectAtIndex:row withObject:objects[0]];

			if (isSelfDrag)
				[pasteboardStoreArray replaceObjectAtIndex:[_draggedRows firstIndex] withObject:[QSNullObject nullObject]];
            break;
		case QSPasteboardQueueMode:
		case QSPasteboardStackMode:
			if (isSelfDrag)
				[pasteboardCacheArray moveIndex:[_draggedRows firstIndex] toIndex:row];
			else
				[pasteboardCacheArray insertObjectsFromArray:objects atIndex:row];
			break;
		default:
			break;
	}
	[pasteboardHistoryTable reloadData];
    //  NSLog(@"source %@", [info draggingSource]);

    return YES;
}


# pragma mark Window Handling

- (void)adjustRowHeight {
	CGFloat height = (NSInteger) (NSHeight([[pasteboardHistoryTable enclosingScrollView] frame])/10-2);
	height = MAX(height, 10.0);
	[[NSUserDefaults standardUserDefaults] setDouble:height forKey:@"QSPasteboardRowHeight"];
	[pasteboardHistoryTable setRowHeight:height];

}
- (void)windowDidResize:(NSNotification *)aNotification {
	NSInteger key = [[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask;

	if ((adjustRowsToFit || key) && !(adjustRowsToFit && key) )
		[self adjustRowHeight];

	//if (!adjustRowsToFit && ") ) {
	//	}
}


@end
