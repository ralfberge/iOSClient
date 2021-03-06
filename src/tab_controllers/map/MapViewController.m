//
//  MapViewController.m
//  ARIS
//
//  Created by Ben Longoria on 2/11/09.
//  Copyright 2009 University of Wisconsin. All rights reserved.
//

#import <UIKit/UIActionSheet.h>
#import <MapKit/MapKit.h>
#import "AppModel.h"
#import "Location.h"
#import "TileOverlay.h"
#import "TileOverlayView.h"
#import "MapViewController.h"
#import "StateControllerProtocol.h"
#import "AppModel.h"
#import "AppServices.h"
#import "Location.h"
#import "Player.h"
#import "ARISAppDelegate.h"
#import "AnnotationView.h"
#import "Media.h"

@interface MapViewController() <MKMapViewDelegate, UIActionSheetDelegate>
{
    NSMutableArray *locations;
    NSMutableArray *locationsToAdd;
    NSMutableArray *locationsToRemove;
    NSMutableArray *overlayArray;
    
    BOOL tracking;
    BOOL appSetNextRegionChange;

    __weak IBOutlet MKMapView *mapView;
    __weak IBOutlet UIToolbar *toolBar;
    UIBarButtonItem *mapTypeButton;
    UIBarButtonItem *playerButton;
    UIBarButtonItem *playerTrackingButton;

    NSTimer *refreshTimer;

    id<MKAnnotation> currentAnnotation; //PHIL HATES this...
    id<MapViewControllerDelegate, StateControllerProtocol> __unsafe_unretained delegate;
}

@property (nonatomic, strong) NSMutableArray *locations;
@property (nonatomic, strong) NSMutableArray *locationsToAdd;
@property (nonatomic, strong) NSMutableArray *locationsToRemove;
@property (nonatomic, strong) NSMutableArray *overlayArray;

@property (nonatomic, assign) BOOL tracking;
@property (nonatomic, assign) BOOL appSetNextRegionChange;

@property (nonatomic, weak) IBOutlet MKMapView *mapView;

@property (nonatomic, strong) NSTimer *refreshTimer;

@end

@implementation MapViewController

@synthesize locations;
@synthesize locationsToAdd;
@synthesize locationsToRemove;
@synthesize overlayArray;
@synthesize tracking;
@synthesize appSetNextRegionChange;
@synthesize mapView;
@synthesize refreshTimer;

- (id) initWithDelegate:(id<MapViewControllerDelegate, StateControllerProtocol>)d
{
    if(self = [super initWithNibName:@"MapViewController" bundle:nil delegate:d])
    {
        self.tabID = @"GPS";
        self.tabIconName = @"map";
        
        delegate = d;
        
        self.title = NSLocalizedString(@"MapViewTitleKey",@"");
        
        self.tracking = YES;
        self.locationsToAdd    = [[NSMutableArray alloc] initWithCapacity:10];
        self.locationsToRemove = [[NSMutableArray alloc] initWithCapacity:10];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeLoadingIndicator)     name:@"ConnectionLost"                               object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerMoved)                name:@"PlayerMoved"                                  object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(removeLoadingIndicator)     name:@"ReceivedLocationList"                         object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateOverlays)             name:@"NewOverlayListReady"                          object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addLocationsToNewQueue:)    name:@"NewlyAvailableLocationsAvailable"             object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addLocationsToRemoveQueue:) name:@"NewlyUnavailableLocationsAvailable"           object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(incrementBadge)             name:@"NewlyChangedLocationsGameNotificationSent"    object:nil];
    }
    return self;
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    
	self.mapView.delegate = self;
    
    playerTrackingButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"74-location.png"] style:UIBarButtonItemStylePlain target:self action:@selector(refreshButtonAction)];
    
    playerButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"player.png"] style:UIBarButtonItemStylePlain target:self action:@selector(playerButtonTouch)];
    
    UIBarButtonItem *flexible = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:self action:@selector(refreshButtonAction)];
    
    mapTypeButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"MapTypeKey",@"") style:UIBarButtonItemStylePlain target:self action:@selector(changeMapType:)];
    
    [toolBar setItems:[NSArray arrayWithObjects:playerTrackingButton, playerButton, flexible, mapTypeButton, nil]];
    
    [self updateOverlays];
    [self refresh];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if     ([[AppModel sharedAppModel].currentGame.mapType isEqualToString:@"SATELLITE"]) mapView.mapType = MKMapTypeSatellite;
    else if([[AppModel sharedAppModel].currentGame.mapType isEqualToString:@"HYBRID"])    mapView.mapType = MKMapTypeHybrid;
    else                                                                                  mapView.mapType = MKMapTypeStandard;
    
    if([AppModel sharedAppModel].currentGame.showPlayerLocation) [mapView setShowsUserLocation:YES];
    else [mapView setShowsUserLocation:NO];
    
    [self hideOrShowPlayerLocations];
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
	[[AppServices sharedAppServices] updateServerMapViewed];
	
    [self refreshViewFromModel];
	[self refresh];
	
	if(refreshTimer && [refreshTimer isValid]) [refreshTimer invalidate];
	refreshTimer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
}

