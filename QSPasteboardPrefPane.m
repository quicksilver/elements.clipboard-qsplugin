

#import "QSPasteboardPrefPane.h"


@implementation QSPasteboardPrefPane
- (id)init {
    self = [super initWithBundle:[NSBundle bundleForClass:[QSPasteboardPrefPane class]]];
    if (self) {
    }
    return self;
}

- (NSImage *) icon{
	return [[NSImage alloc]initByReferencingFile:[[NSBundle bundleForClass:[QSPasteboardPrefPane class]]pathForImageResource:@"Clipboard"]];
}
- (NSString *) mainNibName{
return @"QSPasteboardPrefPane";
}

#pragma mark Token Field delegate methods

- (NSString *)tokenField:(NSTokenField *)tokenField editingStringForRepresentedObject:(id)representedObject {
	NSString *path = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:representedObject];
	return [[path lastPathComponent] stringByDeletingPathExtension];
}

// The method called when the token field (e.g. the 'scope' field completes/creates a new token
- (NSString *)tokenField:(NSTokenField *)tokenField displayStringForRepresentedObject:(id)representedObject {
	NSString *path = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:representedObject];
	return [[path lastPathComponent] stringByDeletingPathExtension];
}

// The method called to find a representation for the entered string in the token field
- (id)tokenField:(NSTokenField *)tokenField representedObjectForEditingString:(NSString *)editingString {
	NSString *path = [[NSWorkspace sharedWorkspace] fullPathForApplication:editingString];
    return [[NSBundle bundleWithPath:path] bundleIdentifier];
}
- (NSTokenStyle) tokenField:(NSTokenField *)tokenField styleForRepresentedObject:(id)representedObject {
    
	if ([representedObject hasPrefix:@"."]) return NSPlainTextTokenStyle;
	return NSRoundedTokenStyle;
}
- (BOOL)tokenField:(NSTokenField *)tokenField hasMenuForRepresentedObject:(id)representedObject {
	//if ([representedObject hasPrefix:@"'"] || [representedObject hasPrefix:@"."]) return NO;
	return NO;
}


@end
