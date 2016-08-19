//
// Copyright (c) 2015 Related Code - http://relatedcode.com
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "Incoming.h"
#import "Outgoing.h"

#import "AudioMediaItem.h"
#import "PhotoMediaItem.h"
#import "VideoMediaItem.h"

#import "ChatView.h"
#import "MapView.h"
#import "StickersView.h"
#import "ProfileView.h"
#import "NavigationController.h"


//-------------------------------------------------------------------------------------------------------------------------------------------------
@interface ChatView()
{
	NSString *groupId;

	BOOL initialized;
	int typingCounter;

	Firebase *firebase1;
	Firebase *firebase2;

	NSInteger loaded;
	NSMutableArray *loads;
	NSMutableArray *items;
	NSMutableArray *messages;

	NSMutableDictionary *started;
	NSMutableDictionary *avatars;

	JSQMessagesBubbleImage *bubbleImageOutgoing;
	JSQMessagesBubbleImage *bubbleImageIncoming;
	JSQMessagesAvatarImage *avatarImageBlank;
}
@end
//-------------------------------------------------------------------------------------------------------------------------------------------------

@implementation ChatView{

    UICollectionReusableView *reusableview;
    UIActivityIndicatorView  *av;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (id)initWith:(NSString *)groupId_
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	self = [super init];
	groupId = groupId_;
	return self;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)viewDidLoad
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[super viewDidLoad];
	self.title = @"Chat";
	//---------------------------------------------------------------------------------------------------------------------------------------------
	loads = [[NSMutableArray alloc] init];
	items = [[NSMutableArray alloc] init];
	messages = [[NSMutableArray alloc] init];
	started = [[NSMutableDictionary alloc] init];
	avatars = [[NSMutableDictionary alloc] init];
    
	//---------------------------------------------------------------------------------------------------------------------------------------------
	self.senderId = [PFUser currentId];
	self.senderDisplayName = [PFUser currentName];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	JSQMessagesBubbleImageFactory *bubbleFactory = [[JSQMessagesBubbleImageFactory alloc] init];
	bubbleImageOutgoing = [bubbleFactory outgoingMessagesBubbleImageWithColor:COLOR_OUTGOING];
	bubbleImageIncoming = [bubbleFactory incomingMessagesBubbleImageWithColor:COLOR_INCOMING];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	avatarImageBlank = [JSQMessagesAvatarImageFactory avatarImageWithImage:[UIImage imageNamed:@"chat_blank"] diameter:30.0];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	[JSQMessagesCollectionViewCell registerMenuAction:@selector(actionCopy:)];
	[JSQMessagesCollectionViewCell registerMenuAction:@selector(actionDelete:)];
	[JSQMessagesCollectionViewCell registerMenuAction:@selector(actionSave:)];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	UIMenuItem *menuItemCopy = [[UIMenuItem alloc] initWithTitle:@"Copy" action:@selector(actionCopy:)];
	UIMenuItem *menuItemDelete = [[UIMenuItem alloc] initWithTitle:@"Delete" action:@selector(actionDelete:)];
	UIMenuItem *menuItemSave = [[UIMenuItem alloc] initWithTitle:@"Save" action:@selector(actionSave:)];
	[UIMenuController sharedMenuController].menuItems = @[menuItemCopy, menuItemDelete, menuItemSave];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	firebase1 = [[Firebase alloc] initWithUrl:[NSString stringWithFormat:@"%@/Message/%@", FIREBASE, groupId]];
	firebase2 = [[Firebase alloc] initWithUrl:[NSString stringWithFormat:@"%@/Typing/%@", FIREBASE, groupId]];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	ClearRecentCounter(groupId);
	//---------------------------------------------------------------------------------------------------------------------------------------------
	[self loadMessages];
	[self typingIndicatorLoad];
	[self typingIndicatorSave:@NO];
    
    
    //----------------------------------------
    [self.collectionView registerClass:[UICollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"HeaderView"];

}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)viewDidAppear:(BOOL)animated
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[super viewDidAppear:animated];
	self.collectionView.collectionViewLayout.springinessEnabled = NO;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)viewWillDisappear:(BOOL)animated
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[super viewWillDisappear:animated];
	if (self.isMovingFromParentViewController)
	{
		ClearRecentCounter(groupId);
		[firebase1 removeAllObservers];
		[firebase2 removeAllObservers];
	}
}

