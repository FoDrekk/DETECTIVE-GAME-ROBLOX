/**
 * Pure-JS shim for the native lz4 module used by rbxm-parser.
 * The native lz4 package (v0.6.x) requires node-gyp to compile xxhash.node
 * and lz4.node, which fails without Visual Studio C++ build tools on Windows.
 *
 * rbxm-parser only uses three functions from lz4:
 *   - decodeBlock(src, dst)   — LZ4 block decompression
 *   - encodeBlock(src, dst)   — LZ4 block compression
 *   - encodeBound(inputSize)  — upper bound on compressed size
 *
 * This shim replaces the native bindings with the pure-JS lz4js package.
 *
 * Usage: require this file BEFORE requiring rbxm-parser, or set NODE_PATH.
 * Alternatively, the build script can be patched to use this module.
 */
const lz4js = require("lz4js");
const path = require("path");

// Patch the native lz4 module in-place.
const lz4Dir = path.dirname(require.resolve("lz4/package.json"));
const lz4Main = require(path.join(lz4Dir, "lib", "static.js"));

// Replace the native bindings with pure-JS equivalents.
const pureBindings = {
  uncompress(src, dst) {
    // lz4js.decompressBlock expects Uint8Arrays.
    const srcArr = new Uint8Array(src.buffer, src.byteOffset, src.length);
    const dstArr = new Uint8Array(dst.buffer, dst.byteOffset, dst.length);
    return lz4js.decompressBlock(srcArr, dstArr, 0, src.length, 0);
  },
  compress(src, dst) {
    const srcArr = new Uint8Array(src.buffer, src.byteOffset, src.length);
    const dstArr = new Uint8Array(dst.buffer, dst.byteOffset, dst.length);
    return lz4js.compressBlock(srcArr, dstArr, 0, src.length, 0);
  },
  compressBound(inputSize) {
    return lz4js.compressBound(inputSize);
  },
};

// Patch utils.bindings to avoid loading the native addon.
lz4Main.utils.bindings = pureBindings;

// Also patch the xxhash functions with no-ops (rbxm-parser doesn't use them
// for block-level operations; it only needs decodeBlock/encodeBlock).
lz4Main.utils.descriptorChecksum = () => 0;
lz4Main.utils.blockChecksum = () => 0;
lz4Main.utils.streamChecksum = (d, c) => {
  if (c === null) return {};
  if (d === null) return 0;
  return c;
};

// Now re-export the patched lz4 so requiring 'lz4' from rbxm-parser gets
// the pure-JS version. We do this by patching the require cache.
const lz4ModulePath = require.resolve("lz4");
const cachedModule = require.cache[lz4ModulePath];
if (cachedModule) {
  cachedModule.exports.decodeBlock = pureBindings.uncompress;
  cachedModule.exports.encodeBound = pureBindings.compressBound;
  cachedModule.exports.encodeBlock = pureBindings.compress;
}

module.exports = { patched: true };
