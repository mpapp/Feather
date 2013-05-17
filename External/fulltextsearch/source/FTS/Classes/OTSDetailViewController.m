#import "OTSDetailViewController.h"
#import "FMDatabase.h"
#import "FMDatabaseQueue.h"

@interface OTSDetailViewController ()

@property (assign, nonatomic) BOOL filterEpisodeSearchResults;
@property (copy, nonatomic) NSArray *episodeManagedObjects;

- (void)configureView;
- (void)toggleEpisodeSearchResults:(id)sender;

@end

@implementation OTSDetailViewController

#pragma mark - Managing the detail item

- (void)setSeriesManagedObject:(NSManagedObject *)seriesManagedObject
{
	if (![_seriesManagedObject isEqual:seriesManagedObject]) {
		_seriesManagedObject = seriesManagedObject;
		[self configureView];
	}
}

- (void)setSearchString:(NSString *)searchString
{
	if (![_searchString isEqualToString:searchString]) {
		_searchString = [searchString copy];
		[self configureView];
	}
}

- (id)initWithStyle:(UITableViewStyle)style
{
	self = [super initWithStyle:style];
	if (!self) return nil;
	
	_filterEpisodeSearchResults = YES;
	
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	UIBarButtonItem *barButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSearch target:self action:@selector(toggleEpisodeSearchResults:)];
	[[self navigationItem] setRightBarButtonItem:barButtonItem];
	[self toggleEpisodeSearchResults:nil];

	[self configureView];
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

- (void)configureView
{
	if ([self seriesManagedObject]) {
		[self setTitle:[[self seriesManagedObject] valueForKey:@"seriesName"]];
		NSSortDescriptor *sd = [NSSortDescriptor sortDescriptorWithKey:@"episodeNumber" ascending:YES];
		[self setEpisodeManagedObjects:[[[[self seriesManagedObject] valueForKey:@"episodes"] allObjects] sortedArrayUsingDescriptors:@[sd]]];
	} else {
		[self setTitle:NSLocalizedString(@"Episodes", @"Episodes title")];
		[self setEpisodeManagedObjects:nil];
	}
	
	if ([self seriesManagedObject] && [self searchString] && [self filterEpisodeSearchResults]) {
		[self performSearch];
	} else {
		[[self tableView] reloadData];
	}
}

- (void)toggleEpisodeSearchResults:(id)sender
{
	[self setFilterEpisodeSearchResults:![self filterEpisodeSearchResults]];

	if ([self filterEpisodeSearchResults]) {
		[[[self navigationItem] rightBarButtonItem] setTintColor:[UIColor colorWithRed:0.846 green:0.000 blue:0.000 alpha:1.000]];
	} else {
		[[[self navigationItem] rightBarButtonItem] setTintColor:nil];
	}
	
	[self configureView];
}

- (void)performSearch
{
	NSURL *dataFileURL = [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
	dataFileURL = [dataFileURL URLByAppendingPathComponent:@"FTSSearchData.sqlite"];
	
	FMDatabaseQueue *queue = [FMDatabaseQueue databaseQueueWithPath:[dataFileURL path]];
	[queue inDatabase:^(FMDatabase *db) {
		NSMutableSet *foundObjectIdentifiers = [[NSMutableSet alloc] init];
		
		FMResultSet *rs = [db executeQuery:@"SELECT DISTINCT episodeID FROM searchData WHERE seriesID = ? AND searchText MATCH ?", [[self seriesManagedObject] valueForKey:@"seriesIdentifier"],  [self searchString], nil];
		while ([rs next]) {
			[foundObjectIdentifiers addObject:[rs stringForColumn:@"episodeID"]];
		}
		[rs close];

		dispatch_async(dispatch_get_main_queue(), ^{
			NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Episode"];
			[fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"series = %@ AND episodeIdentifier IN %@", [self seriesManagedObject], foundObjectIdentifiers]];
			NSSortDescriptor *sd = [NSSortDescriptor sortDescriptorWithKey:@"episodeName" ascending:YES];
			[fetchRequest setSortDescriptors:[NSArray arrayWithObject:sd]];
			[self setEpisodeManagedObjects:[[[self seriesManagedObject] managedObjectContext] executeFetchRequest:fetchRequest error:nil]];
			[[self tableView] reloadData];
		});
	}];
}

#pragma mark - UITableViewDataSource Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	if ([self episodeManagedObjects]) {
		return 1;
	}
	
	return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if ([self episodeManagedObjects]) {
		return [[self episodeManagedObjects] count];
	}
	
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  static NSString *CELL_IDENTIFIER_GENERIC = @"GenericCellIdentifier";
	
	UITableViewCell *cell = cell = [tableView dequeueReusableCellWithIdentifier:CELL_IDENTIFIER_GENERIC];
	if (cell == nil) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault	reuseIdentifier:CELL_IDENTIFIER_GENERIC];
		[cell setAccessoryType:UITableViewCellAccessoryNone];
	}
	
	NSManagedObject *episodeMO = [[self episodeManagedObjects] objectAtIndex:[indexPath row]];
	[[cell textLabel] setText:[episodeMO valueForKey:@"episodeName"]];
	
	return cell;
}

#pragma mark - Split view

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController
{
	barButtonItem.title = NSLocalizedString(@"Series", @"Series");
	[self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
	[self.navigationItem setLeftBarButtonItem:nil animated:YES];
}

@end