#pragma mark - Backend methods

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)loadMessages
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	initialized = NO;
	self.automaticallyScrollsToMostRecentMessage = NO;
	//---------------------------------------------------------------------------------------------------------------------------------------------
	[firebase1 observeEventType:FEventTypeChildAdded withBlock:^(FDataSnapshot *snapshot)
	{
		if (initialized)
		{
			BOOL incoming = [self addMessage:snapshot.value];
			if (incoming) [self messageUpdate:snapshot.value];
			if (incoming) [JSQSystemSoundPlayer jsq_playMessageReceivedSound];
			[self finishReceivingMessage];
		}
        else {
            // NSLog(@"%@", snapshot.value);
            [loads addObject:snapshot.value];
        }
	}];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	[firebase1 observeEventType:FEventTypeChildChanged withBlock:^(FDataSnapshot *snapshot)
	{
		[self updateMessage:snapshot.value];
	}];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	[firebase1 observeEventType:FEventTypeChildRemoved withBlock:^(FDataSnapshot *snapshot)
	{
		[self deleteMessage:snapshot.value];
	}];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	[firebase1 observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot)
	{
		[self insertMessages];
		[self scrollToBottomAnimated:NO];
		initialized	= YES;
	}];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)insertMessages
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
    NSLog(@"%d", [loads count]);
    
    NSInteger max = [loads count];//-loaded;
	NSInteger min = max-INSERT_MESSAGES;
    if (min < 0){ min = 0;}
    
	//---------------------------------------------------------------------------------------------------------------------------------------------
	for (NSInteger i=max-1; i>=min; i--)
	{
		NSDictionary *item = loads[i];
		BOOL incoming = [self insertMessage:item];
        if (incoming){
            [self messageUpdate:item];
        }
		loaded++;
	}
	//---------------------------------------------------------------------------------------------------------------------------------------------
	self.automaticallyScrollsToMostRecentMessage = NO;
	[self finishReceivingMessage];
	self.automaticallyScrollsToMostRecentMessage = YES;
	//---------------------------------------------------------------------------------------------------------------------------------------------
    self.showLoadEarlierMessagesHeader = NO;//(loaded != [loads count]);
    
    // self.showTypingIndicator = (loaded != [loads count]);
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (BOOL)insertMessage:(NSDictionary *)item
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	Incoming *incoming = [[Incoming alloc] initWith:groupId CollectionView:self.collectionView];
	JSQMessage *message = [incoming create:item];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	[items insertObject:item atIndex:0];
	[messages insertObject:message atIndex:0];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	return [self incoming:item];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (BOOL)addMessage:(NSDictionary *)item
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	Incoming *incoming = [[Incoming alloc] initWith:groupId CollectionView:self.collectionView];
	JSQMessage *message = [incoming create:item];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	[items addObject:item];
	[messages addObject:message];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	return [self incoming:item];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)updateMessage:(NSDictionary *)item
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	for (int index=0; index<[items count]; index++)
	{
		NSDictionary *temp = items[index];
		if ([item[@"messageId"] isEqualToString:temp[@"messageId"]])
		{
			items[index] = item;
			[self.collectionView reloadData];
			break;
		}
	}
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)deleteMessage:(NSDictionary *)item
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	for (int index=0; index<[items count]; index++)
	{
		NSDictionary *temp = items[index];
		if ([item[@"messageId"] isEqualToString:temp[@"messageId"]])
		{
			[items removeObjectAtIndex:index];
			[messages removeObjectAtIndex:index];
			[self.collectionView reloadData];
			break;
		}
	}
}

