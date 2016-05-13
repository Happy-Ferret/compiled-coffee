"""
TODO:
- use TypeScript.api for watching and skip the fs.
"""

suspend = require 'suspend'
go = suspend.resume
spawn = require('child_process').spawn
async = require 'async'
#tsapi = require "../../node_modules/typescript.api/bin/index.js"
# TODO why this doesnt work? :O
#ts_yield = require 'typescript-yield'
ts_yield = require '../../node_modules/typescript-yield/build/functions.js'
fs = require 'fs'
mkdirp = require 'mkdirp'
writestreamp = require 'writestreamp'
mergeDefinition = require('../dts-merger/merger').merge
coffee_script = require "../../node_modules/coffee-script-to-" +
		"typescript/lib/coffee-script"
cs_helpers = require "../../node_modules/coffee-script-to-" +
		"typescript/lib/helpers"
#spawn_ = spawn
#spawn = (args...) ->
#	console.log 'Executing: ', args
#	spawn_.apply null, args
path = require 'path'
EventEmitter = require('events').EventEmitter
require 'sugar'

# TODO fix constructor params
class Builder extends EventEmitter
	clock: 0
	build_dirs_created: no
	source_dir: null
	output_dir: null
	sep: path.sep

	constructor: (@files, source_dir, output_dir, @pack = no, @yield = no) ->
		super

		@output_dir = path.resolve output_dir
		@source_dir = path.resolve source_dir

		@coffee_suffix = /\.coffee$/

	prepareDirs: suspend.callback ->
		return if @build_dirs_created
		dirs = [@output_dir]
		dirs.push @output_dir + @sep + 'dist' if @pack
		yield async.eachSeries dirs, (suspend.callback (dir) =>
				exists = yield fs.exists dir, suspend.resumeRaw()
				if not exists[0]
					yield fs.mkdir dir, go()
#					try yield fs.mkdir path, go()
#					catch e
#						throw e if e.type isnt 'EEXIST'
			), go()
		@build_dirs_created = yes

	build: suspend.callback ->
		tick = ++@clock
		error = no

#		console.time 'tick'
		yield @prepareDirs go()
		return @emit 'aborted' if @clock isnt tick
#		(console.timeEnd 'tick')

		# Process definition merging and other source manipulation
		sources = yield async.map @files, (@processSource.bind @, tick), go()
		return @emit 'aborted' if @clock isnt tick
#		(console.timeEnd 'tick')

		# Compile
		# TODO use tss tools or typescript.api (keep all in memory)
		@proc = spawn "#{__dirname}/../../node_modules/typescript/bin/tsc", [
				"#{__dirname}/../../d.ts/ecma.d.ts", 
				"--module", "commonjs",
				"--declaration", 
				"--sourcemap", 
				"--noLib"]
					.include(@tsFiles()),
			cwd: "#{@output_dir}/"
		@proc.stdout.setEncoding 'utf8'
		@proc.stdout.on 'data', (err) =>
			# filter out the file path
			remove = "#{@output_dir}#{@sep}"
			while ~err.indexOf remove
				err = err.replace remove, ''
			process.stdout.write err

		ts_warnings = no
		try yield @proc.on 'close', go()
		catch e
			ts_warnings = yes
		return @emit 'aborted' if @clock isnt tick
#		(console.timeEnd 'tick')

		# Process definition merging and other source manipulation
		yield async.map @files, (@processBuiltSource.bind @, tick), go()
		return @emit 'aborted' if @clock isnt tick
#		(console.timeEnd 'tick')

		if @pack
			[entry_file, module_name] = @pack.split ':'
			# Pack
			@proc = spawn "#{__dirname}/../../node_modules/browserify/bin/cmd.js", [
					"-e", entry_file
					"--standalone", module_name
					"-g", "#{__dirname}/../../node_modules/uglifyify"
					"--detect-globals", "false"
					"-o", "#{@output_dir}-pkg/#{module_name}.js"],
				cwd: "#{@output_dir}/"
			@proc.stderr.setEncoding 'utf8'
			@proc.stderr.on 'data', (err) =>
				# filter out the file path
				remove = "#{@output_dir}#{@sep}"
				while ~err.indexOf remove
					err = err.replace remove, ''
				process.stdout.write err

			yield @proc.on 'close', go()
			return @emit 'aborted' if @clock isnt tick
