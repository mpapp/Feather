//
//  NSView+MPExtensions.h
//  Manuscripts
//
//  Created by Matias Piipari on 21/12/2012.
//  Copyright (c) 2012 Manuscripts.app Limited. All rights reserved.
//

#import <Cocoa/Cocoa.h>


extern inline id MPAnimatorOrView(NSView *view, BOOL animate);
extern inline id MPAnimatorOrConstraint(NSLayoutConstraint *constraint, BOOL animate);

extern inline NSInteger MPBooleanToState(BOOL b);
extern inline BOOL MPStateToBoolean(NSInteger state);


@interface NSView (MPExtensions)

- (void)addEdgeConstraint:(NSLayoutAttribute)edge subview:(NSView *)subview;
- (void)addEdgeConstraint:(NSLayoutAttribute)edge constantOffset:(CGFloat)value subview:(NSView *)subview;

- (void)addSubviewConstrainedToSuperViewEdges:(NSView *)aView;
- (void)addSubviewConstrainedToSuperViewEdges:(NSView *)aView
                                    topOffset:(CGFloat)topOffset
                                  rightOffset:(CGFloat)rightOffset
                                 bottomOffset:(CGFloat)bottomOffset
                                   leftOffset:(CGFloat)leftOffset;

- (void)replaceSubviewsWithSubviewConstrainedToSuperViewEdges:(NSView *)subview;

- (BOOL) hasSubview:(NSView *)subview;

- (NSLayoutConstraint *) heightConstraint;
- (NSLayoutConstraint *) horizontalConstraintWithView:(NSView *)anotherView;
- (NSLayoutConstraint *) verticalConstraintWithView:(NSView *)anotherView;
- (NSLayoutConstraint *) widthConstraint;

- (void) hideWithZeroWidth;
- (void) hideWithZeroWidthAndAnimate:(BOOL)animate;
+ (void) hideViews:(NSArray *)views withZeroWidthAndAnimate:(BOOL)animate;

- (void) hideWithZeroHeight;
- (void) hideWithZeroHeightAndAnimate:(BOOL)animate;
+ (void) hideViews:(NSArray *)views withZeroHeightAndAnimate:(BOOL)animate;

- (void) showWithWidth:(CGFloat)width;
- (void) showWithWidth:(CGFloat)width andAnimate:(BOOL)animate;

- (void) showWithHeight:(CGFloat)height;
- (void) showWithHeight:(CGFloat)height andAnimate:(BOOL)animate;

- (NSString *)superviewPathString;
- (NSArray *)superviewPath;

@end
