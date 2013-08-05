//
//  NpcScriptViewController.m
//  ARIS
//
//  Created by Phil Dougherty on 8/5/13.
//
//

#import "NpcScriptViewController.h"
#import "NpcScriptElementView.h"
#import "NpcScriptOption.h"
#import "ScriptParser.h"
#import "Script.h"
#import "ScriptElement.h"
#import "ARISMediaView.h"
#import "AppModel.h"
#import "AppServices.h"
#import "ARISMoviePlayerViewController.h"

@interface NpcScriptViewController() <ScriptParserDelegate, NPcScriptElementViewDelegate, GameObjectViewControllerDelegate>
{
    Npc *npc;
    
    ScriptParser *parser;
    NpcScriptOption *currentScriptOption;
    Script *currentScript;
    ScriptElement *currentScriptElement;
    
    NpcScriptElementView *npcView;
    NpcScriptElementView *pcView;
    
    int textBoxSizeState;
    CGRect viewFrame;
	
    id<NpcScriptViewControllerDelegate> __unsafe_unretained delegate;
}

@property (nonatomic, strong) Npc *npc;

@property (nonatomic, strong) ScriptParser *parser;
@property (nonatomic, strong) NpcScriptOption *currentScriptOption;
@property (nonatomic, strong) Script *currentScript;
@property (nonatomic, strong) ScriptElement *currentScriptElement;

@property (nonatomic, strong) NpcScriptElementView *npcView;
@property (nonatomic, strong) NpcScriptElementView *pcView;

@end

@implementation NpcScriptViewController

@synthesize npc;
@synthesize parser;
@synthesize currentScriptOption;
@synthesize currentScript;
@synthesize currentScriptElement;
@synthesize npcView;
@synthesize pcView;

- (id) initWithNpc:(Npc *)n frame:(CGRect)f delegate:(id<NpcScriptViewControllerDelegate>)d
{
    if(self = [super init])
    {
        self.npc = n;
        self.parser = [[ScriptParser  alloc] initWithDelegate:self];
        
        viewFrame = f; //ugh
        
        delegate = d;
    }
    return self;
}

- (void) loadView
{
    [super loadView];
    
    self.view.frame = viewFrame;
    self.view.bounds = CGRectMake(0,0,viewFrame.size.width,viewFrame.size.height);
    
    Media *pcMedia;
    if     ([AppModel sharedAppModel].currentGame.pcMediaId != 0) pcMedia = [[AppModel sharedAppModel] mediaForMediaId:[AppModel sharedAppModel].currentGame.pcMediaId ofType:nil];
    else if([AppModel sharedAppModel].player.playerMediaId  != 0) pcMedia = [[AppModel sharedAppModel] mediaForMediaId:[AppModel sharedAppModel].player.playerMediaId ofType:nil];
    if(pcMedia) self.pcView = [[NpcScriptElementView alloc] initWithFrame:self.view.bounds media:pcMedia                                    title:@"You" delegate:self];
    else        self.pcView = [[NpcScriptElementView alloc] initWithFrame:self.view.bounds image:[UIImage imageNamed:@"DefaultPCImage.png"] title:@"You" delegate:self];
    [self.view addSubview:self.pcView];
    
    Media *npcMedia;
    if(self.npc.mediaId != 0) npcMedia = [[AppModel sharedAppModel] mediaForMediaId:self.npc.mediaId ofType:nil];
    if(npcMedia) self.npcView = [[NpcScriptElementView alloc] initWithFrame:self.view.bounds media:npcMedia                                   title:self.npc.name delegate:self];
    else         self.npcView = [[NpcScriptElementView alloc] initWithFrame:self.view.bounds image:[UIImage imageNamed:@"DefaultPCImage.png"] title:self.npc.name delegate:self];
    [self.view addSubview:self.npcView];
    
    [self movePcIn];
}

- (void) loadScriptOption:(NpcScriptOption *)o
{
    self.currentScriptOption = o;
    [self.parser parseText:o.scriptText];
}

- (void) scriptDidFinishParsing:(Script *)s
{
    //Send global npc change requests to delegate (properties on dialog tag- would make more sense if they were on the npc level, but whatevs)
    if(s.hideLeaveConversationButtonSpecified) [delegate scriptRequestsHideLeaveConversation:s.hideLeaveConversationButton];
    if(s.leaveConversationButtonTitle)         [delegate scriptRequestsLeaveConversationTitle:s.leaveConversationButtonTitle];
    if(s.defaultPcTitle)                       [delegate scriptRequestsOptionsPcTitle:s.defaultPcTitle];
    if(s.adjustTextArea)                       [self adjustTextArea:s.adjustTextArea];
    
    self.currentScript = s;
    [self readyNextScriptElementForDisplay];
}

