/*
 Copyright 2017-present the Material Components for iOS authors. All Rights Reserved.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "MDCMaskedTransition.h"

#import "MDMMotionTiming.h"
#import "MDMTransitionAnimator.h"

#import "MDCMaskedPresentationController.h"
#import "MDCMaskedTransitionMotionForContext.h"
#import "MDCMaskedTransitionMotionSpec.h"

// Math utilities

static CGPoint centerOfFrame(CGRect frame) {
  return CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
}

static CGPoint anchorPointFromPosition(CGPoint position, CGRect bounds) {
  return CGPointMake(position.x / bounds.size.width, position.y / bounds.size.height);
}

static CGRect frameCenteredAround(CGPoint position, CGSize size) {
  return CGRectMake(position.x - size.width / 2,
                    position.y - size.height / 2,
                    size.width,
                    size.height);
}

static CGFloat lengthOfVector(CGVector vector) {
  return (CGFloat)sqrt(vector.dx * vector.dx + vector.dy * vector.dy);
}

@interface MDCMaskedTransition () <MDMTransitionWithPresentation, MDMTransitionWithFallback>
@end

@implementation MDCMaskedTransition {
  UIView *_sourceView;
  MDCMaskedPresentationController *_presentationController;
  BOOL _shouldSlideWhenCollapsed;
}

- (instancetype)initWithSourceView:(UIView *)sourceView {
  self = [super init];
  if (self) {
    _sourceView = sourceView;
  }
  return self;
}

- (id<MDMTransition>)fallbackTransitionWithContext:(id<MDMTransitionContext>)context {
  return _shouldSlideWhenCollapsed ? nil : self;
}

#pragma mark - MDMTransitionWithPresentation

- (UIModalPresentationStyle)defaultModalPresentationStyle {
  if (_calculateFrameOfPresentedView != nil) {
    return UIModalPresentationCustom;
  }
  return UIModalPresentationFullScreen;
}

- (UIPresentationController *)presentationControllerForPresentedViewController:(UIViewController *)presented
                                                      presentingViewController:(UIViewController *)presenting
                                                          sourceViewController:(UIViewController *)source {
  _presentationController =
      [[MDCMaskedPresentationController alloc] initWithPresentedViewController:presented
                                                      presentingViewController:presenting
                                                 calculateFrameOfPresentedView:_calculateFrameOfPresentedView];
  return _presentationController;
}

- (void)startWithContext:(NSObject<MDMTransitionContext> *)context {
  // TODO(featherless): This router should be used to fall back to a system slide animation when
  // there is no reverse motion.
  MDCMaskedTransitionMotionSpec spec = motionForContext(context);
  if (context.direction == MDMTransitionDirectionForward) {
    _shouldSlideWhenCollapsed = spec.shouldSlideWhenCollapsed;
  }

  MDMTransitionAnimator *animator = [[MDMTransitionAnimator alloc] init];
  animator.shouldReverseValues = context.direction == MDMTransitionDirectionBackward;

  // # Caching original state

  // We're going to reparent the fore view, so keep this information for later.
  UIView *originalSuperview = context.foreViewController.view.superview;
  const CGRect originalFrame = context.foreViewController.view.frame;

  // # Scrim and presentation controller configuration

  UIView *scrimView;
  if (!_presentationController.scrimView) {
    scrimView = [[UIView alloc] initWithFrame:context.containerView.bounds];
    scrimView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.3];
    [context.containerView addSubview:scrimView];

    _presentationController.scrimView = scrimView;

  } else {
    scrimView = _presentationController.scrimView;
  }

  // The presentation controller, if available, will decide when to make the source view visible
  // again.
  _presentationController.sourceView = _sourceView;

  // # Reparent the fore view into a masked view

  // We want to keep the fore view at the sameposition on screen, so we
  //
  // 1. steal the fore view's frame,
  // 2. zero out the fore view's origin, and then,
  // 3. on completion, reset the fore view's frame.
  //
  UIView *maskedView = [[UIView alloc] initWithFrame:context.foreViewController.view.frame];
  {
    CGRect reparentedFrame = context.foreViewController.view.frame;
    reparentedFrame.origin = CGPointZero;
    context.foreViewController.view.frame = reparentedFrame;
  }
  [context.containerView addSubview:maskedView];

  // # Flood fill view

  UIView *floodFillView = [[UIView alloc] initWithFrame:context.foreViewController.view.bounds];
  floodFillView.backgroundColor = _sourceView.backgroundColor;
  // TODO(featherless): Explore options for configuring the flood fill behavior.

  // TODO(featherless): Profile whether it's more performant to fade the flood fill out or to
  // fade the fore view in (what we're currently doing).
  [maskedView addSubview:floodFillView];
  [maskedView addSubview:context.foreViewController.view];

  // # Frame calculations

  // All frames are assumed to be relative to the container view unless named otherwise.

  const CGRect initialSourceFrame = [_sourceView convertRect:_sourceView.bounds
                                                      toView:context.containerView];
  const CGRect finalMaskedFrame = originalFrame;
  CGRect initialMaskedFrame;
  CGPoint corner;
  const CGPoint initialSourceCenter = centerOfFrame(initialSourceFrame);
  if (spec.isCentered) {
    initialMaskedFrame = frameCenteredAround(initialSourceCenter, originalFrame.size);
    // Bottom right
    corner = CGPointMake(CGRectGetMaxX(initialMaskedFrame), CGRectGetMaxY(initialMaskedFrame));

  } else {
    initialMaskedFrame = CGRectMake(context.containerView.bounds.origin.x,
                                    initialSourceFrame.origin.y - 20,
                                    originalFrame.size.width,
                                    originalFrame.size.height);
    if (CGRectGetMidX(initialSourceFrame) < CGRectGetMidX(initialMaskedFrame)) {
      // Middle-right
      corner = CGPointMake(CGRectGetMaxX(initialMaskedFrame), CGRectGetMidY(initialMaskedFrame));
    } else {
      // Middle-left
      corner = CGPointMake(CGRectGetMinX(initialMaskedFrame), CGRectGetMidY(initialMaskedFrame));
    }
  }

  maskedView.frame = initialMaskedFrame;
  const CGRect initialSourceFrameInMask = [maskedView convertRect:initialSourceFrame
                                                         fromView:context.containerView];

  // # Scale calculations

  const CGFloat initialRadius = _sourceView.bounds.size.width / 2;
  const CGFloat finalRadius = lengthOfVector(CGVectorMake(initialSourceCenter.x - corner.x,
                                                          initialSourceCenter.y - corner.y));
  const CGFloat finalScale = finalRadius / initialRadius;

  // # Preparing the mask

  CAShapeLayer *shapeLayer = [[CAShapeLayer alloc] init];
  {
    // Ensures that we transform from the center of the source view's frame.
    shapeLayer.anchorPoint = anchorPointFromPosition(centerOfFrame(initialSourceFrameInMask),
                                                     maskedView.layer.bounds);
    shapeLayer.frame = maskedView.layer.bounds;
    shapeLayer.path = [[UIBezierPath bezierPathWithOvalInRect:initialSourceFrameInMask] CGPath];
  }
  maskedView.layer.mask = shapeLayer;

  // Our source view is always hidden during the transition.

  _sourceView.hidden = true;

  // # Begin adding animations.

  [CATransaction begin];
  [CATransaction setCompletionBlock:^{
    context.foreViewController.view.frame = originalFrame;

    [originalSuperview addSubview:context.foreViewController.view];

    [maskedView removeFromSuperview];

    // No presentation controller means we need to undo any changes we made to the view hierarchy.
    if (!_presentationController) {
      [scrimView removeFromSuperview];
      _sourceView.hidden = false;
    }

    [context transitionDidEnd]; // Hand off back to UIKit
  }];

  MDCMaskedTransitionMotionTiming motion = (context.direction == MDMTransitionDirectionForward) ? spec.expansion : spec.collapse;

  [animator addAnimationWithTiming:motion.contentFade
                           toLayer:context.foreViewController.view.layer
                        withValues:@[ @0, @1 ]
                           keyPath:@"opacity"];

  // Color transformation
  {
    UIColor *initialColor = floodFillView.backgroundColor;
    if (!initialColor) {
      initialColor = [UIColor clearColor];
    }
    UIColor *finalColor = context.foreViewController.view.backgroundColor;
    if (!finalColor) {
      finalColor = [UIColor whiteColor];
    }
    [animator addAnimationWithTiming:motion.floodBackgroundColor
                             toLayer:floodFillView.layer
                          withValues:@[ initialColor, finalColor ]
                             keyPath:@"backgroundColor"];
  }

  // Mask transformation
  {
    [CATransaction begin];
    if (context.direction == MDMTransitionDirectionForward) {
      [CATransaction setCompletionBlock:^{
        // Upon completion of the animation we want all of the content to be visible, so we jump
        // to a full bounds mask.
        shapeLayer.transform = CATransform3DIdentity;
        shapeLayer.path = [[UIBezierPath bezierPathWithRect:context.foreViewController.view.bounds]
                           CGPath];
      }];
    }
    [animator addAnimationWithTiming:motion.maskTransformation
                             toLayer:shapeLayer
                          withValues:@[ @1, @(finalScale) ]
                             keyPath:@"transform.scale.xy"];
    [CATransaction commit];
  }

  [animator addAnimationWithTiming:motion.horizontalMovement
                           toLayer:maskedView.layer
                        withValues:@[ @(CGRectGetMidX(initialMaskedFrame)),
                                      @(CGRectGetMidX(finalMaskedFrame)) ]
                           keyPath:@"position.x"];

  [animator addAnimationWithTiming:motion.verticalMovement
                           toLayer:maskedView.layer
                        withValues:@[ @(CGRectGetMidY(initialMaskedFrame)),
                                      @(CGRectGetMidY(finalMaskedFrame)) ]
                           keyPath:@"position.y"];
 
  [CATransaction commit];
}

@end
