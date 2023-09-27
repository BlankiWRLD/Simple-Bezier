//
//  ViewController.m
//  Bezier
//
//  Created by MotionVFX on 27/09/2023.
//
#include <MetalKit/MetalKit.h>
#import "ViewController.h"

@implementation ViewController
{
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
    id<MTLRenderPipelineState> _pipelineState;
    id<MTLRenderPipelineState>_dotPipelineState;
    NSMutableArray<NSValue *> *_controlPoints;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _device = MTLCreateSystemDefaultDevice();
    _commandQueue = [_device newCommandQueue];
       
    self.mtkView.device = _device;
    self.mtkView.delegate = self;
    [self setupRenderPipeline];
    [self setupDotRenderPipeline];
    _controlPoints = [NSMutableArray array];
    NSClickGestureRecognizer *clickRecognizer = [[NSClickGestureRecognizer alloc] initWithTarget:self action:@selector(handleMouseClick:)];
    NSPanGestureRecognizer *panRecognizer = [[NSPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    [self.mtkView addGestureRecognizer:panRecognizer];
    [self.mtkView addGestureRecognizer:clickRecognizer];
    _selectedIndices = [NSMutableIndexSet indexSet];
    

}

- (void)handleMouseClick:(NSGestureRecognizer *)recognizer {
    if (recognizer.state == NSGestureRecognizerStateEnded) {
        NSPoint locationInView = [recognizer locationInView:self.mtkView];
        float x = locationInView.x / self.mtkView.bounds.size.width * 2 - 1;
        float y = (locationInView.y / self.mtkView.bounds.size.height) * 2 - 1;
        
        float acceptableDistanceSquared = 0.01;
        NSInteger closestIndex = NSNotFound;
        float minDistanceSquared = FLT_MAX;
        
        // Check if clicked on an existing point
        for (NSInteger i = 0; i < _controlPoints.count; i++) {
            NSPoint point = [_controlPoints[i] pointValue];
            float dx = point.x - x;
            float dy = point.y - y;
            float distanceSquared = dx * dx + dy * dy;
            if (distanceSquared < minDistanceSquared) {
                minDistanceSquared = distanceSquared;
                closestIndex = i;
            }
        }
        
        // Clear any previously selected indices
        [_selectedIndices removeAllIndexes];
        
        // If clicked on a point, select it, else add a new point
        if (closestIndex != NSNotFound && minDistanceSquared < acceptableDistanceSquared) {
            [_selectedIndices addIndex:closestIndex];
        } else {
            [_controlPoints addObject:[NSValue valueWithPoint:NSMakePoint(x, y)]];
        }
        
        [self.mtkView setNeedsDisplay:YES];
    }
}


- (void)handlePan:(NSPanGestureRecognizer *)recognizer {
    NSPoint locationInView = [recognizer locationInView:self.mtkView];
    float x = locationInView.x / self.mtkView.bounds.size.width * 2 - 1;
    float y = (locationInView.y / self.mtkView.bounds.size.height) * 2 - 1;

    // Update all selected control points
    [_selectedIndices enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        _controlPoints[idx] = [NSValue valueWithPoint:NSMakePoint(x, y)];
    }];
    
    [self.mtkView setNeedsDisplay:YES];
}


- (void)drawCurvesWithRenderEncoder:(id<MTLRenderCommandEncoder>)renderEncoder {
    NSUInteger pointCount = _controlPoints.count;
    if (pointCount >= 4) {
        for (NSUInteger p = 0; p <= pointCount - 4; p += 3) {
            NSPoint P0 = [_controlPoints[p] pointValue];
            NSPoint P1 = [_controlPoints[p + 1] pointValue];
            NSPoint P2 = [_controlPoints[p + 2] pointValue];
            NSPoint P3 = [_controlPoints[p + 3] pointValue];
            
            NSUInteger resolution = 1 + _curveResolution;
            NSMutableArray<NSValue *> *curveVertices = [NSMutableArray array];
            for (NSUInteger i = 0; i <= resolution; i++) {
                float t = (float)i / (float)resolution;
                float u = 1.0 - t;
                
                float x = u * u * u * P0.x + 3 * u * u * t * P1.x + 3 * u * t * t * P2.x + t * t * t * P3.x;
                float y = u * u * u * P0.y + 3 * u * u * t * P1.y + 3 * u * t * t * P2.y + t * t * t * P3.y;
                
                [curveVertices addObject:[NSValue valueWithPoint:NSMakePoint(x, y)]];
            }
            
            if (curveVertices.count > 0) {
                float vertexData[curveVertices.count * 2];
                for (NSUInteger i = 0; i < curveVertices.count; i++) {
                    NSPoint point = curveVertices[i].pointValue;
                    vertexData[i * 2] = point.x;
                    vertexData[i * 2 + 1] = point.y;
                }
                id<MTLBuffer> vertexBuffer = [_device newBufferWithBytes:vertexData length:sizeof(vertexData) options:MTLResourceStorageModeShared];
                [renderEncoder setRenderPipelineState:_pipelineState];
                [renderEncoder setVertexBuffer:vertexBuffer offset:0 atIndex:0];
                [renderEncoder drawPrimitives:MTLPrimitiveTypeLineStrip vertexStart:0 vertexCount:curveVertices.count];
            }
            
        }
    }
    
}

- (void)drawDotsWithRenderEncoder:(id<MTLRenderCommandEncoder>)renderEncoder {
    float dotSize = 0.01;
    
    for (NSInteger i = 0; i < _controlPoints.count; i++) {
        NSValue *value = _controlPoints[i];
        NSPoint point = value.pointValue;
        BOOL isSelected = [_selectedIndices containsIndex:i];

        
        float dotVertices[] = {
            point.x - dotSize, point.y - dotSize, isSelected,
            point.x + dotSize, point.y - dotSize, isSelected,
            point.x - dotSize, point.y + dotSize, isSelected,
            point.x + dotSize, point.y + dotSize, isSelected,
        };
        
        [renderEncoder setRenderPipelineState:_dotPipelineState];
        id<MTLBuffer> dotVertexBuffer = [_device newBufferWithBytes:dotVertices length:sizeof(dotVertices) options:MTLResourceStorageModeShared];
        [renderEncoder setVertexBuffer:dotVertexBuffer offset:0 atIndex:0];
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    }
}


- (void)keyDown:(NSEvent *)event {
    if (event.keyCode == 0x31) { // Spacebar keycode
        // Delete selected control points
        [_selectedIndices enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger idx, BOOL *stop) {
            if (idx < _controlPoints.count) {
                [_controlPoints removeObjectAtIndex:idx];
            }
        }];
        [_selectedIndices removeAllIndexes];
        [self.mtkView setNeedsDisplay:YES];
    }
}