- (void) changeMapType:(id)sender
{
    ARISAppDelegate* appDelegate = (ARISAppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate playAudioAlert:@"ticktick" shouldVibrate:NO];

    switch(mapView.mapType)
    {
        case MKMapTypeStandard:  mapView.mapType = MKMapTypeSatellite; break;
        case MKMapTypeSatellite: mapView.mapType = MKMapTypeHybrid;    break;
        case MKMapTypeHybrid:    mapView.mapType = MKMapTypeStandard;  break;
    }
}

- (void) refreshButtonAction
{
	self.tracking = YES;
	[[[MyCLController sharedMyCLController] locationManager] stopUpdatingLocation];
	[[[MyCLController sharedMyCLController] locationManager] startUpdatingLocation];
    
	[self refresh];
}

- (void) playerButtonTouch
{
    [AppModel sharedAppModel].hidePlayers = ![AppModel sharedAppModel].hidePlayers;
    [self hideOrShowPlayerLocations];
}

- (void) hideOrShowPlayerLocations
{
    if([AppModel sharedAppModel].hidePlayers)
    {
        if(self.mapView)
        {
            NSEnumerator *existingAnnotationsEnumerator = [[self.mapView annotations] objectEnumerator];
            NSObject<MKAnnotation> *annotation;
            while(annotation = [existingAnnotationsEnumerator nextObject])
            {
                if(annotation != self.mapView.userLocation && [annotation isKindOfClass:[Location class]] && [((Location *)annotation).gameObject type] == GameObjectPlayer)
                    [self.mapView removeAnnotation:annotation];
            }
        }
    }
    else

    [[[MyCLController sharedMyCLController] locationManager] stopUpdatingLocation];
    [[[MyCLController sharedMyCLController] locationManager] startUpdatingLocation];

    self.tracking = NO;
    [self refresh];
}

- (MKOverlayView *) mapView:(MKMapView *)mapView viewForOverlay:(id)overlay
{
    TileOverlayView *view = [[TileOverlayView alloc] initWithOverlay:overlay];
    //view.tileAlpha = 1;
    
    [AppModel sharedAppModel].overlayIsVisible = true;
    
    return view;
}

- (void) updateOverlays
{
    [overlayArray removeAllObjects];
    [mapView removeOverlays:[mapView overlays]];
    
    for(int i = 0; i < [[AppModel sharedAppModel].overlayList count]; i++)
    {
        TileOverlay *overlay = [[TileOverlay alloc] initWithIndex: i];
        if(overlay != NULL)
        {
            [overlayArray addObject:overlay];
            [mapView addOverlay:overlay];
        }
    }
}

- (void) refresh
{
    if(mapView)
    {
        if([AppModel sharedAppModel].player && ([AppModel sharedAppModel].currentGame.gameId != 0 && [AppModel sharedAppModel].player.playerId != 0))
        {
            [[AppServices sharedAppServices] fetchPlayerLocationList];
            [[AppServices sharedAppServices] fetchPlayerOverlayList];
            [self showLoadingIndicator];
        }
        if(tracking) [self zoomAndCenterMap];
    }
}

