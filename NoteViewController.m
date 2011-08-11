//
//  NoteViewController.m
//  ARIS
//
//  Created by Brian Thiel on 8/9/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "NoteViewController.h"
#import "Note.h"
#import "TitleAndDecriptionFormViewController.h"
#import "ARISAppDelegate.h"
#import "AppServices.h"

@implementation NoteViewController
@synthesize textBox,saveButton,note;
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = @"Note";
        self.tabBarItem.image = [UIImage imageNamed:@"noteicon.png"];

    }
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    if(self.note)
    self.title = self.note.name;
    UIBarButtonItem *hideKeyboardButton = [[UIBarButtonItem alloc] initWithTitle:@"Hide Keyboard" style:UIBarButtonItemStylePlain target:self action:@selector(hideKeyboard)];      
	self.navigationItem.rightBarButtonItem = hideKeyboardButton;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
-(void)textViewDidBeginEditing:(UITextView *)textView{
    if([self.textBox.text isEqualToString:@"Write note here..."])
    [self.textBox setText:@""];
    self.textBox.frame = CGRectMake(0, 0, 320, 230);
}
-(void)hideKeyboard {
    [self.textBox resignFirstResponder];
    self.textBox.frame = CGRectMake(0, 0, 320, 330);
}

-(void)saveButtonTouchAction{
    [self.saveButton setBackgroundColor:[UIColor lightGrayColor]];
    [self displayTitleandDescriptionForm];
}

- (void)displayTitleandDescriptionForm {
    TitleAndDecriptionFormViewController *titleAndDescForm = [[TitleAndDecriptionFormViewController alloc] 
                                                              initWithNibName:@"TitleAndDecriptionFormViewController" bundle:nil];
	
	titleAndDescForm.delegate = self;
	[self.view addSubview:titleAndDescForm.view];
}

- (void)titleAndDescriptionFormDidFinish:(TitleAndDecriptionFormViewController*)titleAndDescForm{
	NSLog(@"NoteVC: Back from form");
	[titleAndDescForm.view removeFromSuperview];
   
	[[AppServices sharedAppServices] createItemAndGiveToPlayerFromFileData:nil 
                                                                  fileName:@"note123"
                                                                     title:titleAndDescForm.titleField.text 
                                                            description:self.textBox.text];
    
    [titleAndDescForm release];	
    NSString *tab;
    ARISAppDelegate* appDelegate = (ARISAppDelegate *)[[UIApplication sharedApplication] delegate];        
    
    //Exit to Inventory Tab
    for(int i = 0;i < [appDelegate.tabBarController.customizableViewControllers count];i++)
    {
        tab = [[appDelegate.tabBarController.customizableViewControllers objectAtIndex:i] title];
        tab = [tab lowercaseString];
        if([tab isEqualToString:@"inventory"])
        {
            appDelegate.tabBarController.selectedIndex = i;
        }
    }
    
}
@end
