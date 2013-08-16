/*
   Copyright (c) 2013 Snippex. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.

 THIS SOFTWARE IS PROVIDED BY Snippex `AS IS' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL Snippex OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SPXStore.h"

static NSString *defaultModelName;
static NSString *defaultStoreName;
static NSString *defaultSeedPath;

@interface NSManagedObjectContext (SPXStoreAdditionsCategory)
- (void)setSPX_store:(id)store;
@end

@interface SPXStoreManager : NSObject

@property (nonatomic, strong) NSMutableDictionary *stores;

- (void)addStore:(SPXStore *)store name:(NSString *)name;
- (SPXStore *)storeNamed:(NSString *)name;

@end

@implementation SPXStoreManager

+(instancetype)sharedInstance
{
	static SPXStoreManager *_sharedInstance = nil;
	static dispatch_once_t oncePredicate;
	dispatch_once(&oncePredicate, ^{
		_sharedInstance = [[self alloc] init];
	});

	return _sharedInstance;
}

- (NSMutableDictionary *)stores
{
    return _stores ?:
    (_stores = [[NSMutableDictionary alloc] init]);
}

- (void)addStore:(SPXStore *)store name:(NSString *)name
{
    [self.stores setObject:store forKey:name];
}

- (SPXStore *)storeNamed:(NSString *)name
{
    return [self.stores objectForKey:name];
}

@end

@interface SPXStore ()
@property (nonatomic, strong) NSManagedObjectModel *model;
@property (nonatomic, strong) NSPersistentStoreCoordinator *coordinator;
@property (nonatomic, strong) NSMutableDictionary *entityKeys;
@property (nonatomic, strong) NSManagedObjectContext *mainContext;
@property (nonatomic, strong) NSManagedObjectContext *privateContext;
@end

@implementation SPXStore

+ (NSError *)saveContext:(NSManagedObjectContext *)context
{
    NSError *error = nil;
    if ([context hasChanges]) [context save:&error];
    return error;
}

- (NSString *)debugDescription
{
    return [NSString stringWithFormat:@"%@\n%@", [self URL], _model.entityVersionHashesByName];
}

- (BOOL)copySeedDatabaseIfRequiredFromPath:(NSString *)seedPath toPath:(NSString *)storePath error:(out NSError * __autoreleasing *)error
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:storePath])
    {
        NSError *localError;
        if (![[NSFileManager defaultManager] copyItemAtPath:seedPath toPath:storePath error:&localError])
        {
            DLog(@"Failed to copy seed database from path '%@' to path '%@': %@", seedPath, storePath, [localError localizedDescription]);
            if (error) *error = localError;
            return NO;
        }
    }

    return YES;
}

- (id)initWithModelName:(NSString *)model storeName:(NSString *)name seedPath:(NSString *)seedPath
{
    if (!(name.length && model.length))
	{
		NSException *exception = [NSException exceptionWithName:NSInvalidArgumentException
														 reason:@"Invalid store or model name specified"
													   userInfo:nil];
		[exception raise];
	}

    self = [super init];

    if (self)
    {
        NSError *error = nil;
        NSString *filename = [NSString stringWithFormat:@"%@.sqlite", name];
        NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:filename];

        if (seedPath && ![self copySeedDatabaseIfRequiredFromPath:seedPath toPath:[storeURL path] error:&error])
            DLog(@"%@", error);

        NSDictionary *options = @{  NSMigratePersistentStoresAutomaticallyOption    : @(YES),
                                    NSInferMappingModelAutomaticallyOption          : @(YES),
                                 };

        _model = [NSManagedObjectModel mergedModelFromBundles:[NSBundle allBundles]];
        _coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:_model];

        if (![_coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error])
        {
            DLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(privateContextDidSave:)
                                                     name:NSManagedObjectContextDidSaveNotification
                                                   object:[self privateContext]];
    }

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)privateContextDidSave:(NSNotification *)note
{
    [self.mainContext performBlock:^{
        [self.mainContext mergeChangesFromContextDidSaveNotification:note];
    }];
}

+ (void)setDefaultStoreName:(NSString *)name filename:(NSString *)filename
{
    [self setDefaultStoreName:name filename:filename seedPath:nil];
}

+ (void)setDefaultStoreName:(NSString *)name filename:(NSString *)filename seedPath:(NSString *)seedPath
{
    NSAssert((name.length && filename.length),
             @"name and filename must not be nil and must have a length greater than 0");
    NSAssert(!(defaultStoreName.length && defaultModelName.length),
             @"You must call this method BEFORE using +default and the defaults CANNOT be set more than once!");

    defaultModelName = name;
    defaultStoreName = [filename stringByDeletingPathExtension];
    defaultSeedPath = seedPath;
}

- (NSMutableDictionary *)entityKeys
{
    return _entityKeys ?:
    (_entityKeys = [[NSMutableDictionary alloc] init]);
}

- (NSManagedObjectContext *)newContextForType:(NSManagedObjectContextConcurrencyType)concurrencyType
{
    NSManagedObjectContext *managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:concurrencyType];

    [managedObjectContext performBlockAndWait:^
    {
        managedObjectContext.parentContext = self.privateContext;
        managedObjectContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy;
    }];

    return managedObjectContext;
}

- (NSManagedObjectContext *)mainContext
{
    if (!_mainContext)
    {
        _mainContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];

        [_mainContext performBlockAndWait:^
        {
            [_mainContext setPersistentStoreCoordinator:_coordinator];
            [_mainContext setMergePolicy:NSMergeByPropertyStoreTrumpMergePolicy];
        }];

        [_mainContext performSelector:@selector(setSPX_store:) withObject:self];
    }

    return _mainContext;
}

- (NSManagedObjectContext *)privateContext
{
    if (!_privateContext)
    {
        _privateContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];

        [_privateContext performBlockAndWait:^
        {
            [_privateContext setParentContext:[self mainContext]];
            [_privateContext setMergePolicy:NSMergeByPropertyStoreTrumpMergePolicy];
        }];

        [_privateContext performSelector:@selector(setSPX_store:) withObject:self];
    }

    return _privateContext;
}

+ (NSManagedObjectContext *)mainContext
{
    return [[SPXStore default] mainContext];
}

+ (NSManagedObjectContext *)privateContext
{
    return [[SPXStore default] privateContext];
}

- (NSURL *)URL
{
    return [[[_coordinator persistentStores] lastObject] URL];
}

+ (instancetype)default
{
    if (!defaultModelName.length || !defaultStoreName.length)
    {
        NSString *name = [[[NSBundle mainBundle] infoDictionary]
                          objectForKey:(NSString*)kCFBundleNameKey];

        defaultModelName = name;
        defaultStoreName = name;
    }

    SPXStore *store = [[SPXStoreManager sharedInstance] storeNamed:defaultModelName];
    
    if (!store)
    {
        store = [[SPXStore alloc] initWithModelName:defaultModelName storeName:defaultStoreName seedPath:defaultSeedPath];
        [[SPXStoreManager sharedInstance] addStore:store name:defaultModelName];
    }

    return store;
}

+ (instancetype)addStoreNamed:(NSString *)name filename:(NSString *)filename seedPath:(NSString *)seedPath
{
    SPXStore *store = [[SPXStore alloc] initWithModelName:name storeName:[filename stringByDeletingPathExtension] seedPath:seedPath];
    [[SPXStoreManager sharedInstance] addStore:store name:name];
    return store;

}

+ (instancetype)addStoreNamed:(NSString *)name filename:(NSString *)filename
{
    return [self addStoreNamed:name filename:filename seedPath:nil];
}

+ (instancetype)storeNamed:(NSString *)name
{
    NSAssert(name, @"name cannot be nil");

    SPXStore *store = [[SPXStoreManager sharedInstance] storeNamed:name];
    if (store) return store;

    store = [[SPXStore alloc] init];
    [[SPXStoreManager sharedInstance] addStore:store name:name];

    return store;
}

- (void)setKey:(id)key forEntityNamed:(NSString *)name
{
    NSAssert((key && name), @"key and/or name cannot be nil");
    [self.entityKeys setObject:key forKey:name];
}

- (NSString *)keyForEntityNamed:(NSString *)name
{
    id identifier = [self.entityKeys objectForKey:name];
    return identifier ?: @"identifier";
}

#pragma mark - File management

-(NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end
