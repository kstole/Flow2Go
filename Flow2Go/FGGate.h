//
//  FGGate.h
//  Flow2Go
//
//  Created by Christian Hansen on 28/03/13.
//  Copyright (c) 2013 Christian Hansen. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "FGNode.h"

@class FGAnalysis;

@interface FGGate : FGNode

@property (nonatomic, retain) NSNumber * countOfEvents;
@property (nonatomic, retain) NSNumber * type;
@property (nonatomic, retain) id vertices;
@property (nonatomic, retain) FGAnalysis *analysis;

@end
