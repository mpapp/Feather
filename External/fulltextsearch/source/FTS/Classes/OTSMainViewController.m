#import "OTSMainViewController.h"
#import "OTSDetailViewController.h"
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"
#import "OTSSeries.h"

@interface OTSMainViewController ()

@property (strong, nonatomic) NSArray *unfilteredMediaItems;
@property (copy, nonatomic) NSArray *filteredMediaItems;
@property (copy, nonatomic) NSString *currentSearchString;
@property (copy, nonatomic) NSString *databasePath;

- (void)performSearch;
- (void)hideKeyboard:(UITapGestureRecognizer*)gestureRecogniser;

@end

@implementation OTSMainViewController

@synthesize managedObjectContext = _managedObjectContext;

- (void)setManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
	_managedObjectContext = managedObjectContext;
	
	_unfilteredMediaItems = nil;
	
	NSURL *dataFileURL = [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
	dataFileURL = [dataFileURL URLByAppendingPathComponent:@"FTSSearchData.sqlite"];
	[self setDatabasePath:[dataFileURL path]];

	NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Series"];
	NSSortDescriptor *sd = [NSSortDescriptor sortDescriptorWithKey:@"seriesName" ascending:YES];
	[fetchRequest setSortDescriptors:[NSArray arrayWithObject:sd]];
	[fetchRequest setFetchBatchSize:30];
	[self setUnfilteredMediaItems:[_managedObjectContext executeFetchRequest:fetchRequest error:nil]];
	[[self seriesTableView] reloadData];
}

- (id)initWithAppropriateNib
{
	self = [super initWithNibName:@"OTSMainViewController" bundle:nil];
	if (!self) return nil;
	
	[self setTitle:NSLocalizedString(@"Series", @"Series table title")];
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
		[self setContentSizeForViewInPopover:CGSizeMake(320.0, 600.0)];
	}
	
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyboard:)];
	[gestureRecognizer setCancelsTouchesInView:NO];
	[[self seriesTableView] addGestureRecognizer:gestureRecognizer];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
  return ([self supportedInterfaceOrientations] & (1 << toInterfaceOrientation)) != 0;
}

- (BOOL)shouldAutorotate
{
  return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
  if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
    return (UIInterfaceOrientationMaskAll);
  } else {
    return UIInterfaceOrientationMaskAllButUpsideDown;
  }
}

#pragma mark - Private Methods

- (void)performSearch
{
	if ([[[self searchBar] text] length] == 0) {
		[self setCurrentSearchString:nil];
		if ([self detailViewController]) {
			[[self detailViewController] setSearchString:nil];
			[[self detailViewController] setSeriesManagedObject:nil];
		}
		[[self seriesTableView] reloadData];
		[[self searchActivityIndicatorView] stopAnimating];
		return;
	}
	
	[[self searchActivityIndicatorView] startAnimating];
	
	NSString *searchString = [NSString stringWithFormat:@"%@*", [[self searchBar] text]];
	DLog(@"%@", searchString);
	
	[self setCurrentSearchString:searchString];
	if ([self detailViewController]) {
		[[self detailViewController] setSearchString:[self currentSearchString]];
	}

	dispatch_queue_t backgroundQueue = dispatch_queue_create("com.ottersoftware.ios.fts.search", NULL);
	int64_t delay = 0.5;
	if ([[[self searchBar] text] length] > 3) {
		delay = 0.0;
	}
	dispatch_time_t time = dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC);
	dispatch_after(time, backgroundQueue, ^(void){
		if (![[self currentSearchString] isEqualToString:searchString]) {
			return;
		}
		
		FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithPath:[self databasePath]];
		[queue inDatabase:^(FMDatabase *db) {
			NSMutableSet *foundObjectIdentifiers = [[NSMutableSet alloc] init];
			FMResultSet *rs = [db executeQuery:@"SELECT DISTINCT seriesID FROM searchData WHERE searchText MATCH ?", searchString, nil];
			while ([rs next]) {
				if (![[self currentSearchString] isEqualToString:searchString]) {
					[rs close];
					return;
				}
				[foundObjectIdentifiers addObject:[rs stringForColumn:@"seriesID"]];
			}
			[rs close];

			if (![[self currentSearchString] isEqualToString:searchString]) {
				return;
			}

			dispatch_async(dispatch_get_main_queue(), ^{
				NSError *error;
				NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Series"];
				[fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"seriesIdentifier IN %@", foundObjectIdentifiers]];
				NSSortDescriptor *sd = [NSSortDescriptor sortDescriptorWithKey:@"seriesName" ascending:YES];
				[fetchRequest setSortDescriptors:[NSArray arrayWithObject:sd]];
				[self setFilteredMediaItems:[[self managedObjectContext] executeFetchRequest:fetchRequest error:&error]];
				if (![self filteredMediaItems]) {
					DLog(@"%@", error);
					return;
				}
				
				if (![[self currentSearchString] isEqualToString:searchString]) {
					return;
				}

				[[self seriesTableView] reloadData];
				[[self searchActivityIndicatorView] stopAnimating];
			});
		}];
	});
}

- (void)hideKeyboard:(UITapGestureRecognizer*)gestureRecogniser
{
	[[self view] endEditing:NO];
}

#pragma mark - UITableViewDataSource Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	if ([self managedObjectContext]) {
		return 1;
	}
	
	return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if ([self managedObjectContext]) {
		if ([[[self searchBar] text] length] > 0) {
			return [[self filteredMediaItems] count];
		} else {
			return [[self unfilteredMediaItems] count];
		}
	}
	
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  static NSString *CELL_IDENTIFIER_GENERIC = @"GenericCellIdentifier";
	
	UITableViewCell *cell = cell = [tableView dequeueReusableCellWithIdentifier:CELL_IDENTIFIER_GENERIC];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault	reuseIdentifier:CELL_IDENTIFIER_GENERIC];
		if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
			[cell setAccessoryType:UITableViewCellAccessoryNone];
		} else {
			[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
		}
	}
	
	NSManagedObject *seriesMO = nil;
	if ([[[self searchBar] text] length] > 0) {
		seriesMO = [[self filteredMediaItems] objectAtIndex:[indexPath row]];
	} else {
		seriesMO = [[self unfilteredMediaItems] objectAtIndex:[indexPath row]];
	}
		
	[[cell textLabel] setText:[seriesMO valueForKey:@"seriesName"]];
	
	return cell;
}

#pragma mark - UITableViewDelegate Methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSManagedObject *seriesMO = nil;
	if ([[[self searchBar] text] length] > 0) {
		seriesMO = [[self filteredMediaItems] objectAtIndex:[indexPath row]];
	} else {
		seriesMO = [[self unfilteredMediaItems] objectAtIndex:[indexPath row]];
	}

	if (!seriesMO) {
		return;
	}

	if (![self detailViewController]) {
		[self setDetailViewController:[[OTSDetailViewController alloc] initWithStyle:UITableViewStylePlain]];
	}
	[[self detailViewController] setSeriesManagedObject:seriesMO];
	[[self detailViewController] setSearchString:[self currentSearchString]];

	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
		[[self navigationController] pushViewController:[self detailViewController] animated:YES];
	}
}

#pragma mark - UISearchBarDelegate Methods

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
	[self performSearch];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
	[searchBar resignFirstResponder];
	[self performSearch];
}

@end
