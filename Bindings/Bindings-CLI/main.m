//
//  main.m
//  Bindings-CLI
//
//  Created by Matias Piipari on 11/10/2014.
//  Copyright (c) 2014 Manuscripts.app Limited. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Bindings/BindingsFramework.h>
#import <ClangKit/ClangKit.h>

void printUsage() {
    printf("Usage:\n");
    printf("a) Bindings-CLI -framework [path or URL to your .framework] <.h file paths to include beside ones in the framework -- optional for frameworks>\n");
    printf("b) Bindings-CLI -dylib [path or URL to your .dylib] <.h file paths to include>");
}

NSArray *headerPathsForArguments(int argc, const char *argv[]) {
    NSMutableArray *headerPaths = [NSMutableArray new];
    for (NSUInteger i = 1; i < argc; i++)
        [headerPaths addObject:[NSString stringWithUTF8String:argv[i]]];
    
    return headerPaths.copy;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSString *frameworkPath = [[NSUserDefaults standardUserDefaults] objectForKey:@"framework"];
        NSString *dylibPath = [[NSUserDefaults standardUserDefaults] objectForKey:@"dylib"];
        
        MPObjectiveCAnalyzer *analyzer = nil;
        NSError *err = nil;
        
        if (argc < 2 && !frameworkPath) {
            printUsage();
            exit(1);
        }

        if ((frameworkPath && dylibPath) || (!frameworkPath && !dylibPath)) {
            printUsage();
            exit(2);
        }
        else if (frameworkPath) {
            analyzer = [[MPObjectiveCAnalyzer alloc] initWithBundleAtURL:[NSURL fileURLWithPath:frameworkPath]
                                                   additionalHeaderPaths:@[] error:&err];
        }
        else if (dylibPath) {
            analyzer = [[MPObjectiveCAnalyzer alloc] initWithDynamicLibraryAtPath:dylibPath
                                                              includedHeaderPaths:@[] error:&err];
        }
        
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        NSString *language = [defs objectForKey:@"language"];
        MPObjectiveCTranslator *translator = [MPObjectiveCTranslator newTranslatorWithName:language];
        if ([language isEqualToString:@"csharp"] && [defs objectForKey:@"namespace"]) {
            [(MPObjectiveCToCSharpTranslator *)translator setNamespaceString:[defs objectForKey:@"namespace"]];
        }

        [analyzer enumerateTranslationUnits:^(NSString *path, CKTranslationUnit *unit) {
            MPObjectiveCTranslationUnit *tUnit
                = [analyzer analyzedTranslationUnitForClangKitTranslationUnit:unit atPath:path];
            fprintf(stdout, "%s", [translator translationForUnit:tUnit].UTF8String);
        }];
    }
    return 0;
}
