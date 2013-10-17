#import "QSPasteboardMonitor.h"
#import "QSPasteboardController.h"
#import "QSPasteboardAccessoryCell.h"

@interface QSController : NSWindowController

- (QSInterfaceController *)interfaceController;

@end

@implementation QSPasteboardController

+ (void)initialize {
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
	return ;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent {
    return YES;
}

-(BOOL)acceptsFirstResponder {
    NSLog(@"accepting 1st resp");
    return YES;
}

+ (BOOL)validateMenuItem:(NSMenuItem*)anItem {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([anItem action] == @selector(showClipboards:) ) {
		[defaults boolForKey:kCapturePasteboardHistory];
	}
	return YES;
}

+ (void)showClipboardHidden:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:@"QSPasteboardHistoryIsVisible"] || [(QSDockingWindow *)[[self sharedInstance] window] isDocked]) {
		[(QSDockingWindow *)[[self sharedInstance] window] orderFrontHidden:sender];
	}
}

+ (void)showClipboard:(id)sender {
	[(QSDockingWindow *)[[self sharedInstance] window] toggle:sender];
	
}

// saves the state of the shelf window when Quicksivler goes to quit (used on next QS launch - see +loadPlugIn)
+(void)saveVisibilityState:(NSNotification *)notif {
    if ([[notif object] isEqualToString:@"QSQuicksilverWillQuitEvent"]) {
		BOOL visible = ![(QSDockingWindow *)[[self sharedInstance] window] hidden];
        [[NSUserDefaults standardUserDefaults] setBool:visible forKey:@"QSPasteboardHistoryIsVisible"];
    }
}

+ (id)sharedInstance {
    static id _sharedInstance;
    if (!_sharedInstance) _sharedInstance = [[[self class] allocWithZone:nil] init];
    return _sharedInstance;
}


- (void)clearStore {
	[pasteboardStoreArray removeAllObjects];
	for (NSInteger i = 0; i<10; i++) {
        [pasteboardStoreArray addObject:[QSNullObject nullObject]];
    };
}
- (id)init {
    if (self = [super initWithWindowNibName:@"Pasteboard" owner:self]) {
		
		pasteboardHistoryArray = nil;
		pasteboardHistoryArray = [[QSLibrarian sharedInstance] shelfNamed:@"QSPasteboardHistory"]; //[[NSMutableArray alloc] initWithCapacity:1];
		
		currentArray = pasteboardHistoryArray;
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
	[(QSDockingWindow *)[self window] show:sender];
}

- (IBAction)showStore:(id)sender {
	[self switchToMode:QSPasteboardStoreMode];
	[(QSDockingWindow *)[self window] show:sender];
}

- (IBAction)showQueue:(id)sender {
	[self switchToMode:QSPasteboardQueueMode];
	[(QSDockingWindow *)[self window] show:sender];
}

- (IBAction)showStack:(id)sender {
	[self switchToMode:QSPasteboardStackMode];
	[(QSDockingWindow *)[self window] show:sender];
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
        [pasteboardHistoryTable reloadData];
    }
}

- (void)pasteItem:(id)sender {
    //  activateFrontWindowOfApplication
    //supressCapture = YES;
    //[[NSWorkspace sharedWorkspace] activateFrontWindowOfApplication:
    //  [[NSWorkspace sharedWorkspace] activeApplication]];
    //[[NSApp keyWindow] orderOut:self];
    [(QSDockingWindow *)[self window] resignKeyWindowNow];
    asPlainText = (([[NSApp currentEvent] modifierFlags] & NSDeviceIndependentModifierFlagsMask) == NSAlternateKeyMask);
    
    //[NSApp deactivate];
	[self qsPaste:nil];
	
	[self hideWindow:sender];
    
    [[(QSController *)[NSApp delegate] interfaceController] hideWindows:self];
    
    
	// ***warning   * the clipboard should be restored
}