- (void) playerMoved
{
    if(mapView && tracking && [AppModel sharedAppModel].player && [AppModel sharedAppModel].currentGame.gameId != 0 && [AppModel sharedAppModel].player.playerId != 0)
        [self zoomAndCenterMap];
}

- (void) zoomAndCenterMap
{	
	appSetNextRegionChange = YES;
	
	//Center the map on the player
	MKCoordinateRegion region = mapView.region;
	region.center = [AppModel sharedAppModel].player.location.coordinate;
	region.span = MKCoordinateSpanMake(0.001f, 0.001f);
    
	[mapView setRegion:region animated:YES];
}

- (void) showLoadingIndicator
{
	UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
	[self navigationItem].rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:activityIndicator];
	[activityIndicator startAnimating];
}

- (void) removeLoadingIndicator
{
	[self navigationItem].rightBarButtonItem = nil;
}

- (void) addLocationsToNewQueue:(NSNotification *)notification
{
    //Quickly make sure we're not re-adding any info (let the 'newly' added ones take over)
    NSArray *newLocations = (NSArray *)[notification.userInfo objectForKey:@"newlyAvailableLocations"];
    for(int i = 0; i < [newLocations count]; i++)
    {
        for(int j = 0; j < [locationsToAdd count]; j++)
        {
            if([((Location *)[newLocations objectAtIndex:i]) compareTo:((Location *)[locationsToAdd objectAtIndex:j])])
                [locationsToAdd removeObjectAtIndex:j];
        }
    }
    [locationsToAdd addObjectsFromArray:newLocations];
    
    if(self.isViewLoaded && self.view.window) [self refreshViewFromModel];
}

- (void) addLocationsToRemoveQueue:(NSNotification *)notification
{
    //Quickly make sure we're not re-adding any info (let the 'newly' added ones take over)
    NSArray *lostLocations = (NSArray *)[notification.userInfo objectForKey:@"newlyUnavailableLocations"];
    for(int i = 0; i < [lostLocations count]; i++)
    {
        for(int j = 0; j < [locationsToRemove count]; j++)
        {
            if([((Location *)[lostLocations objectAtIndex:i]) compareTo:((Location *)[locationsToRemove objectAtIndex:j])])
                [locationsToRemove removeObjectAtIndex:j];
        }
    }
    [locationsToRemove addObjectsFromArray:lostLocations];
    
    //If told to remove something that is in queue to add, remove takes precedence 
    for(int i = 0; i < [locationsToRemove count]; i++)
    {
        for(int j = 0; j < [locationsToAdd count]; j++)
        {
            if([((Location *)[locationsToRemove objectAtIndex:i]) compareTo:((Location *)[locationsToAdd objectAtIndex:j])])
                [locationsToAdd removeObjectAtIndex:j];
        }
    }
    
    if(self.isViewLoaded && self.view.window) [self refreshViewFromModel];
}

- (void) refreshViewFromModel
{
    if(!mapView) return;
    
    //Remove old locations first
    id<MKAnnotation> annotation;
    Location *loc;
    for(int i = 0; i < [[mapView annotations] count]; i++)
    {
        if(![[[mapView annotations] objectAtIndex:i] isKindOfClass:[Location class]]) continue;
        annotation = [[mapView annotations] objectAtIndex:i];
        loc = (Location *)annotation; 
        if(loc.gameObject.type == GameObjectItem) ((Item *)loc.gameObject).qty = loc.qty;  
        for(int j = 0; j < [locationsToRemove count]; j++)
        {
            if([loc compareTo:((Location *)[locationsToRemove objectAtIndex:j])])
            {
                [mapView removeAnnotation:annotation];
                i--;
            }
        }
    }
    [locationsToRemove removeAllObjects];
    
    //Add new locations second
    Location *tmpLocation;
    for (int i = 0; i < [locationsToAdd count]; i++)
    {
        tmpLocation = (Location *)[locationsToAdd objectAtIndex:i];
        if(tmpLocation.hidden == NO && !(tmpLocation.gameObject.type == GameObjectPlayer && [AppModel sharedAppModel].hidePlayers))
            [mapView addAnnotation:tmpLocation];
    }
    [locationsToAdd removeAllObjects];
}

