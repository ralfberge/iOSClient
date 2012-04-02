//
//  StartOverViewController.h
//  ARIS
//
//  Created by David J Gagnon on 4/20/10.
//  Copyright 2010 University of Wisconsin - Madison. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface StartOverViewController : UIViewController {
	IBOutlet UIButton *startOverButton;
	IBOutlet UILabel *warningLabel;
    UIAlertView *alert;
}
@property (nonatomic) UIAlertView *alert;
-(IBAction)startOverButtonPressed: (id) sender;
-(void)dismissAlert;
@end
