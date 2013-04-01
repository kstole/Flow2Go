//
//  PlotViewController.m
//  Flow2Go
//
//  Created by Christian Hansen on 03/08/12.
//  Copyright (c) 2012 Christian Hansen. All rights reserved.
//

#import "FGPlotViewController.h"
#import "FGFCSFile.h"
#import "FGGateCalculator.h"
#import "FGGate+Management.h"
#import "FGPlot+Management.h"
#import "FGPlotDataCalculator.h"
#import "FGGateTableViewController.h"
#import "FGPlotDetailTableViewController.h"
#import "FGPlotHelper.h"
#import "FGGatesContainerView.h"
#import "PopoverView.h"
#import "UIImage+Resize.h"  
#import "UIImage+Extensions.h"
#import "FGMeasurement+Management.h"
#import "FGAnalysis+Management.h"
#import "FGPendingOperations.h"
#import "FGGateCalculationOperation.h"

@interface FGPlotViewController () <FGGateButtonsViewDelegate, GateTableViewControllerDelegate, FGGateCalculationOperationDelegate, UIPopoverControllerDelegate, PopoverViewDelegate>

@property (nonatomic) NSInteger xParIndex;
@property (nonatomic) NSInteger yParIndex;
@property (nonatomic) FGPlotType currentPlotType;
@property (nonatomic, strong) FGGateCalculator *parentGateCalculator;
@property (nonatomic, strong) FGFCSFile *fcsFile;
@property (nonatomic, strong) FGPlotDataCalculator *plotData;
@property (nonatomic, strong) NSMutableArray *displayedGates;
@property (nonatomic, strong) FGPlotHelper *plotHelper;
@property (nonatomic, strong) UIPopoverController *detailPopoverController;
@property (weak, nonatomic) IBOutlet UISegmentedControl *plotTypeSegmentedControl;
@property (nonatomic, strong) PopoverView *popoverView;
@property (nonatomic, strong) UITapGestureRecognizer *backgroundTapGestureRecognizer;

@end

@implementation FGPlotViewController

#define X_AXIS_TAG 1
#define Y_AXIS_TAG 2

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (!self.plot) {
        NSLog(@"plot was nil");
        return;
    }
    self.fcsFile = [self.delegate fcsFileForPlot:self.plot];
    self.title = self.plot.name;
    self.addGateButtonsView.delegate = self;
    [self.addGateButtonsView updateButtons];
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self _configureButtons];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self _centerNavigationControllerSuperview];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.graphHostingView.hostedGraph = self.graph;
    [self _reloadPlotDataAndLayout];
    self.gatesContainerView.delegate = self;
    [self.gatesContainerView performSelector:@selector(redrawGates) withObject:nil afterDelay:0.05];
    [self addTapGestureRecognizerToBackgruond];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.detailPopoverController dismissPopoverAnimated:YES];
    [self.view.window removeGestureRecognizer:self.backgroundTapGestureRecognizer];
    [self _grabImageOfPlot]; //TODO: downscale image in background thread before adding. (consider thumbnail res. for measurement/and high res for sharing)
    [super viewWillDisappear:animated];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)_centerNavigationControllerSuperview
{
    CGRect applicationFrame = [[UIScreen mainScreen] applicationFrame];
    CGSize statusBarSize = [UIApplication sharedApplication].statusBarFrame.size;
    CGFloat statusBarHeight = MIN(statusBarSize.width, statusBarSize.height);
    if (UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)) {
        self.navigationController.view.superview.center = CGPointMake(applicationFrame.size.width/2.0f, applicationFrame.size.height/2.0f + statusBarHeight);
    } else {
        self.navigationController.view.superview.center = CGPointMake(applicationFrame.size.height/2.0f, applicationFrame.size.width/2.0f + statusBarHeight);
    }
}


