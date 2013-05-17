// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to OTSEpisode.m instead.

#import "_OTSEpisode.h"

const struct OTSEpisodeAttributes OTSEpisodeAttributes = {
	.episodeIdentifier = @"episodeIdentifier",
	.episodeName = @"episodeName",
	.episodeNumber = @"episodeNumber",
};

const struct OTSEpisodeRelationships OTSEpisodeRelationships = {
	.series = @"series",
};

const struct OTSEpisodeFetchedProperties OTSEpisodeFetchedProperties = {
};

@implementation OTSEpisodeID
@end

@implementation _OTSEpisode

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"Episode" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"Episode";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"Episode" inManagedObjectContext:moc_];
}

- (OTSEpisodeID*)objectID {
	return (OTSEpisodeID*)[super objectID];
}

+ (NSSet*)keyPathsForValuesAffectingValueForKey:(NSString*)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"episodeNumberValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"episodeNumber"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}

	return keyPaths;
}




@dynamic episodeIdentifier;






@dynamic episodeName;






@dynamic episodeNumber;



- (int64_t)episodeNumberValue {
	NSNumber *result = [self episodeNumber];
	return [result longLongValue];
}

- (void)setEpisodeNumberValue:(int64_t)value_ {
	[self setEpisodeNumber:[NSNumber numberWithLongLong:value_]];
}

- (int64_t)primitiveEpisodeNumberValue {
	NSNumber *result = [self primitiveEpisodeNumber];
	return [result longLongValue];
}

- (void)setPrimitiveEpisodeNumberValue:(int64_t)value_ {
	[self setPrimitiveEpisodeNumber:[NSNumber numberWithLongLong:value_]];
}





@dynamic series;

	






@end