#pragma mark - Picture methods

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)loadAvatar:(NSString *)senderId
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	if (started[senderId] == nil) started[senderId] = @YES; else return;
	//---------------------------------------------------------------------------------------------------------------------------------------------
	if ([senderId isEqualToString:[PFUser currentId]])
	{
		[self downloadThumbnail:[PFUser currentUser]];
		return;
	}
	//---------------------------------------------------------------------------------------------------------------------------------------------
	PFQuery *query = [PFQuery queryWithClassName:PF_USER_CLASS_NAME];
	[query whereKey:PF_USER_OBJECTID equalTo:senderId];
	[query setCachePolicy:kPFCachePolicyCacheThenNetwork];
	[query getFirstObjectInBackgroundWithBlock:^(PFObject *object, NSError *error)
	{
		if (error == nil)
		{
			PFUser *user = (PFUser *) object;
			[self downloadThumbnail:user];
		}
		else [started removeObjectForKey:senderId];
	}];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)downloadThumbnail:(PFUser *)user
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[AFDownload start:user[PF_USER_THUMBNAIL] complete:^(NSString *path, NSError *error, BOOL network)
	{
		if (error == nil)
		{
			UIImage *image = [[UIImage alloc] initWithContentsOfFile:path];
			avatars[user.objectId] = [JSQMessagesAvatarImageFactory avatarImageWithImage:image diameter:30.0];
			[self performSelector:@selector(delayedReload) withObject:nil afterDelay:0.1];
		}
		else [started removeObjectForKey:user.objectId];
	}];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)delayedReload
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[self.collectionView reloadData];
}

#pragma mark - Message sendig methods

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)messageSend:(NSString *)text Video:(NSURL *)video Picture:(UIImage *)picture Audio:(NSString *)audio
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	Outgoing *outgoing = [[Outgoing alloc] initWith:groupId View:self.navigationController.view];
	[outgoing send:text Video:video Picture:picture Audio:audio];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	[JSQSystemSoundPlayer jsq_playMessageSentSound];
	[self finishSendingMessage];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)messageUpdate:(NSDictionary *)item
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
    // https://github.com/caiquan/Beepr_sumeet_new/blob/b68b30208dc3b3aee2b0a188b732d8f1d9707c2c/Classes/Chat/ChatView.m
    // http://stackoverflow.com/questions/29494364/firebase-ios-updating-data
    // if ([item[@"status"] isEqualToString:@"Read"]) return;
    //---------------------------------------------------------------------------------------------------------------------------------------------
//    [[firebase1 childByAppendingPath:item] updateChildValues:@{@"status":@"Read"} withCompletionBlock:^(NSError *error, Firebase *ref)
//     {
//         if (error != nil) NSLog(@"ChatView messageUpdate network error.");
//     }];
    
    if([item[@"status"] isEqualToString:@"Read"]) return;
    
//    [item setValue:@"Read" forKey:@"status"] ;// = @"Read";
//    
//    Firebase *post1Ref = [firebase1 childByAutoId];
//    [post1Ref setValue: item];
    
    [[firebase1 childByAppendingPath:item[@"messageId"]] updateChildValues:@{@"status":@"Read"} withCompletionBlock:^(NSError *error, Firebase *ref)
     {
         if (error != nil) NSLog(@"ChatView messageUpdate network error.");
     }];
    
    NSLog(@"%@", item);
    NSLog(@"%@", item[@"key"]);
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)messageDelete:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
    
    NSDictionary *item = items[indexPath.item];
    //---------------------------------------------------------------------------------------------------------------------------------------------
    [[firebase1 childByAppendingPath:item[@"messageId"]] removeValueWithCompletionBlock:^(NSError *error, Firebase *ref)
     {
         if (error != nil) NSLog(@"ChatView messageDelete network error.");
     }];
}

#pragma mark - Typing indicator

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)typingIndicatorLoad
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
    
    [firebase2 observeEventType:FEventTypeChildChanged withBlock:^(FDataSnapshot *snapshot)
     {
//         CatalyzeUser *user = [CatalyzeUser currentUser];
//         
//         if ([user.usersId isEqualToString:snapshot.key] == NO)
//         {
//             BOOL typing = [snapshot.value boolValue];
//             self.showTypingIndicator = typing;
//             if (typing) [self scrollToBottomAnimated:YES];
//         }
         
         PFUser *cur = [PFUser currentUser];
         
         NSLog(@"cur => %@", cur.objectId);
         NSLog(@"snapshot.key => %@", snapshot.key);
         
         if ([cur.objectId isEqualToString:snapshot.key] == NO){
         
             BOOL typing = [snapshot.value boolValue];
             self.showTypingIndicator = typing;
             if (typing) [self scrollToBottomAnimated:YES];
         }
     }];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)typingIndicatorStart
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
    
    typingCounter++;
    [self typingIndicatorSave:@YES];
    [self performSelector:@selector(typingIndicatorStop) withObject:nil afterDelay:2.0];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)typingIndicatorStop
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
    
    typingCounter--;
    if (typingCounter == 0) [self typingIndicatorSave:@NO];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)typingIndicatorSave:(NSNumber *)typing
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
    
