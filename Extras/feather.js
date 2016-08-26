#!/usr/bin/env node
var sqlite3 = require('sqlite3');
var program = require('commander');
var path = require('path');
var async = require('async');
var EventEmitter = require('events').EventEmitter;
var fs = require('fs');
var assert = require('assert');

program
  .version('0.0.1')
  .option('-a, --all', 'Return all documents. By default returns only current value.')
  .option('-i, --id [doc_id]', 'Return document with specified ID.')
  .option('-k, --keys [keys]', 'Return only specified keys.')
  .option('-o, --type [type]', 'Return objects with the specified objectType field.')
  .option('-d, --deleted', "Return deleted values.")
  .option('-v, --validate', "Validate objects")
  .parse(process.argv);

if (program.args.length === 0)
	program.help();

var rootDir = program.args[0];


var dbNames = fs.readdirSync(rootDir).filter(function(x){ return x.match(/\.cblite$/); })
var dbs = {};
dbNames = dbNames.forEach(function(dbName) {
	dbs[dbName] = new sqlite3.Database(rootDir + "/" + dbName);
});

var cbl = new EventEmitter();

function handleRow(row) {
	if (!program.deleted && row.deleted === '1') {
        return;
    }

	if (row.json && row.json.length > 1) {
		let json = JSON.parse(row.json.toString());

		if (program.type && json.objectType !== program.type) { return; }

		console.log(row.docid + " : " + row.revid + " (current: " + row.current + ")");

		if (program.keys) {
			var ret = {};
			var keys = program.keys.split(",");
			for (const key of keys) {
				ret[key] = json[key];
			}
			json = ret;
		}

        console.log(json);
		console.log();
	}
	else {
		if (program.type && !row.docid.match(new RegExp("^"+program.type))) {
            return;
        }
		console.log(row.docid + " : " + row.revid + " (current: " + row.current + ", deleted:" + row.deleted + ")");
		console.log(row.json.toString());
    	console.log();
	}

    if (program.validate) {
        assert(row.json.length > 1, "Object JSON string should not be empty");
        const json = JSON.parse(row.json.toString());

        assert(json.objectType, "Object is missing the required 'objectType' field: " + json);
        assert(row.docid.indexOf(':') > -1, "Object ID does not match expectation: " + json._id);
    }
}

cbl.on('summary', function(dbName) {
	var db = dbs[dbName];
	db.serialize(function() {
		var queryStr = "SELECT json as json, docs.docid as docid, revid, current, deleted FROM revs INNER JOIN docs ON docs.doc_id = revs.doc_id";

		var criteria = [];
		if (!program.all) {
			criteria.push("current = 1");
		}
		if (program.id) {
			criteria.push("docid = '" + program.id + "'");
		}
		if (criteria.length > 0) {
			queryStr += " WHERE " + criteria.join(" AND ");
		}

		db.all(queryStr, (err, jsonRows) => {
			if (!jsonRows) { 
				return;
			}

			jsonRows.forEach(handleRow);
		});
	});
});

for (const d of dbs) {
	cbl.emit('summary', d);
}
