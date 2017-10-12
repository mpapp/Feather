//
//  NSView+MPExtensions.h
//  Manuscripts
//
//  Created by Matias Piipari on 21/12/2012.
//  Copyright (c) 2015 Manuscripts.app Limited. All rights reserved.
//

#import <Cocoa/Cocoa.h>


extern inline id _Nonnull MPAnimatorOrView(NSView *_Nonnull view, BOOL animate);
extern inline id _Nonnull MPAnimatorOrConstraint(NSLayoutConstraint *_Nonnull constraint, BOOL animate);

extern NSControlStateValue MPBooleanToState(BOOL b);
extern BOOL MPStateToBoolean(NSControlStateValue state);

@interface NSView (MPExtensions)

- (nonnull NSLayoutConstraint *)addEdgeConstraint:(NSLayoutAttribute)edge
                                          subview:(nonnull NSView *)subview;
- (nonnull NSLayoutConstraint *)addEdgeConstraint:(NSLayoutAttribute)edge
                                   constantOffset:(CGFloat)value
                                          subview:(nonnull NSView *)subview;

- (void)addSubviewConstrainedToSuperViewEdges:(nonnull NSView *)aView;
- (void)addSubviewConstrainedToSuperViewEdges:(nonnull NSView *)aView
                                    topOffset:(CGFloat)topOffset
                                  rightOffset:(CGFloat)rightOffset
                                 bottomOffset:(CGFloat)bottomOffset
                                   leftOffset:(CGFloat)leftOffset;

- (void)replaceSubviewsWithSubviewConstrainedToSuperViewEdges:(nonnull NSView *)subview;

- (BOOL)hasSubview:(nonnull NSView *)subview;

- (nullable NSLayoutConstraint *)heightConstraint;
- (nullable NSLayoutConstraint *)horizontalConstraintWithView:(nonnull NSView *)anotherView;
- (nullable NSLayoutConstraint *)verticalConstraintWithView:(nonnull NSView *)anotherView;
- (nullable NSLayoutConstraint *)widthConstraint;

- (void)hideWithZeroWidth;
- (void)hideWithZeroWidthAndAnimate:(BOOL)animate;
+ (void)hideViews:(nonnull NSArray<NSView *> *)views withZeroWidthAndAnimate:(BOOL)animate;

- (void)hideWithZeroHeight;
- (void)hideWithZeroHeightAndAnimate:(BOOL)animate;
+ (void)hideViews:(nonnull NSArray<NSView *> *)views withZeroHeightAndAnimate:(BOOL)animate;

- (void)showWithWidth:(CGFloat)width;
- (void)showWithWidth:(CGFloat)width andAnimate:(BOOL)animate;

- (void)showWithHeight:(CGFloat)height;
- (void)showWithHeight:(CGFloat)height andAnimate:(BOOL)animate;

- (nonnull NSString *)superviewPathString;
- (nonnull NSArray *)superviewPath;

- (nonnull NSData *)PDFDataForRect:(CGRect)rect;

@end
