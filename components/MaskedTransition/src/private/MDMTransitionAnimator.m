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

#import "MDMTransitionAnimator.h"

#if TARGET_IPHONE_SIMULATOR
UIKIT_EXTERN float UIAnimationDragCoefficient(void); // UIKit private drag coefficient.
#endif

static CGFloat simulatorAnimationDragCoefficient(void) {
#if TARGET_IPHONE_SIMULATOR
  return UIAnimationDragCoefficient();
#else
  return 1.0;
#endif
}

static CAMediaTimingFunction* timingFunctionWithControlPoints(CGFloat controlPoints[4]) {
  return [CAMediaTimingFunction functionWithControlPoints:(float)controlPoints[0]
                                                         :(float)controlPoints[1]
                                                         :(float)controlPoints[2]
                                                         :(float)controlPoints[3]];
}

static NSArray* coerceUIKitValuesToCoreAnimationValues(NSArray *values) {
  if ([[values firstObject] isKindOfClass:[UIColor class]]) {
    NSMutableArray *convertedArray = [NSMutableArray arrayWithCapacity:values.count];
    for (UIColor *color in values) {
      [convertedArray addObject:(id)color.CGColor];
    }
    values = convertedArray;

  } else if ([[values firstObject] isKindOfClass:[UIBezierPath class]]) {
    NSMutableArray *convertedArray = [NSMutableArray arrayWithCapacity:values.count];
    for (UIBezierPath *bezierPath in values) {
      [convertedArray addObject:(id)bezierPath.CGPath];
    }
    values = convertedArray;
  }
  return values;
}

@implementation MDMTransitionAnimator

- (void)addAnimationWithTiming:(MDMMotionTiming)timing
                       toLayer:(CALayer *)layer
                    withValues:(NSArray *)values
                       keyPath:(NSString *)keyPath {
  if (timing.duration == 0) {
    return;
  }

  if (_shouldReverseValues) {
    values = [[values reverseObjectEnumerator] allObjects];
  }

  values = coerceUIKitValuesToCoreAnimationValues(values);

  CABasicAnimation *animation;
  switch (timing.curve.type) {
    case MDMMotionCurveTypeInstant:
      animation = nil;
      break;

    case MDMMotionCurveTypeDefault:
    case MDMMotionCurveTypeBezier:
      animation = [CABasicAnimation animationWithKeyPath:keyPath];
      animation.timingFunction = timingFunctionWithControlPoints(timing.curve.data);
      animation.duration = timing.duration * simulatorAnimationDragCoefficient();
      break;

    case MDMMotionCurveTypeSpring: {
      CASpringAnimation *spring = [CASpringAnimation animationWithKeyPath:keyPath];
      spring.mass = timing.curve.data[MDMSpringMotionCurveDataIndexMass];
      spring.stiffness = timing.curve.data[MDMSpringMotionCurveDataIndexTension];
      spring.damping = timing.curve.data[MDMSpringMotionCurveDataIndexFriction];
      spring.duration = spring.settlingDuration;
      animation = spring;
      break;
    }
  }

  if (animation) {
    if (timing.delay != 0) {
      animation.beginTime = ([layer convertTime:CACurrentMediaTime() fromLayer:nil]
                             + timing.delay * simulatorAnimationDragCoefficient());
      animation.fillMode = kCAFillModeBackwards;
    }

    // TODO(featherless): Allow additive behavior to be turned off.

    id initialValue;

    if (_animateFromPresentationValue) {
      if ([layer presentationLayer]) {
        initialValue = [[layer presentationLayer] valueForKeyPath:keyPath];
      } else {
        initialValue = [layer valueForKeyPath:keyPath];
      }
    } else {
      initialValue = [values firstObject];
    }

    if ([[values lastObject] isKindOfClass:[NSNumber class]]) {
      CGFloat currentValue = [initialValue doubleValue];
      CGFloat delta = currentValue - [[values lastObject] doubleValue];
      if (delta == 0) {
        animation = nil;

      } else {
        animation.fromValue = @(delta);
        animation.toValue = @0;
        animation.additive = true;
      }

      // TODO: Cache this set.
    } else if ([[NSSet setWithArray:@[@"bounds.size"]] containsObject:keyPath]) {
      CGSize currentValue = [initialValue CGSizeValue];
      CGSize destinationValue = [[values lastObject] CGSizeValue];
      CGSize delta = CGSizeMake(currentValue.width - destinationValue.width,
                                currentValue.height - destinationValue.height);
      if (CGSizeEqualToSize(delta, CGSizeZero)) {
        animation = nil;

      } else {
        animation.fromValue = [NSValue valueWithCGSize:delta];
        animation.toValue = [NSValue valueWithCGSize:CGSizeZero];
        animation.additive = true;
      }

      // TODO: Cache this set.
    } else if ([[NSSet setWithArray:@[@"position"]] containsObject:keyPath]) {
      CGPoint currentValue = [initialValue CGPointValue];
      CGPoint destinationValue = [[values lastObject] CGPointValue];
      CGPoint delta = CGPointMake(currentValue.x - destinationValue.x,
                                  currentValue.y - destinationValue.y);
      if (CGPointEqualToPoint(delta, CGPointZero)) {
        animation = nil;
      } else {
        animation.fromValue = [NSValue valueWithCGPoint:delta];
        animation.toValue = [NSValue valueWithCGPoint:CGPointZero];
        animation.additive = true;
      }

    } else {
      animation.fromValue = initialValue;
      animation.toValue = [values lastObject];
    }

    [layer addAnimation:animation forKey:nil];
  }

  [layer setValue:[values lastObject] forKeyPath:keyPath];
}

@end