- (void)_configureButtons
{
    UIButton *infoButton = [UIButton buttonWithType:UIButtonTypeInfoLight];
    [infoButton addTarget:self action:@selector(_toggleInfo:) forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *infoBarButton = [UIBarButtonItem.alloc initWithCustomView: infoButton];
    UIBarButtonItem *addGateButton = [UIBarButtonItem.alloc initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(_addGateButtonTapped:)];
    self.navigationItem.leftBarButtonItems = @[addGateButton, infoBarButton];
    self.plotTypeSegmentedControl.selectedSegmentIndex = self.plot.plotType.integerValue;
    [self.yAxisButton setTransform:CGAffineTransformMakeRotation(-M_PI / 2)];
}


- (void)_removeSubviews
{
    for (UIView *aSubView in self.view.subviews)
    {
        [aSubView removeFromSuperview];
    }
}

- (void)_grabImageOfPlot
{
    UIImage *plotImage = [UIImage captureLayer:self.graphHostingView.layer];
    UIImage *gatesImage = [UIImage captureLayer:self.gatesContainerView.layer];
    plotImage = [plotImage overlayWith:gatesImage];
    __weak FGPlot *weakPlot = self.plot;
    [UIImage scaleImage:plotImage toSize:CGSizeMake(300, 300) completion:^(UIImage *resizedImage) {
        [weakPlot setImage:resizedImage];
    }];
    [self _saveThumbIfRootPlot:plotImage];
}


- (void)_saveThumbIfRootPlot:(UIImage *)imageForThumb
{
    if (self.plot.parentNode == nil) {
        __weak FGMeasurement *weakMeasurement = self.plot.analysis.measurement;
        [UIImage scaleImage:imageForThumb toSize:CGSizeMake(74, 74) completion:^(UIImage *resizedImage) {
            [weakMeasurement setThumbImage:resizedImage];
        }];
    }
}


- (void)showDetailPopoverForGate:(FGGate *)gate inRect:(CGRect)anchorFrame editMode:(BOOL)editOn
{
    UINavigationController *gateNavigationVC = [self.storyboard instantiateViewControllerWithIdentifier:@"gateDetailTableViewController"];
    FGGateTableViewController *gateTVC = (FGGateTableViewController *)gateNavigationVC.topViewController;
    gateTVC.delegate = self;
    gateTVC.gate = gate;
    
    if (IS_IPAD) {
        if (self.detailPopoverController.isPopoverVisible) {
            [self.detailPopoverController dismissPopoverAnimated:YES];
        }
        self.detailPopoverController = [UIPopoverController.alloc initWithContentViewController:gateNavigationVC];
        [self.detailPopoverController presentPopoverFromRect:anchorFrame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
        self.detailPopoverController.delegate = self;
    } else {
        [self presentViewController:gateNavigationVC animated:YES completion:nil];
    }
    [gateTVC setEditing:editOn animated:NO];
}


#pragma mark - Actions

- (IBAction)plotTypeChanged:(UISegmentedControl *)sender
{
    NSNumber *plotType = [NSNumber numberWithInteger:sender.selectedSegmentIndex];
    self.plot.plotType = plotType;
    [self _reloadPlotDataAndLayout];
    [self.addGateButtonsView updateButtons];
    [self.gatesContainerView redrawGates];
    NSError *error;
    if(![self.plot.managedObjectContext save:&error]) NSLog(@"Error saving plot when setting plotType: %@", error.localizedDescription);
}


- (void)doneTapped
{
    [self _removeSubviews];
    [self.detailPopoverController dismissPopoverAnimated:YES];
    [self.delegate plotViewController:self didTapDoneForPlot:self.plot];
}


- (void)threeDTapped:(UIBarButtonItem *)barButton
{
    NSLog(@"3D not yet available");
    [self performSegueWithIdentifier:@"Show 3D graph" sender:barButton];
}

- (void)_toggleInfo:(UIButton *)sender
{
    UINavigationController *plotNavigationVC = [self.storyboard instantiateViewControllerWithIdentifier:@"plotDetailTableViewController"];
    FGPlotDetailTableViewController *plotTVC = (FGPlotDetailTableViewController *)plotNavigationVC.topViewController;
    id delegate = self.delegate;
    plotTVC.delegate = delegate;
    
    plotTVC.plot = self.plot;
    
    //[plotTVC setEditing:NO animated:NO];
    if (self.detailPopoverController.isPopoverVisible) {
        UINavigationController *navigationController = (UINavigationController *)self.detailPopoverController.contentViewController;
        if (!navigationController.topViewController.editing) {
            [self.detailPopoverController dismissPopoverAnimated:YES];
        }
        return;
    }
    if (IS_IPAD) {
        self.detailPopoverController = [UIPopoverController.alloc initWithContentViewController:plotNavigationVC];
        self.detailPopoverController.delegate = self;
        [self.detailPopoverController presentPopoverFromRect:sender.frame inView:self.navigationController.navigationBar permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    } else {
        [self presentViewController:plotNavigationVC animated:NO completion:nil];
    }
}



#pragma mark - Add Gate Table View Controller Delegate
- (FGPlotType)addGateButtonsViewCurrentPlotType:(id)sender
{
    return self.plot.plotType.integerValue;
}


- (void)addGateButtonsView:(id)sender didSelectGate:(FGGateType)gateType
{
    FGGate *newGate = [FGGate createChildGateInPlot:self.plot type:gateType vertices:nil];
    NSError *error;
    [newGate.managedObjectContext save:&error];
    if (error) NSLog(@"Error creating child gate: %@", error.localizedDescription);
    [self.displayedGates addObject:newGate];
    [self.gatesContainerView insertNewGate:gateType gateTag:[self.displayedGates indexOfObject:newGate]];
}


#pragma mark - Popover Controller Delegate
- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController
{
    id object = popoverController.contentViewController;
    if ([object isKindOfClass:UINavigationController.class])
    {
        UINavigationController *navigationController = (UINavigationController *)object;
        return !navigationController.topViewController.editing;
    }
    return YES;
}

#pragma mark - Axis Picking
- (IBAction)xAxisTapped:(id)sender
{
    [self _showAxisPicker:X_AXIS_TAG fromButton:sender];
}


- (IBAction)yAxisTapped:(id)sender
{
    [self _showAxisPicker:Y_AXIS_TAG fromButton:sender];
}


- (void)_showAxisPicker:(NSInteger)axisNumber fromButton:(UIButton *)axisButton
{
    NSMutableArray *items = [NSMutableArray array];
    for (NSUInteger parIndex = 0; parIndex < [self.fcsFile.text[@"$PAR"] integerValue]; parIndex++) {
        NSString *title = [self _titleForParameter:parIndex + 1];
        if (title) [items addObject:title];
    }
    CGPoint point;
    switch (axisNumber) {
        case X_AXIS_TAG:
            point = CGPointMake(axisButton.frame.origin.x + axisButton.bounds.size.width / 2.0f, axisButton.frame.origin.y);
            break;
        case Y_AXIS_TAG:
            point = CGPointMake(axisButton.frame.origin.x + axisButton.bounds.size.height / 2.0f, axisButton.frame.origin.y);
            break;
        default:
            break;
    }
    self.popoverView = [PopoverView showPopoverAtPoint:point inView:self.view withTitle:nil withStringArray:items delegate:self];
    self.popoverView.tag = axisNumber;
}

#pragma mark - PopoverViewDelegate Methods

- (void)popoverView:(PopoverView *)popoverView didSelectItemAtIndex:(NSInteger)index
{
    [popoverView performSelector:@selector(dismiss) withObject:nil afterDelay:0.0f];
    if (index < 0) {
        return;
    }
    NSNumber *parNumber = [NSNumber numberWithInteger:index + 1];
    if (self.popoverView.tag == X_AXIS_TAG) {
        self.plot.xParNumber = parNumber;
    } else if (self.popoverView.tag == Y_AXIS_TAG) {
        self.plot.yParNumber = parNumber;
    }
    [self _reloadPlotDataAndLayout];
    [self.gatesContainerView redrawGates];
    
    NSError *error;
    [self.plot.managedObjectContext save:&error];
    if (error) NSLog(@"Erro saving plot: %@", error.localizedDescription);
}


- (void)axisChanged:(id)sender
{
    NSLog(@"sender: %@", sender);
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex <= 0) {
        return;
    }
    NSNumber *parNumber = [NSNumber numberWithInteger:buttonIndex];
    if (actionSheet.tag == X_AXIS_TAG) {
        self.plot.xParNumber = parNumber;
    } else if (actionSheet.tag == Y_AXIS_TAG) {
        self.plot.yParNumber = parNumber;
    }
    [self _reloadPlotDataAndLayout];
    [self.gatesContainerView redrawGates];
    NSError *error;
    [self.plot.managedObjectContext save:&error];
    if (error) NSLog(@"Erro saving plot: %@", error.localizedDescription);
}



#pragma mark Reloading plot
- (void)_reloadPlotDataAndLayout
{
    [self preparePlotData];
    [self _updateAxisTitleButtons];
    
    [self.graph configureStyleForPlotType:self.plot.plotType.integerValue];
    [self.graph updateXAxis:self.plot.xAxisType.integerValue yAxisType:self.plot.yAxisType.integerValue plotType:self.plot.plotType.integerValue];
    [self.graph reloadData];
    [self.graph adjustPlotRangeToFitXRange:self.fcsFile.ranges[_xParIndex] yRange:self.fcsFile.ranges[_yParIndex] plotType:self.plot.plotType.integerValue];
}


- (void)preparePlotData
{
    _xParIndex = self.plot.xParNumber.integerValue - 1;
    _yParIndex = self.plot.yParNumber.integerValue - 1;
    _currentPlotType = self.plot.plotType.integerValue;
    self.plot.xAxisType = [NSNumber numberWithInteger:[self.fcsFile axisTypeForParameterIndex:self.plot.xParNumber.integerValue - 1]];
    self.plot.yAxisType = [NSNumber numberWithInteger:[self.fcsFile axisTypeForParameterIndex:self.plot.yParNumber.integerValue - 1]];
    
    FGGate *parentGate = (FGGate *)self.plot.parentNode;
    if (parentGate && self.parentGateCalculator == nil) [self updateSubPopulation];
    
    self.plotData = [FGPlotDataCalculator plotDataForFCSFile:self.fcsFile
                                                 plotOptions:self.plot.plotOptions
                                                      subset:self.parentGateCalculator.eventsInside
                                                 subsetCount:self.parentGateCalculator.countOfEventsInside];
}

- (void)updateSubPopulation
{
    NSArray *parentGateDatas = [FGGate gatesAsData:self.plot.parentGates];
    self.parentGateCalculator = [FGGateCalculator eventsInsideGatesWithDatas:parentGateDatas fcsFile:self.fcsFile];
}


- (void)_updateAxisTitleButtons
{
    [self.xAxisButton setTitle:[self _titleForParameter:self.plot.xParNumber.integerValue] forState:UIControlStateNormal];
    if (self.plot.plotType.integerValue == kPlotTypeHistogram) {
        [self.yAxisButton setTitle:NSLocalizedString(@"Count #", nil) forState:UIControlStateNormal];
    } else {
        [self.yAxisButton setTitle:[self _titleForParameter:self.plot.yParNumber.integerValue] forState:UIControlStateNormal];
    }
}


- (NSString *)_titleForParameter:(NSInteger)parNumber
{
    NSString *unitName = self.fcsFile.calibrationUnitNames[[NSString stringWithFormat:@"%i", parNumber]];
    NSString *title = [FGFCSFile parameterShortNameForParameterIndex:parNumber - 1 inFCSFile:self.fcsFile];
    if (unitName) title = [title stringByAppendingFormat:@" %@", unitName];
    
    return title;
}

#pragma mark - FGGraph Data Source
- (NSInteger)countForHistogramMaxValue
{
    return self.plotData.countForMaxBin;
}


#pragma mark - CPT Plot Data Source
- (NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot
{
    if (self.plotData) {
        return self.plotData.numberOfPoints;
    } else if (self.parentGateCalculator) {
        return self.parentGateCalculator.countOfEventsInside;
    }
    return self.fcsFile.noOfEvents;
}


- (double)doubleForPlot:(CPTPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index
{
    switch (fieldEnum) {
        case CPTCoordinateX:
            return _plotData.points[index].xVal;
            break;
            
        case CPTCoordinateY:
            return _plotData.points[index].yVal;
            break;
            
        default:
            break;
    }
    return 0.0;
}

#pragma mark - Scatter Plot Delegate
static CPTPlotSymbol *plotSymbol;

#define COLOR_LEVELS 15
#define PLOTSYMBOL_SIZE 2.0

#pragma mark - Scatter Plot Datasource
-(CPTPlotSymbol *)symbolForScatterPlot:(CPTScatterPlot *)plot recordIndex:(NSUInteger)index
{
    if (_currentPlotType == kPlotTypeDensity) {
        if (!self.plotHelper) {
            self.plotHelper = [FGPlotHelper coloredPlotSymbols:COLOR_LEVELS ofSize:CGSizeMake(PLOTSYMBOL_SIZE, PLOTSYMBOL_SIZE)];
        }
        NSInteger cellCount = self.plotData.points[index].count;
        if (cellCount > 0) {
            NSInteger colorLevel = COLOR_LEVELS * (float)cellCount / (float)self.plotData.countForMaxBin;
            if (colorLevel > -1
                && colorLevel < COLOR_LEVELS) {
                return self.plotHelper.plotSymbols[colorLevel];
            }
        }
    } else if (_currentPlotType == kPlotTypeDot) {
        if (!plotSymbol) {
            plotSymbol = [CPTPlotSymbol ellipsePlotSymbol];
            plotSymbol.fill = [CPTFill fillWithColor:[CPTColor colorWithComponentRed:0.0 green:0.0 blue:0.0 alpha:1.0]];
            plotSymbol.lineStyle = nil;
            plotSymbol.size = CGSizeMake(PLOTSYMBOL_SIZE, PLOTSYMBOL_SIZE);
        }
        return plotSymbol;
    }
    return nil;
}


- (NSArray *)viewVerticesFromGateVertices:(NSArray *)gateVertices inView:(UIView *)aView plotSpace:(CPTPlotSpace *)plotSpace
{
    NSMutableArray *viewVertices = NSMutableArray.array;
    double graphPoint[2];
    
    for (FGGraphPoint *aPoint in gateVertices) {
        graphPoint[0] = aPoint.x;
        graphPoint[1] = aPoint.y;
        CGPoint viewPoint = [plotSpace plotAreaViewPointForDoublePrecisionPlotPoint:graphPoint];
        viewPoint = [aView.layer convertPoint:viewPoint fromLayer:plotSpace.graph.plotAreaFrame.plotArea];
        [viewVertices addObject:[NSValue valueWithCGPoint:viewPoint]];
    }
    return viewVertices;
}


- (NSArray *)gateVerticesFromViewVertices:(NSArray *)vertices inView:(UIView *)aView plotSpace:(CPTPlotSpace *)plotSpace
{
    NSMutableArray *gateVertices = NSMutableArray.array;
    double graphPoint[2];
    
    for (NSValue *aValue in vertices) {
        CGPoint pathPoint = aValue.CGPointValue;
        pathPoint = [aView.layer convertPoint:pathPoint toLayer:plotSpace.graph.plotAreaFrame.plotArea];
        [plotSpace doublePrecisionPlotPoint:graphPoint forPlotAreaViewPoint:pathPoint];
        FGGraphPoint *gateVertex = [FGGraphPoint pointWithX:(double)graphPoint[0] andY:(double)graphPoint[1]];
        [gateVertices addObject:gateVertex];
    }    
    return gateVertices;
}


#pragma mark - Gates Container View Delegate
- (void)gatesContainerView:(FGGatesContainerView *)gatesContainerView didModifyGateNo:(NSUInteger)gateNo gateType:(FGGateType)gateType vertices:(NSArray *)updatedVertices
{
    if (updatedVertices.count == 0) return;
    
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)self.graph.defaultPlotSpace;
    [[FGPendingOperations sharedInstance] cancelOperationsForGateWithTag:gateNo];
    NSArray *gateVertices = [self gateVerticesFromViewVertices:updatedVertices inView:gatesContainerView plotSpace:plotSpace];
    FGGate *modifiedGate  = self.displayedGates[gateNo];
    modifiedGate.vertices = gateVertices;
    
    FGGateCalculationOperation *gateOperation = [[FGGateCalculationOperation alloc] initWithGateData:modifiedGate.gateData
                                                                                             fcsFile:self.fcsFile
                                                                                        parentSubSet:self.parentGateCalculator.eventsInside
                                                                                   parentSubSetCount:self.parentGateCalculator.countOfEventsInside];
    gateOperation.delegate = self;
    gateOperation.gateTag = gateNo;
    [gateOperation setCompletionBlock:^{
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self.gateCalculationSpinner stopAnimating];
        }];
    }];
    [self.gateCalculationSpinner startAnimating];
    [[FGPendingOperations sharedInstance].gateCalculationQueue addOperation:gateOperation];
}


