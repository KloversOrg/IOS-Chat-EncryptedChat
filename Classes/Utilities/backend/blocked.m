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

#import "utilities.h"
#import "group.h"

//-------------------------------------------------------------------------------------------------------------------------------------------------
void BlockUser(PFUser *user2)
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
    
    PFUser *user1 = [PFUser currentUser];
    //---------------------------------------------------------------------------------------------------------------------------------------------
    BlockUserOne(user1, user2);
    BlockUserOne(user2, user1);
    //---------------------------------------------------------------------------------------------------------------------------------------------
    GroupRemoveMembers(user1, user2);
    GroupRemoveMembers(user2, user1);
    //---------------------------------------------------------------------------------------------------------------------------------------------
    PeopleDelete(user1, user2);
    PeopleDelete(user2, user1);
    //---------------------------------------------------------------------------------------------------------------------------------------------
    DeleteRecents(user1, user2);
    DeleteRecents(user2, user1);
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
void BlockUserOne(PFUser *user1, PFUser *user2)
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
    
    PFQuery *query = [PFQuery queryWithClassName:PF_BLOCKED_CLASS_NAME];
    [query whereKey:PF_BLOCKED_USER equalTo:[PFUser currentUser]];
    [query whereKey:PF_BLOCKED_USER1 equalTo:user1];
    [query whereKey:PF_BLOCKED_USER2 equalTo:user2];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error)
     {
         if (error == nil)
         {
             if ([objects count] == 0)
             {
                 PFObject *object = [PFObject objectWithClassName:PF_BLOCKED_CLASS_NAME];
                 object[PF_BLOCKED_USER] = [PFUser currentUser];
                 object[PF_BLOCKED_USER1] = user1;
                 object[PF_BLOCKED_USER2] = user2;
                 object[PF_BLOCKED_USERID2] = user2.objectId;
                 [object saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error)
                  {
                      if (error != nil) NSLog(@"BlockUserOne save error.");
                  }];
             }
         }
         else NSLog(@"BlockUserOne query error.");
     }];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
void UnblockUser(PFUser *user2)
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
    
    PFUser *user1 = [PFUser currentUser];
    //---------------------------------------------------------------------------------------------------------------------------------------------
    UnblockUserOne(user1, user2);
    UnblockUserOne(user2, user1);
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
void UnblockUserOne(PFUser *user1, PFUser *user2)
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
    PFQuery *query = [PFQuery queryWithClassName:PF_BLOCKED_CLASS_NAME];
    [query whereKey:PF_BLOCKED_USER equalTo:[PFUser currentUser]];
    [query whereKey:PF_BLOCKED_USER1 equalTo:user1];
    [query whereKey:PF_BLOCKED_USER2 equalTo:user2];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error)
     {
         if (error == nil)
         {
             for (PFObject *blocked in objects)
             {
                 [blocked deleteInBackgroundWithBlock:^(BOOL succeeded, NSError *error)
                  {
                      if (error != nil) NSLog(@"UnblockUserOne delete error.");
                  }];
             }
         }
         else NSLog(@"UnblockUserOne query error.");
     }];
}

