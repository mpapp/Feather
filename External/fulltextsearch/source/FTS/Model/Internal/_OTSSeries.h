// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to OTSSeries.h instead.

#import <CoreData/CoreData.h>


extern const struct OTSSeriesAttributes {
	__unsafe_unretained NSString *seriesIdentifier;
	__unsafe_unretained NSString *seriesName;
} OTSSeriesAttributes;

extern const struct OTSSeriesRelationships {
	__unsafe_unretained NSString *episodes;
} OTSSeriesRelationships;

extern const struct OTSSeriesFetchedProperties {
} OTSSeriesFetchedProperties;

@class OTSEpisode;




@interface OTSSeriesID : NSManagedObjectID {}
@end

@interface _OTSSeries : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (OTSSeriesID*)objectID;





@property (nonatomic, strong) NSString* seriesIdentifier;



//- (BOOL)validateSeriesIdentifier:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* seriesName;



//- (BOOL)validateSeriesName:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSSet *episodes;

- (NSMutableSet*)episodesSet;





@end

@interface _OTSSeries (CoreDataGeneratedAccessors)

- (void)addEpisodes:(NSSet*)value_;
- (void)removeEpisodes:(NSSet*)value_;
- (void)addEpisodesObject:(OTSEpisode*)value_;
- (void)removeEpisodesObject:(OTSEpisode*)value_;

@end

@interface _OTSSeries (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveSeriesIdentifier;
- (void)setPrimitiveSeriesIdentifier:(NSString*)value;




- (NSString*)primitiveSeriesName;
- (void)setPrimitiveSeriesName:(NSString*)value;





- (NSMutableSet*)primitiveEpisodes;
- (void)setPrimitiveEpisodes:(NSMutableSet*)value;


@end
