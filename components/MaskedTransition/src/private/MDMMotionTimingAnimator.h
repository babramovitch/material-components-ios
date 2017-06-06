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

#import <Foundation/Foundation.h>

#import "MDMMotionTiming.h"

/**
 A motion timing animator is responsible for adding Core Animation animations to a layer based on a
 provided timing structure.
 */
@interface MDMMotionTimingAnimator : NSObject

/**
 If enabled, all animations will be added with their values reversed.

 Disabled by default.
 */
@property(nonatomic, assign) BOOL shouldReverseValues;

/**
 If enabled, all animations will start from their current presentation value.

 Disabled by default.
 */
@property(nonatomic, assign) BOOL animateFromPresentationValue;

/**
 Adds a single animation to the layer with the given timing structure.

 @param timing The timing to be used for the animation.
 @param layer The layer to be animated.
 @param values The values to be used in the animation. Must contain exactly two values. Supported
 UIKit types will be coerced to their Core Animation equivalent. Supported UIKit values include
 UIColor and UIBezierPath.
 @param keyPath The key path of the property to be animated.
 */
- (void)addAnimationWithTiming:(MDMMotionTiming)timing
                       toLayer:(CALayer *)layer
                    withValues:(NSArray *)values
                       keyPath:(NSString *)keyPath;

@end
