// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to OTSEpisode.h instead.

#import <CoreData/CoreData.h>


extern const struct OTSEpisodeAttributes {
	__unsafe_unretained NSString *episodeIdentifier;
	__unsafe_unretained NSString *episodeName;
	__unsafe_unretained NSString *episodeNumber;
} OTSEpisodeAttributes;

extern const struct OTSEpisodeRelationships {
	__unsafe_unretained NSString *series;
} OTSEpisodeRelationships;

extern const struct OTSEpisodeFetchedProperties {
} OTSEpisodeFetchedProperties;

@class OTSSeries;





@interface OTSEpisodeID : NSManagedObjectID {}
@end

@interface _OTSEpisode : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (OTSEpisodeID*)objectID;





@property (nonatomic, strong) NSString* episodeIdentifier;



//- (BOOL)validateEpisodeIdentifier:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* episodeName;



//- (BOOL)validateEpisodeName:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSNumber* episodeNumber;



@property int64_t episodeNumberValue;
- (int64_t)episodeNumberValue;
- (void)setEpisodeNumberValue:(int64_t)value_;

//- (BOOL)validateEpisodeNumber:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) OTSSeries *series;

//- (BOOL)validateSeries:(id*)value_ error:(NSError**)error_;





@end

@interface _OTSEpisode (CoreDataGeneratedAccessors)

@end

@interface _OTSEpisode (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveEpisodeIdentifier;
- (void)setPrimitiveEpisodeIdentifier:(NSString*)value;




- (NSString*)primitiveEpisodeName;
- (void)setPrimitiveEpisodeName:(NSString*)value;




- (NSNumber*)primitiveEpisodeNumber;
- (void)setPrimitiveEpisodeNumber:(NSNumber*)value;

- (int64_t)primitiveEpisodeNumberValue;
- (void)setPrimitiveEpisodeNumberValue:(int64_t)value_;





- (OTSSeries*)primitiveSeries;
- (void)setPrimitiveSeries:(OTSSeries*)value;


@end
