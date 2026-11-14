import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';

import { resolveOverlayPath } from '../scripts/overlay-path-policy.mjs';

function fixture(run) {
  const root = mkdtempSync(join(tmpdir(), 'hhm-overlay-policy-'));
  try {
    mkdirSync(join(root, 'projects', 'verified'), { recursive: true });
    writeFileSync(join(root, 'projects', 'verified', 'target.json'), '{}');
    return run(root);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

test('accepts a reviewed overlay and a not-yet-created leaf', () => fixture((root) => {
  assert.equal(
    resolveOverlayPath(root, 'projects/verified/target.json'),
    join(root, 'projects', 'verified', 'target.json'),
  );
  assert.equal(
    resolveOverlayPath(root, 'projects/verified/new.json'),
    join(root, 'projects', 'verified', 'new.json'),
  );
}));

test('rejects absolute paths, traversal, and malformed segments', () => fixture((root) => {
  for (const path of [null, '', '../secrets', 'projects/../secrets', '/etc/passwd', 'projects//target.json', 'projects/\\target.json']) {
    assert.throws(() => resolveOverlayPath(root, path), TypeError, String(path));
  }
}));

test('refuses symlinked ancestor paths even if they point inside the repository', () => fixture((root) => {
  symlinkSync(join(root, 'projects', 'verified'), join(root, 'projects', 'alias'), 'dir');
  assert.throws(
    () => resolveOverlayPath(root, 'projects/alias/target.json'),
    /cannot contain symlinks/,
  );
}));

test('refuses external symlink ancestors and symlinked files', () => fixture((root) => {
  const outside = mkdtempSync(join(tmpdir(), 'hhm-overlay-outside-'));
  try {
    symlinkSync(outside, join(root, 'projects', 'external'), 'dir');
    assert.throws(() => resolveOverlayPath(root, 'projects/external/target.json'), /symlink/);
    symlinkSync(join(root, 'projects', 'verified', 'target.json'), join(root, 'projects', 'file-link.json'));
    assert.throws(() => resolveOverlayPath(root, 'projects/file-link.json'), /symlink/);
  } finally {
    rmSync(outside, { recursive: true, force: true });
  }
}));
