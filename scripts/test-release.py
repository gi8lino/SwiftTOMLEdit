"""Exercise release publication against disposable Git remotes, without GitHub writes."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/prepare-release.sh"
CHECKSUM = "a" * 64


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()


class ReleasePreparationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.remote = self.root / "remote.git"
        self.repo = self.root / "repo"
        subprocess.run(["git", "init", "--bare", str(self.remote)], check=True, capture_output=True)
        subprocess.run(["git", "init", "-b", "main", str(self.repo)], check=True, capture_output=True)
        git(self.repo, "config", "user.name", "Release test")
        git(self.repo, "config", "user.email", "release-test@example.invalid")
        git(self.repo, "config", "commit.gpgsign", "false")
        shutil.copy(ROOT / "Package.swift", self.repo / "Package.swift")
        for name in ["Sources", "Tests"]:
            shutil.copytree(ROOT / name, self.repo / name)
        git(self.repo, "add", ".")
        git(self.repo, "commit", "-m", "Source candidate")
        self.source = git(self.repo, "rev-parse", "HEAD")
        git(self.repo, "tag", "v0.2.2")
        git(self.repo, "remote", "add", "origin", str(self.remote))
        git(self.repo, "push", "origin", "main", "v0.2.2")

    def prepare(self, source=None):
        return subprocess.run(
            [str(SCRIPT), "v0.2.3", CHECKSUM, source or self.source],
            cwd=self.repo, capture_output=True, text=True,
            env={**os.environ, "GITHUB_OUTPUT": str(self.root / "outputs")},
        )

    def test_tag_contains_matching_metadata_and_preserves_existing_tag(self):
        result = self.prepare()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        commit = git(self.remote, "rev-parse", "refs/tags/v0.2.3")
        self.assertEqual(commit, git(self.remote, "rev-parse", "refs/heads/main"))
        self.assertEqual(self.source, git(self.remote, "rev-parse", "refs/tags/v0.2.2"))
        manifest = git(self.remote, "show", f"{commit}:Package.swift")
        self.assertIn('let releaseTag = "v0.2.3"', manifest)
        self.assertIn(f'let releaseChecksum = "{CHECKSUM}"', manifest)
        self.assertEqual(f"commit={commit}\n", (self.root / "outputs").read_text())
        # Repeating publication must neither move the old tag nor main.
        result = self.prepare(commit)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(commit, git(self.remote, "rev-parse", "refs/heads/main"))

    def test_main_changed_since_validation_is_rejected(self):
        (self.repo / "new-file").write_text("Later source\n")
        git(self.repo, "add", ".")
        git(self.repo, "commit", "-m", "Concurrent main change")
        later = git(self.repo, "rev-parse", "HEAD")
        git(self.repo, "push", "origin", "main")
        git(self.repo, "checkout", "--detach", self.source)
        self.assertNotEqual(self.prepare().returncode, 0)
        self.assertEqual(later, git(self.remote, "rev-parse", "refs/heads/main"))
        self.assertEqual("", git(self.remote, "tag", "--list", "v0.2.3"))

    def test_atomic_push_does_not_advance_main_if_tag_is_rejected(self):
        hook = self.remote / "hooks/update"
        hook.write_text('#!/bin/sh\ncase "$1" in refs/tags/*) exit 1;; esac\n')
        hook.chmod(0o755)
        result = self.prepare()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.source, git(self.remote, "rev-parse", "refs/heads/main"))
        self.assertEqual("", git(self.remote, "tag", "--list", "v0.2.3"))


if __name__ == "__main__":
    unittest.main()
