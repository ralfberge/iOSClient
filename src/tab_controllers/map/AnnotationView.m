//
//  AnnotationView.m
//  ARIS
//
//  Created by Brian Deith on 8/11/09.
//  Copyright 2009 Brian Deith. All rights reserved.
//

#import "AnnotationView.h"
#import "UIColor+ARISColors.h"
#import "Media.h"
#import "Location.h"

@interface AnnotationView() <ARISMediaViewDelegate>
@end

@implementation AnnotationView

@synthesize titleRect;
@synthesize subtitleRect;
@synthesize contentRect;
@synthesize titleFont;
@synthesize subtitleFont;
@synthesize icon;
@synthesize showTitle;
@synthesize iconView;
@synthesize shouldWiggle;
@synthesize totalWiggleOffsetFromOriginalPosition;
@synthesize incrementalWiggleOffset;
@synthesize xOnSinWave;

- (id)initWithAnnotation:(id<MKAnnotation>)location reuseIdentifier:(NSString *)reuseIdentifier
{
	if (self = [super initWithAnnotation:location reuseIdentifier:reuseIdentifier])
    {
        Location *loc = (Location *)location;
        
        loc.title = nil;
        loc.subtitle = nil;
        if(![loc.name isEqualToString:@""])
            loc.title = loc.name;
        if(loc.gameObject.type == GameObjectItem && loc.qty > 1 && loc.title)
            loc.subtitle = [NSString stringWithFormat:@"x %d",loc.qty];
        
        self.titleFont    = [UIFont fontWithName:@"HelveticaNeue-Light" size:18];
        self.subtitleFont = [UIFont fontWithName:@"HelveticaNeue-Light" size:12];
        
        self.showTitle = (loc.showTitle && loc.title) ? YES : NO;
        self.shouldWiggle = loc.wiggle;
        self.totalWiggleOffsetFromOriginalPosition = 0;
        self.incrementalWiggleOffset = 0;
        self.xOnSinWave = 0;

        CGRect imageViewFrame;
        
        if(self.showTitle) //TODO || annotation.kind == NearbyObjectPlayer)
        {
            //Find width of annotation
            CGSize titleSize    = [loc.title    sizeWithFont:titleFont];
            CGSize subtitleSize = [loc.subtitle sizeWithFont:subtitleFont];
            int maxWidth = titleSize.width > subtitleSize.width ? titleSize.width : subtitleSize.width;
            if(maxWidth > ANNOTATION_MAX_WIDTH) maxWidth = ANNOTATION_MAX_WIDTH;
            
            titleRect = CGRectMake(0, 0, maxWidth, titleSize.height);
            if(loc.subtitle)
                subtitleRect = CGRectMake(0, titleRect.origin.y+titleRect.size.height, maxWidth, subtitleSize.height);
            else
                subtitleRect = CGRectMake(0,0,0,0);
            
            contentRect=CGRectUnion(titleRect, subtitleRect);
            contentRect.size.width += ANNOTATION_PADDING*2;
            contentRect.size.height += ANNOTATION_PADDING*2;
            
            titleRect=CGRectOffset(titleRect, ANNOTATION_PADDING, ANNOTATION_PADDING);
            if(loc.subtitle) subtitleRect=CGRectOffset(subtitleRect, ANNOTATION_PADDING, ANNOTATION_PADDING);
            
            imageViewFrame = CGRectMake((contentRect.size.width/2)-(IMAGE_WIDTH/2), 
                                        contentRect.size.height+POINTER_LENGTH, 
                                        IMAGE_WIDTH, 
                                        IMAGE_HEIGHT);
            self.centerOffset = CGPointMake(0, ((contentRect.size.height+POINTER_LENGTH+IMAGE_HEIGHT)/-2)+(IMAGE_HEIGHT/2));
        }
        else
        {
            contentRect=CGRectMake(0,0,0,0);
            imageViewFrame = CGRectMake(0, 0, IMAGE_WIDTH, IMAGE_HEIGHT);
            //self.centerOffset = CGPointMake(IMAGE_WIDTH/-2.0, IMAGE_HEIGHT/-2.0);
        }
        
        [self setFrame: CGRectUnion(contentRect, imageViewFrame)];

        if(loc.gameObject.iconMediaId != 0)
            self.iconView = [[ARISMediaView alloc] initWithFrame:imageViewFrame media:[[AppModel sharedAppModel] mediaForMediaId:loc.gameObject.iconMediaId ofType:@"PHOTO"] mode:ARISMediaDisplayModeAspectFit delegate:self];
        else
            self.iconView = [[ARISMediaView alloc] initWithFrame:imageViewFrame image:[UIImage imageNamed:@"logo.png"] mode:ARISMediaDisplayModeAspectFit delegate:self];
        
        [self addSubview:self.iconView];
        
        self.opaque = NO; 
    }
    return self;
}

