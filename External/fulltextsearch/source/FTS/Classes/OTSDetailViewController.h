@interface OTSDetailViewController : UITableViewController <UISplitViewControllerDelegate>

@property (strong, nonatomic) NSManagedObject *seriesManagedObject;
@property (copy, nonatomic) NSString *searchString;

@end