- (IBAction)qsPaste:(id)sender {
	switch (mode) {
		case QSPasteboardHistoryMode:
		case QSPasteboardStoreMode:
			[self copyToClipboard:[self selectedObject]];
			QSForcePaste();
			break;
		case QSPasteboardQueueMode:
		case QSPasteboardStackMode:
			if ([pasteboardCacheArray count]) {
				
				id object = (sender?[pasteboardCacheArray objectAtIndex:0] :[self selectedObject]);
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
    [pasteboardHistoryArray makeObjectsPerformSelector:@selector(loadIcon)];
    
    [(QSDockingWindow *)[self window] setAutosaveName:@"QSPasteboardHistoryWindow"]; // should use the real methods to do this
    NSCell *newCell = nil;
    
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
    
    newCell = [[QSObjectCell alloc] init];
    [[pasteboardHistoryTable tableColumnWithIdentifier: @"object"] setDataCell:newCell];
    
    newCell = [[QSPasteboardAccessoryCell alloc] init];
    
    [[pasteboardHistoryTable tableColumnWithIdentifier: @"sequence"] setDataCell:newCell];
    
    [(QSTableView *)pasteboardHistoryTable setDraggingDelegate:[self window]];
    
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
	QSObject *newObject = [QSObject objectWithPasteboard:[NSPasteboard generalPasteboard]];
	return newObject;
}

- (NSArray *)typesForProxyObject:(id)proxy {
	return standardPasteboardTypes;
}

// Called when an item should be added to the clipboard history
- (void)pasteboardChanged:(NSNotification*)notif {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (! [defaults boolForKey:kCapturePasteboardHistory]) return;
    
    // don't add the object to the clipboard if the user's whitelisted the app
    NSString *activeAppIdent = [[[NSWorkspace sharedWorkspace] activeApplication] objectForKey:@"NSApplicationBundleIdentifier"];
    if ([[defaults arrayForKey:@"clipboardIgnoreApps"] containsObject:activeAppIdent]) {
        return;
    }
    
    NSInteger maxCount = [[NSUserDefaults standardUserDefaults] integerForKey:kCapturePasteboardHistoryCount];
	// run through the pasteboard history, removing unused (over the max count) objects
	while ((NSInteger)[pasteboardHistoryArray count] >maxCount) [pasteboardHistoryArray removeLastObject];
	// get a new object from the general (system-wide) pasteboard
	QSObject *newObject = [QSObject objectWithPasteboard:[notif object]];
	
	if (newObject) {
        // some apps (e.g. 1Password and its browser extensions) copy a blank string to the clipboard to clear it.
        // Quicksilver should take this into consideration and clear the
        if ([newObject objectForType:QSTextType] && ![[newObject objectForType:QSTextType] length]) {
            [pasteboardHistoryArray removeObjectAtIndex:0];
            return;
        }
        
        //		BOOL keepOldObject = FALSE;
		// check the string value of the objects to compare (the object's aren't necessarily the same if one has more pasteboard types
		// (e.g. RTF data) than the other)
		// receiving selection decides whether an existing object on the clipboard should be 'moved up' to the 0th position
		BOOL recievingSelection = [[[self selectedObject] stringValue] isEqualToString:[newObject stringValue]];
		for(QSObject *pasteboardObject in pasteboardHistoryArray) {
			// if the object (string) is already on the pasteboard
			if([[pasteboardObject stringValue] isEqualToString:[newObject stringValue]]) {
				// Fix the object with the most types (each type is stored in the dataDictionary)
				if([[pasteboardObject dataDictionary] count] > [[newObject dataDictionary] count]) {
					//Keep the old object, it's better
                    [[newObject dataDictionary] addEntriesFromDictionary:[pasteboardObject dataDictionary]];
                    //					keepOldObject = TRUE;
				}
				[pasteboardHistoryArray removeObject:pasteboardObject];
				break;
			}
		}
#warning Fixme: writing pasteboard files to disk
        // ******* Commented out code for writing clipboard data to file. Needs to be implemented properly at some point
		// If the object's entirely new to the clipboard, we need to add some info to it
        //		if(!keepOldObject) {
        //
        //#define MAX_NAME_LENGTH 100
        //			NSString *name = [newObject name];
        //			if ([name length] > MAX_NAME_LENGTH)
        //				name = [name substringToIndex:MAX_NAME_LENGTH];
        //			//name = [NSString stringWithFormat:@"%@.%@", name,dateString];
        //
        //			// A string to the app support folder containing the clipboard data
        //			NSString *path = QSApplicationSupportSubPath(@"Data/Clipboard/", YES);
        //			path = [path stringByAppendingPathComponent:name];
        //			path = [path stringByAppendingPathExtension:@"qs"];
        //			// find a unique name (append 1, 2, 3 etc. to end of file name until unique name found)
        //			path = [path firstUnusedFilePath];
        //
        //			[newObject writeToFile:path];
        //		}
		[pasteboardHistoryArray insertObject:newObject atIndex:0];
		
		if (!supressCapture) {
			switch (mode) {
				case QSPasteboardQueueMode:
					[pasteboardCacheArray addObject:newObject];
					break;
				case QSPasteboardStackMode:
					[pasteboardCacheArray insertObject:newObject atIndex:0];
					break;
			}
		}
		
		supressCapture = NO;
		
        
		[pasteboardHistoryTable reloadData];
        
        if (recievingSelection) {
            [pasteboardHistoryTable selectRowIndexes:0 byExtendingSelection:NO];
        } else {
            NSUInteger row = [pasteboardHistoryTable selectedRow];
            if (row>0) {
                if (row+1<[pasteboardHistoryArray count])
                    [pasteboardHistoryTable selectRowIndexes:[NSIndexSet indexSetWithIndex:row+1] byExtendingSelection:NO];
                else
                    [pasteboardHistoryTable deselectRow:row];
            }
        }
        
		
		
        //[pasteboardItemView setObjectValue:[pasteboardHistoryArray objectAtIndex:0]];
        
        [QSLib savePasteboardHistory];
    } else {
		//  if (VERBOSE) NSLog(@"Unable to create object");
    }
    // [[pasteboardProxyWindow contentView] setObjectValue:[pasteboardHistoryArray objectAtIndex:0]];
    
    //    [self updatePasteboardMatrix];
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
				[QSLib savePasteboardHistory];
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
	[(QSDockingWindow *)[self window] saveFrame];
    if (![(QSDockingWindow *)[self window] isDocked] && [[NSUserDefaults standardUserDefaults] boolForKey:@"QSPasteboardController HideAfterPasting"]) {
		[[self window] orderOut:self];
    } else {
        [(QSDockingWindow *)[self window] hide:self];
    }
}
- (id)selectedObject {
    NSInteger index = [pasteboardHistoryTable selectedRow];
    if (index<0) return nil;
    if (![currentArray count]) return nil;
    return [currentArray objectAtIndex:index];
}
- (void)copyToClipboard:(QSObject *)obj {
    if (!asPlainText) {
        [obj putOnPasteboard:[NSPasteboard generalPasteboard] includeDataForTypes:nil];
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
			currentArray = pasteboardHistoryArray;
			break;
		case QSPasteboardStoreMode:
			
			[titleField setStringValue:@"Clipboard Storage"];
			currentArray = pasteboardStoreArray;
			break;
		case QSPasteboardQueueMode:
			[titleField setStringValue:@"Clipboard Cache Old"];
			[self setCacheIsReversed:YES];
			currentArray = pasteboardCacheArray;
			break;
		case QSPasteboardStackMode:
			[titleField setStringValue:@"Clipboard Cache New"];
			[self setCacheIsReversed:NO];
			currentArray = pasteboardCacheArray;
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
		[anItem setState:[anItem tag] == (NSInteger)mode];
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
    return [currentArray count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    //  rowIndex++;
	if (rowIndex>((NSInteger)[currentArray count] -1) ) {
		return nil;
	}
    if ([[aTableColumn identifier] isEqualToString:@"object"] && (NSInteger)[currentArray count] >rowIndex)
        return [currentArray objectAtIndex:rowIndex];
    if ([[aTableColumn identifier] isEqualToString:@"sequence"]) {
        if (rowIndex<9) return [NSNumber numberWithInteger:rowIndex+1];
    }
	
	//	if ([[aTableColumn identifier] isEqualToString:@"source"]) {
	//        NSString *source = [[pasteboardHistoryArray objectAtIndex:rowIndex] objectForKey:kQSObjectSource];
	//        if (!source) source = @"Unknown";
	//        return source;
	//    }
	//    if ([[aTableColumn identifier] isEqualToString:@"name"])
	//        return [[pasteboardHistoryArray objectAtIndex:rowIndex] name];
	//    if ([[aTableColumn identifier] isEqualToString:@"date"])
	//        return [NSDate dateWithTimeIntervalSinceReferenceDate:[[[pasteboardHistoryArray objectAtIndex:rowIndex] objectForKey:kQSObjectSource] floatValue]];
	
    return nil;
}
- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    //NSLog(@"setCell %d", rowIndex);
    if (rowIndex >= (NSInteger)([currentArray count] -1) ) return;
    if ([[aTableColumn identifier] isEqualToString:@"object"]) {
        [aCell setRepresentedObject:[currentArray objectAtIndex:rowIndex]];
		[aCell setState:NSOffState];
    }
}
static NSInteger _draggedRow = -1;
- (BOOL)tableView:(NSTableView *)tv writeRows:(NSArray*)rows toPasteboard:(NSPasteboard*)pboard {
	
	_draggedRow = [[rows objectAtIndex:0] integerValue];
	
	if ([[currentArray objectAtIndex:_draggedRow] isKindOfClass:[QSNullObject class]]) return NO;
    [[currentArray objectAtIndex:[[rows objectAtIndex:0] integerValue]]putOnPasteboard:pboard includeDataForTypes:nil];
    return YES;
}
- (NSDragOperation) tableView:(NSTableView *)tableView validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation {
	switch (mode) {
		case QSPasteboardHistoryMode:
			if ([info draggingSource] == tableView) return NSDragOperationNone;
			[tableView setDropRow:0 dropOperation:NSTableViewDropAbove];
			break;
		case QSPasteboardStoreMode:
			if (operation == NSTableViewDropAbove || row == _draggedRow) return NSDragOperationNone;
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
	
	QSObject *object = nil;
	
	if ([info draggingSource] == tableView)
		object = [currentArray objectAtIndex:_draggedRow];
	else
		object = [QSObject objectWithPasteboard:[info draggingPasteboard]];
	switch (mode) {
		case QSPasteboardHistoryMode:
			if ([info draggingSource] != tableView)
				[object putOnPasteboard:[NSPasteboard generalPasteboard]];
			break;
		case QSPasteboardStoreMode:
			
			[pasteboardStoreArray replaceObjectAtIndex:row withObject:object];
			
			if ([info draggingSource] == tableView)
				[pasteboardStoreArray replaceObjectAtIndex:_draggedRow withObject:[QSNullObject nullObject]];
            break;
		case QSPasteboardQueueMode:
		case QSPasteboardStackMode:
			if ([info draggingSource] == tableView)
				[pasteboardCacheArray moveIndex:_draggedRow toIndex:row];
			else
				[pasteboardCacheArray insertObject:object atIndex:row];
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
