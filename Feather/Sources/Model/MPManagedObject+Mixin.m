//
//  MPManagedObject+Mixin.m
//  Feather
//
//  Created by Matias Piipari on 22/12/2012.
//  Copyright (c) 2013 Matias Piipari. All rights reserved.
//

#import "MPDatabasePackageController.h"
#import "MPShoeboxPackageController.h"

#import "MPManagedObject+MixIn.h"
#import "MPManagedObjectsController+Protected.h"

#import "Mixin.h"
#import "RegexKitLite.h"
#import "MPDatabase.h"
#import "MPException.h"

#import "NSString+MPExtensions.h"

#import <objc/message.h>
#import <objc/runtime.h>

@implementation MPManagedObject (MPManagedObjectMixIn)

+ (void)implementProtocol:(Protocol *)protocol
          overloadMethods:(BOOL)overloadMethods
{
    [self implementProtocol:protocol
       andProtocolsMatching:^BOOL(NSString *adoptedProtocolName) {
        return [adoptedProtocolName hasPrefix:@"MP"];
       } overloadMethods:overloadMethods];
}

+ (void)implementProtocol:(Protocol *)protocol
     andProtocolsMatching:(MPAdoptedProtocolPatternBlock)patternBlock
          overloadMethods:(BOOL)overloadMethods
{    
    // accummulate adopted protocols matching the wanted pattern
    unsigned int protocolCount = 0;
    Protocol * __unsafe_unretained *conformingProtocols = protocol_copyProtocolList(protocol, &protocolCount);
    for (NSUInteger i = 0; i < protocolCount; i++)
    {
        Protocol *conformingProtocol = conformingProtocols[i];
        NSString *conformingProtocolName = @(protocol_getName(conformingProtocol));
        
        if (patternBlock(conformingProtocolName))
        {
            [self implementProtocol:conformingProtocol
               andProtocolsMatching:patternBlock overloadMethods:overloadMethods];
        }
    }
    free(conformingProtocols);
    
    assert(self != [MPManagedObject class]); // abstract base class
    
    unsigned int propertyCount = 0;
    objc_property_t *props = protocol_copyPropertyList(protocol, &propertyCount);
    
    for (NSUInteger i = 0; i < propertyCount; i++)
    {
        objc_property_t prop = props[i];
        const char *propName = property_getName(prop);
        NSString *propNameStr = @(propName);
        const char *attribs = property_getAttributes(prop);
        NSString *attribStr = @(attribs);
        
        [self implementPropertyWithName:propNameStr attributeString:attribStr overloadMethods:overloadMethods];
        
        unsigned int attribCount = 0;
        objc_property_attribute_t *attributeList = property_copyAttributeList(prop, &attribCount);
        
        class_addProperty(self, [propNameStr UTF8String], attributeList, attribCount);
        
        free(attributeList);
    }
    
    free(props);
    
    // protocols with suffix "Protocol" assumed not to have a corresponding Mixin class.
    NSString *protocolName = NSStringFromProtocol(protocol);
    if (![protocolName hasSuffix:@"Protocol"])
    {
        NSString *classString = [NSString stringWithFormat:@"%@Mixin", protocolName];
        Class cls = NSClassFromString(classString);
        assert(cls); // the Mixin is required
        [self mixinFrom:cls followInheritance:YES force:YES];
    }
}

