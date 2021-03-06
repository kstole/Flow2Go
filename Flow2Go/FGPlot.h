//
//  FGPlot.h
//  Flow2Go
//
//  Created by Christian Hansen on 07/03/13.
//  Copyright (c) 2013 Christian Hansen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "FGNode.h"

@class FGAnalysis;

@interface FGPlot : FGNode

@property (nonatomic, retain) UIImage* image;
@property (nonatomic, retain) NSNumber * plotType;
@property (nonatomic, retain) NSNumber * xAxisType;
@property (nonatomic, retain) NSNumber * yAxisType;
@property (nonatomic, retain) FGAnalysis *analysis;

@end