- (void) ARISMediaViewUpdated:(ARISMediaView *)amv
{
    
}

- (void)drawRect:(CGRect)rect {
    if (self.showTitle) {
        CGMutablePathRef calloutPath = CGPathCreateMutable();
        CGPoint pointerPoint = CGPointMake(self.contentRect.origin.x + 0.5 * self.contentRect.size.width,  self.contentRect.origin.y + self.contentRect.size.height + POINTER_LENGTH);
        CGFloat radius = 7.0;
        CGPathMoveToPoint(calloutPath, NULL, CGRectGetMinX(self.contentRect) + radius, CGRectGetMinY(self.contentRect));
        CGPathAddArc(calloutPath, NULL, CGRectGetMaxX(self.contentRect) - radius, CGRectGetMinY(self.contentRect) + radius, radius, 3 * M_PI / 2, 0, 0);
        CGPathAddArc(calloutPath, NULL, CGRectGetMaxX(self.contentRect) - radius, CGRectGetMaxY(self.contentRect) - radius, radius, 0, M_PI / 2, 0);
        
        CGPathAddLineToPoint(calloutPath, NULL, pointerPoint.x + 10.0, CGRectGetMaxY(self.contentRect));
        CGPathAddLineToPoint(calloutPath, NULL, pointerPoint.x, pointerPoint.y);
        CGPathAddLineToPoint(calloutPath, NULL, pointerPoint.x - 10.0,  CGRectGetMaxY(self.contentRect));
        
        CGPathAddArc(calloutPath, NULL, CGRectGetMinX(self.contentRect) + radius, CGRectGetMaxY(self.contentRect) - radius, radius, M_PI / 2, M_PI, 0);
        CGPathAddArc(calloutPath, NULL, CGRectGetMinX(self.contentRect) + radius, CGRectGetMinY(self.contentRect) + radius, radius, M_PI, 3 * M_PI / 2, 0);	
        CGPathCloseSubpath(calloutPath);
        
        CGContextAddPath(UIGraphicsGetCurrentContext(), calloutPath);
        [[UIColor ARISColorTranslucentBlack] set];
        CGContextFillPath(UIGraphicsGetCurrentContext());
        [[UIColor ARISColorWhite] set];
        [self.annotation.title drawInRect:self.titleRect withFont:self.titleFont lineBreakMode:NSLineBreakByTruncatingMiddle alignment:NSTextAlignmentCenter];
        [self.annotation.subtitle drawInRect:self.subtitleRect withFont:self.subtitleFont lineBreakMode:NSLineBreakByTruncatingMiddle alignment:NSTextAlignmentCenter];
        CGContextAddPath(UIGraphicsGetCurrentContext(), calloutPath);
        CGContextStrokePath(UIGraphicsGetCurrentContext());
    }
    
    if(self.shouldWiggle)
    {
        self.xOnSinWave += WIGGLE_SPEED;
        float oldTotal = totalWiggleOffsetFromOriginalPosition;
        self.totalWiggleOffsetFromOriginalPosition = sin(xOnSinWave) * WIGGLE_DISTANCE;
        self.incrementalWiggleOffset = totalWiggleOffsetFromOriginalPosition-oldTotal;
        self.iconView.frame = CGRectOffset(self.iconView.frame, 0.0f, self.incrementalWiggleOffset);
        [self performSelector:@selector(setNeedsDisplay) withObject:nil afterDelay:WIGGLE_FRAMELENGTH];
    }
}	

@end