#			(console.timeEnd 'tick')
		
		throw new TypeScriptError if ts_warnings 

		@proc = null

	tsFiles: -> 
		files = (file.replace @coffee_suffix, '.ts' for file in @files)

	dtsFiles: -> 
		files = (file.replace @coffee_suffix, '.d.ts' for file in @files)

#	saveTypeScript: suspend.callback (files) ->
#
#	# TODO tsapi.reset() on watch !!!
#	compileTypeScript: (sources) ->
#		files = []
#		units = []
#		for item in sources
#			units.push tsapi.create item.file, item.source
#			files.push item.file
#
#		tsapi.resolve files, (resolved) ->
#			# check here for reference errors. 
#			throw new TypeScriptError resolved if not tsapi.check resolved
#			tsapi.compile resolved, (compiled) ->
#				# check here for syntax and type errors.
#				throw new TypeScriptError compiled if not tsapi.check compiled
#				compiled

	processSource: suspend.callback (tick, file) ->
		source = yield @readSourceFile file, go()
		return @emit 'aborted' if @clock isnt tick
		source = @processCoffee file, source
		source = yield @mergeDefinition file, source, go()
		yield @writeTsFile file, source, go()

		file: (file.replace /\.coffee$/, '.ts'), source: source

	processCoffee: (file, source) ->
		# Coffee to TypeScript
		try
			cs_helpers.setTranslatingFile file, source 
			{ js, v3SourceMap } = coffee_script.compile source, sourceMap: yes
			# TODO write the v3SourceMap
			js
		catch err
			useColors = process.stdout.isTTY and not process.env.NODE_DISABLE_COLORS
			message = cs_helpers.prettyErrorMessage err, file, source, useColors
			console.log "error compiling #{file}"
			console.log message
			throw new CoffeeScriptError

	readSourceFile: suspend.callback (file) ->
		yield fs.readFile ([@source_dir, file].join @sep), 
			{encoding: 'utf8'}, go()

	processBuiltSource: suspend.callback (tick, file) ->
		js_file = file.replace @coffee_suffix, '.js'
		source = yield fs.readFile @output_dir + @sep + js_file, 
			{encoding: 'utf8'}, go()
		return @emit 'aborted' if @clock isnt tick
		source = @transpileYield source if @yield
		yield @writeJsFile file, source, go()

	transpileYield: (source) ->
		ts_yield.markGenerators ts_yield.unwrapYield source

	writeTsFile: suspend.callback (file, source) ->
		yield mkdirp @output_dir, go()
		ts_file = file.replace @coffee_suffix, '.ts'
		destination = fs.writeFileSync "#{@output_dir}/#{ts_file}", source

	writeJsFile: suspend.callback (file, source) ->
		yield mkdirp @output_dir, go()
		js_file = file.replace @coffee_suffix, '.js'
		destination = fs.writeFileSync "#{@output_dir}/#{js_file}", source

	mergeDefinition: suspend.callback (file, source) ->
		dts_file = file.replace @coffee_suffix, '.d.ts'
		# no definition file, copy the transpiled source directly
		exists = yield fs.exists @source_dir + @sep + dts_file, suspend.resumeRaw()
		if exists[0]
			definition = yield fs.readFile @source_dir + @sep + dts_file, 
					{encoding: 'utf8'}, go()
			mergeDefinition source, definition
		else source

	close: ->
		@proc?.kill()

	clean: ->
		throw new Error 'not implemented'

	reload: suspend.callback (refreshed) ->
		console.log '-'.repeat 20 if refreshed
		@proc?.kill()
		try
			yield @build go()
			console.log "Compilation completed"
		catch e
			if e not instanceof TypeScriptError and e not instanceof CoffeeScriptError
				throw e
			else
				console.log "Compilation completed with warnings"

	watch: suspend.callback -> 
		for file in @files
			node = @source_dir + @sep + file
			fs.watchFile node, persistent: yes, interval: 500, => 
				@reload yes, ->
		for file in @dtsFiles()
			node = @source_dir + @sep + file
			# TODO watch parent dirs for non yet existing d.ts files
			exists = yield fs.exists node, suspend.resumeRaw()
			continue if not exists[0]
			fs.watchFile node, persistent: yes, interval: 500, => 
				@reload yes, ->
		yield @reload no, go()

class TypeScriptError extends Error
	constructor: ->
		super 'TypeScript compilation error'

class CoffeeScriptError extends Error
	constructor: ->
		super 'CoffeeScript compilation error'


module.exports = {
	Builder, CoffeeScriptError, TypeScriptError
}