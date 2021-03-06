//
//  DensityPlotData.m
//  Flow2Go
//
//  Created by Christian Hansen on 29/08/12.
//  Copyright (c) 2012 Christian Hansen. All rights reserved.
//

#import "FGPlotDataCalculator.h"
#import "FGFCSFile.h"

@implementation FGPlotDataCalculator

#define BIN_COUNT 512
#define HISTOGRAM_AVERAGING 15

+ (FGPlotDataCalculator *)plotDataForFCSFile:(FGFCSFile *)fcsFile
                                 plotOptions:(NSDictionary *)plotOptions
                                      subset:(NSUInteger *)subset
                                 subsetCount:(NSUInteger)subsetCount
{
    if (!fcsFile || !plotOptions) {
        NSLog(@"Error: fcsFile or plotoptions is nil: %s", __PRETTY_FUNCTION__);
        return nil;
    }
    FGPlotType plotType = [plotOptions[PlotType] integerValue];
    switch (plotType)
    {
        case kPlotTypeDot:
            return [FGPlotDataCalculator dotDataForFCSFile:fcsFile plotOptions:plotOptions subset:subset subsetCount:subsetCount];
            break;
            
        case kPlotTypeDensity:
            return [FGPlotDataCalculator densityDataForFCSFile:fcsFile plotOptions:plotOptions subset:subset subsetCount:subsetCount];
            break;
            
        case kPlotTypeHistogram:
            return [FGPlotDataCalculator histogramForFCSFile:fcsFile plotOptions:plotOptions subset:subset subsetCount:subsetCount];
            break;
            
        default:
            NSLog(@"Error: unknown plottype: %d, %s", plotType, __PRETTY_FUNCTION__);
            break;
    }
    return nil;
}


+ (FGPlotDataCalculator *)dotDataForFCSFile:(FGFCSFile *)fcsFile
                                plotOptions:(NSDictionary *)plotOptions
                                     subset:(NSUInteger *)subset
                                subsetCount:(NSUInteger)subsetCount
{
    FGPlotDataCalculator *dotPlotData = [FGPlotDataCalculator.alloc init];
    NSInteger eventsInside = subsetCount;
    if (!subset) eventsInside = fcsFile.data.noOfEvents;

    
    NSInteger xPar = [plotOptions[XParNumber] integerValue] - 1;
    NSInteger yPar = [plotOptions[YParNumber] integerValue] - 1;
    
    dotPlotData.points = calloc(eventsInside, sizeof(FGDensityPoint));
    dotPlotData.numberOfPoints = eventsInside;
    
    NSUInteger eventNo;
    for (NSUInteger index = 0; index < eventsInside; index++)
    {
        eventNo = index;
        if (subset) eventNo = subset[index];
        
        dotPlotData.points[index].xVal = (double)fcsFile.data.events[eventNo][xPar];
        dotPlotData.points[index].yVal = (double)fcsFile.data.events[eventNo][yPar];
    }
    return dotPlotData;
}


