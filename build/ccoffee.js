// Generated by CoffeeScript 1.3.3
(function() {
  var assert, builder, glob, go, main, params, suspend;

  builder = require('./ccoffee/builder.generators');

  params = require('commander');

  glob = require('glob');

  suspend = require('suspend');

  go = suspend.resume;

  assert = require('assert');

  params.version('0.2.1').usage('-i <src> -o <build>').option('-i, --source-dir <dir>', 'Input directory for the source files (required)').option('-o, --build-dir <dir>', 'Output directory for the built files (required)').option('-p, --pack <FILE:MODULE_NAME>', 'Creates a CJS browserify package').option('-w, --watch', 'Watch for the source files changes').option('-y, --yield', 'Support the yield (generators) syntax (currently' + ' doesn\'t work with --pack)').parse(process.argv);

  if (!params.sourceDir || !params.buildDir) {
    return params.help();
  }

  if (params["yield"] && params.pack) {
    return params.help();
  }

  main = suspend(function*() {
    var files, worker;
    files = yield glob('**/*.coffee', {
      cwd: params.sourceDir
    }, go());
    assert(files.length, "No files to precess found");
    worker = new builder.Builder(files, params.sourceDir, params.buildDir, params.pack, params["yield"]);
    if (params.watch) {
      return yield worker.watch(go());
    } else {
      yield worker.build(go());
      return console.log("Compilation completed");
    }
  });

  main();

  /*
  TODO
    var files input
  	watch files
    watch definitions
    flowless restart (clock)
    ...
    typescript service integration? (via memory, not just files)
    merge command line tools directly to this event loop
    watch changes throttling support
  */


}).call(this);
