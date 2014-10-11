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
                                                includedHeaderPaths:headerPathsForArguments(argc, argv)
                                                              error:&err];
        }
        else if (dylibPath) {
            analyzer = [[MPObjectiveCAnalyzer alloc] initWithDynamicLibraryAtPath:dylibPath
                                                         includedHeaderPaths:headerPathsForArguments(argc, argv)
                                                                       error:&err];
        }
        
        for (NSString *includedHeaderPath in analyzer.includedHeaderPaths) {
            [analyzer enumDeclarationsForHeaderAtPath:includedHeaderPath];
        }
        
        /*
        for (NSString *includedHeaderPath in analyzer.includedHeaderPaths) {
            [analyzer enumerateTokensForCompilationUnitAtPath:includedHeaderPath
                                                 forEachToken:
             ^(CKTranslationUnit *unit, CKToken *token) {
                fprintf(stdout, "%s\n",
                        [NSString stringWithFormat:@"%@, %lu: %@ (token kind: %lu, cursor kind: %lu, %@)",
                         includedHeaderPath.lastPathComponent, token.line, token.cursor.displayName, token.kind, token.cursor.kind, token.cursor.kindSpelling].UTF8String);
            } matchingPattern:
             ^BOOL(NSString *path, CKTranslationUnit *unit, CKToken *token) {
                return YES;
            }];
        }
         */
        
        // for each translation unit
        
        // 1) get its constant declarations

        // 2) get its interface declarations
        
        // 3) get its protocol declarations
        
        // 4) get its enum declarations
        
        // 5)for each interface found
        // 5a) get its class object using runtime API
        // 5b) enumerate its properties
        // 5c) enumerate its instance variables
        // 5d) enumerate its class methods
        // 5e) enumerate its instance methods
        
        // 6) for each protocol found
        // 6a) get its Protocol object using runtime API
        // 6b) enumerate its properties
        // 6c) enumerate its instance variables
        // 6d) enumerate its class methods
        // 6e) enumerate its instance methods
    }
    return 0;
}
