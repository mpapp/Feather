//
//  MPDeepSaver.m
//  Feather
//
//  Created by Matias Piipari on 23/05/2015.
//  Copyright (c) 2015 Matias Piipari. All rights reserved.
//

#import "MPDeepSaver.h"

#import "MPDatabase.h"
#import "MPManagedObject.h"
#import "MPEmbeddedObject.h"

#import "MPDatabasePackageController.h"
#import "NSObject+MPExtensions.h"
#import "NSArray+MPExtensions.h"
#import "NSNotificationCenter+ErrorNotification.h"

#import <CouchbaseLite/CouchbaseLite.h>

@implementation MPDeepSaver

+ (BOOL)deepSave:(id<MPEmbeddingObject>)obj error:(NSError *__autoreleasing *)outError {
    
    if (![obj save:outError])
        return NO;
    
    // first find objects that are dirty (needsSave = YES)
    [obj.class propertiesOfSubclassesForClass:obj.class matching:
      ^BOOL(__unsafe_unretained Class cls, NSString *key) {
          Class propClass = [obj.class classOfProperty:key];
          
          if ([propClass isSubclassOfClass:MPManagedObject.class] || [propClass isSubclassOfClass:MPEmbeddedObject.class]) {
              id o = [(id)obj valueForKey:key];
              
              if ([o needsSave])
                  [o deepSave:outError];
          }
          else if ([key hasPrefix:@"embedded"]) {
              id o = [(id)obj valueForKey:key];
              
              if ([propClass isSubclassOfClass:NSArray.class] || [propClass isSubclassOfClass:NSSet.class]) {
                  for (MPEmbeddedObject *eo in o) {
                      if (eo.needsSave)
                          [eo deepSave:outError];
                  }
              }
              else if ([propClass isSubclassOfClass:NSDictionary.class]) {
                  for (id k in o) {
                      MPManagedObject *v = o[k];
                      if (v.needsSave)
                          [v deepSave:outError];
                  }
              }
              else {
                  NSAssert(false, @"Unexpected type with key '%@': %@", key, o);
              }
          }
          
          return YES;
      }];
     
    return YES;
}

@end
