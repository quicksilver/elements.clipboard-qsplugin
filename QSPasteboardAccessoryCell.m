

#import "QSPasteboardAccessoryCell.h"



@implementation QSPasteboardAccessoryCell

@synthesize textColor = _textColor;

- (id)initImageCell:(NSImage *)anImage{
    if (self=[super initImageCell:anImage]){
        
    }
    return self;
}

- (void)dealloc{
	[self setTextColor:nil];
}

- (NSColor *)textColor {
    @synchronized(self) {
        return _textColor;
    }
}

- (void)setTextColor:(NSColor *)newTextColor {
    @synchronized(self) {
        _textColor = newTextColor;
        [[self controlView] setNeedsDisplay:YES];
    }
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView{
    
    NSBezierPath *roundRect=[NSBezierPath bezierPath];
    [roundRect appendBezierPathWithRoundedRectangle:NSInsetRect(cellFrame,1,1) withRadius:NSWidth(cellFrame)/4];
    [[[self textColor] colorWithAlphaComponent:0.1] set];
    [roundRect fill];
    
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
