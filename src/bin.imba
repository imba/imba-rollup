import {parseArgs} from './helpers'
var fs = require 'fs'
var path = require 'path'
var args = process.argv.slice(0)
var env = Object.assign({}, process.env)
var cwd = process.cwd()

var schema = {
	alias: {
		h: 'help',
		s: 'serve',
		p: 'print',
		v: 'version',
		w: 'watch',
		d: 'debug'
	},
	
	schema: {
		config: {type: 'string'},
		output: {type: 'string'},
		target: {type: 'string'},
		format: {type: 'string'},
	},
	group: ['source-map']
}
var options = parseArgs(process.argv.slice(0),schema)
var cfgPath = path.resolve(cwd,options.config || 'imbaconfig.json')
var dir = path.dirname(cfgPath)
var cfg = fs.existsSync(cfgPath) ? require(cfgPath) : {}
var imbaPath = path.resolve(__dirname,'../node_modules/imba')

def relPath dir
	path.relative(cwd,dir)

def absPath dir
	path.resolve(cwd,dir)

def resolvePaths obj
	if obj isa Array
		for item,i in obj
			obj[i] = resolvePaths(item)
	elif typeof obj == 'string'
		return obj.replace(/^\.\//,dir + '/')
	elif typeof obj == 'object'
		for own k,v of obj
			obj[k] = resolvePaths(v)
	return obj


import rollup from 'rollup'
import imba-plugin from 'imba/rollup.js'
import resolve from 'rollup-plugin-node-resolve'
import commonjs from 'rollup-plugin-commonjs'
import serve-plugin from 'rollup-plugin-serve'
import hmr-plugin from 'rollup-plugin-livereload'

var bundles = []
var watch = options.watch
var serve = options.serve

class Bundle
	def constructor config
		@config = config
		@promise = Promise.new do |resolve,reject|
			@resolver = resolve
			@rejector = reject
		self

	def start
		@watcher = rollup.watch(@config)
		@watcher.on('event') do |e| @onevent(e)
		return @promise

	def onevent e
		# console.log "event",e
		if e.code == 'BUNDLE_START'
			console.log "bundles {relPath(e.input)} → {relPath(e.output[0])}"
		elif e.code == 'BUNDLE_END'
			console.log "created {relPath(e.input)} → {relPath(e.output[0])} in {e.duration}ms"
			# @resolver(e)
		elif e.code == 'ERROR'
			console.log "bundling error",e
			@rejector(e)
		elif e.code == 'END'
			# console.log "created {relPath(e.input)} → {relPath(e.output[0])}"
			@resolver(e)


for entry in cfg.entries
	entry = resolvePaths(entry)
	let target = entry.target or 'web'
	let plugins = (entry.plugins ||= [])
	plugins.unshift(commonjs())
	plugins.unshift(resolve(extensions: ['.imba', '.mjs','.js','.cjs','.json']))
	plugins.unshift(imba-plugin(target: target, imbaPath: imbaPath))

	if options.serve and target == 'web'
		let pubdir = path.dirname(entry.output.file)
		plugins.push(serve-plugin({contentBase: pubdir,historyApiFallback: true}))
		if options.hmr
			plugins.push(hmr-plugin(pubdir))
	bundles.push(Bundle.new(entry))

def run
	var bundlers = await Promise.all(bundles.map(do $1.start() ))

	unless watch
		process.exit(0)

run()