//    CatalyzeUser *user = [CatalyzeUser currentUser];
//    
//    [firebase2 updateChildValues:@{user.usersId:typing} withCompletionBlock:^(NSError *error, Firebase *ref)
//     {
//         if (error != nil) NSLog(@"ChatView typingIndicatorSave network error.");
//     }];
    
    [firebase2 updateChildValues:@{[PFUser currentUser].objectId:typing} withCompletionBlock:^(NSError *error, Firebase *ref)
     {
         if (error != nil) NSLog(@"ChatView typingIndicatorSave network error.");
     }];
}

#pragma mark - UITextViewDelegate

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[self typingIndicatorStart];
	return YES;
}

#pragma mark - JSQMessagesViewController method overrides

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)didPressSendButton:(UIButton *)button withMessageText:(NSString *)text senderId:(NSString *)senderId senderDisplayName:(NSString *)name date:(NSDate *)date
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[self messageSend:text Video:nil Picture:nil Audio:nil];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)didPressAccessoryButton:(UIButton *)sender
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[self actionAttach];
}

#pragma mark - JSQMessages CollectionView DataSource

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (id<JSQMessageData>)collectionView:(JSQMessagesCollectionView *)collectionView messageDataForItemAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
    // JSQMessage *jsQMessage = messages[indexPath.item];
    NSLog(@"%@", messages[indexPath.item]);
    return messages[indexPath.item];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (id<JSQMessageBubbleImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView
			 messageBubbleImageDataForItemAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	if ([self outgoing:items[indexPath.item]])
	{
		return bubbleImageOutgoing;
	}
	else return bubbleImageIncoming;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (id<JSQMessageAvatarImageDataSource>)collectionView:(JSQMessagesCollectionView *)collectionView
					avatarImageDataForItemAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	JSQMessage *message = messages[indexPath.item];
	if (avatars[message.senderId] == nil)
	{
		[self loadAvatar:message.senderId];
		return avatarImageBlank;
	}
	else return avatars[message.senderId];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	if (indexPath.item % 3 == 0)
	{
		JSQMessage *message = messages[indexPath.item];
		return [[JSQMessagesTimestampFormatter sharedFormatter] attributedTimestampForDate:message.date];
	}
	else return nil;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	if ([self incoming:items[indexPath.item]])
	{
		JSQMessage *message = messages[indexPath.item];
		if (indexPath.item > 0)
		{
			JSQMessage *previous = messages[indexPath.item-1];
			if ([previous.senderId isEqualToString:message.senderId])
			{
				return nil;
			}
		}
		return [[NSAttributedString alloc] initWithString:message.senderDisplayName];
	}
	else return nil;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	NSDictionary *item = items[indexPath.item];
	if ([self outgoing:item])
	{
		return [[NSAttributedString alloc] initWithString:item[@"status"]];
	}
	else return nil;
}

#pragma mark - UICollectionView DataSource

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	return [messages count];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (UICollectionViewCell *)collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	UIColor *color = [self outgoing:items[indexPath.item]] ? [UIColor whiteColor] : [UIColor blackColor];

	JSQMessagesCollectionViewCell *cell = (JSQMessagesCollectionViewCell *)[super collectionView:collectionView cellForItemAtIndexPath:indexPath];
	cell.textView.textColor = color;
	cell.textView.linkTextAttributes = @{NSForegroundColorAttributeName:color};

	return cell;
}

#pragma mark - UICollectionView Delegate