+ (FGPlotDataCalculator *)densityDataForFCSFile:(FGFCSFile *)fcsFile
                                    plotOptions:(NSDictionary *)plotOptions
                                         subset:(NSUInteger *)subset
                                    subsetCount:(NSUInteger)subsetCount
{
    if (!fcsFile || !plotOptions) {
        NSLog(@"Error: fcsFile or Plotoptions is nil: %s", __PRETTY_FUNCTION__);
        return nil;
    }
    
    NSInteger eventsInside = subsetCount;
    if (!subset) eventsInside = fcsFile.data.noOfEvents;
    
    if (!eventsInside) {
        return nil;
    }
    
    NSInteger xPar = [plotOptions[XParNumber] integerValue] - 1;
    NSInteger yPar = [plotOptions[YParNumber] integerValue] - 1;
    
    FGAxisType xAxisType = [plotOptions[XAxisType] integerValue];
    FGAxisType yAxisType = [plotOptions[YAxisType] integerValue];
    
    double maxIndex = (double)(BIN_COUNT - 1);
    
    double xMin = fcsFile.data.ranges[xPar].minValue;
    double xMax = fcsFile.data.ranges[xPar].maxValue;
    double yMin = fcsFile.data.ranges[yPar].minValue;
    double yMax = fcsFile.data.ranges[yPar].maxValue;    
    
    // For linear scales
    double xFCSRangeToBinRange = maxIndex / (xMax - xMin);
    double xBinRangeToFCSRange = 1.0 / xFCSRangeToBinRange;
    
    double yFCSRangeToBinRange = maxIndex / (yMax - yMin);
    double yBinRangeToFCSRange = 1.0 / yFCSRangeToBinRange;

    // For logarithmic scales
    double xFactor = pow(xMin/xMax, 1.0/maxIndex);
    double yFactor = pow(yMin/yMax, 1.0/maxIndex);
    
    double log10XFactor = log10(xFactor);
    double log10YFactor = log10(yFactor);
    
    double log10XMin = log10(xMin);
    double log10YMin = log10(yMin);
    
    
    FGPlotPoint plotPoint;
    NSUInteger col = 0;
    NSUInteger row = 0;
    
    NSUInteger **binValues = calloc(BIN_COUNT, sizeof(NSUInteger *));
    for (NSUInteger i = 0; i < BIN_COUNT; i++) {
        binValues[i] = calloc(BIN_COUNT, sizeof(NSUInteger));
    }
    
    NSUInteger eventNo;
    for (NSUInteger index = 0; index < eventsInside; index++)
    {
        eventNo = index;
        if (subset) eventNo = subset[index];
        
        plotPoint.xVal = fcsFile.data.events[eventNo][xPar];
        plotPoint.yVal = fcsFile.data.events[eventNo][yPar];
        
        switch (xAxisType)
        {
            case kAxisTypeLinear:
                col = (plotPoint.xVal - xMin) * xFCSRangeToBinRange;
                break;
                
            case kAxisTypeLogarithmic:
                col = (log10XMin - log10(plotPoint.xVal))/log10XFactor;
                break;
                
            default:
                break;
        }
        
        switch (yAxisType)
        {
            case kAxisTypeLinear:
                row = (plotPoint.yVal - yMin) * yFCSRangeToBinRange;
                break;
                
            case kAxisTypeLogarithmic:
//                if (plotPoint.yVal > yMax) {
//                    NSLog(@"Row: %d, Index: %d, plotpoint(%f,%f)", row, index, plotPoint.xVal, plotPoint.yVal);
//                }
                row = (log10YMin - log10(plotPoint.yVal))/log10YFactor;
                break;
                
            default:
                break;
        }
//        if (col >= BIN_COUNT) col = BIN_COUNT - 1;
//        if (row >= BIN_COUNT) row = BIN_COUNT - 1;
        
        binValues[col][row] += 1;
    }
    
    FGPlotDataCalculator *densityPlotData = [FGPlotDataCalculator.alloc init];
    
    
    densityPlotData.points = calloc(BIN_COUNT * BIN_COUNT, sizeof(FGDensityPoint));
    NSUInteger recordNo = 0;
    NSInteger count = 0;
    for (NSUInteger rowNo = 0; rowNo < BIN_COUNT; rowNo++)
    {
        for (NSUInteger colNo = 0; colNo < BIN_COUNT; colNo++)
        {
            count = binValues[colNo][rowNo];
            if (count > 0)
            {
                densityPlotData.points[recordNo].count = count;
                [densityPlotData _checkForMaxCount:densityPlotData.points[recordNo].count];
                
                switch (xAxisType)
                {
                    case kAxisTypeLinear:
                        densityPlotData.points[recordNo].xVal = (double)colNo * xBinRangeToFCSRange + xMin;
                        break;
                        
                    case kAxisTypeLogarithmic:
                        densityPlotData.points[recordNo].xVal = pow(10, log10XMin - log10XFactor * (double)colNo);
                        break;
                        
                    default:
                        break;
                }
                switch (yAxisType)
                {
                    case kAxisTypeLinear:
                        densityPlotData.points[recordNo].yVal = (double)rowNo * yBinRangeToFCSRange + yMin;
                        break;
                        
                    case kAxisTypeLogarithmic:
                        densityPlotData.points[recordNo].yVal = pow(10, log10YMin - log10YFactor * (double)rowNo);
                        break;
                        
                    default:
                        break;
                }
                recordNo++;
            }
        }
    }
    densityPlotData.numberOfPoints = recordNo;
    
    for (NSUInteger i = 0; i < BIN_COUNT; i++) {
        free(binValues[i]);
    }
    if (binValues) free(binValues);
    return densityPlotData;
}



