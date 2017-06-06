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

#import "MDCMaskedPresentationController.h"

#import <Transitioning/Transitioning.h>
#import "MDMAnimator.h"

#import "MDCMaskedTransitionMotionForContext.h"

@interface MDCMaskedPresentationController () <MDMTransition>
@end

@implementation MDCMaskedPresentationController {
  CGRect (^_calculateFrameOfPresentedView)(UIPresentationController *);
}

- (instancetype)initWithPresentedViewController:(UIViewController *)presentedViewController
                       presentingViewController:(UIViewController *)presentingViewController
                  calculateFrameOfPresentedView:(CGRect (^)(UIPresentationController *))calculateFrameOfPresentedView {
  self = [super initWithPresentedViewController:presentedViewController
                       presentingViewController:presentingViewController];
  if (self) {
    _calculateFrameOfPresentedView = calculateFrameOfPresentedView;
  }
  return self;
}

- (CGRect)frameOfPresentedViewInContainerView {
  return _calculateFrameOfPresentedView(self);
}

- (void)dismissalTransitionWillBegin {
  if (!self.presentedViewController.mdm_transitionController.activeTransition) {
    self.sourceView.hidden = false;

    [self.presentedViewController.transitionCoordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
      self.scrimView.alpha = 0;
    } completion:nil];
  }
}

- (void)dismissalTransitionDidEnd:(BOOL)completed {
  if (completed) {
    [self.scrimView removeFromSuperview];
    self.scrimView = nil;

    self.sourceView.hidden = false;
    self.sourceView = nil;
  } else {
    self.scrimView.alpha = 1;
    self.sourceView.hidden = true;
  }
}

- (void)startWithContext:(NSObject<MDMTransitionContext> *)context {
  MDCMaskedTransitionMotionSpec spec = motionForContext(context);

  MDMAnimator *animator = [[MDMAnimator alloc] init];
  animator.shouldReverseValues = context.direction == MDMTransitionDirectionBackward;

  MDCMaskedTransitionMotionTiming motion = (context.direction == MDMTransitionDirectionForward) ? spec.expansion : spec.collapse;

  [animator addAnimationWithTiming:motion.scrimFade
                           toLayer:self.scrimView.layer
                        withValues:@[ @0, @1 ]
                           keyPath:@"opacity"];
}

@end