/*
- (UICollectionReusableView *)collectionView:(JSQMessagesCollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath
{
    NSLog(@"");
    
    if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
        
         reusableview = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"HeaderView" forIndexPath:indexPath];
        
//        if (reusableview==nil) {
//            reusableview=[[UICollectionReusableView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
//        }
        
//        UILabel *label=[[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
//        label.text=[NSString stringWithFormat:@"Recipe Group #%i", indexPath.section + 1];
//        [reusableview addSubview:label];
        
        av = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        av.frame = CGRectMake(round((reusableview.frame.size.width - 25) / 2), round((reusableview.frame.size.height - 25) / 2), 25, 25);
        [av startAnimating];
        [reusableview addSubview:av];
        
        return reusableview;
    }
    return nil;
    
//    if (self.showTypingIndicator && [kind isEqualToString:UICollectionElementKindSectionFooter]) {
//        return [collectionView dequeueTypingIndicatorFooterViewForIndexPath:indexPath];
//    }
//    else if (self.showLoadEarlierMessagesHeader && [kind isEqualToString:UICollectionElementKindSectionHeader]) {
//        return [collectionView dequeueLoadEarlierMessagesViewHeaderForIndexPath:indexPath];
//    }
    
//    HeaderTableView *headerTableView = [[[NSBundle mainBundle] loadNibNamed:@"HeaderTableView" owner:self options:nil] objectAtIndex:0];
//    
//    
//    return headerTableView;
    
//    UICollectionViewFlowLayout *layout= [[UICollectionViewFlowLayout alloc]init];
//    
//    return [[UICollectionView alloc]initWithFrame:CGRectMake(0, 0, 390, 300) collectionViewLayout:layout];
}
*/

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (BOOL)collectionView:(UICollectionView *)collectionView canPerformAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath
			withSender:(id)sender
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	NSDictionary *item = items[indexPath.item];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	if (action == @selector(actionCopy:))
	{
		if ([item[@"type"] isEqualToString:@"text"]) return YES;
	}
	if (action == @selector(actionDelete:))
	{
		if ([self outgoing:item]) return YES;
	}
	if (action == @selector(actionSave:))
	{
		if ([item[@"type"] isEqualToString:@"picture"]) return YES;
		if ([item[@"type"] isEqualToString:@"audio"]) return YES;
		if ([item[@"type"] isEqualToString:@"video"]) return YES;
	}
	return NO;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)collectionView:(UICollectionView *)collectionView performAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath
			withSender:(id)sender
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	if (action == @selector(actionCopy:))		[self actionCopy:indexPath];
	if (action == @selector(actionDelete:))		[self actionDelete:indexPath];
	if (action == @selector(actionSave:))		[self actionSave:indexPath];
}

#pragma mark - JSQMessages collection view flow layout delegate

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
				   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	if (indexPath.item % 3 == 0)
	{
		return kJSQMessagesCollectionViewCellLabelHeightDefault;
	}
	else return 0;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
				   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	if ([self incoming:items[indexPath.item]])
	{
		if (indexPath.item > 0)
		{
			JSQMessage *message = messages[indexPath.item];
			JSQMessage *previous = messages[indexPath.item-1];
			if ([previous.senderId isEqualToString:message.senderId])
			{
				return 0;
			}
		}
		return kJSQMessagesCollectionViewCellLabelHeightDefault;
	}
	else return 0;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
				   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	if ([self outgoing:items[indexPath.item]])
	{
		return kJSQMessagesCollectionViewCellLabelHeightDefault;
	}
	else return 0;
}

#pragma mark - Responding to collection view tap events

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)collectionView:(JSQMessagesCollectionView *)collectionView
				header:(JSQMessagesLoadEarlierHeaderView *)headerView didTapLoadEarlierMessagesButton:(UIButton *)sender
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	// ActionPremium(self);
    
    // https://github.com/matrix-org/matrix-ios-kit/blob/master/Samples/MatrixKitSample/MXKSampleJSQMessagesViewController.m
    // https://www.bountysource.com/issues/8476408-load-earlier-messages-insertitemsatindexpaths-causing-layout-overlap
    NSLog(@"didTapLoadEarlierMessagesButton");
    
    /*
      self.finishReceivingMessageAnimated(false)
      self.collectionView.layoutIfNeeded()
      self.collectionView.contentOffset = CGPointMake(0, self.collectionView.contentSize.height - oldBottomOffset)
     
     
     let bottomOffset = self.collectionView.contentSize.height - self.collectionView.contentOffset.y
    
     fetchMessages
     
     
     */
    
    // NSLog([@"%d", [messages count]);
    
    NSInteger max = [loads count] - messages.count - 1;//[loads count];//-loaded;
    NSInteger min = max-INSERT_MESSAGES;
    if (min < 0){
        
        min = 0;
        
        self.showLoadEarlierMessagesHeader = NO;
    }
    
    NSLog(@"messages.count> %d", messages.count);
    
    for (NSInteger i=max -1; i>=min; i--)
    {
        NSDictionary *item = loads[i];
        BOOL incoming = [self insertMessage:item];
        if (incoming){
            [self messageUpdate:item];
        }
        // loaded++;
    }
    
    
    NSLog(@">messages.count> %d", messages.count);
    
    [self.collectionView reloadData];
     
     // [self scrollToBottomAnimated:NO];
    
    
    
    