- (void)gatesContainerView:(FGGatesContainerView *)gatesContainerView didTapGate:(NSUInteger)gateNo inRect:(CGRect)rect
{
    [self showDetailPopoverForGate:self.displayedGates[gateNo] inRect:rect editMode:NO];
}


- (void)gatesContainerView:(FGGatesContainerView *)gatesContainerView didDoubleTapGate:(NSUInteger)gateNo
{
    FGGate *tappedGate = self.displayedGates[gateNo];
    [self.delegate plotViewController:self didSelectGate:tappedGate forPlot:self.plot];
}


#pragma mark - GateCalculationOperation Delegate
- (void)gateCalculationOperationDidFinish:(FGGateCalculationOperation *)operation
{
    FGGate *modifiedGate = self.displayedGates[operation.gateTag];
    modifiedGate.countOfEvents = [NSNumber numberWithUnsignedInteger:operation.subSetCount];
    NSError *error;
    [self.plot.managedObjectContext save:&error];
    if (error) NSLog(@"Error updating gate: %@", error.localizedDescription);
}


#pragma mark - Mark View Datasource
- (NSUInteger)numberOfGatesInGatesContainerView:(FGGatesContainerView *)gatesContainerView
{
    self.displayedGates = [[self.plot childGatesForXPar:self.plot.xParNumber.integerValue
                                                andYPar:self.plot.yParNumber.integerValue] mutableCopy];
    return self.displayedGates.count;
}


