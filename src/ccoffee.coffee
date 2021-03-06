#!/usr/bin/env node --harmony

builder = require './ccoffee/builder.generators'
params = require 'commander'
glob = require 'glob'
suspend = require 'suspend'
go = suspend.resume
assert = require 'assert'

params
	# TODO read version from package.json
	.version('0.2.1')
  .usage('-i <src> -o <build>')
#	.option('-w, --watch', 'Watch for file changes')
#	.option('-l, --log', 'Show logging information')
	.option('-i, --source-dir <dir>', 
		'Input directory for the source files (required)')
	.option('-o, --build-dir <dir>', 
		'Output directory for the built files (required)')
	.option('-p, --pack <FILE:MODULE_NAME>', 'Creates a CJS browserify package')
	.option('-w, --watch', 'Watch for the source files changes')
	.option('-y, --yield', 'Support the yield (generators) syntax (currently' +
			' doesn\'t work with --pack)')
	.parse(process.argv)

if not params.sourceDir or not params.buildDir 
	return params.help()

if params.yield and params.pack 
	return params.help()

main = suspend ->
	# TODO doesnt glob subdirs?
	files = yield glob '**/*.coffee', {cwd: params.sourceDir}, go()
	assert files.length, "No files to precess found"
	worker = new builder.Builder files, params.sourceDir, params.buildDir, params.pack,
		params.yield
	
	# run
	if params.watch
		yield worker.watch go()
	else 
		yield worker.build go()
		console.log "Compilation completed"
		
main()

###
TODO
  var files input
	watch files
  watch definitions
  flowless restart (clock)
  ...
  typescript service integration? (via memory, not just files)
  merge command line tools directly to this event loop
  watch changes throttling support
###