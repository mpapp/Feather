# The Managed Object Programming Guide

The MPManagedObject is the base class for the domain model objects in Feather. It extends Couchbase Lite's CBLModel. CBLModel and associated classes help with CRUD of versioned documents stored in a Couchbase Lite. MPManagedObject and its associated classes MPDatabase and MPDatabasePackageController add on top of this several kinds of higher level functionality:

 - Commonly useful properties:
   - Timestamps: createdAt, updatedAt which store approximate creation and last update times.
   - Authorship: the object creator, and its subsequent editors/
   - Object type: the class name of the object is stored under key 'objectType', allowing together with the other properties managed objects to be deserialised unambiguously from a JSON representation stored in CouchDB, Couchbase Lite or plain JSON files into an in-memory representation, and serialised back.
 - MPManagedObjectsController:
    - query managed objects using CouchCocoa views and queries.
    - cache model objects until they are deleted. This is necessary because no CouchCocoa object retains a strong pointer to a CouchModel object -- model objects would get deallocated the first moment they lose a reference from the Feather objects, whereas we want them to be deallocated only when they are deleted. A retain cycle is not introduced by this: CouchModel has a strong pointer to a CBLDocument, but the back pointer is weak.
    - Post notifications for managed object additions, deletions, updates, changes coming in via pull replication (MPManagedObjectChangeObserver is the base protocol for the observer registrations).
 - Freeform metadata:
    1. MPMetadata: a database metadata object which can be used for freeform metadata synced across devices.
    2. MPLocalMetadata which stores similarly freeform, but unreplicated, local metadata.
 - A conflict resolution policy that can be used with push/pull replication and extended for MPManagedObject subclasses.
 - Packages of Couchbase Lite databases: a number of databases are packaged and managed jointly by a MPDatabasePackageController, and stored...
    - under a shared root directory (.cblite formatted databases)
    - a shared CouchDB server in databases which share a naming scheme and can be found given a root URL and the database's name (interaction with remote is done using replication).
 - MPSnapshot: persisted versioning of all object and attachment data in a database package. Read more about snapshots from the [Snapshot Programming Guide](docs/snapshots.html).


## Subclassing

Subclassing MPManagedObject and associated classes is straightforward: although the base classes are intended to be abstract, and this is enforced, there are no methods which absolutely need to be overloaded. Strong naming conventions and introspection is used with class naming, avoiding having to overload methods. To give examples:

 - NSNotifications posted for adding, deleting or updating properties of a MPManagedObject are determined by the class name and the change type that happened (add, delete, update).
 - Managed object controller names follow the the form [X]sController where [X] is the name of the MPManagedObject subclass which the controller is responsible for managing. No overloading of +managedObjectClass is necessary because of this convention.

### Subclassing MPManagedObject

At the time of writing, there are no required methods to overload to subclass MPManagedObject.

MPManagedObject itself inherits via CouchModel from CouchDynamicObject the ability to define getters and setters for database backed, serialised properties dynamically during runtime. It is not necessary to implement accessors for such properties, but in Feather a convention of manually defined setters and getters is defined.

As an example, consider a MPManagedObject subclass MPDocument with properties title, subtitle, abstract, type. The implementation using the convention followed in Feather is the following:

    @implementation MPDocument
    - (void)setTitle:(NSString *)title { [self setValue:title ofProperty:@"title"]; }
    - (NSString *)title { return [self getValueOfProperty:@"title"]; }

    - (void)setSubtitle:(NSString *)subtitle { [self setValue:subtitle ofProperty:@"subtitle"]; }
    - (NSString *)subtitle { return [self getValueOfProperty:@"subtitle"]; }

    - (void)setAbstract:(NSString *)abstract { [self setValue:abstract ofProperty:@"abstract"]; }
    - (NSString *)abstract { return [self getValueOfProperty:@"abstract"]; }

    - (void)setType:(MPManuscriptType)type { [self setValue:@(type) ofProperty:@"manuscriptType"]; }
    - (MPManuscriptType)type { return [[self getValueOfProperty:@"manuscriptType"] intValue]; }
    @end

Definining these getters and setters during compile time is optional, and could be accomplished also with the following implementation.

    @implementation MPDocument
    @dynamic title, subtitle, abstract, type
    @end

### Subclassing MPManagedObjectsController