//    int bottomOffset = self.collectionView.contentSize.height - self.collectionView.contentOffset.y;
//    
//    [self finishReceivingMessageAnimated:false];
//    [self.collectionView layoutIfNeeded];
//    [self.collectionView setContentOffset:CGPointMake(0, self.collectionView.contentSize.height - bottomOffset)];
    
    
}

-(void)scrollViewDidScroll: (UIScrollView*)scrollView
{
    float scrollViewHeight = scrollView.frame.size.height;
    float scrollContentSizeHeight = scrollView.contentSize.height;
    float scrollOffset = scrollView.contentOffset.y;
    
    if (scrollOffset == 0)
    {
        // then we are at the top
        
        NSLog(@"then we are at the top");
        
        NSInteger max = [loads count] - messages.count - 1;//[loads count];//-loaded;
        NSInteger min = max-INSERT_MESSAGES;
        
        if(max > 0){
            self.showLoadEarlierMessagesHeader = NO;
            if (min < 0){
                min = 0;
                
                if (av != nil) {
                    [av stopAnimating];
                    [reusableview willRemoveSubview:av];
                }
                
                self.showLoadEarlierMessagesHeader = NO;
            }
            
            // [self.collectionView.hea]
        
            NSLog(@"messages.count> %d", messages.count);
        
            for (NSInteger i=max -1; i>=min; i--)
            {
                NSDictionary *item = loads[i];
                BOOL incoming = [self insertMessage:item];
                if (incoming){
                    [self messageUpdate:item];
                }
                // loaded++;
            }
        
        
            NSLog(@">messages.count> %d", messages.count);
        
            // [self.collectionView reloadData];
            
            
        
            [self.collectionView performBatchUpdates:^{
                [self.collectionView reloadSections:[NSIndexSet indexSetWithIndex:0]];
                
                if (av != nil) {
                    [av stopAnimating];
                    [reusableview willRemoveSubview:av];
                }
                
                
                self.showLoadEarlierMessagesHeader = NO;
            } completion:nil];
        }
    }
    else if (scrollOffset + scrollViewHeight == scrollContentSizeHeight)
    {
        // then we are at the end
    }
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapAvatarImageView:(UIImageView *)avatarImageView
		   atIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	NSDictionary *item = items[indexPath.item];
	if ([self incoming:item])
	{
		ProfileView *profileView = [[ProfileView alloc] initWith:item[@"userId"] User:nil];
		[self.navigationController pushViewController:profileView animated:YES];
	}
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapMessageBubbleAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	NSDictionary *item = items[indexPath.item];
	JSQMessage *message = messages[indexPath.item];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	if ([item[@"type"] isEqualToString:@"picture"])
	{
		PhotoMediaItem *mediaItem = (PhotoMediaItem *)message.media;
		if (mediaItem.status == STATUS_FAILED)
		{
		}
		if (mediaItem.status == STATUS_SUCCEED)
		{
			NSArray *photos = [IDMPhoto photosWithImages:@[mediaItem.image]];
			IDMPhotoBrowser *browser = [[IDMPhotoBrowser alloc] initWithPhotos:photos];
			[self presentViewController:browser animated:YES completion:nil];
		}
	}
	//---------------------------------------------------------------------------------------------------------------------------------------------
	if ([item[@"type"] isEqualToString:@"video"])
	{
		VideoMediaItem *mediaItem = (VideoMediaItem *)message.media;
		if (mediaItem.status == STATUS_FAILED)
		{
		}
		if (mediaItem.status == STATUS_SUCCEED)
		{
			MPMoviePlayerViewController *moviePlayer = [[MPMoviePlayerViewController alloc] initWithContentURL:mediaItem.fileURL];
			[self presentMoviePlayerViewControllerAnimated:moviePlayer];
			[moviePlayer.moviePlayer play];
		}
	}
	//---------------------------------------------------------------------------------------------------------------------------------------------
	if ([item[@"type"] isEqualToString:@"audio"])
	{
		AudioMediaItem *mediaItem = (AudioMediaItem *)message.media;
		if (mediaItem.status == STATUS_FAILED)
		{
		}
		if (mediaItem.status == STATUS_SUCCEED)
		{
			MPMoviePlayerViewController *moviePlayer = [[MPMoviePlayerViewController alloc] initWithContentURL:mediaItem.fileURL];
			[self presentMoviePlayerViewControllerAnimated:moviePlayer];
			[moviePlayer.moviePlayer play];
		}
	}
	//---------------------------------------------------------------------------------------------------------------------------------------------
	if ([item[@"type"] isEqualToString:@"location"])
	{
		JSQLocationMediaItem *mediaItem = (JSQLocationMediaItem *)message.media;
		MapView *mapView = [[MapView alloc] initWith:mediaItem.location];
		NavigationController *navController = [[NavigationController alloc] initWithRootViewController:mapView];
		[self presentViewController:navController animated:YES completion:nil];
	}
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)collectionView:(JSQMessagesCollectionView *)collectionView didTapCellAtIndexPath:(NSIndexPath *)indexPath touchLocation:(CGPoint)touchLocation
//-------------------------------------------------------------------------------------------------------------------------------------------------
{

}

