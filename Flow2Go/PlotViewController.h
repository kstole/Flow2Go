//
//  PlotViewController.h
//  Flow2Go
//
//  Created by Christian Hansen on 03/08/12.
//  Copyright (c) 2012 Christian Hansen. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Measurement.h"
#import "CorePlot-CocoaTouch.h"
#import "CPTGraph.h"
#import "MarkView.h"

@class Plot;
@class Gate;

@interface PlotViewController : UIViewController <CPTPlotDataSource, CPTScatterPlotDelegate, CPTScatterPlotDataSource, CPTPlotSpaceDelegate, MarkViewDelegate, UIActionSheetDelegate>
{
    IBOutlet UIView *graphView;
}

- (void)showPlot:(Plot *)plot forMeasurement:(Measurement *)aMeasurement;

@property (nonatomic, weak) IBOutlet MarkView *markView;
@property (weak, nonatomic) IBOutlet UIButton *xAxisButton;
@property (weak, nonatomic) IBOutlet UIButton *yAxisButton;


@end