+ (void)implementPropertyWithName:(NSString *)propNameStr
                  attributeString:(NSString *)attribStr
                  overloadMethods:(BOOL)overloadMethods
{
    unichar typeChar = [attribStr characterAtIndex:1];
    
    // matches e.g. T@"NSDate",&
    NSArray *attribTypeMatchesObjectType = [attribStr captureComponentsMatchedByRegex:@"@\"(.*)\""];
    
    if (attribTypeMatchesObjectType && attribTypeMatchesObjectType.count > 1)
    {
        NSString *propType = attribTypeMatchesObjectType[1];
        
        if ([propType isEqualToString:@"NSDate"])
        {
            NSString *propStoredNameStr = [NSString stringWithFormat:@"%@Timestamp", propNameStr];
            [self implementPropertyWithName:propNameStr
                       getterImplementation:
             ^id(id _self) {
                 return [_self getValueOfProperty:propStoredNameStr];
             }
                       setterImplementation:
             ^(id _self, id setObj) {
                [_self setValue:setObj ofProperty:propStoredNameStr];
            } overload:overloadMethods];
        }
        else if ([propType isEqualToString:@"NSArray"])
        {
            assert([propNameStr isMatchedByRegex:@"s$"]); // has 's' as suffix (plural)
            NSString *propStoredNameStr = [propNameStr stringByReplacingOccurrencesOfRegex:@"s$" withString:@"IDs"];
            
            [self implementPropertyWithName:propNameStr
                       getterImplementation:
             ^id(MPManagedObject *_self) {
                 return [_self getValueOfObjectIdentifierArrayProperty:propStoredNameStr];
             }
                       setterImplementation:
             ^(MPManagedObject *_self, NSArray *setObjs) {
                 [_self setObjectIdentifierArrayValueForManagedObjectArray:setObjs
                                                                  property:propStoredNameStr];
             } overload:overloadMethods];
        }
        else
        {
            Class class = NSClassFromString(propType);
            assert(class);
            
            if ([class isSubclassOfClass:[MPManagedObject class]])
            {
                [self implementPropertyWithName:propNameStr
                           getterImplementation:
                 ^MPManagedObject *(MPManagedObject *_self)
                {
                    NSString *objectID = [_self getValueOfProperty:propNameStr];
                    if (!objectID)
                        return nil;
                    
                    Class moClass = [MPManagedObject managedObjectClassFromDocumentID:objectID];
                    Class propertyClass = [_self.class classOfProperty:propNameStr];
                    NSAssert([moClass isSubclassOfClass:propertyClass], @"Unexpected class: %@", moClass);
                    
                    MPManagedObjectsController *moc = [[[_self controller] packageController] controllerForManagedObjectClass:moClass];
                    if (!moc) {
                        moc = [[MPShoeboxPackageController sharedShoeboxController] controllerForManagedObjectClass:moClass];
                    }
                    
                    /* // The old method for recovering the object.
                     CBLDatabase *db = [_self databaseForModelProperty:propNameStr];
                     CBLDocument *doc = [db existingDocumentWithID:objectID];
                     NSParameterAssert([doc.modelObject isKindOfClass:moClass]);
                     */

                    return [moc objectWithIdentifier:objectID];
                }
                           setterImplementation:
                 ^(MPManagedObject *_self, MPManagedObject *setObj)
                {
                    [_self setValue:[setObj.document documentID] ofProperty:propNameStr];
                } overload:overloadMethods];
            }
            else
            {
                [self implementPropertyWithName:propNameStr
                           getterImplementation:
                 ^id(id _self) {
                     return [_self getValueOfProperty:propNameStr];
                 }
                           setterImplementation:^(id _self, id setObj)
                {
                    [_self setValue:setObj ofProperty:propNameStr];
                } overload:overloadMethods];
            }
        }
    }
    else if (typeChar == _C_LNG_LNG)
    {
        [self implementPropertyWithName:propNameStr
                   getterImplementation:^long long(id _self) {
                       return [[_self getValueOfProperty:propNameStr] longLongValue];
                   }
                   setterImplementation:^(id _self, long long setVal) {
                       [_self setValue:@(setVal) ofProperty:propNameStr];
                   } overload:overloadMethods];
    }
    else if (typeChar == _C_ULNG_LNG)
    {
        [self implementPropertyWithName:propNameStr
                   getterImplementation:^long long(id _self) {
                       return [[_self getValueOfProperty:propNameStr] unsignedLongLongValue];
                   }
                   setterImplementation:^(id _self, unsigned long long setVal) {
                       [_self setValue:@(setVal) ofProperty:propNameStr];
                   } overload:overloadMethods];
    }
    else if (typeChar == _C_INT  ||
             typeChar == _C_SHT  ||
             typeChar == _C_USHT ||
             typeChar == _C_CHR  ||
             typeChar == _C_UCHR)
    {
        [self implementPropertyWithName:propNameStr
                   getterImplementation:^int(id _self) {
                       return [[_self getValueOfProperty:propNameStr] intValue];
                   }
                   setterImplementation:^(id _self, int setVal) {
                       [_self setValue:@(setVal) ofProperty:propNameStr];
                   } overload:overloadMethods];
    }
    else if (typeChar == _C_BOOL)
    {
        [self implementPropertyWithName:propNameStr
                   getterImplementation:^BOOL(id _self) {
                       return [[_self getValueOfProperty:propNameStr] boolValue];
                   }
                   setterImplementation:^(id _self, BOOL setVal) {
                       [_self setValue:@(setVal) ofProperty:propNameStr];
                   } overload:overloadMethods];
    }
    else if (typeChar == _C_DBL)
    {
        [self implementPropertyWithName:propNameStr
                   getterImplementation:^double(id _self) {
                       return [[_self getValueOfProperty:propNameStr] doubleValue];
                   }
                   setterImplementation:^(id _self, double setVal) {
                       [_self setValue:@(setVal) ofProperty:propNameStr];
                   } overload:overloadMethods];
    }
    else if (typeChar == _C_FLT)
    {
        [self implementPropertyWithName:propNameStr
                   getterImplementation:^float(id _self) {
                       return [[_self getValueOfProperty:propNameStr] floatValue];
                   }
                   setterImplementation:^(id _self, float setVal) {
                       [_self setValue:@(setVal) ofProperty:propNameStr];
                   } overload:overloadMethods];
    }
    else if (typeChar == _C_CLASS) // class methods silently ignored -- need implementing in mixin or host class
    {
        return;
        /*
         [self implementPropertyWithName:propNameStr
         getterImplementation:^Class(id _self) {
         return objc_getAssociatedObject(_self, [propNameStr UTF8String]);
         }
         setterImplementation:^(id _self, Class val) {
         objc_setAssociatedObject(
         _self, [propNameStr UTF8String], val, OBJC_ASSOCIATION_ASSIGN);
         } overload:overloadMethods];
         */
    }
    else if (typeChar == _C_ID)
    {
        [self implementPropertyWithName:propNameStr
                   getterImplementation:^id(id _self)
        {
            return objc_getAssociatedObject(_self, [propNameStr UTF8String]);
        }
                   setterImplementation:^(id _self, id setVal)
        {
            objc_setAssociatedObject(_self, [propNameStr UTF8String], setVal, OBJC_ASSOCIATION_RETAIN);
        }
                               overload:overloadMethods];
    }
    else
    {
        @throw [[MPUnexpectedTypeException alloc] initWithTypeString:attribStr];
    }
}