- (void) dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void) mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated
{
    if(!appSetNextRegionChange)
    {
        tracking = NO;
    }

    appSetNextRegionChange = NO;
}

- (MKAnnotationView *) mapView:(MKMapView *)myMapView viewForAnnotation:(id <MKAnnotation>)annotation
{
    if(annotation == mapView.userLocation) return nil;
    else return [[AnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:nil];
}

- (void) mapView:(MKMapView *)aMapView didSelectAnnotationView:(MKAnnotationView *)view
{
    if(view.annotation == aMapView.userLocation) return;
    Location *location = (Location *)view.annotation;

    NSMutableArray *buttonTitles = [NSMutableArray arrayWithCapacity:1];
    int cancelButtonIndex = 0;
    if(location.allowsQuickTravel)
    {
        [buttonTitles addObject: NSLocalizedString(@"GPSViewQuickTravelKey", @"")];
        cancelButtonIndex = 1;
    }
    [buttonTitles addObject: NSLocalizedString(@"CancelKey", @"")];

    UIActionSheet *actionSheet = [[UIActionSheet alloc]initWithTitle:location.name
                                                            delegate:self
                                                   cancelButtonTitle:nil
                                              destructiveButtonTitle:nil
                                                   otherButtonTitles:nil];
    actionSheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
    actionSheet.cancelButtonIndex = cancelButtonIndex;

    for(NSString *title in buttonTitles)
        [actionSheet addButtonWithTitle:title];

    [actionSheet showInView:view];
}

- (void) mapView:(MKMapView *)mV didAddAnnotationViews:(NSArray *)views
{
    for (AnnotationView *aView in views)
    {
        //Drop animation
        CGRect endFrame = aView.frame;
        aView.frame = CGRectMake(aView.frame.origin.x, aView.frame.origin.y - 230.0, aView.frame.size.width, aView.frame.size.height);
        [UIView animateWithDuration:0.45 delay:0.0 options:UIViewAnimationCurveEaseIn animations:^{[aView setFrame: endFrame];} completion:^(BOOL finished) {}];
    }
}

- (double) getZoomLevel:(MKMapView *)mV
{
    double MERCATOR_RADIUS = 85445659.44705395;
    double MAX_GOOGLE_LEVELS  = 20;
    CLLocationDegrees longitudeDelta = mV.region.span.longitudeDelta;
    CGFloat mapWidthInPixels = mV.bounds.size.width;
    double zoomScale = longitudeDelta * MERCATOR_RADIUS * M_PI / (180.0 * mapWidthInPixels);
    double zoomer = MAX_GOOGLE_LEVELS - log2( zoomScale );
    if ( zoomer < 0 ) zoomer = 0;
    return zoomer;
}

- (void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    currentAnnotation = [mapView.selectedAnnotations lastObject];

    [mapView deselectAnnotation:currentAnnotation animated:NO];

    if(buttonIndex != actionSheet.cancelButtonIndex)
    {
        [(ARISAppDelegate *)[[UIApplication sharedApplication] delegate] playAudioAlert:@"click" shouldVibrate:NO];
        [self performSelector:@selector(quickTravelToLastSelectedAnnotation) withObject:nil afterDelay:0.5];
    }
}

//THIS IS A HACK-
/*
 When the action sheet comes up, if you look closely, it fades out the buttons underneath (not the tab bar ones, the buttons above that).
 If you hit cancel, it will re-fade them back in. However, if you immediately launch a view over them, it thinks it doesn't have to re-animate
 them in, and they stay alpha = 0. So, I created this no-argument function such that it can be called "after a delay", allowing the animation 
 to begin. Stupid apple.
 */
- (void) quickTravelToLastSelectedAnnotation
{
    [delegate displayGameObject:((Location *)currentAnnotation).gameObject fromSource:((Location *)currentAnnotation)];
}

@end