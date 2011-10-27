//
//  NodeViewController.h
//  ARIS
//
//  Created by Kevin Harris on 5/11/09.
//  Copyright 2009 University of Wisconsin - Madison. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppModel.h"
#import "Node.h"
#import "ARISMoviePlayerViewController.h"
#import "AsyncImageView.h"

@interface NodeViewController : UIViewController <UITableViewDataSource,UITableViewDelegate,UIWebViewDelegate>
{
	Node *node;
	MPMoviePlayerViewController *mMoviePlayer; //only used if item is a video
	CGSize imageSize;
	UITableView *tableView;
	UIButton *mediaPlaybackButton;
    UIButton *contineuButton;
	IBOutlet UIScrollView *scrollView;
    BOOL isLink;
    BOOL hasMedia;
    BOOL imageLoaded, webLoaded;
    CGFloat newHeight;
    CGFloat imageNewHeight;
    AsyncImageView *mediaImageView;
    UIActivityIndicatorView *spinner;
    NSArray *cellArray;
}

@property(readwrite, retain) Node *node;
@property(readwrite, assign) BOOL isLink;
@property(readwrite, assign) BOOL hasMedia;
@property(nonatomic, retain) IBOutlet UITableView *tableView;
@property(nonatomic, retain) IBOutlet UIScrollView *scrollView;
@property (nonatomic, assign) CGFloat  newHeight;
@property (nonatomic, assign) CGFloat  imageNewHeight;
@property(nonatomic, retain)UIActivityIndicatorView *spinner;
@property(nonatomic,retain)AsyncImageView *mediaImageView;
@property(nonatomic, retain) IBOutlet UIButton *continueButton;
@property(nonatomic, retain)NSArray *cellArray;
-(void)imageFinishedLoading;
- (void) refreshView;
- (int) calculateTextHeight:(NSString *)text;
@end

