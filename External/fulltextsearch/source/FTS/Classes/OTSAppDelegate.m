#import "OTSAppDelegate.h"
#import "OTSMainViewController.h"
#import "OTSDetailViewController.h"
#import "FMDatabase.h"

@interface OTSAppDelegate()

@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;
@property (strong, nonatomic) UINavigationController *navigationController;
@property (strong, nonatomic) UISplitViewController *splitViewController;
@property (strong, nonatomic) OTSMainViewController *mainViewController;

- (void)initializeCoreDataStack;
- (void)buildFTSDatabase;

@end

#pragma mark -

@implementation OTSAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	NSURL *dataFileURL = [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
	dataFileURL = [dataFileURL URLByAppendingPathComponent:@"FTSSourceData.coredata"];
	if (![[NSFileManager defaultManager] fileExistsAtPath:[dataFileURL path]]) {
		NSURL *bundleFileURL = [[NSBundle mainBundle] URLForResource:@"FTSSourceData" withExtension:@"coredata"];
		[[NSFileManager defaultManager] copyItemAtURL:bundleFileURL toURL:dataFileURL error:nil];
	}
	
  [self setWindow:[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]]];
  [[self window] setBackgroundColor:[UIColor blackColor]];
	
	[self setMainViewController:[[OTSMainViewController alloc] initWithAppropriateNib]];
	
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
		[self setNavigationController:[[UINavigationController alloc] initWithRootViewController:[self mainViewController]]];
		[[[self navigationController] navigationBar] setBarStyle:UIBarStyleBlackOpaque];
		[[self window] setRootViewController:[self navigationController]];
	} else {
		UINavigationController *mainNavigationController = [[UINavigationController alloc] initWithRootViewController:[self mainViewController]];
		[[mainNavigationController navigationBar] setBarStyle:UIBarStyleBlackOpaque];
		
		OTSDetailViewController *detailViewController = [[OTSDetailViewController alloc] initWithStyle:UITableViewStylePlain];
		UINavigationController *detailNavigationController = [[UINavigationController alloc] initWithRootViewController:detailViewController];
		[[detailNavigationController navigationBar] setBarStyle:UIBarStyleBlackOpaque];
		
		[[self mainViewController] setDetailViewController:detailViewController];

		[self setSplitViewController:[[UISplitViewController alloc] init]];
		[[self splitViewController] setDelegate:detailViewController];
		[[self splitViewController] setViewControllers:@[mainNavigationController, detailNavigationController]];
		
		[[self window] setRootViewController:[self splitViewController]];
	}
	
	[self initializeCoreDataStack];

	[[self window] makeKeyAndVisible];
	
	return YES;
}

#pragma mark - Private methods

- (void)initializeCoreDataStack
{
  NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"FTSSourceData" withExtension:@"momd"];
	if (!modelURL) {
		modelURL = [[NSBundle mainBundle] URLForResource:@"FTSSourceData" withExtension:@"mom"];
	}
  ZAssert(modelURL, @"Failed to find model URL");
  
  NSManagedObjectModel *mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
  ZAssert(mom, @"Failed to initialize model");
  
  NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
  ZAssert(psc, @"Failed to initialize persistent store coordinator");
  
  NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
  [moc setPersistentStoreCoordinator:psc];
  [self setManagedObjectContext:moc];
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		NSURL *storeURL = [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
		storeURL = [storeURL URLByAppendingPathComponent:@"FTSSourceData.coredata"];
		
		NSError *error = nil;
		NSMutableDictionary *options = [NSMutableDictionary dictionary];
		[options setValue:[NSNumber numberWithBool:YES] forKey:NSMigratePersistentStoresAutomaticallyOption];
		[options setValue:[NSNumber numberWithBool:YES] forKey:NSInferMappingModelAutomaticallyOption];
		NSPersistentStore *store = [psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error];
		if (!store) {
			ALog(@"Error adding persistent store to coordinator %@\n%@", [error localizedDescription], [error userInfo]);
			NSString *message = NSLocalizedString(@"The database is either corrupt or was created by a newer version of the app. Please contact support for help with this error.", nil);
			UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Database Problem", nil) message:message delegate:nil cancelButtonTitle:NSLocalizedString(@"Quit", "@Quit button caption") otherButtonTitles:nil];
			[alertView show];
			return;
		}

		dispatch_sync(dispatch_get_main_queue(), ^{
			[self buildFTSDatabase];
		});
	});
}

- (void)buildFTSDatabase
{
	NSURL *dataFileURL = [[[NSFileManager defaultManager] URLsForDirectory:NSLibraryDirectory inDomains:NSUserDomainMask] lastObject];
	dataFileURL = [dataFileURL URLByAppendingPathComponent:@"FTSSearchData.sqlite"];
	if ([[NSFileManager defaultManager] fileExistsAtPath:[dataFileURL path]]) {
		[[self mainViewController] setManagedObjectContext:[self managedObjectContext]];
		return;
	}
	
	UIView *progressView = [[self mainViewController] progressView];
	[[progressView layer] setCornerRadius:7.0];
	[[progressView layer] setMasksToBounds:YES];

  dispatch_queue_t private_queue = dispatch_queue_create("com.ottersoftware.ios.fts", 0);
  dispatch_async(private_queue, ^(void) {
		BOOL dbSuccess = YES;
		
		FMDatabase* db = [FMDatabase databaseWithPath:[dataFileURL path]];
		dbSuccess = [db open];
		ZAssert(dbSuccess, @"Could not open db.");
		
		dbSuccess = [db executeUpdate:@"create virtual table searchData using FTS4 (seriesID, episodeID, searchText)", nil];
		ZAssert(dbSuccess, @"Didn't create table: %@", 	[db lastErrorMessage]);
		
		NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Series"];
		NSArray *results = [[self managedObjectContext] executeFetchRequest:request error:nil];
		if (results) {
			for (NSManagedObject *seriesMO in results) {
				DLog(@"Processing item %d of %d", [results indexOfObject:seriesMO] , [results count]);
				@autoreleasepool {
					[db beginTransaction];
					dbSuccess = [db executeUpdate:@"insert into searchData (seriesID, searchText) values (?, ?)", [seriesMO valueForKey:@"seriesIdentifier"], [[seriesMO valueForKey:@"seriesName"] otsNormalizeString], nil];
					ZAssert(dbSuccess, @"Didn't create series record: %@", 	[db lastErrorMessage]);
					
					for (NSManagedObject *episodeMO in [seriesMO valueForKey:@"episodes"]) {
						dbSuccess = [db executeUpdate:@"insert into searchData (seriesID, episodeID, searchText) values (?, ?, ?)", [seriesMO valueForKey:@"seriesIdentifier"], [episodeMO valueForKey:@"episodeIdentifier"], [[episodeMO valueForKey:@"episodeName"] otsNormalizeString], nil];
						ZAssert(dbSuccess, @"Didn't create episode record: %@", 	[db lastErrorMessage]);
					}
					[db commit];
				};
			}
		}
		
		[db close];

    dispatch_async(dispatch_get_main_queue(), ^(void) {
      [progressView removeFromSuperview];
      [[self mainViewController] setManagedObjectContext:[self managedObjectContext]];
    });
	});
	
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
		[[[self mainViewController] view] addSubview:progressView];
	} else {
		[[[[self mainViewController] detailViewController] view] addSubview:progressView];
	}
	
	[progressView setCenter:[[progressView superview] center]];
}

@end
