## About Feather [![build status](https://gitlab.com/mpapp/Feather/badges/master/build.svg)](https://gitlab.com/mpapp/Feather/commits/master) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

Feather is a set of data modeling and persistence classes built on top of Couchbase Lite, intended to provide data model and model controller classes with strong conventions which I've found useful when building a largeish application on top of Couchbase Lite.

The MPManagedObject, the MPManagedObjectsController, and MPDatabasePackageController form the basis of the Manuscripts.app domain model. You can read more about these in [Managed Object Programming Guide](docs/Managed Objects.html). Here's however a short intro to the key classes in the framework:

 - MPDatabasePackageController: a collection of related .cblite databases under a shared root. The class is not specific to document based applications, but in a NSDocument / UIDocument based application, your document subclass can essentially act as a facade to a database package controller.

 - MPManagedObjectsController: a controller for a subset of model objects stored in one of the .cblite databases of a database package. A database package controller has managed objects controllers for the different kinds of models stored in the database. In turn any 'managed object' in a Feather-like .cblite database has a managed objects controller.

    - a container for views & queries, collations of subsets of objects in a database package.
    - For instance, a MPEmployeesController manages MPEmployee managed object instances, and the connection is done based on reflection (pluralise model class name and add 'Controller' in the end -- this is enforced).
    - Models can be subclassed: if managed object class X subclasses MPManagedObject, the application must have a corresponding controller class XsController. If I however subclass Y from X, there is no requirement to have a YsController if XsController exists (a concrete controller class is required).
    - Notification posting for managed object additions, deletions, updates, and changes coming in via pull replication (minor patch to was required for correctly  detecting external from internal changes). Notification names are determined based on the closest controller type available. For instance in the above X, Y, XsController case, adding a model object of type Y would fire a "didAddY" notification.

 - MPManagedObject: a CBLModel subclass with some added functionality and conventions.
     - Commonly useful properties for model objects:
        - Object type: the class name of the object is stored under key 'objectType', allowing together with the other properties managed objects to be deserialised unambiguously from a JSON representation stored in CouchDB, TouchDB or plain JSON files into an in-memory representation, and serialised back. This is basically the 'type' property from CBLModel taken to a logical extreme.
        - Timestamps: createdAt, updatedAt which store approximate creation and last update times.
        - Contributorship: the object creator, and its subsequent editors.

 - MPEmbeddedObject: a CouchDynamicObject subclass that can be embedded as a property in MPManagedObject. An MPEmbeddedObject can also embed other MPEmbeddedObjects (though the root in the object tree must be a MPManagedObject).
     - Provides ability to use complex types in the model classes, for 1:1 and 1:many mappings where one side of the relationship doesn't need a top-level document.
     - If a field in an embedded object is changed, this is propagated back to the MPManagedObject (so the model object gets marked for saving, same as if any other field in the "embedding" MPManagedObject got changed).
     - The fields are expressed internally as JSON dictionaries embedded in the MPManagedObject's properties dictionary.

 - Mixins:
    - Cached derived properties: any readwrite @properties of a class which mixes in MPCachaeable are cleared automatically when -clearCachedValues is sent to it. This functionality is mixed into both MPManagedObjectsController and MPManagedObject, and cache clearing messages are sent to the managed objects controllers for instance when an objects of the type the controller manages are added or removed (so for instance cached lists of objects can be cleared).

 - Snapshots: persisted versioning of all object and attachment data in a database package.
    - The managed objects contained in a database package, and attachments associated with the objects, can be persisted into a snapshot database, itself bundled also in the database package. A snapshot database contains:

 - feather.js -- a commandline utility for querying ('grepping') objects stored in .cblite databases.