- (void)setupRenderPipeline {
    id<MTLLibrary> library = [_device newDefaultLibrary];
    
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragment_main"];
    
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = self.mtkView.colorPixelFormat;
    
    NSError *error = nil;
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
}

- (void)setupDotRenderPipeline {
    id<MTLLibrary> library = [_device newDefaultLibrary];
    
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"dot_vertex"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"dot_fragment"];
    
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = self.mtkView.colorPixelFormat;

    MTLVertexDescriptor *vertexDescriptor = [[MTLVertexDescriptor alloc] init];
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0;
    vertexDescriptor.layouts[0].stride = sizeof(float) * 2;
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat;
    vertexDescriptor.attributes[1].offset = sizeof(float) * 2;
    vertexDescriptor.attributes[1].bufferIndex = 0;
    vertexDescriptor.layouts[0].stride = sizeof(float) * 3;
    pipelineDescriptor.vertexDescriptor = vertexDescriptor;

    NSError *error = nil;
    _dotPipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (error) {
        NSLog(@"Failed to create dot pipeline state: %@", error);
    }
}

- (IBAction)curveResolution:(id)sender {
    if ([sender isKindOfClass:[NSSlider class]]) {
        NSSlider *slider = (NSSlider *)sender;
        double sliderValue = slider.doubleValue;
        _curveResolution = (NSUInteger)sliderValue;
        [self.mtkView setNeedsDisplay:YES];
    }
}
- (IBAction)resetButton:(id)sender {
    [_controlPoints removeAllObjects];
    [self.mtkView setNeedsDisplay:YES];
}

- (void)drawInMTKView:(nonnull MTKView *)view {
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:view.currentRenderPassDescriptor];

    [self drawCurvesWithRenderEncoder:renderEncoder];
    [self drawDotsWithRenderEncoder:renderEncoder];
   
    [renderEncoder endEncoding];
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}


- (void)mtkView:(nonnull MTKView *)view drawableSizeWillChange:(CGSize)size {
}


@end
