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

#import "BlockedView.h"

//-------------------------------------------------------------------------------------------------------------------------------------------------
@interface BlockedView()
{
	NSMutableArray *blockeds;
	NSIndexPath *indexSelected;
}
@end
//-------------------------------------------------------------------------------------------------------------------------------------------------

@implementation BlockedView

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)viewDidLoad
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[super viewDidLoad];
	self.title = @"Blocked users";
	//---------------------------------------------------------------------------------------------------------------------------------------------
	blockeds = [[NSMutableArray alloc] init];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	[self loadBlockeds];
}

#pragma mark - Backend actions

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)loadBlockeds
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	PFQuery *query = [PFQuery queryWithClassName:PF_BLOCKED_CLASS_NAME];
	[query whereKey:PF_BLOCKED_USER equalTo:[PFUser currentUser]];
	[query whereKey:PF_BLOCKED_USER1 equalTo:[PFUser currentUser]];
	[query includeKey:PF_BLOCKED_USER2];
	[query setLimit:1000];
	[query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error)
	{
		if (error == nil)
		{
			[blockeds removeAllObjects];
			[blockeds addObjectsFromArray:objects];
			[self.tableView reloadData];
		}
		else [ProgressHUD showError:@"Network error."];
	}];
}

#pragma mark - User actions

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)actionUnblockUser
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	// ActionPremium(self);
    
    PFObject *blocked = blockeds[indexSelected.row];
    PFUser *user2 = blocked[PF_BLOCKED_USER2];
    //-----------------------------------------------------------------------------------------------------------------------------------------
    UnblockUser(user2);
    //-----------------------------------------------------------------------------------------------------------------------------------------
    [blockeds removeObject:blocked];
    [self.tableView reloadData];
}

#pragma mark - Table view data source

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	return 1;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	return [blockeds count];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
	if (cell == nil) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];

	PFObject *blocked = blockeds[indexPath.row];
	PFUser *user = blocked[PF_BLOCKED_USER2];
	cell.textLabel.text = user[PF_USER_FULLNAME];

	return cell;
}

#pragma mark - Table view delegate

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	indexSelected = indexPath;
	//---------------------------------------------------------------------------------------------------------------------------------------------
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];

	UIAlertAction *action1 = [UIAlertAction actionWithTitle:@"Unblock user" style:UIAlertActionStyleDefault
													handler:^(UIAlertAction *action) { [self actionUnblockUser]; }];
	UIAlertAction *action2 = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];

	[alert addAction:action1]; [alert addAction:action2];
	// [self presentViewController:alert animated:YES completion:nil];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        
        // iPad用の設定
        alert.popoverPresentationController.sourceView = self.view;
        
        UIView *view = [self.navigationItem.rightBarButtonItem valueForKey:@"view"];
        alert.popoverPresentationController.sourceRect = [tableView cellForRowAtIndexPath:indexPath].frame;//tableView.cellForRowAtIndexPath(indexPath)!.frame // CGRectMake(view.frame.origin.x -10, 0.0, 20.0, 20.0);
        
        [self presentViewController:alert animated:YES completion:nil];
    }else{
        [self presentViewController:alert animated:YES completion:nil];
    }

}

@end