As with MPManagedObject, there are no hard requirements on which properties must be overloaded for correctly working subclasses. Typically subclasses of MPManagedObjectsController would overload [MPManagedObjectsController configureDesignDocument:] to define the views needed by the object queries of the controller, query methods, and public interfaces for querying managed objects.

    - (void)configureDesignDocument:(CouchDesignDocument *)designDoc
    {
        [super configureDesignDocument:designDoc];

        [designDoc defineViewNamed:@"snapshottedObjectsBySnapshotID" mapBlock:^(NSDictionary *doc, CBLMapEmitBlock emit) {
            emit(doc[@"snapshotID"], nil);
        }];
    }


## Database packages

A Feather document package contains multiple kinds of MPManagedObject instances. These objects are serialised in a series of databases locally on disk in a CBL database. Each MPDatabase contains serialised data for MPManagedObject instances of one or more kinds, each kind managed by one MPManagedObjectsController. In other words, a .manuscript document consists of multiple interlinked databases, a so-called 'database package'.

A Database package is read from and written to disk or a remote database by a MPDatabasePackageController (abstract class). See the unit test suite for examples of how to implement a MPDatabasePackageController.

## Snapshots

The managed objects contained in a database package, and attachments associated with the objects, can be persisted into a snapshot database, itself bundled also in the database package. A snapshot database contains:

 - MPSnapshotObject instances: snapshot objects (themselves subclasses of MPManagedObject) which store snapshot metadata such as an identifier, timestamp and an optional human readable name for the snapshot.
 - MPSnapshottedObject instances: objects which each contain a dictionary representation of another MPManagedObject instance under a key [MPSnapshottedObject snapshottedProperties].
   - A MPSnapshottedObject is immutable, and identified by the document ID whose data it contains, and the revision of this object it contains.
   - Because it is immutable it will only ever include a single revision.
   - When an object is snapshotted, its attachments are stored in the snapshot database. The MPSnapshottedObject record contains an array of SHA1 checksums of the attachments for the objects. If the SHA1 of the file contents match a pre-existing attachment in the snapshot database, no new attachment data is stored for it. If no match is found, a new MPSnapshottedAttachment is created for the attachment and its data is uploaded as an attachment to it.
 - MPSnapshottedAttachment instances: attachments of snapshotted objects are linked to objects of type MPSnapshottedAttachment. A MPSnapshottedAttachment is an attachment wrapper, which includes a SHA1 checksum ([MPSnapshottedAttachment sha]), content type ([MPSnapshottedAttachment contentType]) and an attachment ([MPSnapshottedAttachment attachment]).
   - A separate wrapper is used to avoid duplicating attachment data for each revision of an object which refers to the same attachment data as an earlier revision did.
   - If snapshot deletion is introduced at a later date, this separation should allow for garbage collecting snapshotted attachment data, by querying for snapshotted objects which are not referred to by any snapshotted object.

## Creating a snapshot, and reverting to one

A MPDatabasePackageController contains a MPSnapshotsController to allow the creation of, and reverting to database snapshots. The public interface for dealing with snapshots has two methods:

 1. [MPDatabasePackageController newSnapshotWithName:] for creating a snapshot.
 2. [MPDatabasePackageController restoreFromSnapshotWithName:error:] for restoring to a snapshot.

Restoring to a snapshot happens asynchronously. At the time of writing there is no completion handler or notification fired upon completion -- the usual MPManagedObjectChangeObserver notifications will fire though so the UI and internal caches kept by various objects in the application will respond to restoring of state (at an arbitrary order).

## feather.js - a Feather database package dump utility

Managed objects are serialised to a CBL database, which is a SQLite file with a schema described in more detail [here](https://github.com/couchbase/couchbase-lite-ios/wiki/Object-Design-And-Schema). In brief, the data for document revisions is stored in a table called 'revs' in a field called 'data', as blobs of JSON (read more about the Couchbase Lite schema. This data storage method makes it possible to dump and filter Couchbase Lite data in interesting ways. Feather includes a simple tool for dumping and filtering this data. Below you'll find the help description for feather.js available at the time of writing:

<pre>

feather.js --help

  Usage: feather.js [options]

  Options:

    -h, --help         output usage information
    -V, --version      output the version number
    -a, --all          Return all documents. By default returns only current value.
    -i, --id [doc_id]  Return document with specified ID.
    -k, --keys [keys]  Return only specified keys.
    -o, --type [type]  Return objects with the specified objectType field.
    -d, --deleted      Return deleted values.

</pre>