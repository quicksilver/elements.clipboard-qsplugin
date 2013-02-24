

#import "QSPasteboardAccessoryCell.h"



@implementation QSPasteboardAccessoryCell

- (id)initImageCell:(NSImage *)anImage{
    if (self=[super initImageCell:anImage]){
        
    }
    return self;
}

- (void)dealloc{
	[self setTextColor:nil];
	[super dealloc];	
}
- (NSColor *)textColor { return textColor; }

- (void)setTextColor:(NSColor *)newTextColor {
    [textColor release];
    textColor = [newTextColor retain];
	[[self controlView] setNeedsDisplay:YES];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView{
    
    if (![self isHighlighted]){
    NSBezierPath *roundRect=[NSBezierPath bezierPath];
    [roundRect appendBezierPathWithRoundedRectangle:NSInsetRect(cellFrame,1,1) withRadius:NSWidth(cellFrame)/4];
    [[[self textColor] colorWithAlphaComponent:0.1]set];
    [roundRect fill];
    }
    
    if ([self objectValue]){
        NSUInteger rank=[[self objectValue] unsignedIntegerValue];
        
        NSDictionary *attributes=[NSDictionary dictionaryWithObjectsAndKeys:[self textColor] ? [self textColor] : [NSColor textColor],NSForegroundColorAttributeName,[self font] ? [self font] : [NSFont systemFontOfSize:11], NSFontAttributeName,nil];
        NSString *string=[NSString stringWithFormat:@"%lu",(unsigned long)rank];
        
        NSSize textSize=[string sizeWithAttributes:attributes];
        
        NSRect drawRect=centerRectInRect(rectFromSize(textSize),cellFrame);
        [string drawInRect:drawRect withAttributes:attributes];
    }
}
@end
