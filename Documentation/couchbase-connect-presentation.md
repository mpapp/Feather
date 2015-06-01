# Building offline first apps with Couchbase Lite and Feather

![fit](../Resources/icon.pdf)

Matias Piipari (**@mz2**)
CEO & Co-founder, *Manuscriptsapp.com*
CTO, *Papersapp.com*

---

# Why use Couchbase Lite in a mobile app?

1. Build web connected apps focused on the offline case.
2. Sync with a Couchbase / CouchDB-like server … or without.
3. Easy API for domain modeling.
4. Store both JSON documents and attachments.
5. It's user's data (as opposed to iCloud, Parse, Dropbox etc).
6. It's cross-platform.

---

# CBL is an open source project run by some really great people.

# Thank you!

---

# Why use Couchbase Lite in a desktop app?

- The same requirements apply.
- Sometimes you need mobile first, sometimes desktop first, sometimes web.
- CBL helps design in a way that doesn't hinder a platform move.

---

# I needed more building blocks.

- Partition data on disk for effective peer-to-peer syncing (!)
- Partition data in memory to 'tables' / 'collections'
- Easily "build" data for my app from primary sources.
- Support embedded object relations.

--- 

# Feather

![fit, original](../Resources/icon-1024.png)

---

# Embedded objects

- Embedded objects (or collections of thereof) encoded in a JSON document.
- Propagate changes to containing model object.

---

# Querying data

- Data validation.
- Query helper.

--- 

# Respond to updates in object graph

- Notifications for add / update / delete.
- Caching helpers!

--- 

# Relations

- Get data from a document database package.
- Fall back to shoebox database package.

---

# Copying with a prototype

---

## Database package

**In memory**: a root object for a group of CBL databases storing managed objects.

**On disk**: a group of .cblite files in the same folder.

---

## Stapler: a utility to create a database package

Input:

- A series of JSON files describing documents to load.
- (Optional: attachment metadata.)
- (Attachment files.)

Output: a Feather database package.

---

## Scriptability

- (Even sandboxed) Mac applications do not live on an island.