#pragma mark - User actions

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)actionAttach
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[self.view endEditing:YES];
	NSArray *menuItems = @[[[RNGridMenuItem alloc] initWithImage:[UIImage imageNamed:@"chat_camera"] title:@"Camera"],
						   [[RNGridMenuItem alloc] initWithImage:[UIImage imageNamed:@"chat_audio"] title:@"Audio"],
						   [[RNGridMenuItem alloc] initWithImage:[UIImage imageNamed:@"chat_pictures"] title:@"Pictures"],
						   [[RNGridMenuItem alloc] initWithImage:[UIImage imageNamed:@"chat_videos"] title:@"Videos"],
						   [[RNGridMenuItem alloc] initWithImage:[UIImage imageNamed:@"chat_location"] title:@"Location"],
						   [[RNGridMenuItem alloc] initWithImage:[UIImage imageNamed:@"chat_stickers"] title:@"Stickers"]];
	RNGridMenu *gridMenu = [[RNGridMenu alloc] initWithItems:menuItems];
	gridMenu.delegate = self;
	[gridMenu showInViewController:self center:CGPointMake(self.view.bounds.size.width/2, self.view.bounds.size.height/2)];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)actionStickers
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	// ActionPremium(self);
    
    StickersView *stickersView = [[StickersView alloc] init];
    stickersView.delegate = self;
    NavigationController *navController = [[NavigationController alloc] initWithRootViewController:stickersView];
    [self presentViewController:navController animated:YES completion:nil];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)actionDelete:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	// ActionPremium(self);
    [self messageDelete:indexPath];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)actionCopy:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	NSDictionary *item = items[indexPath.item]; // DecryptText(groupId, text)
	// [[UIPasteboard generalPasteboard] setString:item[@"text"]]; //
    
    [[UIPasteboard generalPasteboard] setString:DecryptText(groupId, item[@"text"])];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)actionSave:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
    NSDictionary *item = items[indexPath.item];
    
    JSQMessage *message = messages[indexPath.item];
    //---------------------------------------------------------------------------------------------------------------------------------------------
    if ([item[@"type"] isEqualToString:@"picture"])
    {
        PhotoMediaItem *mediaItem = (PhotoMediaItem *)message.media;
        if (mediaItem.status == STATUS_FAILED)
        {
        }
        if (mediaItem.status == STATUS_SUCCEED)
        {
//            NSArray *photos = [IDMPhoto photosWithImages:@[mediaItem.image]];
//            IDMPhotoBrowser *browser = [[IDMPhotoBrowser alloc] initWithPhotos:photos];
//            [self presentViewController:browser animated:YES completion:nil];
            
            UIImageWriteToSavedPhotosAlbum(mediaItem.image, nil, nil, nil);
            [ProgressHUD showSuccess:@"Photo Saved."];
        }
    }
    
    if ([item[@"type"] isEqualToString:@"video"])
    {
        VideoMediaItem *mediaItem = (VideoMediaItem *)message.media;
        if (mediaItem.status == STATUS_FAILED)
        {
        }
        if (mediaItem.status == STATUS_SUCCEED)
        {
            if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum ([mediaItem.fileURL path]))
            {
                UISaveVideoAtPathToSavedPhotosAlbum ([mediaItem.fileURL path], self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
            }
        }
    }
    
    if ([item[@"type"] isEqualToString:@"audio"])
    {
        AudioMediaItem *mediaItem = (AudioMediaItem *)message.media;
        if (mediaItem.status == STATUS_FAILED)
        {
        }
        if (mediaItem.status == STATUS_SUCCEED)
        {
            if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum ([mediaItem.fileURL path]))
            {
                UISaveVideoAtPathToSavedPhotosAlbum ([mediaItem.fileURL path], self, @selector(video:didFinishSavingWithError:contextInfo:), nil);
            } // pathForResource:@"audiofile" ofType:@"mp3"]
            
        }
    }
    
	// ActionPremium(self);
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
    NSLog(@"videoPath : %@", videoPath);
    if (error)
    {
//        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Photo/Video Saving Failed"  delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles: nil, nil];
//        [alert show];
        [ProgressHUD showSuccess:@"Error Video/Audio Saved."];
    }
    else
    {
//        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Photo/Video Saved" message:@"Saved To Photo Album"  delegate:self cancelButtonTitle:@"Ok" otherButtonTitles: nil];
//        [alert show];
        
        [ProgressHUD showSuccess:@"Video/Audio Saved."];
    }
}

