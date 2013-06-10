//
//  ItemActionViewController.h
//  ARIS
//
//  Created by Brian Thiel on 7/11/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ItemViewController.h"

@class Item;
@interface ItemActionViewController : UIViewController
- (id) initWithItem:(Item *)i mode:(ItemDetailsModeType)mode delegate:(id)delegate;
@end
