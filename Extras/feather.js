#!/usr/bin/env node
var sqlite3 = require('sqlite3');
var program = require('commander');
var path = require('path');
var async = require('async');
var EventEmitter = require('events').EventEmitter;
var fs = require('fs');

program
  .version('0.0.1')
  .option('-a, --all', 'Return all documents. By default returns only current value.')
  .option('-i, --id [doc_id]', 'Return document with specified ID.')
  .option('-k, --keys [keys]', 'Return only specified keys.')
  .option('-o, --type [type]', 'Return objects with the specified objectType field.')
  .option('-d, --deleted', "Return deleted values.")
  .parse(process.argv);

if (program.args.length == 0)
	program.help();

var rootDir = program.args[0];


var dbNames = fs.readdirSync(rootDir).filter(function(x){ return x.match(/\.cblite$/); })
var dbs = {};
dbNames = dbNames.forEach(function(dbName) {
	dbs[dbName] = new sqlite3.Database(rootDir + "/" + dbName);
});

var cbl = new EventEmitter();

cbl.on('summary', function(dbName) {
	var db = dbs[dbName];
	db.serialize(function() {
		var queryStr = "SELECT json as json, docs.docid as docid, revid, current, deleted FROM revs INNER JOIN docs ON docs.doc_id = revs.doc_id";

		var criteria = [];
		if (!program.all) { criteria.push("current = 1"); }
		if (program.id) { criteria.push("docid = '" + program.id + "'"); }
		if (criteria.length > 0) { queryStr += " WHERE " + criteria.join(" AND "); }

		db.all(queryStr, function(err, jsonRows) {
			if (!jsonRows) return;

			jsonRows.forEach(function(row) {
				if (!program.deleted && row.deleted == '1') { return; }

				if (row.json && row.json.length > 1) {
					var json = JSON.parse(row.json.toString());

					if (program.type && json.objectType != program.type) { return; }

					console.log(row.docid + " : " + row.revid + " (current: " + row.current + ")");

					if (program.keys) {
						var ret = {};
						var keys = program.keys.split(",");
						for (var k in keys) {
							var key = keys[k];
							ret[key] = json[key];
						}
						json = ret;
					}

		            console.log(json);
					console.log();
				}
				else {
					if (program.type && !row.docid.match(new RegExp("^"+program.type))) { return; };
					console.log(row.docid + " : " + row.revid + " (current: " + row.current + ", deleted:" + row.deleted + ")");
					console.log("<<< null >>>");
					console.log();
				}
	        });
		});
	});
});

for (var d in dbs) {
	cbl.emit('summary', d);
}