- (void)_checkForMaxCount:(NSUInteger)count
{
    if (count > _countForMaxBin)
    {
        _countForMaxBin = count;
    }
}


+ (FGPlotDataCalculator *)histogramForFCSFile:(FGFCSFile *)fcsFile
                                  plotOptions:(NSDictionary *)plotOptions
                                       subset:(NSUInteger *)subset
                                  subsetCount:(NSUInteger)subsetCount
{
    if (!fcsFile || !plotOptions) {
        NSLog(@"Error: fcsFile or Plotoptions is nil: %s", __PRETTY_FUNCTION__);
        return nil;
    }
    
    NSInteger eventsInside = subsetCount;
    if (!subset) eventsInside = fcsFile.data.noOfEvents;
    
    NSInteger parIndex = [plotOptions[XParNumber] integerValue] - 1;
    
    FGAxisType axisType = [plotOptions[XAxisType] integerValue];
    
    double maxIndex = (double)(BIN_COUNT - 1);
    
    double xMin = fcsFile.data.ranges[parIndex].minValue;
    double xMax = fcsFile.data.ranges[parIndex].maxValue;
    
    // For linear scales
    double xFCSRangeToBinRange = maxIndex / (xMax - xMin);
    double xBinRangeToFCSRange = 1.0 / xFCSRangeToBinRange;
    
    
    // For logarithmic scales
    double xFactor = pow(xMin/xMax, 1.0/maxIndex);
    
    double log10XFactor = log10(xFactor);
    
    double log10XMin = log10(xMin);
    
    
    FGPlotPoint plotPoint;
    NSUInteger col = 0;
    
    NSUInteger *binValues = calloc(BIN_COUNT, sizeof(NSUInteger));

    
    NSUInteger eventNo;
    for (NSUInteger index = 0; index < eventsInside; index++)
    {
        eventNo = index;
        if (subset) eventNo = subset[index];
        
        plotPoint.xVal = fcsFile.data.events[eventNo][parIndex];
        
        switch (axisType)
        {
            case kAxisTypeLinear:
                col = (plotPoint.xVal - xMin) * xFCSRangeToBinRange;
                break;
                
            case kAxisTypeLogarithmic:
                col = (log10XMin - log10(plotPoint.xVal))/log10XFactor;
                break;
                
            default:
                break;
        }
        binValues[col] += 1;
    }
    
    FGPlotDataCalculator *histogramPlotData = [[FGPlotDataCalculator alloc] init];
    histogramPlotData.numberOfPoints = BIN_COUNT;
    histogramPlotData.points = calloc(BIN_COUNT, sizeof(FGDensityPoint));
    
    for (NSUInteger colNo = 0; colNo < BIN_COUNT; colNo++)
    {
        [histogramPlotData _checkForMaxCount:histogramPlotData.points[colNo].yVal];
        
        switch (axisType)
        {
            case kAxisTypeLinear:
                histogramPlotData.points[colNo].xVal = (double)colNo * xBinRangeToFCSRange + xMin;
                break;
                
            case kAxisTypeLogarithmic:
                histogramPlotData.points[colNo].xVal = pow(10, log10XMin - log10XFactor * (double)colNo);
                break;
                
            default:
                break;
        }
    }

    // Prepare y-values
    double runningAverage = 0.0;
    
    for (NSUInteger col = 0; col < BIN_COUNT; col++) {
        runningAverage += (double)binValues[col];

        if (col >= HISTOGRAM_AVERAGING) {
            runningAverage -= (double)binValues[col - HISTOGRAM_AVERAGING];
            histogramPlotData.points[col].yVal = runningAverage / HISTOGRAM_AVERAGING;
            [histogramPlotData _checkForMaxCount:(NSUInteger)histogramPlotData.points[col].yVal];
        } else {
            histogramPlotData.points[col].yVal = (double)binValues[col];;
        }
    }
    if (binValues) free(binValues);
    return histogramPlotData;
}


- (void)dealloc
{
    if (self.points) free(self.points);
}


@end