#pragma mark - RNGridMenuDelegate

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)gridMenu:(RNGridMenu *)gridMenu willDismissWithSelectedItem:(RNGridMenuItem *)item atIndex:(NSInteger)itemIndex
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[gridMenu dismissAnimated:NO];
	if ([item.title isEqualToString:@"Camera"])		PresentMultiCamera(self, YES);
	if ([item.title isEqualToString:@"Audio"])		PresentAudioRecorder(self);
	if ([item.title isEqualToString:@"Pictures"])	PresentPhotoLibrary(self, YES);
	if ([item.title isEqualToString:@"Videos"])		PresentVideoLibrary(self, YES);
	if ([item.title isEqualToString:@"Location"])	[self messageSend:nil Video:nil Picture:nil Audio:nil];
	if ([item.title isEqualToString:@"Stickers"])	[self actionStickers];
}

#pragma mark - UIImagePickerControllerDelegate

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	NSURL *video = info[UIImagePickerControllerMediaURL];
	UIImage *picture = info[UIImagePickerControllerEditedImage];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	[self messageSend:nil Video:video Picture:picture Audio:nil];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	[picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - IQAudioRecorderControllerDelegate

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)audioRecorderController:(IQAudioRecorderController *)controller didFinishWithAudioAtPath:(NSString *)path
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[self messageSend:nil Video:nil Picture:nil Audio:path];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)audioRecorderControllerDidCancel:(IQAudioRecorderController *)controller
//-------------------------------------------------------------------------------------------------------------------------------------------------
{

}

#pragma mark - StickersDelegate

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)didSelectSticker:(NSString *)sticker
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
    UIImage *picture = [UIImage imageNamed:sticker];
    [self messageSend:nil Video:nil Picture:picture Audio:nil];
}

#pragma mark - Helper methods

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (BOOL)incoming:(NSDictionary *)item
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	return ([self.senderId isEqualToString:item[@"userId"]] == NO);
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (BOOL)outgoing:(NSDictionary *)item
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	return ([self.senderId isEqualToString:item[@"userId"]] == YES);
}

@end

