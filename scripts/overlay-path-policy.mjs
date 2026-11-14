import { lstatSync, realpathSync } from 'node:fs';
import { isAbsolute, relative, resolve, sep } from 'node:path';

const relativePathPattern = /^(?:\.|[A-Za-z0-9._-]+(?:\/[A-Za-z0-9._-]+)*)$/;

/**
 * Resolve a catalog-owned provider path without following any symlink.
 *
 * A path may be absent (it is checked separately by the caller), but none of
 * its existing ancestors may be symlinks, even when a symlink points back into
 * the repository. This prevents a validated path from silently reading an
 * alternate provider target outside the reviewed Git tree.
 */
export function resolveOverlayPath(root, path) {
  if (typeof path !== 'string' || !relativePathPattern.test(path)) {
    throw new TypeError(`invalid relative path ${JSON.stringify(path)}`);
  }
  const canonicalRoot = realpathSync(root);
  let candidate = canonicalRoot;
  for (const segment of path.split('/')) {
    if (segment === '.') continue;
    if (segment === '..') throw new TypeError('path escapes repository root');
    candidate = resolve(candidate, segment);
    const rel = relative(canonicalRoot, candidate);
    if (rel === '..' || rel.startsWith(`..${sep}`) || isAbsolute(rel)) {
      throw new TypeError('path escapes repository root');
    }
    try {
      if (lstatSync(candidate).isSymbolicLink()) {
        throw new TypeError('provider overlay paths cannot contain symlinks');
      }
    } catch (error) {
      if (error?.code !== 'ENOENT') throw error;
    }
  }
  return candidate;
}
