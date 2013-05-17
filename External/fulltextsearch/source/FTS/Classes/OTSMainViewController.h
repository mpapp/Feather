@class OTSDetailViewController;

@interface OTSMainViewController : UIViewController <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate>

@property (strong, nonatomic) IBOutlet UIView *progressView;

@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *searchActivityIndicatorView;
@property (weak, nonatomic) IBOutlet UITableView *seriesTableView;

@property (strong, nonatomic) OTSDetailViewController *detailViewController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

- (id)initWithAppropriateNib;

@end