- (void) readyNextScriptElementForDisplay
{
    self.currentScriptElement = [self.currentScript nextScriptElement];
    if(!self.currentScriptElement)
    {
        [[AppServices sharedAppServices] updateServerNodeViewed:self.currentScriptOption.nodeId fromLocation:0];
        [self movePcIn];
        [delegate scriptEndedExitToType:self.currentScript.exitToType title:self.currentScript.exitToTabTitle id:self.currentScript.exitToTypeId];
        return;
    }
    
    if([self.currentScriptElement.type isEqualToString:@"pc"])
    {
        [self.pcView loadScriptElement:self.currentScriptElement];
        [self movePcIn];
    }
    else if([self.currentScriptElement.type isEqualToString:@"npc"])
    {
        [self.npcView loadScriptElement:self.currentScriptElement];
        [self moveNpcIn];
    }
    else if([currentScriptElement.type isEqualToString:@"video"])
    {
        [self moveAllOut];
        Media *media = [[AppModel sharedAppModel] mediaForMediaId:currentScriptElement.typeId ofType:@"VIDEO"];
        ARISMoviePlayerViewController *mMoviePlayer = [[ARISMoviePlayerViewController alloc] initWithContentURL:[NSURL URLWithString:media.url]];
        mMoviePlayer.moviePlayer.shouldAutoplay = YES;
        [mMoviePlayer.moviePlayer prepareToPlay];
        [self presentMoviePlayerViewControllerAnimated:mMoviePlayer];
    }
    else if([currentScriptElement.type isEqualToString:@"panoramic"])
    {
        [self moveAllOut];
        [self.navigationController pushViewController:[[[AppModel sharedAppModel] panoramicForPanoramicId:currentScriptElement.typeId] viewControllerForDelegate:self fromSource:self] animated:YES];
    }
    else if([currentScriptElement.type isEqualToString:@"webpage"])
    {
        [self moveAllOut];
        [self.navigationController pushViewController:[[[AppModel sharedAppModel] webPageForWebPageId:currentScriptElement.typeId] viewControllerForDelegate:self fromSource:self] animated:YES];
    }
    else if([currentScriptElement.type isEqualToString:@"node"])
    {
        [self moveAllOut];
        [self.navigationController pushViewController:[[[AppModel sharedAppModel] nodeForNodeId:currentScriptElement.typeId] viewControllerForDelegate:self fromSource:self] animated:YES];
    }
    else if([currentScriptElement.type isEqualToString:@"item"])
    {
        [self moveAllOut];
        [self.navigationController pushViewController:[[[AppModel sharedAppModel] itemForItemId:currentScriptElement.typeId] viewControllerForDelegate:self fromSource:self] animated:YES];
    }
}

- (void) scriptElementViewRequestsTitle:(NSString *)t
{
    [delegate scriptRequestsTitle:t];
}

- (void) scriptElementViewRequestsContinue:(NpcScriptElementView *)s
{
    [s fadeWithCallback:@selector(readyNextScriptElementForDisplay)];
}

- (void) gameObjectViewControllerRequestsDismissal:(GameObjectViewController *)govc
{
    
}

- (void) audioPlayerDidFinishPlaying:(AVAudioPlayer *)audioPlayer successfully:(BOOL)flag
{
    [[AVAudioSession sharedInstance] setActive: NO error: nil];
}

- (void) scriptElementViewRequestsTextBoxArea:(NSString *)a
{
    [self adjustTextArea:a];
}

- (void) scriptElementViewRequestsHideTextAdjust:(BOOL)h
{
    
}

- (void) adjustTextArea:(NSString *)area
{
    if([area isEqualToString:@"hidden"])    [self toggleTextBoxSize:0];
    else if([area isEqualToString:@"half"]) [self toggleTextBoxSize:1];
    else if([area isEqualToString:@"full"]) [self toggleTextBoxSize:2];
}

- (void) toggleNextTextBoxSize
{
    [delegate scriptRequestsTextBoxSize:(textBoxSizeState+1)%3];
}

- (void) toggleTextBoxSize:(int)s
{
    ARISAppDelegate* appDelegate = (ARISAppDelegate *)[[UIApplication sharedApplication] delegate];
	[appDelegate playAudioAlert:@"swish" shouldVibrate:NO];
    [delegate scriptRequestsTextBoxSize:s];
    [self.pcView  toggleTextBoxSize:s];
    [self.npcView toggleTextBoxSize:s];
}

#define pcOffscreenRect  CGRectMake(  self.pcView.frame.size.width, self.pcView.frame.origin.y, self.pcView.frame.size.width, self.pcView.frame.size.height)
#define npcOffscreenRect CGRectMake(0-self.npcView.frame.size.width,self.npcView.frame.origin.y,self.npcView.frame.size.width,self.npcView.frame.size.height)
- (void) movePcIn
{
	[self movePcTo:self.view.frame  withAlpha:1.0
		  andNpcTo:npcOffscreenRect withAlpha:0.0];
}

- (void) moveNpcIn
{
	[self movePcTo:pcOffscreenRect withAlpha:0.0
		  andNpcTo:self.view.frame withAlpha:1.0];
}

- (void) moveAllOut
{
	[self movePcTo:pcOffscreenRect  withAlpha:0.0
		  andNpcTo:npcOffscreenRect withAlpha:0.0];
}

- (void) movePcTo:(CGRect)pcRect  withAlpha:(CGFloat)pcAlpha
		 andNpcTo:(CGRect)npcRect withAlpha:(CGFloat)npcAlpha
{
	[UIView beginAnimations:@"movement" context:nil];
	[UIView setAnimationCurve:UIViewAnimationCurveLinear];
	[UIView setAnimationDuration:0.25];
	npcView.frame = npcRect;
	npcView.alpha = npcAlpha;
	pcView.frame = pcRect;
	pcView.alpha = pcAlpha;
	[UIView commitAnimations];
}

@end