+ (void)implementPropertyWithName:(NSString *)propertyNameStr
             getterImplementation:(id)getterImp
             setterImplementation:(id)setterImp
                         overload:(BOOL)overload
{
    if ([propertyNameStr isEqualToString:@"evaluatedManagedObjectClass"])
    {
        NSLog(@"foo");
    }
    
    assert(self != [MPManagedObject class]); // abstract base class
    const char *propName = [propertyNameStr UTF8String];
    unsigned long propNameLen = strlen(propName);
    
    objc_property_t prop = class_getProperty(self, propName);
    if (!prop)
    {
        NSLog(@"No property %@.%@", NSStringFromClass(self), propertyNameStr);
        return;
    }
    assert(prop);
    const char *attribStr = property_getAttributes(prop);
    const unsigned char typeChar = attribStr[1];
    
    BOOL isReadOnly = [[[NSString alloc] initWithUTF8String:attribStr] containsSubstring:@"R"];
    
    // getter name is nil if it's the default
    char *getterName = property_copyAttributeValue(prop, "G");
    if (getterName == NULL) {
        getterName = malloc(sizeof(char) * (propNameLen + 1));
        strncpy(getterName, propName, propNameLen + 1);
    }
    
    //e.g. @@, q@
    NSString *getterNameStr = @(getterName);
    SEL getterSel = NSSelectorFromString(getterNameStr);
    
    if (!class_getInstanceMethod(self, getterSel))
    {
        class_addMethod(self, getterSel,
                        imp_implementationWithBlock(getterImp),
                        [[NSString stringWithFormat:@"%c@", typeChar] UTF8String]);
    }
    else if (overload)
    {
        class_replaceMethod(self, getterSel,
                            imp_implementationWithBlock(getterImp),
                            [[NSString stringWithFormat:@"%c@", typeChar] UTF8String]);
    }
    free(getterName);

    
    if (!isReadOnly)
    {
        // setter name is nil if it's default
        char *setterName = property_copyAttributeValue(prop, "S");
        if (setterName == NULL) {
            setterName = malloc(sizeof(char) * (propNameLen + 5)); // 5 = 'set' + ':' + end char
            
            // construct 'setPropertyName:'
            strncpy(setterName, "set", 3);
            strncpy(&setterName[3], [[@(propName) stringByMakingSentenceCase] UTF8String], propNameLen);
            strncpy(&setterName[propNameLen + 3], ":\0", 2);
        }
        
        //e.g. v@:@, vq:@
        NSString *setterNameStr = @(setterName);
        SEL setterSel = NSSelectorFromString(setterNameStr);
        
        if (!class_getInstanceMethod(self, setterSel))
        {
            class_addMethod(self, setterSel,
                            imp_implementationWithBlock(setterImp),
                            [[NSString stringWithFormat:@"v%c:@", typeChar] UTF8String]);
        } else if (overload)
        {
            class_replaceMethod(self, setterSel,
                                imp_implementationWithBlock(setterImp),
                                [[NSString stringWithFormat:@"v%c:@", typeChar] UTF8String]);
        }
        free(setterName);
    }
}

@end