//
//  ViewController.h
//  Bezier
//
//  Created by MotionVFX on 27/09/2023.
//

#import <Cocoa/Cocoa.h>
#include <MetalKit/MetalKit.h>

@interface ViewController : NSViewController  <MTKViewDelegate>

@property (weak) IBOutlet MTKView *mtkView;
@property (weak) IBOutlet NSSlider *curveSlider;

@property NSUInteger curveResolution;
@property NSUInteger closestIndex;
@end

