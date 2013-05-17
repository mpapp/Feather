// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to OTSSeries.m instead.

#import "_OTSSeries.h"

const struct OTSSeriesAttributes OTSSeriesAttributes = {
	.seriesIdentifier = @"seriesIdentifier",
	.seriesName = @"seriesName",
};

const struct OTSSeriesRelationships OTSSeriesRelationships = {
	.episodes = @"episodes",
};

const struct OTSSeriesFetchedProperties OTSSeriesFetchedProperties = {
};

@implementation OTSSeriesID
@end

@implementation _OTSSeries

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"Series" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"Series";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"Series" inManagedObjectContext:moc_];
}

- (OTSSeriesID*)objectID {
	return (OTSSeriesID*)[super objectID];
}

+ (NSSet*)keyPathsForValuesAffectingValueForKey:(NSString*)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	

	return keyPaths;
}




@dynamic seriesIdentifier;






@dynamic seriesName;






@dynamic episodes;

	
- (NSMutableSet*)episodesSet {
	[self willAccessValueForKey:@"episodes"];
  
	NSMutableSet *result = (NSMutableSet*)[self mutableSetValueForKey:@"episodes"];
  
	[self didAccessValueForKey:@"episodes"];
	return result;
}
	






@end