- (FGGateType)gatesContainerView:(FGGatesContainerView *)gatesContainerView gateTypeForGateNo:(NSUInteger)gateNo
{
    FGGate *gate = self.displayedGates[gateNo];
    return gate.type.integerValue;
}


- (NSArray *)gatesContainerView:(FGGatesContainerView *)gatesContainerView verticesForGate:(NSUInteger)gateNo
{
    FGGate *gate = self.displayedGates[gateNo];
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)self.graph.defaultPlotSpace;
    if (gate.xParNumber.integerValue == self.plot.xParNumber.integerValue) {
        return [self viewVerticesFromGateVertices:gate.vertices inView:self.gatesContainerView plotSpace:plotSpace];
    } else {
        return [self viewVerticesFromGateVertices:[FGGraphPoint switchXandYForGraphpoints:gate.vertices] inView:self.gatesContainerView plotSpace:plotSpace];
    }
}


#pragma mark - Gate Table View Controller delegate
- (void)didTapNewPlot:(FGGateTableViewController *)sender
{
    [self.detailPopoverController dismissPopoverAnimated:YES];
    [self.delegate plotViewController:self didSelectGate:sender.gate forPlot:self.plot];
}


- (void)didTapDeleteGate:(FGGateTableViewController *)sender
{
    if (self.detailPopoverController.isPopoverVisible) {
        [self.detailPopoverController dismissPopoverAnimated:YES];
    } else if (!IS_IPAD) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    FGGate *gate = sender.gate;
    [gate deleteInContext:gate.managedObjectContext];
    [NSManagedObjectContext.MR_defaultContext saveOnlySelfWithCompletion:^(BOOL success, NSError *error) {
        if (!error) {
            [self.gatesContainerView redrawGates];
        } else {
            UIAlertView *alertView = [UIAlertView.alloc initWithTitle:NSLocalizedString(@"Error", nil)
                                                              message:[NSLocalizedString(@"Could not delete gate \"", nil) stringByAppendingFormat:@"%@\"", gate.name]
                                                             delegate:nil
                                                    cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                                    otherButtonTitles: nil];
            [alertView show];
        }
    }];
}


#pragma mark - Background tap
- (void)addTapGestureRecognizerToBackgruond
{
    self.backgroundTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapBehind:)];
    [self.backgroundTapGestureRecognizer setNumberOfTapsRequired:1];
    self.backgroundTapGestureRecognizer.cancelsTouchesInView = NO; //So the user can still interact with controls in the modal view
    [self.view.window addGestureRecognizer:self.backgroundTapGestureRecognizer];
}


- (void)handleTapBehind:(UITapGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateEnded) {
        CGPoint location = [sender locationInView:nil]; //Passing nil gives us coordinates in the window
        if (![self.view pointInside:[self.view convertPoint:location fromView:self.view.window] withEvent:nil]) {
            [self.view.window removeGestureRecognizer:sender];
            [self doneTapped];
        }
    }
}

@end
